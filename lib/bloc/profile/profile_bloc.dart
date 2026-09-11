import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({
    ImagePicker? imagePicker,
    ProfileRepository? profileRepository,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _profileRepository =
           profileRepository ?? ServiceLocator.get<ProfileRepository>(),
       super(const ProfileState()) {
    on<ProfileFirstNameChanged>(_onFirstNameChanged);
    on<ProfileLastNameChanged>(_onLastNameChanged);
    on<ProfilePickImageRequested>(_onPickImageRequested);
    on<ProfileRemoveImageRequested>(_onRemoveImageRequested);
    on<ProfileContinuePressed>(_onContinuePressed);
    on<ProfileClearMessage>(_onClearMessage);
    on<ProfileClearCompleted>(_onClearCompleted);
  }

  final ImagePicker _imagePicker;
  final ProfileRepository _profileRepository;
  static const _tag = 'ProfileBloc';

  void _onFirstNameChanged(
    ProfileFirstNameChanged event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(firstName: event.value, clearError: true));
  }

  void _onLastNameChanged(
    ProfileLastNameChanged event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(lastName: event.value, clearError: true));
  }

  Future<void> _onPickImageRequested(
    ProfilePickImageRequested event,
    Emitter<ProfileState> emit,
  ) async {
    // Profile photos are not supported by Catalog API; keep local UX only.
    emit(state.copyWith(isPickingImage: true, clearError: true));
    try {
      final picked = await _imagePicker.pickImage(
        source: event.source,
        imageQuality: 85,
      );
      emit(
        state.copyWith(
          imagePath: picked?.path,
          isPickingImage: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isPickingImage: false,
          errorMessage: 'Unable to open image picker right now.',
        ),
      );
    }
  }

  void _onRemoveImageRequested(
    ProfileRemoveImageRequested event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(imagePath: '', clearError: true));
  }

  Future<void> _onContinuePressed(
    ProfileContinuePressed event,
    Emitter<ProfileState> emit,
  ) async {
    if (!state.canContinue) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final first = state.firstName.trim();
      final last = state.lastName.trim();
      await _profileRepository.updateNames(
        firstName: first,
        lastName: last,
      );
      AppLog.d(_tag, 'Profile names saved');
      emit(state.copyWith(isSubmitting: false, isCompleted: true));
    } catch (e) {
      AppLog.e(_tag, 'Profile update failed', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearMessage(ProfileClearMessage event, Emitter<ProfileState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onClearCompleted(
    ProfileClearCompleted event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(clearCompleted: true));
  }
}
