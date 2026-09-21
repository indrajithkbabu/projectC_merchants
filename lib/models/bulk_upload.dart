import 'package:equatable/equatable.dart';

enum BulkItemTag { group, precise, standalone }

/// Where selected photos should move when the user taps Ungroup.
enum BulkUngroupDestination {
  main,
  existingSubgroup,
  newSubgroup,
  newCollection,
}

class BulkKnownSubGroup extends Equatable {
  const BulkKnownSubGroup({
    required this.id,
    required this.name,
    this.sampleSpec = const ProductSpec(),
  });

  final String id;
  final String name;
  final ProductSpec sampleSpec;

  @override
  List<Object?> get props => [id, name, sampleSpec];
}

enum BulkSpecScope { group, single, multi }

enum WeightMode { fixed, range }

enum FieldMode { fixed, varied }

enum SizeMode { free, fixed, varied }

enum SizeUnit { mm, cm, inch, custom }

class ProductSpec extends Equatable {
  const ProductSpec({
    this.weightMode = WeightMode.fixed,
    this.grossMin,
    this.grossMax,
    this.deductStone = false,
    this.reduction,
    this.purityMode = FieldMode.fixed,
    this.purity = '92',
    this.wastageMode = FieldMode.fixed,
    this.wastagePercent,
    this.sizeMode = SizeMode.free,
    this.sizeValue,
    this.sizeUnit = SizeUnit.mm,
    this.customUnit = '',
    this.metalType = const ['gold'],
    this.category = '',
  });

  static const purityOptions = <String>['75', '82', '86', '92', '999'];

  static const metalOptions = <String>[
    'gold',
    'silver',
    'rose gold',
    'platinum',
    'diamond',
  ];

  static const categoryOptions = <String>[
    'ring',
    'necklace',
    'bangle',
    'earrings',
    'pendant',
    'bracelet',
    'chain',
    'bridal_set',
    'other',
  ];

  final WeightMode weightMode;
  final double? grossMin;
  final double? grossMax;
  final bool deductStone;
  final double? reduction;
  final FieldMode purityMode;
  final String? purity;
  final FieldMode wastageMode;
  final double? wastagePercent;
  final SizeMode sizeMode;
  final double? sizeValue;
  final SizeUnit sizeUnit;
  final String customUnit;
  final List<String> metalType;
  final String category;

  double? get _deduction =>
      deductStone && reduction != null && reduction! > 0 ? reduction : 0;

  double? get netMin {
    if (grossMin == null) return null;
    return _roundWeight(grossMin! - (_deduction ?? 0));
  }

  double? get netMax {
    if (weightMode != WeightMode.range || grossMax == null) return netMin;
    return _roundWeight(grossMax! - (_deduction ?? 0));
  }

  String get netLabel {
    final min = netMin;
    if (min == null) return '—';
    if (weightMode == WeightMode.range && netMax != null && netMax != min) {
      return '${_fmt(min)}–${_fmt(netMax!)} g';
    }
    return '${_fmt(min)} g';
  }

  /// Fine weight = net × (purity% + wastage%) / 100.
  /// With no other deduction, net equals gross.
  String? get fineWeightDisplay {
    if (purityMode != FieldMode.fixed || wastageMode != FieldMode.fixed) {
      return null;
    }
    final purityValue = double.tryParse(
      (purity ?? '').replaceAll('%', '').trim(),
    );
    final wastage = wastagePercent;
    final minNet = netMin;
    if (purityValue == null || wastage == null || minNet == null || minNet <= 0) {
      return null;
    }
    final factor = (purityValue + wastage) / 100.0;
    if (factor <= 0) return null;
    final fineMin = _roundWeight(minNet * factor);
    if (weightMode == WeightMode.range &&
        netMax != null &&
        netMax != minNet) {
      final fineMax = _roundWeight(netMax! * factor);
      return 'Fine weight : ${_fmt(fineMin)}–${_fmt(fineMax)}g';
    }
    return 'Fine weight : ${_fmt(fineMin)}g';
  }

  bool get isValid {
    switch (weightMode) {
      case WeightMode.fixed:
        if (grossMin == null || grossMin! <= 0) return false;
        if (deductStone) {
          if (reduction == null || reduction! < 0 || reduction! >= grossMin!) {
            return false;
          }
        }
        break;
      case WeightMode.range:
        if (grossMin == null ||
            grossMax == null ||
            grossMin! <= 0 ||
            grossMax! <= 0 ||
            grossMin! > grossMax!) {
          return false;
        }
        if (deductStone) {
          if (reduction == null ||
              reduction! < 0 ||
              reduction! >= grossMin!) {
            return false;
          }
        }
        break;
    }
    if (purityMode == FieldMode.fixed &&
        (purity == null || !purityOptions.contains(purity))) {
      return false;
    }
    // API wastage is always a number — Varied is UI-only; Fixed must be set.
    if (wastageMode == FieldMode.fixed &&
        (wastagePercent == null ||
            wastagePercent! < 0 ||
            wastagePercent! > 100)) {
      return false;
    }
    if (sizeMode == SizeMode.fixed) {
      if (sizeValue == null || sizeValue! <= 0) return false;
      if (sizeUnit == SizeUnit.custom && customUnit.trim().isEmpty) {
        return false;
      }
    }
    if (metalType.isEmpty) return false;
    if (category.trim().isEmpty) return false;
    return true;
  }

  /// Catalog multipart / JSON `specifications` payload.
  Map<String, dynamic> toApiJson() {
    final weight =
        weightMode == WeightMode.range
            ? <String, dynamic>{
              'type': 'range',
              'min': grossMin ?? 0,
              'max': grossMax ?? 0,
            }
            : <String, dynamic>{'type': 'fixed', 'value': grossMin ?? 0};

    final deductionValue =
        deductStone && reduction != null && reduction! > 0 ? reduction! : 0.0;
    final otherDeduction =
        weightMode == WeightMode.range
            ? <String, dynamic>{
              'type': 'range',
              'min': deductionValue,
              'max': deductionValue,
            }
            : <String, dynamic>{'type': 'fixed', 'value': deductionValue};

    final purityJson =
        purityMode == FieldMode.varied
            ? <String, dynamic>{'type': 'varied'}
            : <String, dynamic>{'type': 'fixed', 'value': purity ?? '92'};

    final wastage =
        wastageMode == FieldMode.fixed ? (wastagePercent ?? 0) : 0.0;

    final Map<String, dynamic> sizeJson;
    if (sizeMode == SizeMode.fixed) {
      sizeJson = {
        'type': 'standard',
        'value': sizeValue ?? 0,
        'unit': _apiUnit(),
      };
    } else {
      // Free + Varied both map to free_size (API has no varied size).
      sizeJson = {'type': 'free_size'};
    }

    return {
      'weight': weight,
      'otherDeduction': otherDeduction,
      'purity': purityJson,
      'wastage': wastage,
      'size': sizeJson,
      'metalType': metalType,
      'category': category.trim(),
    };
  }

  factory ProductSpec.fromApiJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const ProductSpec();

    final weight = json['weight'];
    final weightMap =
        weight is Map<String, dynamic>
            ? weight
            : weight is Map
            ? Map<String, dynamic>.from(weight)
            : const <String, dynamic>{};
    final weightType = weightMap['type']?.toString() ?? 'fixed';
    final isRange = weightType == 'range';

    final deduction = json['otherDeduction'];
    final deductionMap =
        deduction is Map<String, dynamic>
            ? deduction
            : deduction is Map
            ? Map<String, dynamic>.from(deduction)
            : const <String, dynamic>{};
    final reductionValue =
        isRange
            ? (deductionMap['min'] as num?)?.toDouble() ??
                (deductionMap['value'] as num?)?.toDouble()
            : (deductionMap['value'] as num?)?.toDouble() ??
                (deductionMap['min'] as num?)?.toDouble();

    final purity = json['purity'];
    final purityMap =
        purity is Map<String, dynamic>
            ? purity
            : purity is Map
            ? Map<String, dynamic>.from(purity)
            : const <String, dynamic>{};
    final purityType = purityMap['type']?.toString() ?? 'fixed';
    final purityValue = purityMap['value']?.toString();

    final wastageRaw = json['wastage'];
    final wastage =
        wastageRaw is num
            ? wastageRaw.toDouble()
            : double.tryParse(wastageRaw?.toString() ?? '');

    final size = json['size'];
    final sizeMap =
        size is Map<String, dynamic>
            ? size
            : size is Map
            ? Map<String, dynamic>.from(size)
            : const <String, dynamic>{};
    final sizeType = sizeMap['type']?.toString() ?? 'free_size';
    final unitRaw = sizeMap['unit']?.toString() ?? 'mm';
    final SizeUnit sizeUnit;
    final String customUnit;
    switch (unitRaw) {
      case 'cm':
        sizeUnit = SizeUnit.cm;
        customUnit = '';
      case 'inch':
        sizeUnit = SizeUnit.inch;
        customUnit = '';
      case 'mm':
        sizeUnit = SizeUnit.mm;
        customUnit = '';
      default:
        sizeUnit = SizeUnit.custom;
        customUnit = unitRaw;
    }

    final metals =
        (json['metalType'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList() ??
        const <String>['gold'];

    return ProductSpec(
      weightMode: isRange ? WeightMode.range : WeightMode.fixed,
      grossMin:
          isRange
              ? (weightMap['min'] as num?)?.toDouble()
              : (weightMap['value'] as num?)?.toDouble(),
      grossMax:
          isRange
              ? (weightMap['max'] as num?)?.toDouble()
              : (weightMap['value'] as num?)?.toDouble(),
      deductStone: reductionValue != null && reductionValue > 0,
      reduction: reductionValue,
      purityMode:
          purityType == 'varied' ? FieldMode.varied : FieldMode.fixed,
      purity: purityOptions.contains(purityValue) ? purityValue : '92',
      wastageMode: FieldMode.fixed,
      wastagePercent: wastage,
      sizeMode: sizeType == 'standard' ? SizeMode.fixed : SizeMode.free,
      sizeValue: (sizeMap['value'] as num?)?.toDouble(),
      sizeUnit: sizeUnit,
      customUnit: customUnit,
      metalType: metals.isEmpty ? const ['gold'] : metals,
      category: json['category']?.toString() ?? '',
    );
  }

  String _apiUnit() {
    switch (sizeUnit) {
      case SizeUnit.mm:
        return 'mm';
      case SizeUnit.cm:
        return 'cm';
      case SizeUnit.inch:
        return 'inch';
      case SizeUnit.custom:
        return customUnit.trim();
    }
  }

  ProductSpec copyWith({
    WeightMode? weightMode,
    double? grossMin,
    double? grossMax,
    bool? deductStone,
    double? reduction,
    FieldMode? purityMode,
    String? purity,
    FieldMode? wastageMode,
    double? wastagePercent,
    SizeMode? sizeMode,
    double? sizeValue,
    SizeUnit? sizeUnit,
    String? customUnit,
    List<String>? metalType,
    String? category,
  }) {
    return ProductSpec(
      weightMode: weightMode ?? this.weightMode,
      grossMin: grossMin ?? this.grossMin,
      grossMax: grossMax ?? this.grossMax,
      deductStone: deductStone ?? this.deductStone,
      reduction: reduction ?? this.reduction,
      purityMode: purityMode ?? this.purityMode,
      purity: purity ?? this.purity,
      wastageMode: wastageMode ?? this.wastageMode,
      wastagePercent: wastagePercent ?? this.wastagePercent,
      sizeMode: sizeMode ?? this.sizeMode,
      sizeValue: sizeValue ?? this.sizeValue,
      sizeUnit: sizeUnit ?? this.sizeUnit,
      customUnit: customUnit ?? this.customUnit,
      metalType: metalType ?? this.metalType,
      category: category ?? this.category,
    );
  }

  static double _roundWeight(double value) =>
      double.parse(value.toStringAsFixed(2));

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  @override
  List<Object?> get props => [
    weightMode,
    grossMin,
    grossMax,
    deductStone,
    reduction,
    purityMode,
    purity,
    wastageMode,
    wastagePercent,
    sizeMode,
    sizeValue,
    sizeUnit,
    customUnit,
    metalType,
    category,
  ];
}

class BulkUploadItem extends Equatable {
  const BulkUploadItem({
    required this.id,
    required this.imagePath,
    this.tag = BulkItemTag.group,
    this.spec = const ProductSpec(),
    this.customTitle = '',
    this.subGroupId,
  });

  final String id;
  final String imagePath;
  final BulkItemTag tag;
  final ProductSpec spec;

  /// Optional override for the preview/details label. Empty → `{groupTitle} N`.
  final String customTitle;

  /// Server / local sub-group id when the photo is not in the main group.
  final String? subGroupId;

  String get tagLabel {
    switch (tag) {
      case BulkItemTag.group:
        return 'Group';
      case BulkItemTag.precise:
        return 'Precise';
      case BulkItemTag.standalone:
        return 'Standalone';
    }
  }

  BulkUploadItem copyWith({
    String? id,
    String? imagePath,
    BulkItemTag? tag,
    ProductSpec? spec,
    String? customTitle,
    String? subGroupId,
    bool clearSubGroupId = false,
  }) {
    return BulkUploadItem(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      tag: tag ?? this.tag,
      spec: spec ?? this.spec,
      customTitle: customTitle ?? this.customTitle,
      subGroupId:
          clearSubGroupId ? null : (subGroupId ?? this.subGroupId),
    );
  }

  @override
  List<Object?> get props => [id, imagePath, tag, spec, customTitle, subGroupId];
}
