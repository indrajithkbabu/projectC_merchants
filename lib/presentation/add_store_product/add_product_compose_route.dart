import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/jewel_upload_qa.dart';
import 'package:project_c/helper/product_gallery_picker.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/product_image_cropper.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/product_image_editor_page.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/compose_overlay_widgets.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/compose_weight_scale.dart';
import 'package:project_c/presentation/add_store_product/compose_product_draft.dart';

/// Debug-only compose open timeline. Search logcat for `[ComposeNavPerf]`.
void _composeNavPerf(String stage, {int? n, Stopwatch? sw}) {
  if (!kDebugMode) return;
  final ms = sw == null ? '' : ' +${sw.elapsedMilliseconds}ms';
  final count = n == null ? '' : ' n=$n';
  debugPrint('[ComposeNavPerf]$ms $stage$count');
}

/// Post-gallery compose: full-bleed photo + right rail + weight/tags.
/// Send keeps existing gates — incomplete specs → title-only; valid → preview.
///
/// When [returnResult] is true (refine / preview Edit), send pops drafts back
/// to the caller instead of starting the create handoff.
class AddProductComposeRoute extends StatefulWidget {
  const AddProductComposeRoute({
    super.key,
    required this.imagePaths,
    this.storeId,
    this.initialIndex = 0,
    this.initialDrafts = const [],
    this.itemIds = const [],
    this.returnResult = false,
    this.allowAddDelete = true,
    this.importMode = false,
    this.sourceStoreId = '',
    this.sourceStoreName = '',
    this.sourceProductIds = const [],
    this.sourceLocked = const [],
  });

  final List<String> imagePaths;
  final String? storeId;
  final int initialIndex;

  /// Parallel to [imagePaths] when refining existing items.
  final List<ComposePhotoDraft> initialDrafts;
  final List<String> itemIds;

  /// Pop drafts/paths for the caller (preview Edit) instead of create flow.
  final bool returnResult;

  /// False in edit-refine (add/delete stay on preview / metadata edit).
  final bool allowAddDelete;

  /// Quick import review. Same controls as upload. Stock stays the source's.
  /// A source lock cannot be turned off. "All" applies the next edit only.
  final bool importMode;
  final String sourceStoreId;
  final String sourceStoreName;

  /// Parallel to the opened photos. Kept in step with deletes.
  final List<String> sourceProductIds;
  final List<bool> sourceLocked;

  @override
  State<AddProductComposeRoute> createState() => _AddProductComposeRouteState();
}

class _AddProductComposeRouteState extends State<AddProductComposeRoute> {
  late final PageController _pageController;
  late final TextEditingController _tagController;
  late final TextEditingController _grossMinController;
  late final TextEditingController _grossMaxController;
  late final TextEditingController _stoneController;
  late final TextEditingController _sizeController;
  late final FocusNode _tagFocus;
  late final FocusNode _tagBackspaceFocus;
  late final FocusNode _grossFocus;
  late List<String> _paths;
  late List<ComposePhotoDraft> _drafts;
  late int _page;
  bool _editing = false;
  bool _picking = false;
  bool _thumbsReady = false;
  bool _applyToAll = true;
  bool _showStone = false;
  /// When range is on, which end the scale edits.
  bool _editingRangeMax = false;
  ComposeRailFlyout _flyout = ComposeRailFlyout.none;
  final Stopwatch _openSw = Stopwatch();
  bool _loggedFirstFrame = false;
  bool _loggedHeroFrame = false;
  bool _loggedThumbs = false;
  bool _didPrecacheHero = false;
  bool _syncingFields = false;
  late List<String> _sourceProductIds;
  late List<bool> _sourceLocked;
  late List<ComposeStockStatus> _sourceStock;
  late List<int> _sourceMto;

  ComposePhotoDraft get _draft =>
      _drafts[_page.clamp(0, _drafts.length - 1)];

  @override
  void initState() {
    super.initState();
    _openSw.start();
    _paths = [
      for (final p in widget.imagePaths)
        if (p.trim().isNotEmpty) p.trim(),
    ];
    final seeded = widget.initialDrafts;
    _drafts = [
      for (var i = 0; i < _paths.length; i++)
        i < seeded.length ? seeded[i] : ComposePhotoDraft.defaults(),
    ];
    // Import keeps each source photo's own details. "This photo" is the start.
    if (widget.importMode) {
      _applyToAll = false;
      _sourceProductIds = [
        for (var i = 0; i < _paths.length; i++)
          i < widget.sourceProductIds.length
              ? widget.sourceProductIds[i]
              : '',
      ];
      _sourceLocked = [
        for (var i = 0; i < _paths.length; i++)
          i < widget.sourceLocked.length && widget.sourceLocked[i],
      ];
      _drafts = [
        for (var i = 0; i < _drafts.length; i++)
          _sourceLocked[i] ? _drafts[i].copyWith(isLocked: true) : _drafts[i],
      ];
    } else {
      _sourceProductIds = const [];
      _sourceLocked = const [];
    }
    _sourceStock = [for (final d in _drafts) d.stockStatus];
    _sourceMto = [for (final d in _drafts) d.mtoDays];
    // Multi-photo refine with different drafts → This photo; else All.
    if (!widget.importMode &&
        widget.returnResult &&
        _drafts.length > 1 &&
        _drafts.any((d) => d != _drafts.first)) {
      _applyToAll = false;
    }
    _composeNavPerf('compose_initState', n: _paths.length, sw: _openSw);
    final start =
        _paths.isEmpty ? 0 : widget.initialIndex.clamp(0, _paths.length - 1);
    _page = start;
    _pageController = PageController(initialPage: start);
    _tagController = TextEditingController();
    _grossMinController = TextEditingController();
    _grossMaxController = TextEditingController();
    _stoneController = TextEditingController();
    _sizeController = TextEditingController();
    _tagFocus = FocusNode();
    _grossFocus = FocusNode();
    _tagBackspaceFocus = FocusNode();
    _grossFocus.addListener(() {
      if (!mounted) return;
      if (!_grossFocus.hasFocus) _onGrossChanged();
      setState(() {});
    });
    _tagController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadFieldsFromDraft();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loggedFirstFrame) return;
      _loggedFirstFrame = true;
      _composeNavPerf('compose_first_post_frame', n: _paths.length, sw: _openSw);
      Future<void>.delayed(const Duration(milliseconds: 480), () {
        if (mounted) _revealThumbs();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheHero || _paths.isEmpty) return;
    _didPrecacheHero = true;
    final path = _paths[_page.clamp(0, _paths.length - 1)];
    if (ProductImagePaths.isNetwork(path)) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = MediaQuery.sizeOf(context).width;
    final cacheWidth = ProductGalleryPicker.composeHeroDecodeWidth(
      logicalWidth: logicalW,
      dpr: dpr,
    );
    unawaited(
      precacheImage(
        ResizeImage(FileImage(File(path)), width: cacheWidth),
        context,
      ).then((_) {}, onError: (Object _, StackTrace __) {}),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tagController.dispose();
    _grossMinController.dispose();
    _grossMaxController.dispose();
    _stoneController.dispose();
    _sizeController.dispose();
    _tagFocus.dispose();
    _tagBackspaceFocus.dispose();
    _grossFocus.dispose();
    super.dispose();
  }

  void _revealThumbs() {
    if (_thumbsReady || !mounted || _paths.length <= 1) return;
    setState(() => _thumbsReady = true);
    if (!_loggedThumbs) {
      _loggedThumbs = true;
      _composeNavPerf(
        'compose_thumb_strip_built',
        n: _paths.length,
        sw: _openSw,
      );
    }
  }

  void _onHeroFrame() {
    if (_loggedHeroFrame) return;
    _loggedHeroFrame = true;
    _composeNavPerf('compose_hero_first_frame', n: _paths.length, sw: _openSw);
    _revealThumbs();
  }

  void _loadFieldsFromDraft() {
    _syncingFields = true;
    final s = _draft.spec;
    _grossMinController.text =
        s.grossMin == null ? '' : _numText(s.grossMin!);
    _grossMaxController.text =
        s.grossMax == null ? '' : _numText(s.grossMax!);
    _stoneController.text =
        s.reduction == null || !s.deductStone ? '' : _numText(s.reduction!);
    _sizeController.text = s.sizeValue == null ? '' : _numText(s.sizeValue!);
    _showStone = s.deductStone && (s.reduction ?? 0) > 0;
    _syncingFields = false;
  }

  static String _numText(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
      RegExp(r'\.$'),
      '',
    );
  }

  void _updateDraft(
    ComposePhotoDraft Function(ComposePhotoDraft d) transform, {
    bool reloadFields = false,
  }) {
    setState(() {
      if (_applyToAll) {
        _drafts = [
          for (var i = 0; i < _drafts.length; i++)
            _guardImport(i, transform(_drafts[i])),
        ];
      } else {
        final i = _page.clamp(0, _drafts.length - 1);
        _drafts[i] = _guardImport(i, transform(_drafts[i]));
      }
      if (reloadFields) _loadFieldsFromDraft();
    });
  }

  void _setFlyout(ComposeRailFlyout next) {
    setState(() {
      _flyout = _flyout == next ? ComposeRailFlyout.none : next;
    });
    _tagFocus.unfocus();
  }

  void _closeFlyout() {
    if (_flyout == ComposeRailFlyout.none) return;
    setState(() => _flyout = ComposeRailFlyout.none);
  }

  void _advanceAfter(ComposeRailFlyout from) {
    if (!kComposeAutoAdvance) {
      _closeFlyout();
      return;
    }
    final d = _draft;
    ComposeRailFlyout next = ComposeRailFlyout.none;
    if (from == ComposeRailFlyout.metal) {
      next = ComposeRailFlyout.purity;
    } else if (from == ComposeRailFlyout.purity) {
      if (d.spec.wastagePercent == null) {
        next = ComposeRailFlyout.wastage;
      } else if (d.spec.category.trim().isEmpty) {
        next = ComposeRailFlyout.category;
      }
    } else if (from == ComposeRailFlyout.wastage) {
      if (d.spec.category.trim().isEmpty) {
        next = ComposeRailFlyout.category;
      }
    }
    setState(() => _flyout = next);
  }

  Future<void> _openEdit() async {
    if (_editing || _picking || _paths.isEmpty) return;
    final index = _page.clamp(0, _paths.length - 1);
    setState(() => _editing = true);
    try {
      // Full editor: crop / mark / text (same ProductImageEditorPage).
      final edited = await ProductImageCropper.cropOne(
        _paths[index],
        context: context,
        title:
            _paths.length == 1
                ? 'Edit photo'
                : 'Edit ${index + 1} of ${_paths.length}',
        initialTool: ProductImageEditTool.none,
      );
      if (!mounted || edited == null || edited.trim().isEmpty) return;
      if (edited == _paths[index]) return;
      setState(() => _paths[index] = edited);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  /// Gallery / camera append — same picker as store-profile Add products.
  Future<void> _addPhotos() async {
    if (!widget.allowAddDelete || _editing || _picking) return;
    final room = ProductGalleryPicker.maxAssets - _paths.length;
    if (room <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can add up to ${ProductGalleryPicker.maxAssets} photos.',
          ),
        ),
      );
      return;
    }
    setState(() => _picking = true);
    try {
      final picked = await ProductGalleryPicker.pickImagePaths(
        context,
        includeCamera: true,
      );
      if (!mounted || picked.isEmpty) return;
      final existing = _paths.map((p) => p.trim()).toSet();
      final toAdd = <String>[
        for (final p in picked)
          if (p.trim().isNotEmpty && !existing.contains(p.trim())) p.trim(),
      ];
      if (toAdd.isEmpty) return;
      if (toAdd.length > room) {
        toAdd.removeRange(room, toAdd.length);
      }
      // All-scope: new photos inherit current details; This-photo: defaults.
      final seed = _applyToAll ? _draft : ComposePhotoDraft.defaults();
      final jumpTo = _paths.length;
      setState(() {
        _paths = [..._paths, ...toAdd];
        _drafts = [
          ..._drafts,
          for (var i = 0; i < toAdd.length; i++) seed.copyWith(),
        ];
        _page = jumpTo.clamp(0, _paths.length - 1);
        if (_paths.length > 1) _thumbsReady = true;
        _loadFieldsFromDraft();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(_page);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open image picker right now.')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _deleteCurrent() {
    if (!widget.allowAddDelete || _paths.isEmpty) return;
    if (_paths.length == 1) {
      Navigator.of(context).maybePop();
      return;
    }
    final i = _page.clamp(0, _paths.length - 1);
    setState(() {
      _paths.removeAt(i);
      _drafts.removeAt(i);
      _dropImportMeta(i);
      _page = _page.clamp(0, _paths.length - 1);
      _loadFieldsFromDraft();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;
      _pageController.jumpToPage(_page);
    });
  }

  void _onGrossChanged() {
    if (_syncingFields) return;
    final min = double.tryParse(_grossMinController.text.trim());
    final max = double.tryParse(_grossMaxController.text.trim());
    final stone = double.tryParse(_stoneController.text.trim());
    _updateDraft((d) {
      final mode = d.spec.weightMode;
      final s = d.spec;
      return d.copyWith(
        spec: ProductSpec(
          weightMode: mode,
          grossMin: min,
          grossMax: mode == WeightMode.range ? max : min,
          deductStone: _showStone && stone != null && stone > 0,
          reduction: _showStone ? stone : null,
          purityMode: s.purityMode,
          purity: s.purity,
          wastageMode: s.wastageMode,
          wastagePercent: s.wastagePercent,
          sizeMode: s.sizeMode,
          sizeValue: s.sizeValue,
          sizeUnit: s.sizeUnit,
          customUnit: s.customUnit,
          metalType: s.metalType,
          category: s.category,
        ),
      );
    });
  }

  void _commitTagField() {
    final raw = _tagController.text;
    if (raw.trim().isEmpty) return;
    _tagController.clear();
    _updateDraft((d) => addProductNames(d, raw));
  }

  void _onTagChanged(String raw) {
    // Comma commits preceding name(s); keep typing after the last comma.
    if (!raw.contains(',')) return;
    final parts = raw.split(',');
    final complete = parts.sublist(0, parts.length - 1).join(',');
    final rest = parts.last;
    if (complete.trim().isEmpty) {
      _tagController.value = TextEditingValue(
        text: rest,
        selection: TextSelection.collapsed(offset: rest.length),
      );
      return;
    }
    _updateDraft((d) => addProductNames(d, complete));
    _tagController.value = TextEditingValue(
      text: rest,
      selection: TextSelection.collapsed(offset: rest.length),
    );
  }

  String _fmtWeight(double v) {
    final t = v.toStringAsFixed(2);
    if (t.endsWith('0') && !t.endsWith('.00')) {
      return v.toStringAsFixed(1);
    }
    if (t.endsWith('.00')) return v.toStringAsFixed(1);
    return t;
  }

  /// Controllers only while flinging — no setState (keeps dial smooth).
  void _previewGrossFromScale(double gross) {
    final s = _draft.spec;
    var min = s.grossMin ?? 0.5;
    var max = s.grossMax ?? min;
    if (s.weightMode == WeightMode.range) {
      if (_editingRangeMax) {
        max = gross;
        if (max < min) min = max;
      } else {
        min = gross;
        if (min > max) max = min;
      }
    } else {
      min = gross;
      max = gross;
    }
    _grossMinController.text = _fmtWeight(min);
    _grossMaxController.text = _fmtWeight(max);
  }

  void _setGrossFromScale(double gross) {
    final s = _draft.spec;
    var min = s.grossMin ?? 0.5;
    var max = s.grossMax ?? min;
    if (s.weightMode == WeightMode.range) {
      if (_editingRangeMax) {
        max = gross;
        if (max < min) min = max; // push the other end
      } else {
        min = gross;
        if (min > max) max = min;
      }
    } else {
      min = gross;
      max = gross;
    }
    final stone = double.tryParse(_stoneController.text.trim()) ?? 0.0;
    final clampedStone =
        _showStone
            ? stone.clamp(0.0, math.max(0.0, min)).toDouble()
            : 0.0;
    _grossMinController.text = _fmtWeight(min);
    _grossMaxController.text = _fmtWeight(max);
    if (_showStone) {
      _stoneController.text = _fmtWeight(clampedStone);
    }
    _updateDraft(
      (d) => d.copyWith(
        spec: d.spec.copyWith(
          weightMode: s.weightMode,
          grossMin: min,
          grossMax: max,
          deductStone: _showStone && clampedStone > 0,
          reduction: clampedStone,
        ),
      ),
    );
  }

  void _setStoneFromScale(double stone) {
    final gross = _draft.spec.grossMin ?? 0.5;
    final clamped = stone.clamp(0.0, gross).toDouble();
    _stoneController.text = _fmtWeight(clamped);
    _updateDraft(
      (d) => d.copyWith(
        spec: d.spec.copyWith(
          deductStone: clamped > 0,
          reduction: clamped,
        ),
      ),
    );
  }

  void _toggleScope() {
    final toAll = !_applyToAll;
    setState(() {
      // Upload copies the current photo onto the rest. Import must not:
      // that would erase each source product's own details. All only means
      // the next edit lands on every photo.
      if (toAll && !widget.importMode) {
        final current = _draft;
        _drafts = [for (final _ in _drafts) current];
      }
      _applyToAll = toAll;
    });
  }

  /// Locked-by-source: stock stays source; lock cannot clear.
  /// Unlocked: importer may edit stock (quick-import-api.md).
  ComposePhotoDraft _guardImport(int i, ComposePhotoDraft next) {
    if (!widget.importMode) return next;
    final lockedBySource = i < _sourceLocked.length && _sourceLocked[i];
    if (!lockedBySource) {
      return next.copyWith(isLocked: next.isLocked);
    }
    final stock =
        i < _sourceStock.length ? _sourceStock[i] : next.stockStatus;
    final mto = i < _sourceMto.length ? _sourceMto[i] : next.mtoDays;
    return next.copyWith(
      stockStatus: stock,
      mtoDays: mto,
      isLocked: true,
    );
  }

  bool get _currentSourceLocked {
    if (!widget.importMode || _paths.isEmpty) return false;
    final i = _page.clamp(0, _paths.length - 1);
    return i < _sourceLocked.length && _sourceLocked[i];
  }

  void _dropImportMeta(int i) {
    if (!widget.importMode) return;
    if (i < _sourceProductIds.length) _sourceProductIds.removeAt(i);
    if (i < _sourceLocked.length) _sourceLocked.removeAt(i);
    if (i < _sourceStock.length) _sourceStock.removeAt(i);
    if (i < _sourceMto.length) _sourceMto.removeAt(i);
  }

  String get _sourceName {
    final name = widget.sourceStoreName.trim();
    return name.isEmpty ? 'the source store' : name;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? get _importNotice {
    if (!widget.importMode || _paths.isEmpty) return null;
    final i = _page.clamp(0, _paths.length - 1);
    if (i < _sourceLocked.length && _sourceLocked[i]) {
      return 'Locked by $_sourceName · lists after they approve';
    }
    if (_draft.stockStatus == ComposeStockStatus.outOfStock) {
      return 'Out of stock at $_sourceName · status follows them';
    }
    return null;
  }

  void _send() {
    if (_paths.isEmpty) return;
    _commitTagField();
    if (widget.importMode) {
      Navigator.of(context).pop(<String, Object?>{
        'quickImport': true,
        'imagePaths': List<String>.from(_paths),
        'photoDrafts': List<ComposePhotoDraft>.from(_drafts),
        'sourceProductIds': List<String>.from(_sourceProductIds),
        'sourceLocked': List<bool>.from(_sourceLocked),
        'sourceStoreId': widget.sourceStoreId,
        'sourceStoreName': widget.sourceStoreName,
      });
      return;
    }
    final draft = _draft;
    final title = composeTitleFromDraft(draft);
    JewelUploadQa.step(
      'Compose send',
      detail:
          'photos=${_paths.length} applyToAll=$_applyToAll '
          'specValid=${draft.spec.isValid} stock=${draft.stockStatus.name} '
          'locked=${draft.isLocked} title="$title"'
          '${widget.returnResult ? ' returnResult=true' : ''} '
          'perPhoto=${[
            for (var i = 0; i < _drafts.length; i++)
              '[$i]=${_drafts[i].stockStatus.name}/L=${_drafts[i].isLocked}',
          ].join(' ')}',
    );
    if (widget.returnResult) {
      Navigator.of(context).pop(<String, Object?>{
        'returnResult': true,
        'itemIds': List<String>.from(widget.itemIds),
        'imagePaths': List<String>.from(_paths),
        'photoDrafts': List<ComposePhotoDraft>.from(_drafts),
        'applyToAll': _applyToAll,
        'initialTitle': title,
        'tags': draft.tags,
        'groupSpec': draft.spec,
        'stockStatus': draft.stockStatus.name,
        'mtoDays': draft.mtoDays,
        'isLocked': draft.isLocked,
      });
      return;
    }
    final items = <GalleryImageItem>[
      for (var i = 0; i < _paths.length; i++)
        GalleryImageItem(
          id: 'compose_${_paths[i].hashCode}_$i',
          filePath: _paths[i],
          isPlaceholder: false,
        ),
    ];
    Navigator.of(context).pop(<String, Object?>{
      'selectedItems': items,
      'storeId': widget.storeId,
      'initialTitle': title,
      'tags': draft.tags,
      'groupSpec': draft.spec,
      'composeOverlay': true,
      'stockStatus': draft.stockStatus.name,
      'mtoDays': draft.mtoDays,
      'isLocked': draft.isLocked,
      'applyToAll': _applyToAll,
      // Per-photo drafts for This-photo mode (and All — same list).
      'photoDrafts': List<ComposePhotoDraft>.from(_drafts),
    });
  }

  String get _metal {
    final m = _draft.spec.metalType;
    return m.isEmpty ? 'gold' : m.first;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = ScreenWrapper.statusBarTop(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final count = _paths.length;
    final pageLabel = count <= 1 ? null : '${_page + 1} / $count';
    final d = _draft;
    final spec = d.spec;

    return ScreenWrapper(
      backgroundColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      // Keep the photo full-bleed; keyboard overlays instead of shrinking it.
      resizeToAvoidBottomInset: false,
      child: Theme(
        data: composeOverlayInputTheme(context),
        child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed photo (swipe between photos; no pinch-zoom)
          Positioned.fill(
            child:
                count == 0
                    ? Center(
                      child: Text(
                        'No photos',
                        style: AppTextStyles.body(color: Colors.white70),
                      ),
                    )
                    : PageView.builder(
                      controller: _pageController,
                      itemCount: count,
                      allowImplicitScrolling: false,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (i) {
                        _tagFocus.unfocus();
                        setState(() {
                          _page = i;
                          _flyout = ComposeRailFlyout.none;
                          _loadFieldsFromDraft();
                        });
                      },
                      itemBuilder: (context, index) {
                        final isHero = index == _page;
                        return _ComposePhoto(
                          key: ValueKey<String>(_paths[index]),
                          path: _paths[index],
                          onFirstFrame: isHero ? _onHeroFrame : null,
                          onTap: _closeFlyout,
                        );
                      },
                    ),
          ),

          // Top scrim — keeps chrome readable on bright photos.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPad + 72,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: topPad,
            left: 0,
            right: 0,
            child: Padding(
              padding: AppPadding.screenHorizontal,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    ComposeFrostCircle(
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.center,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    if (widget.importMode)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'From $_sourceName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.caption(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              if (pageLabel != null)
                                Text(
                                  pageLabel,
                                  style: AppTextStyles.caption(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      const Spacer(),
                      if (pageLabel != null)
                        ComposeFrostPill(
                          child: Text(
                            pageLabel,
                            style: AppTextStyles.caption(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      const Spacer(),
                    ],
                    ComposeFrostCircle(
                      child: IconButton(
                        tooltip: 'Crop',
                        onPressed:
                            _editing || _picking || count == 0
                                ? null
                                : _openEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ),
                        icon: Icon(
                          Icons.crop_rounded,
                          color:
                              (_editing || _picking)
                                  ? Colors.white38
                                  : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    if (widget.allowAddDelete && !widget.importMode) ...[
                      const SizedBox(width: 8),
                      ComposeFrostCircle(
                        child: IconButton(
                          tooltip: 'Add photos',
                          onPressed:
                              _editing || _picking ? null : _addPhotos,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          icon: Icon(
                            Icons.add_rounded,
                            color: _picking ? Colors.white38 : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                    if (widget.allowAddDelete) ...[
                      const SizedBox(width: 8),
                      ComposeFrostCircle(
                        child: IconButton(
                          tooltip: 'Delete',
                          onPressed:
                              _editing || _picking || count == 0
                                  ? null
                                  : _deleteCurrent,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color:
                                (_editing || _picking)
                                    ? Colors.white38
                                    : Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Net / gross weight readout (top-left, under close).
          Positioned(
            top: topPad + 52,
            left: AppPadding.horizontal,
            right: 72,
            child: _buildWeightReadout(spec),
          ),

          // Right rail only (no full-width hit target over the photo).
          Positioned(
            top: topPad + 56,
            right: 8,
            bottom: 210 + bottomPad + keyboardInset,
            child: _buildRail(d, spec),
          ),

          // Bottom: thumbs / scope / weight / tags / send
          // Lifts with the keyboard; photo underneath stays full-size.
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardInset,
            child: GestureDetector(
              onTap: _closeFlyout,
              behavior: HitTestBehavior.translucent,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  AppPadding.horizontal,
                  8,
                  AppPadding.horizontal,
                  10 + bottomPad,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0, 0.35, 1],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_importNotice != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _importNotice!,
                            style: AppTextStyles.caption(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (count > 1) ...[
                      Row(
                        children: [
                          ComposeScopePill(
                            applyToAll: _applyToAll,
                            count: count,
                            onToggle: _toggleScope,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child:
                                _thumbsReady
                                    ? SizedBox(
                                      height: 48,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: count,
                                        separatorBuilder:
                                            (_, _) => const SizedBox(width: 6),
                                        itemBuilder: (context, index) {
                                          final selected = index == _page;
                                          return GestureDetector(
                                            onTap: () {
                                              _pageController.animateToPage(
                                                index,
                                                duration: const Duration(
                                                  milliseconds: 220,
                                                ),
                                                curve: Curves.easeOut,
                                              );
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 160,
                                              ),
                                              width: selected ? 44 : 36,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      selected
                                                          ? Colors.white
                                                          : Colors.white24,
                                                  width: selected ? 2 : 1,
                                                ),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: _ComposePhoto(
                                                key: ValueKey(
                                                  't_${_paths[index]}',
                                                ),
                                                path: _paths[index],
                                                thumb: true,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                    : const SizedBox(height: 48),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_showStone) ...[
                      _buildStoneScaleRow(spec),
                      const SizedBox(height: 6),
                    ],
                    ComposeWeightScale(
                      value:
                          _editingRangeMax
                              ? (spec.grossMax ?? spec.grossMin ?? 0.5)
                              : (spec.grossMin ?? 0.5),
                      minValue: 0.5,
                      step: 0.5,
                      pxPerGram: 24,
                      hint:
                          spec.weightMode == WeightMode.range
                              ? (_editingRangeMax
                                  ? 'Scroll to choose max weight'
                                  : 'Scroll to choose min weight')
                              : 'Scroll to choose weight',
                      rangeMin:
                          spec.weightMode == WeightMode.range
                              ? spec.grossMin
                              : null,
                      rangeMax:
                          spec.weightMode == WeightMode.range
                              ? spec.grossMax
                              : null,
                      inactiveValue:
                          spec.weightMode == WeightMode.range
                              ? (_editingRangeMax
                                  ? spec.grossMin
                                  : spec.grossMax)
                              : null,
                      onInactiveTap:
                          spec.weightMode == WeightMode.range
                              ? () {
                                setState(
                                  () =>
                                      _editingRangeMax = !_editingRangeMax,
                                );
                              }
                              : null,
                      // Live preview while flinging; commit draft on settle.
                      onChanged: _previewGrossFromScale,
                      onSettle: _setGrossFromScale,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: _buildTagBar(d)),
                        const SizedBox(width: 10),
                        _SendButton(count: count, onTap: _send),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildWeightReadout(ProductSpec spec) {
    final typingGross = _grossFocus.hasFocus && _showStone;
    final isRange = spec.weightMode == WeightMode.range;
    // Keep size stable when Range toggles — avoids net-weight jump.
    final valueStyle = AppTextStyles.title(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );
    final unitStyle = AppTextStyles.caption(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.white70,
    );

    // Listen to controllers so the number tracks the dial without setState
    // on the whole compose tree (smooth fling).
    return AnimatedBuilder(
      animation: Listenable.merge([
        _grossMinController,
        _grossMaxController,
        _stoneController,
      ]),
      builder: (context, _) {
        final stone =
            _showStone
                ? (double.tryParse(_stoneController.text.trim()) ?? 0)
                : 0.0;
        final gMin =
            double.tryParse(_grossMinController.text.trim()) ??
            spec.grossMin;
        final gMax =
            double.tryParse(_grossMaxController.text.trim()) ??
            spec.grossMax ??
            gMin;
        final netMin = gMin == null ? null : gMin - stone;
        final netMax =
            isRange && gMax != null ? gMax - stone : netMin;
        final hasNet = netMin != null;

        Widget valueText() {
          if (!hasNet) {
            return Text('—', style: valueStyle);
          }
          if (isRange && netMax != null) {
            final minActive = !_editingRangeMax;
            final maxActive = _editingRangeMax;
            return Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    if (minActive) {
                      _grossFocus.requestFocus();
                    } else {
                      setState(() => _editingRangeMax = false);
                    }
                  },
                  child: Text(
                    _fmtWeight(netMin),
                    style: valueStyle.copyWith(
                      decoration:
                          minActive
                              ? TextDecoration.underline
                              : TextDecoration.none,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
                Text(' – ', style: valueStyle),
                GestureDetector(
                  onTap: () {
                    if (maxActive) {
                      _grossFocus.requestFocus();
                    } else {
                      setState(() => _editingRangeMax = true);
                    }
                  },
                  child: Text(
                    _fmtWeight(netMax),
                    style: valueStyle.copyWith(
                      decoration:
                          maxActive
                              ? TextDecoration.underline
                              : TextDecoration.none,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
                Text(' g', style: unitStyle),
              ],
            );
          }
          return GestureDetector(
            onTap: () => _grossFocus.requestFocus(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmtWeight(netMin), style: valueStyle),
                Text(' g', style: unitStyle),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              typingGross ? 'GROSS WEIGHT' : 'NET WEIGHT',
              style: AppTextStyles.caption(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            Offstage(
              offstage: true,
              child: SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  controller:
                      _editingRangeMax
                          ? _grossMaxController
                          : _grossMinController,
                  focusNode: _grossFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => _onGrossChanged(),
                ),
              ),
            ),
            valueText(),
            if (_showStone && gMin != null && stone > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Gross ${_fmtWeight(gMin)} g — Stone ${_fmtWeight(stone)} g',
                style: AppTextStyles.caption(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Stack: + Stone, then Range below (not side-by-side).
            if (!_showStone) ...[
              GestureDetector(
                onTap: () {
                  setState(() => _showStone = true);
                  _stoneController.text = _fmtWeight(spec.reduction ?? 0);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '+ Stone',
                    style: AppTextStyles.caption(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _buildRangeToggle(spec, isRange),
          ],
        );
      },
    );
  }

  void _setRangeEnabled(ProductSpec spec, bool enable) {
    if (enable == (spec.weightMode == WeightMode.range)) return;
    if (enable) {
      final min = spec.grossMin ?? 0.5;
      final max =
          spec.grossMax != null && spec.grossMax! > min
              ? spec.grossMax!
              : (spec.grossMin == null ? 1.5 : min + 1);
      _updateDraft(
        (d) => d.copyWith(
          spec: d.spec.copyWith(
            weightMode: WeightMode.range,
            grossMin: spec.grossMin ?? 0.5,
            grossMax: max,
          ),
        ),
        reloadFields: true,
      );
      setState(() => _editingRangeMax = false);
    } else {
      final v = spec.grossMin ?? 0.5;
      _updateDraft(
        (d) => d.copyWith(
          spec: d.spec.copyWith(
            weightMode: WeightMode.fixed,
            grossMin: v,
            grossMax: v,
          ),
        ),
        reloadFields: true,
      );
    }
  }

  Widget _buildRangeToggle(ProductSpec spec, bool isRange) {
    final onColor = AppColors.success;
    return GestureDetector(
      onTap: () => _setRangeEnabled(spec, !isRange),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
        decoration: BoxDecoration(
          color:
              isRange
                  ? onColor.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isRange
                    ? onColor.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.22),
            width: isRange ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Range',
              style: AppTextStyles.caption(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isRange ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 28,
              width: 46,
              child: Switch(
                value: isRange,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeTrackColor: onColor,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  return Colors.white.withValues(
                    alpha: states.contains(WidgetState.selected) ? 1 : 0.85,
                  );
                }),
                trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.transparent;
                  }
                  return Colors.white.withValues(alpha: 0.35);
                }),
                onChanged: (on) => _setRangeEnabled(spec, on),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoneScaleRow(ProductSpec spec) {
    return Row(
      children: [
        Text(
          'STONE',
          style: AppTextStyles.caption(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ComposeWeightScale(
            value: (spec.reduction ?? 0).clamp(0.0, spec.grossMin ?? 0),
            minValue: 0,
            step: 0.1,
            pxPerGram: 100,
            height: 48,
            hint: '',
            labelEvery: 1,
            onChanged: (v) {
              _stoneController.text = _fmtWeight(v);
            },
            onSettle: _setStoneFromScale,
          ),
        ),
        IconButton(
          tooltip: 'Clear stone',
          onPressed: () {
            setState(() {
              _showStone = false;
              _stoneController.clear();
            });
            _updateDraft(
              (d) => d.copyWith(
                spec: d.spec.copyWith(
                  deductStone: false,
                  reduction: 0,
                ),
              ),
            );
          },
          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
        ),
      ],
    );
  }

  Widget _buildTagBar(ComposePhotoDraft d) {
    final category = d.spec.category.trim().toLowerCase();
    bool isSystem(String tag) {
      final t = tag.trim().toLowerCase();
      return ProductSpec.composeMetalOptions.contains(t) ||
          ProductSpec.composeCategoryOptions.contains(t) ||
          t == category;
    }

    String displayName(String tag) {
      final t = tag.trim();
      if (t.isEmpty) return t;
      return t
          .split(' ')
          .map(
            (w) =>
                w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
          )
          .join(' ');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in d.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          isSystem(tag)
                              ? Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                              )
                              : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName(tag),
                          style: AppTextStyles.caption(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (!isSystem(tag)) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              _updateDraft(
                                (x) => x.copyWith(
                                  tags: [
                                    for (final t in x.tags)
                                      if (t != tag) t,
                                  ],
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: KeyboardListener(
                  focusNode: _tagBackspaceFocus,
                  onKeyEvent: (event) {
                    if (event is! KeyDownEvent) return;
                    if (event.logicalKey != LogicalKeyboardKey.backspace) {
                      return;
                    }
                    if (_tagController.text.isNotEmpty) return;
                    // Remove last user-added name.
                    final removable =
                        d.tags.where((t) => !isSystem(t)).toList();
                    if (removable.isEmpty) return;
                    final last = removable.last;
                    _updateDraft(
                      (x) => x.copyWith(
                        tags: [
                          for (final t in x.tags)
                            if (t != last) t,
                        ],
                      ),
                    );
                  },
                  child: TextField(
                    controller: _tagController,
                    focusNode: _tagFocus,
                    onTap: _closeFlyout,
                    onChanged: _onTagChanged,
                    onSubmitted: (_) {
                      _commitTagField();
                      _tagFocus.requestFocus();
                    },
                    style: AppTextStyles.body(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Add another name',
                      hintStyle: AppTextStyles.body(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              if (_tagController.text.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Add name',
                  onPressed: () {
                    _commitTagField();
                    _tagFocus.requestFocus();
                  },
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRail(ComposePhotoDraft d, ProductSpec spec) {
    final metal = _metal;
    final purityEmpty = false;
    final wastageEmpty = spec.wastagePercent == null;
    final categoryEmpty = spec.category.trim().isEmpty;
    final purityGlyph =
        spec.purityMode == FieldMode.varied ? 'Mix' : (spec.purity ?? '92');
    final wastageGlyph =
        wastageEmpty
            ? '+'
            : (spec.wastageMode == FieldMode.varied
                ? '~${_numText(spec.wastagePercent!)}%'
                : '${_numText(spec.wastagePercent!)}%');
    final catGlyph =
        categoryEmpty ? '+' : ProductSpec.categoryShort(spec.category);
    final sizeGlyph =
        spec.sizeMode == SizeMode.free
            ? 'Free'
            : (spec.sizeMode == SizeMode.varied
                ? (spec.sizeValue == null ? '~' : _numText(spec.sizeValue!))
                : (spec.sizeValue == null ? '+' : _numText(spec.sizeValue!)));
    final sizeLabel =
        spec.sizeMode == SizeMode.free
            ? 'Size'
            : (spec.sizeValue == null
                ? 'Size'
                : '${_numText(spec.sizeValue!)} ${sizeUnitLabel(spec.sizeUnit)}');

    // Hug content width — a full-width overlay was eating pinch gestures.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ComposeRailSlot(
            open: _flyout == ComposeRailFlyout.metal,
            flyout: ComposeFlyoutRow(
              children: [
                for (final m in ProductSpec.composeMetalOptions)
                  ComposeFlyoutOption(
                    label: ProductSpec.metalLabel(m),
                    selected: metal == m,
                    onTap: () {
                      _updateDraft(
                        (x) => x.copyWith(
                          spec: x.spec.copyWith(
                            metalType: [m],
                            purity: ProductSpec.defaultPurityForMetal(m),
                            purityMode: FieldMode.fixed,
                          ),
                          tags: [
                            m,
                            for (final t in x.tags)
                              if (t != m &&
                                  !ProductSpec.composeMetalOptions.contains(t))
                                t,
                          ],
                        ),
                      );
                      _advanceAfter(ComposeRailFlyout.metal);
                    },
                  ),
              ],
            ),
            chip: ComposeRailChip(
              label: 'Metal',
              glyph: ProductSpec.metalRailLabel(metal),
              open: _flyout == ComposeRailFlyout.metal,
              onTap: () => _setFlyout(ComposeRailFlyout.metal),
            ),
          ),
          ComposeRailSlot(
            open: _flyout == ComposeRailFlyout.purity,
            flyout: ComposeFlyoutRow(
              children: [
                for (final p in ProductSpec.purityOptionsForMetal(metal))
                  ComposeFlyoutOption(
                    label: p,
                    selected:
                        spec.purityMode == FieldMode.fixed && spec.purity == p,
                    onTap: () {
                      _updateDraft(
                        (x) => x.copyWith(
                          spec: x.spec.copyWith(
                            purity: p,
                            purityMode: FieldMode.fixed,
                          ),
                        ),
                      );
                      _advanceAfter(ComposeRailFlyout.purity);
                    },
                  ),
                ComposeFlyoutOption(
                  label: 'Varied',
                  selected: spec.purityMode == FieldMode.varied,
                  onTap: () {
                    _updateDraft(
                      (x) => x.copyWith(
                        spec: x.spec.copyWith(purityMode: FieldMode.varied),
                      ),
                    );
                    _advanceAfter(ComposeRailFlyout.purity);
                  },
                ),
              ],
            ),
            chip: ComposeRailChip(
              label: 'Purity',
              glyph: purityGlyph,
              open: _flyout == ComposeRailFlyout.purity,
              empty: purityEmpty,
              onTap: () => _setFlyout(ComposeRailFlyout.purity),
            ),
          ),
          ComposeRailSlot(
            open: _flyout == ComposeRailFlyout.wastage,
            flyout: _wastageFlyout(spec),
            chip: ComposeRailChip(
              label: 'Wastage',
              glyph: wastageGlyph,
              open: _flyout == ComposeRailFlyout.wastage,
              empty: wastageEmpty,
              onTap: () => _setFlyout(ComposeRailFlyout.wastage),
            ),
          ),
          ComposeRailSlot(
            open: _flyout == ComposeRailFlyout.category,
            flyout: ComposeFlyoutRow(
              children: [
                for (final c in ProductSpec.composeCategoryOptions)
                  ComposeFlyoutOption(
                    label: ProductSpec.metalLabel(c),
                    selected: spec.category == c,
                    onTap: () {
                      _updateDraft(
                        (x) => x.copyWith(
                          spec: x.spec.copyWith(category: c),
                          tags: [
                            c,
                            for (final t in x.tags)
                              if (t != c &&
                                  !ProductSpec.composeCategoryOptions.contains(
                                    t,
                                  ))
                                t,
                          ],
                        ),
                      );
                      // End of auto-advance chain.
                      _closeFlyout();
                    },
                  ),
              ],
            ),
            chip: ComposeRailChip(
              label:
                  categoryEmpty
                      ? 'Category'
                      : ProductSpec.metalLabel(spec.category),
              glyph: catGlyph,
              open: _flyout == ComposeRailFlyout.category,
              empty: categoryEmpty,
              onTap: () => _setFlyout(ComposeRailFlyout.category),
            ),
          ),
          ComposeRailSlot(
            open: _flyout == ComposeRailFlyout.size,
            flyout: _sizeFlyout(spec),
            chip: ComposeRailChip(
              label: sizeLabel,
              glyph: sizeGlyph,
              open: _flyout == ComposeRailFlyout.size,
              onTap: () => _setFlyout(ComposeRailFlyout.size),
            ),
          ),
          ComposeRailSlot(
            open: _flyout == ComposeRailFlyout.stock,
            flyout: _stockFlyout(d),
            chip: ComposeRailChip(
              label: switch (d.stockStatus) {
                ComposeStockStatus.inStock => 'In Stock',
                ComposeStockStatus.outOfStock => 'Out',
                ComposeStockStatus.mto => 'To order',
              },
              glyph: '',
              open: _flyout == ComposeRailFlyout.stock,
              accent: switch (d.stockStatus) {
                ComposeStockStatus.inStock => const Color(0xFF2ECC71),
                ComposeStockStatus.outOfStock => const Color(0xFFE74C3C),
                ComposeStockStatus.mto => Colors.white24,
              },
              glyphWidget: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    switch (d.stockStatus) {
                      ComposeStockStatus.inStock => Icons.check_rounded,
                      ComposeStockStatus.outOfStock => Icons.close_rounded,
                      ComposeStockStatus.mto => Icons.schedule_rounded,
                    },
                    color: Colors.white,
                    size: 22,
                  ),
                  if (widget.importMode && _currentSourceLocked)
                    const Positioned(
                      right: -6,
                      bottom: -6,
                      child: Icon(
                        Icons.link_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              onTap: () {
                if (widget.importMode && _currentSourceLocked) {
                  _toast('Stock follows $_sourceName');
                  return;
                }
                if (d.stockStatus == ComposeStockStatus.inStock) {
                  _updateDraft(
                    (x) =>
                        x.copyWith(stockStatus: ComposeStockStatus.outOfStock),
                  );
                  _setFlyout(ComposeRailFlyout.stock);
                } else if (_flyout == ComposeRailFlyout.stock) {
                  _updateDraft(
                    (x) => x.copyWith(
                      stockStatus: ComposeStockStatus.inStock,
                      mtoDays: 7,
                    ),
                  );
                  _closeFlyout();
                } else {
                  _setFlyout(ComposeRailFlyout.stock);
                }
              },
            ),
          ),
          ComposeRailSlot(
            open: false,
            chip: ComposeRailChip(
              label: d.isLocked ? 'Locked' : 'Unlocked',
              glyph: '',
              open: false,
              empty: !d.isLocked,
              glyphWidget: Icon(
                d.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: Colors.white,
                size: 20,
              ),
              onTap: () {
                if (widget.importMode) {
                  final i = _page.clamp(0, _drafts.length - 1);
                  if (i < _sourceLocked.length && _sourceLocked[i]) {
                    _toast(
                      'Locked by $_sourceName · lists after they approve',
                    );
                    return;
                  }
                  final next = !d.isLocked;
                  _updateDraft((x) => x.copyWith(isLocked: next));
                  if (next) {
                    _toast(
                      'Locked · other stores need your approval to import',
                    );
                  }
                  return;
                }
                final next = !d.isLocked;
                _updateDraft((x) => x.copyWith(isLocked: next));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _wastageFlyout(ProductSpec spec) {
    final text =
        spec.wastagePercent == null ? '' : _numText(spec.wastagePercent!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ComposeModePill(
            options: const ['Fixed', 'Varied'],
            selectedIndex: spec.wastageMode == FieldMode.varied ? 1 : 0,
            onSelected: (i) {
              _updateDraft(
                (x) => x.copyWith(
                  spec: x.spec.copyWith(
                    wastageMode: i == 0 ? FieldMode.fixed : FieldMode.varied,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          ComposeWastageStepper(
            valueText: text.isEmpty ? '' : '$text%',
            onMinus: () {
              final cur = spec.wastagePercent ?? 0;
              final next = (cur - 0.5).clamp(0.0, 100.0);
              if (next <= 0) {
                _updateDraft(
                  (x) => x.copyWith(
                    spec: ProductSpec(
                      weightMode: x.spec.weightMode,
                      grossMin: x.spec.grossMin,
                      grossMax: x.spec.grossMax,
                      deductStone: x.spec.deductStone,
                      reduction: x.spec.reduction,
                      purityMode: x.spec.purityMode,
                      purity: x.spec.purity,
                      wastageMode: x.spec.wastageMode,
                      wastagePercent: null,
                      sizeMode: x.spec.sizeMode,
                      sizeValue: x.spec.sizeValue,
                      sizeUnit: x.spec.sizeUnit,
                      customUnit: x.spec.customUnit,
                      metalType: x.spec.metalType,
                      category: x.spec.category,
                    ),
                  ),
                );
              } else {
                _updateDraft(
                  (x) => x.copyWith(
                    spec: x.spec.copyWith(wastagePercent: next),
                  ),
                );
              }
            },
            onPlus: () {
              final cur = spec.wastagePercent;
              // v4 default wastage is 4% (was empty → jump to 12).
              final next = cur == null ? 4.0 : (cur + 0.5).clamp(0.0, 100.0);
              _updateDraft(
                (x) => x.copyWith(
                  spec: x.spec.copyWith(wastagePercent: next),
                ),
              );
              if (cur == null) {
                _advanceAfter(ComposeRailFlyout.wastage);
              }
            },
            onChanged: (raw) {
              final cleaned = raw.replaceAll('%', '').trim();
              final v = double.tryParse(cleaned);
              if (v == null) return;
              _updateDraft(
                (x) => x.copyWith(
                  spec: x.spec.copyWith(wastagePercent: v.clamp(0, 100)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sizeFlyout(ProductSpec spec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ComposeModePill(
            options: const ['Free', 'Fixed', 'Varied'],
            selectedIndex: switch (spec.sizeMode) {
              SizeMode.free => 0,
              SizeMode.fixed => 1,
              SizeMode.varied => 2,
            },
            onSelected: (i) {
              final mode = switch (i) {
                1 => SizeMode.fixed,
                2 => SizeMode.varied,
                _ => SizeMode.free,
              };
              _updateDraft(
                (x) => x.copyWith(spec: x.spec.copyWith(sizeMode: mode)),
              );
              if (mode == SizeMode.free) _closeFlyout();
            },
          ),
          if (spec.sizeMode != SizeMode.free) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _sizeController,
                    onChanged: (v) {
                      final n = double.tryParse(v.trim());
                      _updateDraft(
                        (x) => x.copyWith(
                          spec: x.spec.copyWith(sizeValue: n),
                        ),
                      );
                    },
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    cursorColor: Colors.white,
                    style: AppTextStyles.body(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ComposeModePill(
                  options: const ['in', 'mm', 'cm'],
                  selectedIndex: switch (spec.sizeUnit) {
                    SizeUnit.inch => 0,
                    SizeUnit.mm => 1,
                    SizeUnit.cm => 2,
                    SizeUnit.custom => 1,
                  },
                  onSelected: (i) {
                    final unit = switch (i) {
                      0 => SizeUnit.inch,
                      2 => SizeUnit.cm,
                      _ => SizeUnit.mm,
                    };
                    _updateDraft(
                      (x) => x.copyWith(spec: x.spec.copyWith(sizeUnit: unit)),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stockFlyout(ComposePhotoDraft d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Make to order',
                  style: AppTextStyles.caption(color: Colors.white),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: d.stockStatus == ComposeStockStatus.mto,
                  onChanged: (on) {
                    _updateDraft(
                      (x) => x.copyWith(
                        stockStatus:
                            on
                                ? ComposeStockStatus.mto
                                : ComposeStockStatus.outOfStock,
                        mtoDays: on ? (x.mtoDays <= 0 ? 7 : x.mtoDays) : x.mtoDays,
                      ),
                    );
                  },
                ),
              ],
            ),
            if (d.stockStatus == ComposeStockStatus.mto) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      final next = (d.mtoDays - 1).clamp(1, 90);
                      _updateDraft((x) => x.copyWith(mtoDays: next));
                    },
                    icon: const Icon(Icons.remove, color: Colors.white),
                  ),
                  Text(
                    '${d.mtoDays} days',
                    style: AppTextStyles.body(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final next = (d.mtoDays + 1).clamp(1, 90);
                      _updateDraft((x) => x.copyWith(mtoDays: next));
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: count == 0 ? null : onTap,
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.send_rounded, color: Colors.black, size: 22),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: AppTextStyles.caption(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ComposePhoto extends StatefulWidget {
  const _ComposePhoto({
    super.key,
    required this.path,
    this.thumb = false,
    this.onFirstFrame,
    this.onTap,
  });

  final String path;
  final bool thumb;
  final VoidCallback? onFirstFrame;
  final VoidCallback? onTap;

  @override
  State<_ComposePhoto> createState() => _ComposePhotoState();
}

class _ComposePhotoState extends State<_ComposePhoto> {
  bool _announcedFrame = false;

  void _announceIfNeeded() {
    if (_announcedFrame || widget.onFirstFrame == null) return;
    _announcedFrame = true;
    widget.onFirstFrame!();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final cacheWidth =
        widget.thumb
            ? (52 * dpr).round().clamp(48, 160)
            : ProductGalleryPicker.composeHeroDecodeWidth(
              logicalWidth: screenW,
              dpr: dpr,
            );

    final image = ProductMediaImage(
      path: widget.path,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      decodeCacheWidth: cacheWidth,
      filterQuality: widget.thumb ? FilterQuality.low : FilterQuality.medium,
      error: const ColoredBox(
        color: Color(0xFF1F2C34),
        child: Icon(Icons.broken_image_outlined, color: Colors.white54),
      ),
    );
    if (!_announcedFrame && widget.onFirstFrame != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _announceIfNeeded();
      });
    }

    if (widget.thumb) return image;

    // No InteractiveViewer — pinch/zoom made PageView swipes unstable.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox.expand(child: image),
    );
  }
}
