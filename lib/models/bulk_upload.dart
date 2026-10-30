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

  /// Union of all metal purity chips (validation + legacy forms).
  static const purityOptions = <String>[
    '99.9',
    '95',
    '92.5',
    '92',
    '91.6',
    '90',
    '84',
    '82',
    '80',
    '75',
    '58.5',
    '999',
    '86',
  ];

  /// Compose rail metals (design). `diamond` kept for older listings/edit.
  static const metalOptions = <String>[
    'gold',
    'silver',
    'rose gold',
    'platinum',
    'diamond',
  ];

  static const composeMetalOptions = <String>[
    'gold',
    'silver',
    'rose gold',
    'platinum',
  ];

  static const categoryOptions = <String>[
    'ring',
    'necklace',
    'bangle',
    'earrings',
    'jhumka',
    'pendant',
    'chain',
    'haram',
    'bracelet',
    'bridal_set',
    'other',
  ];

  /// Nine compose-rail categories (design).
  static const composeCategoryOptions = <String>[
    'ring',
    'necklace',
    'bangle',
    'earrings',
    'jhumka',
    'pendant',
    'chain',
    'haram',
    'bracelet',
  ];

  static List<String> purityOptionsForMetal(String metal) {
    switch (metal.trim().toLowerCase()) {
      case 'silver':
        return const ['92.5', '99.9', '80'];
      case 'rose gold':
        return const ['75', '58.5', '92'];
      case 'platinum':
        return const ['95', '90'];
      case 'gold':
      default:
        return const ['92', '91.6', '84', '75', '99.9'];
    }
  }

  static String defaultPurityForMetal(String metal) {
    final opts = purityOptionsForMetal(metal);
    return opts.isEmpty ? '92' : opts.first;
  }

  static String metalSymbol(String metal) {
    switch (metal.trim().toLowerCase()) {
      case 'silver':
        return 'Ag';
      case 'rose gold':
        return 'RG';
      case 'platinum':
        return 'Pt';
      case 'gold':
      default:
        return 'Au';
    }
  }

  static String metalLabel(String metal) {
    final m = metal.trim();
    if (m.isEmpty) return 'Metal';
    return m[0].toUpperCase() + m.substring(1);
  }

  /// Compact right-rail metal text (Gold / Silver / Rose / Plat).
  static String metalRailLabel(String metal) {
    switch (metal.trim().toLowerCase()) {
      case 'silver':
        return 'Silver';
      case 'rose gold':
        return 'Rose';
      case 'platinum':
        return 'Plat';
      case 'gold':
      default:
        return 'Gold';
    }
  }

  static String categoryShort(String category) {
    final c = category.trim();
    if (c.isEmpty) return '+';
    if (c.length == 1) return c.toUpperCase();
    return c.substring(0, 2).toUpperCase();
  }

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

  /// Gross weight label, e.g. `55 g` / `10–20 g`.
  String get grossLabel {
    final min = grossMin;
    if (min == null) return '—';
    if (weightMode == WeightMode.range &&
        grossMax != null &&
        grossMax != min) {
      return '${_fmt(min)}–${_fmt(grossMax!)} g';
    }
    return '${_fmt(min)} g';
  }

  /// True when stone deduction makes net differ from gross.
  bool get hasDistinctNet {
    if (grossMin == null || netMin == null) return false;
    final deduction =
        deductStone && reduction != null && reduction! > 0 ? reduction! : 0.0;
    return deduction > 0;
  }

  /// Fine weight value only (`23.5g`), or null when formula inputs are invalid/zero.
  ///
  /// Fine = net × (purity% + wastage%) / 100. Any zero/missing input → no Fine.
  String? get fineWeightValue {
    if (purityMode != FieldMode.fixed || wastageMode != FieldMode.fixed) {
      return null;
    }
    final purityValue = double.tryParse(
      (purity ?? '').replaceAll('%', '').trim(),
    );
    final wastage = wastagePercent;
    final minNet = netMin;
    if (purityValue == null ||
        purityValue <= 0 ||
        wastage == null ||
        wastage <= 0 ||
        minNet == null ||
        minNet <= 0) {
      return null;
    }
    final factor = (purityValue + wastage) / 100.0;
    if (factor <= 0) return null;
    final fineMin = _roundWeight(minNet * factor);
    if (weightMode == WeightMode.range &&
        netMax != null &&
        netMax != minNet) {
      final fineMax = _roundWeight(netMax! * factor);
      return '${_fmt(fineMin)}–${_fmt(fineMax)}g';
    }
    return '${_fmt(fineMin)}g';
  }

  /// Fine weight = net × (purity% + wastage%) / 100.
  /// Returns null when purity, wastage, or net is missing/zero (use Net/Gross).
  String? get fineWeightDisplay {
    final value = fineWeightValue;
    if (value == null) return null;
    return 'Fine weight : $value';
  }

  /// Compact primary weight for details chrome: Fine → Net → Gross.
  ({String label, String value})? get primaryWeightDisplay {
    final fine = fineWeightValue;
    if (fine != null) {
      return (label: 'Fine', value: fine);
    }
    if (hasDistinctNet) {
      final net = netLabel.trim();
      if (net.isNotEmpty && net != '—') {
        return (label: 'Net', value: net.replaceAll(' ', ''));
      }
    }
    final gross = grossLabel.trim();
    if (gross.isNotEmpty && gross != '—') {
      return (label: 'Gross', value: gross.replaceAll(' ', ''));
    }
    final net = netLabel.trim();
    if (net.isNotEmpty && net != '—') {
      return (label: 'Net', value: net.replaceAll(' ', ''));
    }
    return null;
  }

  /// Expandable details under the primary weight (purity / wastage / size).
  List<String> get weightDetailLines {
    final lines = <String>[];
    if (purityMode == FieldMode.varied) {
      lines.add('Purity Varied');
    } else if (purity != null && purity!.trim().isNotEmpty) {
      var p = purity!.trim();
      if (p.endsWith('%')) p = p.substring(0, p.length - 1).trim();
      lines.add('Purity $p');
    }
    if (wastageMode == FieldMode.fixed && wastagePercent != null) {
      lines.add('Wastage $wastagePercent%');
    } else if (wastageMode == FieldMode.varied) {
      lines.add('Wastage Varied');
    }
    if (sizeMode == SizeMode.free) {
      lines.add('Free Size');
    } else if (sizeMode == SizeMode.varied) {
      lines.add('Size Varied');
    } else if (sizeMode == SizeMode.fixed && sizeValue != null) {
      final unit =
          sizeUnit == SizeUnit.custom ? customUnit.trim() : sizeUnit.name;
      lines.add('Size $sizeValue $unit'.trim());
    }
    return lines;
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

  /// Flat product body for `POST …/products/batch` (jewel flow).
  ///
  /// When [isValid] is false (title-only / partial), omits weight/wastage/size
  /// so the server publishes with `hasPrecisionTag: false`.
  Map<String, dynamic> toBatchProductJson({
    String? imageId,
    List<String>? imageIds,
    required String stockStatus,
    int? mtoDays,
    required bool isLocked,
    List<String> tags = const [],
    String? title,
    String? thumbhash,
    String? imageKey,
    int? imageBytes,
    int? imageWidth,
    int? imageHeight,
  }) {
    final ids =
        (imageIds ?? const <String>[])
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    final singleId = (imageId ?? '').trim();
    final hash = (thumbhash ?? '').trim();
    final key = (imageKey ?? '').trim();
    final body = <String, dynamic>{
      if (ids.length > 1)
        'image_ids': ids
      else if (ids.length == 1)
        'image_id': ids.first
      else if (singleId.isNotEmpty)
        'image_id': singleId,
      // Persist placeholder + size so list/detail don't return thumbhash:null /
      // bytes:0 when the sign session metadata was not copied server-side.
      if (hash.isNotEmpty) 'thumbhash': hash,
      if (key.isNotEmpty) 'key': key,
      if (imageBytes != null && imageBytes > 0) 'bytes': imageBytes,
      if (imageWidth != null && imageWidth > 0) 'width': imageWidth,
      if (imageHeight != null && imageHeight > 0) 'height': imageHeight,
      'stock_status': stockStatus,
      if (stockStatus == 'mto' && mtoDays != null) 'mto_days': mtoDays,
      'is_locked': isLocked,
      'tags': tags,
      if ((title ?? '').trim().isNotEmpty) 'title': title!.trim(),
    };

    final metalRaw =
        metalType.isEmpty ? '' : metalType.first.trim().toLowerCase();
    if (metalRaw.isNotEmpty) {
      body['metal'] = switch (metalRaw) {
        'rose gold' || 'rosegold' => 'rose_gold',
        _ => metalRaw.replaceAll(' ', '_'),
      };
    }
    if (category.trim().isNotEmpty) {
      body['category'] = category.trim();
    }

    // Partial / title-only: only send specs that are actually filled.
    if (!isValid) {
      if (purity != null && purity!.trim().isNotEmpty) {
        body['purity'] = purity!.replaceAll('%', '').trim();
        body['purity_mode'] =
            purityMode == FieldMode.varied ? 'varied' : 'fixed';
      }
      if (grossMin != null && grossMin! > 0) {
        body['gross_min'] = grossMin;
        body['gross_max'] =
            weightMode == WeightMode.range
                ? (grossMax ?? grossMin)
                : grossMin;
      }
      if (deductStone && reduction != null && reduction! > 0) {
        body['stone_weight'] = reduction;
      }
      if (wastageMode == FieldMode.fixed && wastagePercent != null) {
        body['wastage_pct'] = wastagePercent;
        body['wastage_mode'] = 'fixed';
      } else if (wastageMode == FieldMode.varied && wastagePercent != null) {
        body['wastage_pct'] = wastagePercent;
        body['wastage_mode'] = 'varied';
      }
      if (sizeMode == SizeMode.fixed && sizeValue != null) {
        body['size_mode'] = 'fixed';
        body['size_value'] = sizeValue;
        body['size_unit'] = switch (sizeUnit) {
          SizeUnit.mm => 'mm',
          SizeUnit.cm => 'cm',
          SizeUnit.inch => 'in',
          SizeUnit.custom =>
            customUnit.trim().isEmpty ? 'mm' : customUnit.trim().toLowerCase(),
        };
      } else if (sizeMode == SizeMode.free) {
        body['size_mode'] = 'free';
      } else if (sizeMode == SizeMode.varied) {
        body['size_mode'] = 'varied';
      }
      return body;
    }

    final purityValue = (purity ?? '92').replaceAll('%', '').trim();
    final stone =
        deductStone && reduction != null && reduction! > 0 ? reduction : null;
    final sizeUnitApi = switch (sizeUnit) {
      SizeUnit.mm => 'mm',
      SizeUnit.cm => 'cm',
      SizeUnit.inch => 'in',
      SizeUnit.custom =>
        customUnit.trim().isEmpty ? 'mm' : customUnit.trim().toLowerCase(),
    };
    body.addAll({
      if (!body.containsKey('metal')) 'metal': 'gold',
      'purity': purityValue,
      'purity_mode': purityMode == FieldMode.varied ? 'varied' : 'fixed',
      'gross_min': grossMin ?? 0,
      'gross_max':
          weightMode == WeightMode.range
              ? (grossMax ?? grossMin ?? 0)
              : (grossMin ?? 0),
      'stone_weight': stone,
      'wastage_pct': wastageMode == FieldMode.fixed ? (wastagePercent ?? 0) : 0,
      'wastage_mode': wastageMode == FieldMode.varied ? 'varied' : 'fixed',
      'size_mode': sizeMode == SizeMode.fixed ? 'fixed' : 'free',
      'size_value': sizeMode == SizeMode.fixed ? sizeValue : null,
      'size_unit': sizeMode == SizeMode.fixed ? sizeUnitApi : null,
    });
    return body;
  }

  /// Minimal title-only product row (no weight/purity/size).
  static Map<String, dynamic> titleOnlyBatchProductJson({
    required String imageId,
    required String stockStatus,
    int? mtoDays,
    required bool isLocked,
    List<String> tags = const [],
    String? title,
    String? thumbhash,
    String? imageKey,
    int? imageBytes,
    int? imageWidth,
    int? imageHeight,
  }) {
    return const ProductSpec().toBatchProductJson(
      imageId: imageId,
      stockStatus: stockStatus,
      mtoDays: mtoDays,
      isLocked: isLocked,
      tags: tags,
      title: title,
      thumbhash: thumbhash,
      imageKey: imageKey,
      imageBytes: imageBytes,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
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

  /// Flat CatalogProduct fields (`metal`, `gross_min`, `wastage_pct`, …).
  factory ProductSpec.fromCatalogProductMap(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const ProductSpec();

    final metalRaw = (json['metal'] as String?)?.trim().toLowerCase() ?? '';
    final metal = switch (metalRaw) {
      'rose_gold' || 'rosegold' => 'rose gold',
      '' => 'gold',
      _ => metalRaw.replaceAll('_', ' '),
    };
    final purityRaw =
        (json['purity'] as String?)?.replaceAll('%', '').trim() ?? '';
    final grossMin = (json['gross_min'] as num?)?.toDouble();
    final grossMax =
        (json['gross_max'] as num?)?.toDouble() ?? grossMin;
    final wastage = (json['wastage_pct'] as num?)?.toDouble();
    final stone = (json['stone_weight'] as num?)?.toDouble();
    final sizeModeRaw =
        (json['size_mode'] as String?)?.trim().toLowerCase() ?? 'free';
    final sizeValue = (json['size_value'] as num?)?.toDouble();
    final unitRaw =
        (json['size_unit'] as String?)?.trim().toLowerCase() ?? 'mm';
    final SizeUnit sizeUnit;
    final String customUnit;
    switch (unitRaw) {
      case 'cm':
        sizeUnit = SizeUnit.cm;
        customUnit = '';
      case 'inch' || 'in':
        sizeUnit = SizeUnit.inch;
        customUnit = '';
      case 'mm':
        sizeUnit = SizeUnit.mm;
        customUnit = '';
      default:
        sizeUnit = SizeUnit.custom;
        customUnit = unitRaw;
    }
    final SizeMode sizeMode;
    if (sizeModeRaw == 'fixed' || sizeModeRaw == 'standard') {
      sizeMode = SizeMode.fixed;
    } else if (sizeModeRaw == 'varied') {
      sizeMode = SizeMode.varied;
    } else {
      sizeMode = SizeMode.free;
    }
    final category = (json['category'] as String?)?.trim() ?? '';
    final isRange =
        grossMin != null &&
        grossMax != null &&
        (grossMax - grossMin).abs() > 0.0001;

    return ProductSpec(
      weightMode: isRange ? WeightMode.range : WeightMode.fixed,
      grossMin: grossMin,
      grossMax: grossMax,
      deductStone: stone != null && stone > 0,
      reduction: stone,
      purityMode: FieldMode.fixed,
      purity:
          purityOptions.contains(purityRaw)
              ? purityRaw
              : (purityRaw.isEmpty ? '92' : purityRaw),
      // Null wastage on jewel products → Varied so chrome / isValid still work
      // (Fine weight stays hidden until a numeric wastage exists).
      wastageMode: wastage != null ? FieldMode.fixed : FieldMode.varied,
      wastagePercent: wastage,
      sizeMode: sizeMode,
      sizeValue: sizeValue,
      sizeUnit: sizeUnit,
      customUnit: customUnit,
      metalType: [metal],
      category: category,
    );
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
