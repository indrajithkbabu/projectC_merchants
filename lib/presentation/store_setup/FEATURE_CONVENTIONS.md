# Store Setup Feature Conventions

This file defines what to follow for UI and logic inside `lib/presentation/store_setup/`.

## Mandatory Update Rule
- If store setup fields, copy, validation, selection flow, or requirements change, update this file in the same PR.

## UI Rules
- Wrap routes with `ScreenWrapper` (scaffold / light-gray background:
  `AppColors.scaffold`).
- Use `AppPadding` for spacing and layout.
- Use `AppTextStyles` for text and `AppColors` for palette consistency.
- Reuse shared helper widgets before creating feature-specific alternatives.
- Header is Telegram-style: `AppBackButton` + **Create your store** title in one
  row, then short helper copy (channel description + “up to 5 store photos”).
- Primary input is `StoreSetupIdentityCard`: white rounded card with circular
  camera/photo affordance (left) + underlined store-name field (right). No
  emoji/smiley suffix on the name field.
- Photos: empty circle → `StoreImagesPickRequested` (multi, max 5). After pick,
  the **first** image shows in the circle (optional count badge when >1). Tap
  the circle with photos → `showStoreSetupPhotosPreviewSheet` (PageView scroll
  when multiple, delete on current page, Add when under max). Do **not** show
  the horizontal `StoreImagesPickerStrip` on this route.
- Store link availability stays below in `StoreLinkCard` (white card on scaffold).
- Keep name-field fonts modest (~17) so the form feels compact.

## Logic Ownership
- Store setup screens handle presentation and user input orchestration only.
- Keep side effects in listeners instead of build methods.
- Keep non-store-setup logic out of this feature’s presentation layer.
- `StoreSetupBloc` calls slug availability, create store, and skip-store APIs.
  Max images = `StoreRequest.maxStoreImages` (5).
- Image pick downscales (`maxWidth`/`maxHeight` 1600, quality 80) to reduce
  nginx **413 Request Entity Too Large** risk. Create never uploads all photos
  in one multipart: create with the first image (or JSON-only on 413), then
  `appendStoreImages` one file at a time (same pattern as bulk collection
  publish). A 413 HTML response is from **nginx/backend body-size limits**, not
  Flutter itself — the client mitigates by smaller payloads.
- Skip navigates to store listing; create continues to team contacts.

## Route and Navigation Notes
- Route entries belong in centralized navigation files.
- Use shared Cupertino-style route transition behavior.
- Opened from Profile tab / Contacts empty CTA after auth (not forced in
  onboarding). Create → `add_team_route` → `store_listing_route` (home warm
  cache is cleared on create so the new store shows immediately).

## Folder Scope
- `store_setup_route.dart`: store setup route.
- `store_setup_widgets/`: widgets that are specific to store setup UI
  (`store_setup_identity_card`, `store_setup_photos_preview_sheet`,
  `store_link_card`, `store_images_picker_strip`, `store_name_field`).
