import 'package:equatable/equatable.dart';

/// One item in `POST /views` batch payload.
class ViewBeaconItem extends Equatable {
  const ViewBeaconItem({required this.type, required this.id});

  /// `photo` | `asset` | `collection` | `subgroup`
  final String type;
  final String id;

  String get sessionKey => '$type:$id';

  Map<String, String> toJson() => {'type': type, 'id': id};

  @override
  List<Object?> get props => [type, id];
}

class ViewBeaconItemResult extends Equatable {
  const ViewBeaconItemResult({
    required this.type,
    required this.id,
    required this.recorded,
    this.reason = '',
  });

  final String type;
  final String id;
  final bool recorded;
  final String reason;

  factory ViewBeaconItemResult.fromJson(Map<String, dynamic> json) {
    return ViewBeaconItemResult(
      type: json['type'] as String? ?? '',
      id: json['id'] as String? ?? '',
      recorded: json['recorded'] == true,
      reason: json['reason'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [type, id, recorded, reason];
}

class ViewBeaconResponse extends Equatable {
  const ViewBeaconResponse({
    this.recorded = 0,
    this.skipped = 0,
    this.results = const [],
  });

  final int recorded;
  final int skipped;
  final List<ViewBeaconItemResult> results;

  factory ViewBeaconResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    return ViewBeaconResponse(
      recorded: (json['recorded'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      results:
          raw is List
              ? raw
                  .whereType<Map>()
                  .map(
                    (e) => ViewBeaconItemResult.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .toList()
              : const [],
    );
  }

  @override
  List<Object?> get props => [recorded, skipped, results];
}
