part of 'profile_bloc.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.firstName = '',
    this.lastName = '',
    this.imagePath,
    this.isPickingImage = false,
    this.isSubmitting = false,
    this.isCompleted = false,
    this.errorMessage,
  });

  final String firstName;
  final String lastName;
  final String? imagePath;
  final bool isPickingImage;
  final bool isSubmitting;
  final bool isCompleted;
  final String? errorMessage;

  bool get canContinue => firstName.trim().isNotEmpty && !isSubmitting;
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;

  ProfileState copyWith({
    String? firstName,
    String? lastName,
    String? imagePath,
    bool clearImage = false,
    bool? isPickingImage,
    bool? isSubmitting,
    bool? isCompleted,
    String? errorMessage,
    bool clearError = false,
    bool clearCompleted = false,
  }) {
    return ProfileState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      isPickingImage: isPickingImage ?? this.isPickingImage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCompleted: clearCompleted ? false : (isCompleted ?? this.isCompleted),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    imagePath,
    isPickingImage,
    isSubmitting,
    isCompleted,
    errorMessage,
  ];
}
