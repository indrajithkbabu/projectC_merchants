import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/presentation/add_store_product/add_store_product_widgets/spec_mode_toggle.dart';

class ProductSpecForm extends StatefulWidget {
  const ProductSpecForm({
    super.key,
    required this.initial,
    this.subtitle,
    this.onChanged,
  });

  final ProductSpec initial;
  final String? subtitle;

  /// Fired whenever fields change so a parent bottom CTA can track validity.
  final ValueChanged<ProductSpec>? onChanged;

  @override
  State<ProductSpecForm> createState() => _ProductSpecFormState();
}

class _ProductSpecFormState extends State<ProductSpecForm> {
  late WeightMode _weightMode;
  late bool _deductStone;
  late FieldMode _purityMode;
  late String _purity;
  late FieldMode _wastageMode;
  late SizeMode _sizeMode;
  late SizeUnit _sizeUnit;
  late List<String> _metalType;
  late String _category;

  late final TextEditingController _grossMinController;
  late final TextEditingController _grossMaxController;
  late final TextEditingController _reductionController;
  late final TextEditingController _wastageController;
  late final TextEditingController _sizeController;
  late final TextEditingController _customUnitController;

  @override
  void initState() {
    super.initState();
    final spec = widget.initial;
    _weightMode = spec.weightMode;
    _deductStone = spec.deductStone;
    _purityMode = spec.purityMode;
    _purity = spec.purity ?? '92';
    _wastageMode = spec.wastageMode;
    _sizeMode = spec.sizeMode;
    _sizeUnit = spec.sizeUnit;
    _metalType =
        spec.metalType.isNotEmpty
            ? List<String>.from(spec.metalType)
            : <String>['gold'];
    _category =
        spec.category.trim().isNotEmpty
            ? spec.category.trim()
            : ProductSpec.categoryOptions.first;
    _grossMinController = TextEditingController(
      text: _numText(spec.grossMin),
    );
    _grossMaxController = TextEditingController(
      text: _numText(spec.grossMax),
    );
    _reductionController = TextEditingController(
      text: _numText(spec.reduction),
    );
    _wastageController = TextEditingController(
      text: _numText(spec.wastagePercent),
    );
    _sizeController = TextEditingController(text: _numText(spec.sizeValue));
    _customUnitController = TextEditingController(text: spec.customUnit);

    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    _grossMinController.dispose();
    _grossMaxController.dispose();
    _reductionController.dispose();
    _wastageController.dispose();
    _sizeController.dispose();
    _customUnitController.dispose();
    super.dispose();
  }

  ProductSpec get _spec => ProductSpec(
    weightMode: _weightMode,
    grossMin: _parse(_grossMinController.text),
    grossMax: _parse(_grossMaxController.text),
    deductStone: _deductStone,
    reduction: _parse(_reductionController.text),
    purityMode: _purityMode,
    purity: _purity,
    wastageMode: _wastageMode,
    wastagePercent: _parse(_wastageController.text),
    sizeMode: _sizeMode,
    sizeValue: _parse(_sizeController.text),
    sizeUnit: _sizeUnit,
    customUnit: _customUnitController.text,
    metalType: List<String>.from(_metalType),
    category: _category,
  );

  void _notify() => widget.onChanged?.call(_spec);

  void _rebuild() {
    setState(() {});
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.subtitle != null) ...[
          Text(widget.subtitle!, style: AppTextStyles.bodySecondary()),
          const SizedBox(height: 18),
        ],
        _sectionHeader(
          label: 'Weight',
          trailing: SpecModeToggle<WeightMode>(
            value: _weightMode,
            options: const [
              (WeightMode.fixed, 'Fixed'),
              (WeightMode.range, 'Range'),
            ],
            onChanged: (value) {
              setState(() => _weightMode = value);
              _notify();
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_weightMode == WeightMode.range)
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: _grossMinController,
                  label: 'Gross min',
                  suffix: 'g',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numberField(
                  controller: _grossMaxController,
                  label: 'Gross max',
                  suffix: 'g',
                ),
              ),
            ],
          )
        else
          _numberField(
            controller: _grossMinController,
            label: 'Gross',
            suffix: 'g',
          ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _deductStone,
          onChanged: (value) {
            setState(() => _deductStone = value ?? false);
            _notify();
          },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          visualDensity: VisualDensity.compact,
          activeColor: AppColors.primary,
          title: Text(
            'Deduct stone / other weight to get net',
            style: AppTextStyles.caption(fontSize: 13),
          ),
        ),
        if (_deductStone) ...[
          const SizedBox(height: 4),
          _numberField(
            controller: _reductionController,
            label: 'Reduction',
            suffix: 'g',
          ),
        ],
        const SizedBox(height: 10),
        _netRow(spec.netLabel),
        const SizedBox(height: 22),
        _sectionHeader(
          label: 'Purity',
          trailing: SpecModeToggle<FieldMode>(
            value: _purityMode,
            options: const [
              (FieldMode.fixed, 'Fixed'),
              (FieldMode.varied, 'Varied'),
            ],
            onChanged: (value) {
              setState(() => _purityMode = value);
              _notify();
            },
          ),
        ),
        if (_purityMode == FieldMode.fixed) ...[
          const SizedBox(height: 12),
          _purityDropdown(),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Left open so each item can be set later.',
            style: AppTextStyles.caption(),
          ),
        ],
        const SizedBox(height: 22),
        _sectionHeader(
          label: 'Wastage (making margin)',
          trailing: SpecModeToggle<FieldMode>(
            value: _wastageMode,
            options: const [
              (FieldMode.fixed, 'Fixed'),
              (FieldMode.varied, 'Varied'),
            ],
            onChanged: (value) {
              setState(() => _wastageMode = value);
              _notify();
            },
          ),
        ),
        if (_wastageMode == FieldMode.fixed) ...[
          const SizedBox(height: 12),
          _numberField(
            controller: _wastageController,
            label: 'Wastage',
            suffix: '%',
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Left open so each item can be set later.',
            style: AppTextStyles.caption(),
          ),
        ],
        const SizedBox(height: 22),
        _sectionHeader(
          label: 'Size',
          trailing: SpecModeToggle<SizeMode>(
            value: _sizeMode,
            options: const [
              (SizeMode.free, 'Free'),
              (SizeMode.fixed, 'Fixed'),
              (SizeMode.varied, 'Varied'),
            ],
            onChanged: (value) {
              setState(() => _sizeMode = value);
              _notify();
            },
          ),
        ),
        if (_sizeMode == SizeMode.fixed) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _numberField(
                  controller: _sizeController,
                  label: 'Size',
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 108, child: _unitDropdown()),
            ],
          ),
          if (_sizeUnit == SizeUnit.custom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customUnitController,
              onChanged: (_) => _rebuild(),
              style: AppTextStyles.body(fontSize: 16),
              decoration: _underlineDecoration(hint: 'Custom unit'),
            ),
          ],
        ] else ...[
          const SizedBox(height: 8),
          Text(
            _sizeMode == SizeMode.free
                ? 'Free size for made-to-fit pieces.'
                : 'Left open so each item can be set later.',
            style: AppTextStyles.caption(),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          'Metal / gemstone',
          style: AppTextStyles.label(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metal in ProductSpec.metalOptions)
              FilterChip(
                label: Text(metal, style: AppTextStyles.caption(fontSize: 13)),
                selected: _metalType.contains(metal),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (!_metalType.contains(metal)) {
                        _metalType = [..._metalType, metal];
                      }
                    } else if (_metalType.length > 1) {
                      _metalType =
                          _metalType.where((m) => m != metal).toList();
                    }
                  });
                  _notify();
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.16),
                checkmarkColor: AppColors.primary,
                side: BorderSide(
                  color:
                      _metalType.contains(metal)
                          ? AppColors.primary
                          : AppColors.border,
                ),
                backgroundColor: AppColors.surface,
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Category',
          style: AppTextStyles.label(
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 10),
        _categoryDropdown(),
      ],
    );
  }

  Widget _sectionHeader({required String label, required Widget trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.label(
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _netRow(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('Net weight', style: AppTextStyles.body(fontSize: 15)),
          const Spacer(),
          Text(
            label,
            style: AppTextStyles.label(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? suffix,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => _rebuild(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: AppTextStyles.body(fontSize: 16, fontWeight: FontWeight.w500),
      decoration: _underlineDecoration(hint: label, suffix: suffix),
    );
  }

  Widget _purityDropdown() {
    return DropdownButtonFormField<String>(
      value: ProductSpec.purityOptions.contains(_purity) ? _purity : '92',
      decoration: _underlineDecoration(),
      items: [
        for (final option in ProductSpec.purityOptions)
          DropdownMenuItem(
            value: option,
            child: Text(option, style: AppTextStyles.body()),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _purity = value);
        _notify();
      },
    );
  }

  Widget _categoryDropdown() {
    final value =
        ProductSpec.categoryOptions.contains(_category)
            ? _category
            : ProductSpec.categoryOptions.first;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _underlineDecoration(hint: 'Category'),
      items: [
        for (final option in ProductSpec.categoryOptions)
          DropdownMenuItem(
            value: option,
            child: Text(
              option.replaceAll('_', ' '),
              style: AppTextStyles.body(),
            ),
          ),
      ],
      onChanged: (next) {
        if (next == null) return;
        setState(() => _category = next);
        _notify();
      },
    );
  }

  Widget _unitDropdown() {
    return DropdownButtonFormField<SizeUnit>(
      value: _sizeUnit,
      decoration: _underlineDecoration(),
      items: [
        for (final unit in SizeUnit.values)
          DropdownMenuItem(
            value: unit,
            child: Text(_unitLabel(unit), style: AppTextStyles.body()),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _sizeUnit = value);
        _notify();
      },
    );
  }

  InputDecoration _underlineDecoration({String? hint, String? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.hint(fontSize: 16, fontWeight: FontWeight.w400),
      suffixText: suffix,
      suffixStyle: AppTextStyles.caption(fontWeight: FontWeight.w600),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  static String _unitLabel(SizeUnit unit) {
    switch (unit) {
      case SizeUnit.mm:
        return 'mm';
      case SizeUnit.cm:
        return 'cm';
      case SizeUnit.inch:
        return 'inch';
      case SizeUnit.custom:
        return 'custom';
    }
  }

  static String _numText(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  static double? _parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }
}
