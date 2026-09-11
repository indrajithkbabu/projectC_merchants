# Home Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/home/`.

## Mandatory Update Rule
- If home screen purpose, placeholders, cards, entry points, or requirements change, update this file in the same PR.

## UI Rules
- Wrap full routes with `ScreenWrapper`.
- Use `AppPadding`, `AppTextStyles`, and `AppColors`.
- Reuse shared helper widgets before introducing local duplicates.
- Keep spacing and typography consistent with global conventions.

## Logic Ownership
- Home presentation should coordinate only home-facing display and interactions.
- Use listeners for side effects (navigation/messages), not build-time effects.
- Keep business/state logic outside widgets; consume bloc/cubit/view model state only.

## Route and Navigation Notes
- Keep route registration centralized.
- Use the shared route transition style.

## Folder Scope
- `home_placeholder_route.dart`: home placeholder/presentational route.
