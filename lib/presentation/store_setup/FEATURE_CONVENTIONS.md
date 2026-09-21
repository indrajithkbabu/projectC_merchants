# Store Setup Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/store_setup/`.

## Mandatory Update Rule
- If store setup fields, copy, validation, selection flow, or requirements change, update this file in the same PR.

## UI Rules
- Wrap routes with `ScreenWrapper`.
- Use `AppPadding` for spacing and layout.
- Use `AppTextStyles` for text and `AppColors` for palette consistency.
- Reuse shared helper widgets before creating feature-specific alternatives.
- Optional showcase photos (0–5) use `StoreImagesPickerStrip`.

## Logic Ownership
- Store setup screens handle presentation and user input orchestration only.
- Keep side effects in listeners instead of build methods.
- Keep non-store-setup logic out of this feature’s presentation layer.
- `StoreSetupBloc` calls slug availability, create store (JSON or multipart with
  `images`), and skip-store APIs.
- Skip navigates to store listing; create continues to team contacts.

## Route and Navigation Notes
- Route entries belong in centralized navigation files.
- Use shared Cupertino-style route transition behavior.

## Folder Scope
- `store_setup_route.dart`: store setup route.
- `store_setup_widgets/`: widgets that are specific to store setup UI.
