import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/product_spec_form.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// Edit collection-level weight / purity / wastage / size for an existing listing.
class EditProductSpecsRoute extends StatefulWidget {
  const EditProductSpecsRoute({
    super.key,
    required this.storeId,
    required this.listingId,
    required this.revision,
    required this.initialSpec,
    this.productTitle = '',
  });

  final String storeId;
  final String listingId;
  final int revision;
  final ProductSpec initialSpec;
  final String productTitle;

  @override
  State<EditProductSpecsRoute> createState() => _EditProductSpecsRouteState();
}

class _EditProductSpecsRouteState extends State<EditProductSpecsRoute> {
  bool _isSaving = false;
  ProductSpec? _draft;

  Future<void> _save(ProductSpec spec) async {
    if (_isSaving || !spec.isValid) return;
    setState(() => _isSaving = true);

    final repository = ServiceLocator.get<CollectionRepository>();
    try {
      final updated = await repository.updateCollection(
        storeId: widget.storeId,
        listingId: widget.listingId,
        revision: widget.revision,
        specifications: spec.toApiJson(),
        usePrecisionTag: true,
      );

      StoreProduct product;
      int revision = updated.revision;
      String apiTag = updated.tag;
      try {
        final detail = await repository.fetchCollection(
          storeId: widget.storeId,
          listingId: widget.listingId,
        );
        product = CatalogUiMapper.detailToProduct(detail);
        revision = detail.revision;
        apiTag = detail.tag;
      } catch (_) {
        product = StoreProduct(
          id: updated.id,
          title:
              updated.name.isNotEmpty
                  ? updated.name
                  : widget.productTitle,
          description: updated.description,
          tags: [
            if (updated.tag.isNotEmpty) updated.tag,
            if (spec.category.isNotEmpty) spec.category,
            ...spec.metalType,
          ],
          imagePaths: const [],
          canEdit: true,
          canDelete: true,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(<String, Object?>{
        ...product.toMap(),
        'revision': revision,
        'apiTag': apiTag,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final canSubmit = !_isSaving && draft != null && draft.isValid;

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      child: AbsorbPointer(
        absorbing: _isSaving,
        child: Column(
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
                        AppBackButton(
                          onPressed:
                              _isSaving
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Text(
                            'Edit weight, purity & size',
                            style: AppTextStyles.headline(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_isSaving) ...[
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppColors.primary,
                        backgroundColor: AppColors.surfaceSecondary,
                      ),
                      const SizedBox(height: 16),
                    ],
                    ProductSpecForm(
                      initial: widget.initialSpec,
                      subtitle:
                          widget.productTitle.trim().isEmpty
                              ? 'Updates physical details for this product.'
                              : 'Updates physical details for "${widget.productTitle.trim()}".',
                      onChanged: (spec) => setState(() => _draft = spec),
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
                  label:
                      _isSaving ? 'Saving…' : 'Save weight, purity & size',
                  enabled: canSubmit,
                  isLoading: _isSaving,
                  onPressed: () {
                    final spec = _draft;
                    if (spec == null || !spec.isValid || _isSaving) return;
                    _save(spec);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
