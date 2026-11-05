# Catly merchant profile deep linking guide

## Purpose and scope

This guide defines how Catly shares and opens a merchant profile using two complementary link types:

1. **Verified HTTPS links:** Android App Links and iOS Universal Links use a normal website URL that can open Catly or the merchant website.
2. **Custom-scheme links:** a `catly://` URI asks the operating system to open Catly through a registered app handler.

The HTTPS URL is the public share link. The custom scheme is a supplemental entry point for controlled integrations. Both must resolve through the same Flutter destination handler and Catalog access checks.

This guide describes the intended implementation. Production domain ownership, app identifiers, signing certificates, Flutter version, routing library, and existing website configuration must be confirmed before applying the examples. Examples contain placeholders and are not production-ready credentials.

## Link contract

For the initial merchant profile scope:

```text
Public share URL:  https://catly.in/malabar-gold
Custom scheme:     catly://store/malabar-gold
Destination:       store with slug malabar-gold
```

In the custom URI, `catly` is the scheme, `store` is the host, and `malabar-gold` is the single path segment. The public HTTPS URL must be used in the native share sheet, messages, and QR codes. A custom scheme does not provide a dependable website fallback if the app is absent.

The root-level HTTPS format is the requested example. It shares a namespace with pages such as `/about`, `/privacy`, and `/login`. Reserve such paths and handle existing collisions before release. A future decision to use `/store/{slug}` would permit narrower platform association rules and avoid most root-level conflicts; all teams must agree the format before publishing permanent links.

Slug uniqueness alone does not guarantee permanence. A published slug must never point to a different merchant later. Enforce immutability or retain permanent aliases when a slug changes, reserve deleted slugs, and audit existing data. Confirm the current update and deletion behaviour before designing a migration.

## How the two approaches work

### Verified HTTPS links

The app declares the domains it handles. Catly hosts platform-specific association files on that same domain. Android and iOS use those declarations to verify the relationship. When a recipient taps an eligible link, the operating system may deliver it to the installed app. Otherwise, the browser can request the same URL and render the website.

```text
WhatsApp / SMS / another application
                 |
        https://catly.in/malabar-gold
                 |
     Operating system and source app
          /                  \
     Catly app             Browser
          |                    |
 Flutter parses slug      Merchant web page
          |                    |
          +---- Catalog API ---+
                   |
          Apply visibility rules
```

For example, a recipient with Catly installed may tap a WhatsApp link and open the Malabar Gold profile directly. A recipient without the app opens the merchant website. A recipient with the app can still reach the browser because of user preference, verification status, source-app behaviour, or platform rules. The web page must remain useful in every browser case.

The OS decides whether to route a link to the installed app; the backend does not need to detect app installation. When the app opens directly, the website may never receive the click.

Apple notes that entering a URL in Safari's address bar stays in the browser, and same-domain navigation in Safari generally stays in Safari. Third-party browsers and in-app browsers can differ. See [Apple Universal Links](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content) and [Android App Links](https://developer.android.com/training/app-links/about).

### Custom scheme

The mobile app registers `catly` with the OS. A controlled caller can open `catly://store/malabar-gold`. If the OS delivers it to Catly, Flutter parses the URI, resolves the slug through the backend, and navigates to the same profile.

If Catly is not installed, the result varies by platform and browser: an error or no useful action is possible. Another app may register the same scheme; it is not a verified proof of domain ownership. Do not use this URL as a public share link or as proof of authorization. See [Android deep-link types](https://developer.android.com/training/app-links/create-deeplinks).

### Deferred installation is out of scope

Neither of these approaches alone guarantees that a user who installs Catly after seeing a merchant web page lands on that merchant on first launch. A user can reopen the original HTTPS link after installing. Automatic post-install continuation requires a separate deferred deep-link design, platform-specific integration, and product approval.

## Flutter implementation

### 1. Share the current profile

Add **Share Profile** on the merchant profile screen. Obtain the canonical HTTPS URL for the store currently being viewed, then invoke the native mobile share sheet. Example content:

```text
View Malabar Gold on Catly:
https://catly.in/malabar-gold
```

Use a maintained share plugin compatible with the existing project, or the project's existing sharing abstraction. Do not share the current user's store when they are viewing another merchant. Do not put phone numbers, internal user identifiers, credentials, or other private data in the URL. Define whether private-store profiles can be shared; sharing must never change access permissions.

Prefer a backend-provided canonical `shareUrl`. If the existing API cannot supply it initially, build it only from trusted configuration and a validated canonical slug; do not construct the public host from untrusted request headers.

### 2. Choose one incoming-link integration

Inspect the existing Flutter router, Flutter version, and installed plugins. Use either Flutter's built-in deep-link handling or a maintained plugin that handles incoming links; configure a single owner for link delivery to avoid duplicate navigation.

Flutter's default handler is enabled by default in current versions; if a third-party deep-link plugin is used, follow Flutter's instructions for disabling the default handler on each platform. Behaviour differs for older Flutter versions. See [Flutter Android setup](https://docs.flutter.dev/cookbook/navigation/set-up-app-links), [Flutter iOS setup](https://docs.flutter.dev/cookbook/navigation/set-up-universal-links), and the [deep-link flag migration](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change). A Router-based design is useful for complex app navigation; preserve the existing architecture where it already handles these cases. [Flutter routing](https://docs.flutter.dev/ui/navigation).

### 3. Parse both forms into one destination

The handler should accept only supported schemes, hosts, and path shapes. Catalog currently validates slugs as lowercase hyphen-separated values, length 3–50. Keep the Flutter validation aligned with the backend, which remains authoritative. Do not treat an incoming link as trusted.

Illustrative Dart parser; integrate with the chosen link-delivery mechanism and router:

```dart
class StoreDestination {
  const StoreDestination(this.slug);
  final String slug;
}

final _slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
const _reservedPaths = {'about', 'login', 'privacy', 'api'};

StoreDestination? parseStoreLink(Uri uri) {
  final isHttps = uri.scheme == 'https' && uri.host == 'catly.in';
  final isCustom = uri.scheme == 'catly' && uri.host == 'store';
  if (!isHttps && !isCustom) return null;
  if (uri.userInfo.isNotEmpty || uri.hasPort || uri.pathSegments.length != 1) {
    return null;
  }

  final slug = uri.pathSegments.single;
  if (slug.length < 3 || slug.length > 50 || !_slugPattern.hasMatch(slug)) {
    return null;
  }
  if (isHttps && _reservedPaths.contains(slug)) return null;
  return StoreDestination(slug);
}
```

The reserved list is illustrative, not an exhaustive production list. Coordinate it with website routing and the backend. Explicitly decide whether queries and fragments are allowed for analytics; never allow them to authorize actions or trigger arbitrary redirects. Ensure encoded paths and malformed input are tested. Unknown destinations should be handled safely rather than interpreted as store slugs.

### 4. Resolve and navigate

For either link type:

1. Parse and validate the incoming URI.
2. Retain the destination until app initialization and the router are ready.
3. Resolve the slug using `GET /v1/catalog/stores/by-slug/:slug` and the current viewer's auth context.
4. Navigate to the returned store with the existing merchant profile flow.
5. Show a loading, private-store, unavailable, or retry state as appropriate.

Never use the last viewed or logged-in merchant as a fallback when lookup fails. Backend access checks apply even if the link is valid.

### 5. Handle lifecycle and authentication

| Situation | Expected behaviour |
| --- | --- |
| App terminated | Initialize app and router, then process the destination. |
| App backgrounded | Resume and route to the requested merchant. |
| App already running | Handle the new link once without corrupting or duplicating navigation. |
| Initialization in progress | Queue the destination until dependencies are ready. |
| Login required | Preserve the destination through login; resolve it again afterwards. |
| Login cancelled | Keep or discard the pending destination according to the agreed UX. |
| Account switched | Re-resolve with the new account; never carry over access rights. |
| Two links arrive | Define precedence; a reasonable default is the most recent valid destination. |
| Network failure | Show retry; do not open an unrelated cached store. |

Consume pending navigation once and test duplicate link delivery. A pending destination contains a route, not permission to access its contents.

## Android configuration

### HTTPS App Link intent filter

In the relevant activity of `AndroidManifest.xml`, configure an HTTPS `VIEW` intent filter with `DEFAULT`, `BROWSABLE`, and `autoVerify`. Illustrative example:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="catly.in" />
</intent-filter>
```

This example has no path restriction and is broad: links to other paths on `catly.in` may reach the app. Review all website routes and implement safe handling for unsupported destinations. A `/store/` namespace would allow more focused path matching. Merge with the existing app configuration carefully.

### Custom-scheme intent filter

Keep the custom scheme in a separate filter to make the intended matching clear:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="catly" android:host="store" />
</intent-filter>
```

### Digital Asset Links file

Host this exact path publicly over HTTPS without a redirect:

```text
https://catly.in/.well-known/assetlinks.json
```

Illustrative JSON:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.catly",
      "sha256_cert_fingerprints": ["REPLACE_WITH_REAL_SHA256_FINGERPRINT"]
    }
  }
]
```

Use the real application ID and the fingerprint of the certificate signing the distributed app. If Google Play App Signing is used, check the Play app-signing certificate rather than assuming the upload key is correct. Configure staging and debug identities deliberately. See [Android App Links verification](https://developer.android.com/training/app-links/verify-applinks) and [troubleshooting](https://developer.android.com/training/app-links/troubleshoot).

## iOS configuration

### Universal Links

Enable Associated Domains for the target in Xcode and add:

```text
applinks:catly.in
```

The entitlement contains the host, without the scheme, path, port, or trailing slash. Host the following JSON file publicly over HTTPS without redirect or authentication:

```text
https://catly.in/.well-known/apple-app-site-association
```

The file has no `.json` extension. Illustrative contents:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAM_ID.com.example.catly"],
        "components": [
          { "/": "/*", "comment": "Broad example; review Catly paths" }
        ]
      }
    ]
  }
}
```

Replace the placeholder with the app's actual Apple application identifier. The `/*` rule is intentionally broad: define exclusions and app handling for non-store website routes, or adopt a narrower store namespace. Apple uses an associated-domains CDN, so allow for propagation and caching when testing changes. Each relevant host needs its own appropriate association setup. [Apple Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains).

### Custom scheme

Register `catly` in the iOS target's URL Types or `Info.plist`. Illustrative configuration:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.example.catly.links</string>
    <key>CFBundleURLSchemes</key>
    <array><string>catly</string></array>
  </dict>
</array>
```

The app must still validate the scheme, host and path, and resolve the store through the API. Coordinate the native lifecycle callback with the selected Flutter link handler.

## Website and domain responsibilities

The website must render the merchant URL for browser visitors, including desktop users. It should fetch public-safe Catalog data, render private or unavailable states, and offer app-store or app-opening actions where product requires them. The website cannot reliably detect whether the app is installed in every browser.

For iOS, a same-domain link tapped while browsing the site in Safari often remains in Safari. A separate associated subdomain may help for a deliberate web-to-app handoff, but requires its own association and testing. A custom-scheme button may be offered as an explicit action, but browser behaviour when the app is absent varies. Do not rely on a hidden launch attempt or timer as a reliable installation detector. [Apple troubleshooting](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links).

Serve merchant-specific title and Open Graph metadata in the initial HTML so messaging previews can obtain the store name, canonical URL, and approved public image. Do not expose private products or restricted information in metadata. External messaging platforms may cache previews.

Route `/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association` before catch-all website routes. Verify they return the actual files, not HTML, authentication pages, redirects, or CDN errors. `catly.in`, `www.catly.in`, and any link subdomain are separate hosts and need deliberate configuration. Confirm production and staging DNS, TLS, CDN routing, and the team responsible for deployments.

## Catalog backend responsibilities

The existing code provides starting points:

- `CatalogStore` has a unique `slug` in `models/catalogStoreModel.js`.
- `GET /v1/catalog/stores/by-slug/:slug` and `GET /v1/catalog/web/stores/:slug` are registered in `routes/catalogRoutes.js`.
- `getWebStore` in `services/catalogStoreService.js` applies public/private behaviour and excludes locked products from the public product query.
- The existing web endpoint checks an allowed `Origin` and returns JSON; assess whether it fits the website's actual rendering and server-to-server access design. An Origin check is not user authentication.

Before implementation, audit store update and deletion paths, public data fields, cache behaviour, private-store policy, and whether suspension exists in the current model. Add or adjust functionality only where the audit identifies a gap.

Recommended backend contract:

1. Resolve a validated current slug or permitted permanent alias to exactly one store.
2. Return canonical slug and HTTPS share URL using trusted configuration.
3. Apply the same viewer privacy and product-lock rules for linked and ordinary navigation.
4. Return defined not-found, private, unavailable, and temporary-error responses.
5. Expose only fields required by public web pages and preview metadata.
6. Reserve site paths and prevent old public slugs from being assigned to another store.

No per-share database record, install-detection API, subscription gate, or new link-generation service is required for the stated scope. A MongoDB ID in an API response is not itself an authorization mechanism; review whether each public field is necessary, and keep internal IDs out of the shared URL.

## Testing and release checklist

### Functional scenarios

- Share the currently displayed merchant, including when viewing another merchant.
- Tap an HTTPS link with the app installed and absent, from WhatsApp, SMS, Notes/Messages, a browser, and desktop.
- Test terminated, backgrounded, and foreground app states; check that each incoming link is handled once.
- Test guest, logged-in, account-switch, onboarding, login-cancel, and multiple-link cases.
- Test public and private stores, locked products, invalid slugs, missing stores, deleted or unavailable stores, aliases, and network failure.
- Test the custom URI with the app installed and absent, including malformed input and unknown routes.
- Check the merchant's social preview and confirm private content does not appear.
- Verify that a website path such as `/privacy` is not mistaken for a store.
- Confirm changing branding or privacy updates Catly's own caches within the agreed period; third-party preview caches may persist longer.

### Platform and deployment verification

- Test production-like signed Android builds and the actual signing fingerprint. Use Android Studio App Links tools and commands such as `adb shell pm verify-app-links --re-verify <package-name>` and `adb shell pm get-app-links <package-name>`. A forced intent test alone does not establish verified-link routing.
- Test Universal Links on real iPhones from a tappable link in Notes, Messages, and intended third-party apps. Typing the URL in Safari's address bar tests the website, not app routing.
- Verify both association endpoints directly over HTTPS and inspect status, content, redirects, TLS, and CDN behaviour.
- Check real devices after association-file changes; Android and Apple association caches may delay updates.
- Test staging and production separately, using the correct host, app identity, entitlement, and certificate for each.
- Monitor website and API failures, domain verification, and app navigation errors without placing sensitive data in logs.

## Team ownership and decisions

| Area | Primary responsibility |
| --- | --- |
| Flutter | Sharing, link delivery, validation, navigation, lifecycle and login continuation |
| Android and iOS | Intent filters, app identifiers, signing, associated domains and custom-scheme registration |
| Web | Merchant page, public preview metadata, app-opening UX and browser fallback |
| Backend | Slug resolution and permanence, canonical URL, privacy, availability and public data |
| Infrastructure | DNS, HTTPS, association files, CDN routing and environment separation |
| QA | End-to-end device, source-app, browser, authentication and failure testing |

Before implementation, agree the final public path, slug-change and deletion rules, private-store display, share-button visibility, app-opening UX on the website, production and staging identities, and whether any future post-install continuation is required. Confirm who controls the domain and the `.well-known` files.
