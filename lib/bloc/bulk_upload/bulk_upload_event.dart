part of 'bulk_upload_bloc.dart';

sealed class BulkUploadEvent extends Equatable {
  const BulkUploadEvent();

  @override
  List<Object?> get props => [];
}

class BulkUploadTitleChanged extends BulkUploadEvent {
  const BulkUploadTitleChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

class BulkUploadTitleOnlyPressed extends BulkUploadEvent {
  const BulkUploadTitleOnlyPressed();
}

class BulkUploadClearOpenTitleOnlyForm extends BulkUploadEvent {
  const BulkUploadClearOpenTitleOnlyForm();
}

class BulkUploadAddDetailsPressed extends BulkUploadEvent {
  const BulkUploadAddDetailsPressed();
}

class BulkUploadClearOpenGroupDetails extends BulkUploadEvent {
  const BulkUploadClearOpenGroupDetails();
}

class BulkUploadApplyGroupSpec extends BulkUploadEvent {
  const BulkUploadApplyGroupSpec(this.spec);

  final ProductSpec spec;

  @override
  List<Object?> get props => [spec];
}

class BulkUploadClearOpenPreview extends BulkUploadEvent {
  const BulkUploadClearOpenPreview();
}

class BulkUploadSelectModeToggled extends BulkUploadEvent {
  const BulkUploadSelectModeToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

/// Sets the selected item ids (e.g. browse → Edit with a pre-made selection).
class BulkUploadSelectionSet extends BulkUploadEvent {
  const BulkUploadSelectionSet(
    this.itemIds, {
    this.selectMode = true,
  });

  final List<String> itemIds;
  final bool selectMode;

  @override
  List<Object?> get props => [itemIds, selectMode];
}

class BulkUploadItemSelectionToggled extends BulkUploadEvent {
  const BulkUploadItemSelectionToggled(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

class BulkUploadApplyItemSpec extends BulkUploadEvent {
  const BulkUploadApplyItemSpec({required this.itemId, required this.spec});

  final String itemId;
  final ProductSpec spec;

  @override
  List<Object?> get props => [itemId, spec];
}

class BulkUploadApplyMultiSpec extends BulkUploadEvent {
  const BulkUploadApplyMultiSpec(this.spec);

  final ProductSpec spec;

  @override
  List<Object?> get props => [spec];
}

class BulkUploadItemTitleChanged extends BulkUploadEvent {
  const BulkUploadItemTitleChanged({required this.itemId, required this.title});

  final String itemId;
  final String title;

  @override
  List<Object?> get props => [itemId, title];
}

class BulkUploadItemImageReplaced extends BulkUploadEvent {
  const BulkUploadItemImageReplaced({
    required this.itemId,
    required this.imagePath,
  });

  final String itemId;
  final String imagePath;

  @override
  List<Object?> get props => [itemId, imagePath];
}

class BulkUploadItemRemoved extends BulkUploadEvent {
  const BulkUploadItemRemoved(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

class BulkUploadImagesAdded extends BulkUploadEvent {
  const BulkUploadImagesAdded(this.filePaths);

  final List<String> filePaths;

  @override
  List<Object?> get props => [filePaths];
}

class BulkUploadUngroupSelected extends BulkUploadEvent {
  const BulkUploadUngroupSelected({
    required this.destination,
    this.targetSubGroupId,
    this.newName = '',
  });

  final BulkUngroupDestination destination;
  final String? targetSubGroupId;
  final String newName;

  @override
  List<Object?> get props => [destination, targetSubGroupId, newName];
}

class BulkUploadDeleteSelected extends BulkUploadEvent {
  const BulkUploadDeleteSelected();
}

class BulkUploadClearItemsEmpty extends BulkUploadEvent {
  const BulkUploadClearItemsEmpty();
}

class BulkUploadPublishPressed extends BulkUploadEvent {
  const BulkUploadPublishPressed();
}

class BulkUploadClearPublished extends BulkUploadEvent {
  const BulkUploadClearPublished();
}

class BulkUploadRestartRequested extends BulkUploadEvent {
  const BulkUploadRestartRequested();
}

class BulkUploadClearCloseFlow extends BulkUploadEvent {
  const BulkUploadClearCloseFlow();
}

class BulkUploadClearMessage extends BulkUploadEvent {
  const BulkUploadClearMessage();
}

class BulkUploadClearShouldPopWithResult extends BulkUploadEvent {
  const BulkUploadClearShouldPopWithResult();
}
