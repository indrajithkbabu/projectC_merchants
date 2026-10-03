import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/designs/whatsapp/whatsapp.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:project_c/helper/colors.dart';

/// Full-screen WhatsApp-style product photo editor (crop, text, draw).
///
/// Pops with the edited file path on Done, or `null` on cancel.
class ProductImageEditorPage extends StatefulWidget {
  const ProductImageEditorPage({
    super.key,
    required this.filePath,
    this.title,
  });

  final String filePath;
  final String? title;

  @override
  State<ProductImageEditorPage> createState() => _ProductImageEditorPageState();
}

class _ProductImageEditorPageState extends State<ProductImageEditorPage> {
  final _editorKey = GlobalKey<ProImageEditorState>();
  String? _editedPath;

  bool get _useMaterialDesign =>
      Theme.of(context).platform != TargetPlatform.iOS;

  ImageEditorDesignMode get _designMode =>
      _useMaterialDesign
          ? ImageEditorDesignMode.material
          : ImageEditorDesignMode.cupertino;

  Future<String> _persistBytes(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/product_edit_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  void _closeEditor(EditorMode editorMode) {
    if (!mounted) return;
    // Sub-editors are pushed routes — pop them. Main pops with result.
    if (editorMode != EditorMode.main) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(_editedPath);
  }

  List<ReactiveWidget> _buildPaintEditorBody(
    PaintEditorState paintEditor,
    Stream<dynamic> rebuildStream,
  ) {
    return [
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => _PaintModeStrip(paintEditor: paintEditor),
      ),
      ReactiveWidget(
        stream: rebuildStream,
        builder:
            (_) => WhatsAppPaintBottomBar(
              configs: paintEditor.configs,
              strokeWidth: paintEditor.paintCtrl.strokeWidth,
              initColor: paintEditor.paintCtrl.color,
              onColorChanged: (color) {
                paintEditor.paintCtrl.setColor(color);
                paintEditor.uiPickerStream.add(null);
              },
              onSetLineWidth: paintEditor.setStrokeWidth,
            ),
      ),
      if (!_useMaterialDesign)
        ReactiveWidget(
          stream: rebuildStream,
          builder: (_) => WhatsappPaintColorpicker(paintEditor: paintEditor),
        ),
      ReactiveWidget(
        stream: rebuildStream,
        builder:
            (_) => WhatsAppPaintAppBar(
              configs: paintEditor.configs,
              canUndo: paintEditor.canUndo,
              onDone: paintEditor.done,
              onTapUndo: paintEditor.undoAction,
              onClose: paintEditor.close,
              activeColor: paintEditor.activeColor,
            ),
      ),
    ];
  }

  List<ReactiveWidget> _buildTextEditorBody(
    TextEditorState textEditor,
    Stream<dynamic> rebuildStream,
  ) {
    return [
      if (_useMaterialDesign)
        ReactiveWidget(
          stream: rebuildStream,
          builder:
              (_) => Padding(
                padding: const EdgeInsets.only(top: kToolbarHeight),
                child: WhatsappTextSizeSlider(textEditor: textEditor),
              ),
        )
      else
        ReactiveWidget(
          stream: rebuildStream,
          builder:
              (_) => Padding(
                padding: const EdgeInsets.only(top: kToolbarHeight),
                child: WhatsappTextColorpicker(textEditor: textEditor),
              ),
        ),
      ReactiveWidget(
        stream: rebuildStream,
        builder:
            (_) => WhatsAppTextAppBar(
              configs: textEditor.configs,
              align: textEditor.align,
              onDone: textEditor.done,
              onAlignChange: textEditor.toggleTextAlign,
              onBackgroundModeChange: textEditor.toggleBackgroundMode,
            ),
      ),
      ReactiveWidget(
        stream: rebuildStream,
        builder:
            (_) => WhatsAppTextBottomBar(
              configs: textEditor.configs,
              initColor: textEditor.primaryColor,
              onColorChanged: (color) {
                textEditor.primaryColor = color;
              },
              selectedStyle: textEditor.selectedTextStyle,
              onFontChange: textEditor.setTextStyle,
            ),
      ),
    ];
  }

  List<Widget> _buildWhatsAppChrome(ProImageEditorState editor) {
    final title = widget.title?.trim();
    return [
      WhatsAppAppBar(
        configs: editor.configs,
        onClose: editor.closeEditor,
        onTapCropRotateEditor: editor.openCropRotateEditor,
        onTapStickerEditor: editor.openEmojiEditor,
        onTapPaintEditor: editor.openPaintEditor,
        onTapTextEditor: editor.openTextEditor,
        onTapUndo: editor.undoAction,
        canUndo: editor.canUndo,
        openEditor: editor.isSubEditorOpen,
      ),
      if (title != null && title.isNotEmpty && !editor.isSubEditorOpen)
        Positioned(
          top: MediaQuery.paddingOf(context).top + 58,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: GoogleFonts.inter().fontFamily,
                ),
              ),
            ),
          ),
        ),
      Positioned(
        bottom: 20 + MediaQuery.paddingOf(context).bottom,
        right: 20,
        child: FloatingActionButton(
          heroTag: 'product_image_editor_done',
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: AppColors.textOnPrimary,
          elevation: 3,
          onPressed: editor.doneEditing,
          child: const Icon(Icons.check_rounded, size: 28),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ProImageEditor.file(
            File(widget.filePath),
            key: _editorKey,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                _editedPath = await _persistBytes(bytes);
              },
              onCloseEditor: _closeEditor,
            ),
            configs: ProImageEditorConfigs(
              designMode: _designMode,
              theme: ThemeData.dark().copyWith(
                primaryColor: AppColors.primary,
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
                  secondary: Color(0xFF25D366),
                ),
              ),
              imageGeneration: const ImageGenerationConfigs(
                allowEmptyEditingCompletion: true,
                outputFormat: OutputFormat.jpg,
                jpegQuality: 85,
              ),
              i18n: const I18n(
                paintEditor: I18nPaintEditor(
                  freestyle: 'Draw',
                  arrow: 'Arrow',
                  line: 'Line',
                  rectangle: 'Square',
                  circle: 'Round',
                  dashLine: 'Dash',
                ),
                textEditor: I18nTextEditor(
                  bottomNavigationBarText: 'Text',
                  inputHintText: 'Type something…',
                ),
                cropRotateEditor: I18nCropRotateEditor(
                  bottomNavigationBarText: 'Crop',
                ),
              ),
              mainEditor: MainEditorConfigs(
                enableZoom: true,
                style: const MainEditorStyle(
                  background: Colors.black,
                  bottomBarBackground: Colors.black,
                ),
                widgets: MainEditorWidgets(
                  appBar: (editor, rebuildStream) => null,
                  bottomBar: (editor, rebuildStream, key) => null,
                  wrapBody: (editor, rebuildStream, content) {
                    return Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        content,
                        if (editor.selectedLayerIndex < 0)
                          ..._buildWhatsAppChrome(editor),
                      ],
                    );
                  },
                ),
              ),
              paintEditor: PaintEditorConfigs(
                enableModeFreeStyle: true,
                enableModeCircle: true,
                enableModeRect: true,
                enableModeArrow: true,
                enableModeLine: true,
                enableModeDashLine: true,
                enableModeEraser: true,
                enableModeBlur: false,
                enableModePixelate: false,
                initialPaintMode: PaintMode.freeStyle,
                style: const PaintEditorStyle(
                  initialColor: Color(0xFF25D366),
                  initialStrokeWidth: 5,
                  background: Colors.black,
                ),
                widgets: PaintEditorWidgets(
                  appBar: (paintEditor, rebuildStream) => null,
                  bottomBar: (paintEditor, rebuildStream) => null,
                  colorPicker:
                      (paintEditor, rebuildStream, currentColor, setColor) =>
                          null,
                  bodyItems: _buildPaintEditorBody,
                ),
              ),
              textEditor: TextEditorConfigs(
                customTextStyles: [
                  GoogleFonts.inter(),
                  GoogleFonts.roboto(),
                  GoogleFonts.lato(),
                  GoogleFonts.comicNeue(),
                ],
                style: TextEditorStyle(
                  textFieldMargin: EdgeInsets.zero,
                  bottomBarBackground: Colors.transparent,
                  bottomBarMainAxisAlignment:
                      !_useMaterialDesign
                          ? MainAxisAlignment.spaceEvenly
                          : MainAxisAlignment.start,
                ),
                widgets: TextEditorWidgets(
                  appBar: (textEditor, rebuildStream) => null,
                  colorPicker:
                      (editor, rebuildStream, currentColor, setColor) => null,
                  bottomBar: (textEditor, rebuildStream) => null,
                  bodyItems: _buildTextEditorBody,
                ),
              ),
              cropRotateEditor: CropRotateEditorConfigs(
                enableDoubleTap: true,
                widgets: CropRotateEditorWidgets(
                  appBar: (cropRotateEditor, rebuildStream) => null,
                  bottomBar:
                      (cropRotateEditor, rebuildStream) => ReactiveWidget(
                        stream: rebuildStream,
                        builder:
                            (_) => WhatsAppCropRotateToolbar(
                              bottomBarColor: const Color(0xFF1C1C1E),
                              configs: cropRotateEditor.configs,
                              onCancel: cropRotateEditor.close,
                              onRotate: cropRotateEditor.rotate,
                              onDone: cropRotateEditor.done,
                              onReset: cropRotateEditor.reset,
                              openAspectRatios:
                                  cropRotateEditor.openAspectRatioOptions,
                            ),
                      ),
                ),
                style: const CropRotateEditorStyle(
                  cropCornerColor: Colors.white,
                  helperLineColor: Colors.white,
                  cropCornerLength: 28,
                  cropCornerThickness: 3,
                  background: Colors.black,
                ),
              ),
              filterEditor: const FilterEditorConfigs(enabled: false),
              tuneEditor: const TuneEditorConfigs(enabled: false),
              blurEditor: const BlurEditorConfigs(enabled: false),
              stickerEditor: const StickerEditorConfigs(enabled: false),
              emojiEditor: EmojiEditorConfigs(
                checkPlatformCompatibility: true,
                style: EmojiEditorStyle(
                  backgroundColor: Colors.black87,
                  textStyle: DefaultEmojiTextStyle.copyWith(fontSize: 42),
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: Colors.transparent,
                    columns: max(
                      1,
                      (6 / 400 * constraints.maxWidth - 1).floor(),
                    ),
                    emojiSizeMax: 48,
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                ),
              ),
              helperLines: const HelperLineConfigs(
                style: HelperLineStyle(
                  horizontalColor: Color(0xFF25D366),
                  verticalColor: Color(0xFF25D366),
                ),
              ),
            ),
          );
        },
      );
  }
}

/// Horizontal tool strip: pencil, shapes, eraser (WhatsApp-like paint modes).
class _PaintModeStrip extends StatelessWidget {
  const _PaintModeStrip({required this.paintEditor});

  final PaintEditorState paintEditor;

  static const _modes = <(PaintMode, IconData, String)>[
    (PaintMode.freeStyle, Icons.edit, 'Draw'),
    (PaintMode.circle, Icons.circle_outlined, 'Round'),
    (PaintMode.rect, Icons.crop_square_rounded, 'Square'),
    (PaintMode.arrow, Icons.arrow_right_alt_rounded, 'Arrow'),
    (PaintMode.line, Icons.horizontal_rule_rounded, 'Line'),
    (PaintMode.eraser, Icons.auto_fix_off_outlined, 'Eraser'),
  ];

  @override
  Widget build(BuildContext context) {
    final active = paintEditor.paintMode;
    return Positioned(
      left: 10,
      right: 10,
      bottom: 58 + MediaQuery.paddingOf(context).bottom,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in _modes) ...[
                _ModeChip(
                  icon: entry.$2,
                  label: entry.$3,
                  selected: active == entry.$1,
                  onTap: () => paintEditor.setMode(entry.$1),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.black54,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textOnPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
