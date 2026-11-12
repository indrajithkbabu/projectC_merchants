import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/profile_context.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/store/store_repository.dart';

/// Owner Staff list (UI 5.2 / 5.4): Add staff → Owner · You → Staff → Invited.
class StaffListRoute extends StatefulWidget {
  const StaffListRoute({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  final String storeId;
  final String storeName;

  @override
  State<StaffListRoute> createState() => _StaffListRouteState();
}

class _StaffListRouteState extends State<StaffListRoute> {
  final _repo = ServiceLocator.get<StoreRepository>();
  List<StaffListRow> _rows = const [];
  /// Thin bar under app bar — never blanks an already-visible list.
  bool _busy = false;
  bool _hasLoadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await _repo.fetchStaff(storeId: widget.storeId);
      final rows = List<StaffListRow>.from(page.items);
      rows.sort((a, b) {
        int rank(StaffListRow r) {
          if (r.isOwner) return 0;
          if (r.isInvitation) return 2;
          return 1;
        }

        final cmp = rank(a).compareTo(rank(b));
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (!mounted) return;
      final owners = rows.where((r) => r.isOwner).length;
      final invited = rows.where((r) => r.isInvitation).length;
      final staff = rows.length - owners - invited;
      ProfileSwitchingLog.d(
        'PS-40',
        'staff list loaded store=${widget.storeId} '
        'order=AddStaff→Owner→Staff→Invited '
        'owners=$owners staff=$staff invited=$invited',
      );
      setState(() {
        _rows = rows;
        _busy = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hasLoadedOnce = true;
        // Keep prior rows on soft refresh failure; only block empty first load.
        if (_rows.isEmpty) {
          _error = CatalogErrorMapper.toUserMessage(e);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
          );
        }
      });
    }
  }

  Future<void> _openAddStaff() async {
    ProfileSwitchingLog.d(
      'PS-41/42',
      'Staff → Add staff store=${widget.storeId}',
    );
    final result = await Navigator.of(context).pushNamed(
      Routes.addTeamRoute,
      arguments: <String, Object?>{
        'storeName': widget.storeName,
        'returnToProfile': true,
        'storeId': widget.storeId,
      },
    );
    if (!mounted) return;
    if (result == true) {
      // List refresh shows Invited rows — no success snackbar.
      await _load();
    }
  }

  Future<void> _onRowTap(StaffListRow row) async {
    if (row.isYou || row.isOwner) return;
    if (row.isInvitation) {
      final inviteId = row.invitationId?.trim() ?? row.id.trim();
      if (inviteId.isEmpty) return;
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Revoke invite',
                    style: AppTextStyles.body(color: AppColors.error),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('revoke'),
                ),
                ListTile(
                  title: Text('Cancel', style: AppTextStyles.body()),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          );
        },
      );
      if (action != 'revoke' || !mounted) return;
      try {
        ProfileSwitchingLog.d(
          'PS-47',
          'revoke invite id=$inviteId store=${widget.storeId}',
        );
        setState(() => _busy = true);
        await _repo.revokeInvitation(
          storeId: widget.storeId,
          invitationId: inviteId,
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
        );
      }
      return;
    }

    final userId = row.userId?.trim() ?? '';
    if (userId.isEmpty || !row.canRemove) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Remove ${row.name}',
                  style: AppTextStyles.body(color: AppColors.error),
                ),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
              ListTile(
                title: Text('Cancel', style: AppTextStyles.body()),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
    if (action != 'remove' || !mounted) return;
    try {
      ProfileSwitchingLog.d(
        'PS-46/55/72',
        'remove staff userId=$userId store=${widget.storeId} '
        '(owner should stay on own store)',
      );
      setState(() => _busy = true);
      await _repo.removeMember(storeId: widget.storeId, userId: userId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showErrorOnly = _error != null && _rows.isEmpty && _hasLoadedOnce;

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: AppPadding.screen(
              top: ScreenWrapper.statusBarTop(context),
              bottom: 8,
            ),
            child: Row(
              children: [
                AppBackButton(onPressed: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Text(
                    'Staff',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headline(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          if (_busy)
            LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceSecondary,
            )
          else
            const SizedBox(height: 2),
          if (showErrorOnly)
            Expanded(
              child: Center(
                child: Padding(
                  padding: AppPadding.screenHorizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: AppTextStyles.bodySecondary()),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: Text('Retry', style: AppTextStyles.button()),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView(
                  padding: AppPadding.screen(bottom: 24),
                  children: [
                    ListTile(
                      onTap: _busy ? null : _openAddStaff,
                      splashColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.surfaceSecondary,
                        child: Icon(
                          Icons.add_rounded,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      title: Text(
                        'Add staff',
                        style: AppTextStyles.body(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.divider),
                    for (final row in _rows) ...[
                      ListTile(
                        onTap: _busy ? null : () => _onRowTap(row),
                        splashColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        leading: _StaffAvatar(row: row),
                        title: Text(
                          row.name,
                          style: AppTextStyles.body(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          row.statusLabel,
                          style: AppTextStyles.caption(),
                        ),
                      ),
                      Divider(height: 1, color: AppColors.divider),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffAvatar extends StatelessWidget {
  const _StaffAvatar({required this.row});

  final StaffListRow row;

  @override
  Widget build(BuildContext context) {
    final url = row.avatarUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return CatalogNetworkAvatar(
        url: url,
        size: 44,
        backgroundColor: AppColors.surfaceSecondary,
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.8),
      child: Text(
        row.displayInitials,
        style: AppTextStyles.caption(
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
