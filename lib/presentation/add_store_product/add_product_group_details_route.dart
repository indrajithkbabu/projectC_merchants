import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/bulk_photo_strip.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/bulk_photos_preview_sheet.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_spec_form.dart';

class AddProductGroupDetailsRoute extends StatefulWidget {
  const AddProductGroupDetailsRoute({
    super.key,
    required this.scope,
    this.itemId,
  });

  final BulkSpecScope scope;
  final String? itemId;

  @override
  State<AddProductGroupDetailsRoute> createState() =>
      _AddProductGroupDetailsRouteState();
}

class _AddProductGroupDetailsRouteState
    extends State<AddProductGroupDetailsRoute> {
  ProductSpec? _draft;
  final Map<String, TextEditingController> _titleControllers = {};
  TextEditingController? _groupTitleController;
  TextEditingController? _multiNameController;

  @override
  void dispose() {
    for (final controller in _titleControllers.values) {
      controller.dispose();
    }
    _groupTitleController?.dispose();
    _multiNameController?.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(BulkUploadItem item, String label) {
    final existing = _titleControllers[item.id];
    if (existing != null) return existing;
    final controller = TextEditingController(text: label);
    _titleControllers[item.id] = controller;
    return controller;
  }

  TextEditingController _groupController(String title) {
    final existing = _groupTitleController;
    if (existing != null) return existing;
    final controller = TextEditingController(text: title);
    _groupTitleController = controller;
    return controller;
  }

  TextEditingController _multiNameControllerFor(
    BulkUploadState state,
    List<BulkUploadItem> focusItems,
  ) {
    final existing = _multiNameController;
    if (existing != null) return existing;
    final controller = TextEditingController(
      text: _sharedMultiName(state, focusItems),
    );
    _multiNameController = controller;
    return controller;
  }

  String _sharedMultiName(
    BulkUploadState state,
    List<BulkUploadItem> focusItems,
  ) {
    if (focusItems.isEmpty) return state.groupTitle.trim();
    final customs =
        focusItems
            .map((item) => item.customTitle.trim())
            .where((title) => title.isNotEmpty)
            .toSet();
    if (customs.length == 1) return customs.first;
    final labels = focusItems.map(state.displayNameOf).toSet();
    if (labels.length == 1) return labels.first;
    return state.groupTitle.trim();
  }

  void _applyMultiName(String title, List<BulkUploadItem> focusItems) {
    final bloc = context.read<BulkUploadBloc>();
    for (final item in focusItems) {
      bloc.add(BulkUploadItemTitleChanged(itemId: item.id, title: title));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BulkUploadBloc, BulkUploadState>(
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<BulkUploadBloc>().add(const BulkUploadClearMessage());
          },
        ),
        BlocListener<BulkUploadBloc, BulkUploadState>(
          listenWhen:
              (prev, curr) =>
                  curr.shouldOpenPreview && !prev.shouldOpenPreview,
          listener: (context, state) {
            // Return to group route; it owns pushing preview so Done can
            // pop preview → group → store_profile with the published map.
            Navigator.of(context).pop('open_preview');
          },
        ),
        BlocListener<BulkUploadBloc, BulkUploadState>(
          listenWhen:
              (prev, curr) => curr.itemsBecameEmpty && !prev.itemsBecameEmpty,
          listener: (context, state) {
            context.read<BulkUploadBloc>().add(
              const BulkUploadClearItemsEmpty(),
            );
            Navigator.of(context).maybePop();
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<BulkUploadBloc, BulkUploadState>(
          builder: (context, state) {
            final focusItems = _focusItems(state);
            final count =
                widget.scope == BulkSpecScope.group
                    ? state.items.length
                    : focusItems.length;
            final draft = _draft;
            final canSubmit = draft != null && draft.isValid && count > 0;

            // Drop controllers for removed items.
            final liveIds = {for (final item in state.items) item.id};
            for (final id in _titleControllers.keys.toList()) {
              if (!liveIds.contains(id)) {
                _titleControllers.remove(id)?.dispose();
              }
            }

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppPadding.screen(
                      top: ScreenWrapper.statusBarTop(context),
                      bottom: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppBackButton(),
                            Expanded(
                              child: Text(
                                _screenTitle(state, count),
                                style: AppTextStyles.headline(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (widget.scope == BulkSpecScope.group)
                          _buildGroupHeader(state)
                        else if (widget.scope == BulkSpecScope.multi)
                          _buildMultiHeader(state, focusItems)
                        else
                          _buildEditableItems(state, focusItems),
                        const SizedBox(height: 18),
                        ProductSpecForm(
                          initial: state.specForScope(
                            scope: widget.scope,
                            itemId: widget.itemId,
                          ),
                          subtitle: _subtitle(count),
                          onChanged: (spec) {
                            setState(() => _draft = spec);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      border: Border(
                        top: BorderSide(color: AppColors.border, width: 0.7),
                      ),
                    ),
                    padding: AppPadding.screen(top: 10, bottom: 12),
                    child: PrimaryButton(
                      label: _submitLabel(count),
                      enabled: canSubmit,
                      onPressed: () {
                        final spec = _draft;
                        if (spec == null || !spec.isValid) return;
                        _submit(spec);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupHeader(BulkUploadState state) {
    final controller = _groupController(state.groupTitle);
    final paths = [for (final item in state.items) item.imagePath];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group title',
          style: AppTextStyles.label(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        TextField(
          controller: controller,
          onChanged:
              (value) => context.read<BulkUploadBloc>().add(
                BulkUploadTitleChanged(value),
              ),
          style: AppTextStyles.body(fontSize: 17, fontWeight: FontWeight.w600),
          decoration: _fieldDecoration(hint: 'e.g. Bridal ring collection'),
        ),
        if (paths.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Photos · ${paths.length}',
            style: AppTextStyles.label(
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          BulkPhotoStrip(
            paths: paths,
            onTap:
                (index) => showBulkPhotosPreviewSheet(
                  context: context,
                  initialIndex: index,
                  readOnly: state.isEditMode,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            state.isEditMode
                ? 'Tap a photo to crop, draw, or add text. Save on the preview screen.'
                : 'Refine individual photos from the preview after applying.',
            style: AppTextStyles.caption(),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiHeader(
    BulkUploadState state,
    List<BulkUploadItem> focusItems,
  ) {
    if (focusItems.isEmpty) {
      return Text(
        'No items selected.',
        style: AppTextStyles.bodySecondary(),
      );
    }

    final paths = [for (final item in focusItems) item.imagePath];
    final nameController = _multiNameControllerFor(state, focusItems);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name',
          style: AppTextStyles.label(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        TextField(
          controller: nameController,
          onChanged: (value) => _applyMultiName(value, focusItems),
          style: AppTextStyles.body(fontSize: 17, fontWeight: FontWeight.w600),
          decoration: _fieldDecoration(hint: 'Item name'),
        ),
        const SizedBox(height: 16),
        Text(
          'Photos · ${paths.length}',
          style: AppTextStyles.label(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 10),
        BulkPhotoStrip(
          paths: paths,
          onTap: (index) {
            final ids = {
              for (final item in focusItems) item.id,
            };
            showBulkPhotosPreviewSheet(
              context: context,
              initialIndex: index,
              readOnly: state.isEditMode,
              onlyItemIds: ids,
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Same name and details will apply to all selected photos.',
          style: AppTextStyles.caption(),
        ),
      ],
    );
  }

  Widget _buildEditableItems(
    BulkUploadState state,
    List<BulkUploadItem> focusItems,
  ) {
    if (focusItems.isEmpty) {
      return Text(
        'No items selected.',
        style: AppTextStyles.bodySecondary(),
      );
    }

    // Single-item refine only — multi uses the shared photo strip header.
    final item = focusItems.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item',
          style: AppTextStyles.label(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 10),
        _EditableItemCard(
          item: item,
          titleController: _controllerFor(item, state.displayNameOf(item)),
          canRemove: state.items.length > 1,
          busy: false,
          onTitleChanged:
              (value) => context.read<BulkUploadBloc>().add(
                BulkUploadItemTitleChanged(itemId: item.id, title: value),
              ),
          onPreviewImage: () {
            final index = state.items.indexWhere((entry) => entry.id == item.id);
            showBulkPhotosPreviewSheet(
              context: context,
              initialIndex: index < 0 ? 0 : index,
              readOnly: state.isEditMode,
            );
          },
          onRemove:
              () => context.read<BulkUploadBloc>().add(
                BulkUploadItemRemoved(item.id),
              ),
        ),
      ],
    );
  }

  List<BulkUploadItem> _focusItems(BulkUploadState state) {
    switch (widget.scope) {
      case BulkSpecScope.group:
        return state.items;
      case BulkSpecScope.single:
        return state.items
            .where((item) => item.id == widget.itemId)
            .toList(growable: false);
      case BulkSpecScope.multi:
        final selected = state.selectedItemIds.toSet();
        return state.items
            .where((item) => selected.contains(item.id))
            .toList(growable: false);
    }
  }

  String _screenTitle(BulkUploadState state, int count) {
    switch (widget.scope) {
      case BulkSpecScope.group:
        return 'Group details';
      case BulkSpecScope.single:
        return 'Item details';
      case BulkSpecScope.multi:
        return 'Edit $count items';
    }
  }

  String _subtitle(int count) {
    switch (widget.scope) {
      case BulkSpecScope.group:
        return 'Applies rough details to all $count items at once. Refine any item later for precise data.';
      case BulkSpecScope.single:
        return 'Precise details for this item only. Saving marks it as Precise.';
      case BulkSpecScope.multi:
        return 'Applies to the selected items only. They’ll be marked Precise.';
    }
  }

  String _submitLabel(int count) {
    switch (widget.scope) {
      case BulkSpecScope.group:
        return 'Apply to all $count items';
      case BulkSpecScope.single:
        return 'Save precise details';
      case BulkSpecScope.multi:
        return 'Apply to $count items';
    }
  }

  void _submit(ProductSpec spec) {
    final bloc = context.read<BulkUploadBloc>();
    switch (widget.scope) {
      case BulkSpecScope.group:
        bloc.add(BulkUploadApplyGroupSpec(spec));
      case BulkSpecScope.single:
        final id = widget.itemId;
        if (id == null) return;
        bloc.add(BulkUploadApplyItemSpec(itemId: id, spec: spec));
        Navigator.of(context).maybePop();
      case BulkSpecScope.multi:
        bloc.add(BulkUploadApplyMultiSpec(spec));
        Navigator.of(context).maybePop();
    }
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.hint(fontSize: 16, fontWeight: FontWeight.w400),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }
}

class _EditableItemCard extends StatelessWidget {
  const _EditableItemCard({
    required this.item,
    required this.titleController,
    required this.canRemove,
    required this.busy,
    required this.onTitleChanged,
    required this.onPreviewImage,
    required this.onRemove,
  });

  final BulkUploadItem item;
  final TextEditingController titleController;
  final bool canRemove;
  final bool busy;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onPreviewImage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: busy ? null : onPreviewImage,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: ProductMediaImage(path: item.imagePath),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Name',
                  style: AppTextStyles.caption(fontWeight: FontWeight.w600),
                ),
                TextField(
                  controller: titleController,
                  onChanged: onTitleChanged,
                  style: AppTextStyles.body(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Item name',
                    hintStyle: AppTextStyles.hint(fontSize: 15),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: busy ? null : onPreviewImage,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Photos',
                        style: AppTextStyles.label(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    if (canRemove) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: busy ? null : onRemove,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Remove',
                          style: AppTextStyles.label(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
