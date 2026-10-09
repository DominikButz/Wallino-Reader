# Wallino Reader — Codebase Overview

This file describes the project structure, conventions, and key facts to help a
coding agent work in this repository without re-analyzing the code base from
scratch each session.

## What this project is

Wallino Reader is a **fork of the open-source [wallabag iOS app](https://github.com/wallabag/ios-app).
wallabag is a self-hosted, open-source "read it later" service. This app is a
native client that talks to a wallabag server (self-hosted or wallabag.it /
Framabag) and lets users read, archive, tag, and share saved articles offline.

- Language: Swift (SwiftUI + Combine)
- Platforms: iOS (primary) and macOS
- Min targets: iOS 17 (app target); the UI test target requires iOS 26.2+, macOS 11
- Xcode project: `wallino-reader.xcodeproj`

## Renaming (fork divergence)

The app was renamed from "wallabag" to **Wallino Reader** to allow a separate
App Store publication. Identifiers use the prefix `com.duoyun.wallino-reader`
(also for keychain service, App Groups, and dispatch queue labels). The share
extension target was renamed to `iOS-share_ext`. Debug builds add a `.debug`
suffix to the bundle identifier and use a separate App Group
(`group.com.duoyun.wallino-reader.debug`) so debug and production never share
data; `WallabagAppGroup.identifier` derives the correct group at runtime.

## Monetization & removed upstream features

The app targets a **self-hosted wallabag backend only** and has no
subscriptions. The following upstream features were removed:

- **Auto-renewable subscription** ("wallabag Plus") — deleted (`App/Features/WallabagPlus/`).
- **RevenueCat SDK** — removed entirely; no third-party purchase handling.
- **ChatGPT / AI** ("Synthesis" and "Suggest tag", `App/Features/AI/` plus the
  `GPTBACK_KEY` backend and the `swift-openapi-*` packages) — removed. AI-driven
  auto-tagging is planned to be re-added later via Apple Intelligence.

Tips/donations remain as a one-time in-app purchase, implemented with native
**StoreKit 2** (`App/Features/Tip/`). The product is `tips1` (consumable),
defined in the `App/WallinoStoreKit.storekit` StoreKit test configuration.

## Top-level layout

| Path | Purpose |
| --- | --- |
| `App/` | Main iOS app target (`Wallino Reader`): views, view models, entities, DI. |
| `iOS-share_ext/` | Share extension target (`iOS-share_ext`): SwiftUI share sheet that adds entries with mark-as-read, favorite, and tag selection. |
| `Intents/` | Siri/Shortcuts intents (`WallabagIntent`, `AddEntryIntent`). |
| `macOS/` | macOS app target (minimal — only `Info.plist`). |
| `WallabagKit/` | Local Swift package: pure API client for the wallabag REST API. |
| `SharedLib/` | Local Swift package: shared utilities (Keychain, UserDefaults, RetrieveMode). |
| `wallabagTests/` | iOS unit tests. |
| `Tests iOS/`, `Tests macOS/` | Per-platform test targets (Info.plist only). |
| `fastlane/` | CI / App Store release tooling (`beta`, `release`, `upload_screenshots`). |
| `media/`, `instructions_1.md` | Local assets and task notes; UI-test "plain" screenshots land in `media/screenshots/<locale>/` (all git-ignored). |
| `App/Resources/terms_privacy/` | Bundled legal HTML documents (`terms.html`, `privacy.html`) displayed in-app via `HTMLViewerView`. |
| `.swiftlint.yml`, `.swift-version`, `.swiftversion` | Tooling config. |
| `Config.xcconfig` | Build configuration (git-ignored). |

## Share extension (`iOS-share_ext/`)

- `ShareViewController.swift` is a thin UIKit bridge that hosts a SwiftUI
  `ShareView` via `UIHostingController`, extracts the shared item, and calls
  `completeRequest`/`cancelRequest` on `extensionContext`. It resolves the item
  from (in order) the JavaScript-preprocessing property list (`href`/`title`/
  `contentHTML`), a `public.url` attachment, or a `public.plain-text` attachment
  — the latter is common for newspaper apps whose shared "text" embeds the URL;
  URLs are pulled out with `String.detectedURLs`. Any number of URLs is accepted.
- `ShareView.swift` / `ShareViewModel.swift` provide the form (mark-as-read,
  favorite, tag multi-select with search and inline tag creation). Save issues
  one `POST /api/entries` per detected URL, applying the same options to each.
- The extension links only `WallabagKit` and `SharedLib` (no CoreData/Factory);
  it talks to the wallabag REST API directly and reads credentials from the App
  Group (`WallabagUserDefaults`). Mark-as-read/favorite/tags are sent as
  `archive`/`starred`/`tags` on the add request.
- Its `NSExtensionActivationRule` accepts pdf, image, url, and `public.plain-text`
  attachments (any match, not exactly one).
- It reuses the app's `Localizable.strings` (all 12 registered languages) via a
  shared `PBXVariantGroup`.

## Article content fetching (server fetch failures)

wallabag fetches and extracts articles on the **server** (graby). When that fails
— anti-bot walls, paywalls, stale `graby-site-config` — the server stores its
`wallabag.fetching_error_message` ("wallabag can't retrieve contents…") as the
entry content; the app is otherwise just a client. To work around this, the app
fetches the article from the **device** and hands the raw HTML to the server,
which still runs its own extraction on the supplied HTML.

- `SharedLib/.../Features/ArticleFetch/ArticleFetcher.swift` — device fetch
  (`URLSession`, Safari User-Agent, 30s timeout), `og:title`/`<title>` scraping,
  `ArticleContent.isFetchingError(_:)` detection. Shared by app + extension.
- `WallabagSession.addEntry` auto-repairs failed content after `POST
  /api/entries`; `WallabagSession.repairContent(entry:)` does the same for an
  existing entry. Both send the HTML via `PATCH /api/entries/{id}.json` with
  `content` (plus `title`); wallabag treats that as manual content, skips the
  server fetch, and runs `cleanupHtml`/extraction on it.
- The share extension applies the same fallback after its per-URL POST.
- The entry "Refetch" action (entry toolbar menu + entry-row long-press context
  menu) tries the server `PATCH /api/entries/{id}/reload` first and falls back to
  the device fetch when it fails or content is still the error placeholder.
- `WebView` reloads when `entry.content` changes so a refetch/repair is visible.

## App architecture (`App/`)

- **Entry point:** `App/WallinoApp.swift` (`@main`). Sets up the DI container
  singletons, injects environment objects/values, wires up scene phase handling,
  and the macOS "Refresh entries" command.
- **Dependency injection:** uses the **Factory** library (`App/Lib/DependencyInjection.swift`).
  All shared services are registered as `Factory<...>` singletons on `Container`,
  then injected via `@Injected` / `@InjectedObject` / `Container.shared.*`.
- **Core Data:** `App/Lib/CoreData.swift` (persistence), entities in `App/Entity/`
  (`Entry`, `Tag`, `Annotation`, `Podcast`). Models live in `App/Resources/wallabag.xcdatamodeld`
  and `wallabagStore.xcdatamodeld`. `wallabagStore.xcdatamodeld` is versioned for
  lightweight migration — annotations were added in `wallabagStore 3.xcdatamodel`.
- **State / services (`App/Lib/`):**
  - `AppState` — session/registration state.
  - `WallabagSession` — OAuth session against the server. Renews the access
    token with the OAuth `refresh_token` grant (`refreshSession()`), falling back
    to the password grant; authenticated mutations go through
    `performAuthenticated`, which re-authenticates and retries once on an auth
    failure.
  - `AppSync` / `CoreDataSync` (`App/Features/Sync/`) — server sync.
  - `Theme`, `WallabagError`, etc.
- **Features (`App/Features/`)**: one folder per feature area — `Entry`, `Tag`,
  `Registration`, `Router`, `Search`, `Setting`, `Player`, `Tip`,
  `BugReport`, `About`, `PasteBoard`, `Error`, `Haptic`, `Sync`. The `About`
  feature includes `HTMLViewerView` for displaying bundled legal HTML documents
  (terms & conditions, privacy policy). Annotations
  live inside the `Entry` feature (`WebView.swift`, `AnnotationEditMenu.swift`,
  `AnnotationEditorView.swift`, plus the
  `App/Resources/html-ressources/annotation.{js,css}` web-view assets).
- **Add entry:** `App/Features/Entry/Add/` (`AddEntryView`/`AddEntryModel`) accepts
  free text in the URL field and extracts the URLs with `String.detectedURLs`,
  creating one entry per URL and ignoring the surrounding text.
- **Navigation:** custom `Router` (`App/Features/Router/`) with `RoutePath` enum
  (includes `.terms`, `.privacy` for legal document views) and
  a `RouteSwiftUIExtension`. Main tab view is `App/Features/MainView.swift`
  (Entries + Tags tabs; the Tags tab uses a separate navigation path `tagsPath`).

## API client (`WallabagKit/`)

Pure Swift package (no external deps) generated/structured around the wallabag
REST API. `WallabagKit.swift` is the main entry; `Endpoint/` holds per-resource
endpoints (`WallabagEntryEndpoint`, `WallabagTagEndpoint`, `WallabagAnnotationEndpoint`,
`WallabagOAuth`, `WallabagConfigEndpoint`); `Model/` holds `WallabagEntry`,
`WallabagTag`, `WallabagAnnotation`, `AnnotationRange`, `WallabagAnnotationCollection`,
`WallabagToken`, `WallabagConfig`, `WallabagCollection`. `WallabagKit` also exposes
`fetchAnnotations(for:)` for `GET /api/annotations/{entry}.json`,
`requestTokenWithRefreshTokenAsync(...)` for the OAuth `refresh_token` grant, and
`delete(to:)`, which sends a DELETE and checks only the status code (no body
decoding, since DELETE responses may be empty/204). `WallabagKitError`
distinguishes authentication failures (`isAuthenticationFailure`).

## Annotations

wallabag annotations (highlight + note on an article) are fully supported —
create, display, edit, delete — and synced with the server.

- **Core Data:** `Annotation` entity (`App/Entity/Annotation.swift`) with a to-one
  `entry` relationship (inverse of `Entry.annotations`, to-many cascade). `ranges`
  is stored JSON-encoded as `[AnnotationRange]` in a `Binary` attribute (via the
  `rangesArray` accessor). Added in `wallabagStore 3.xcdatamodel`.
- **WallabagKit:** `WallabagAnnotationEndpoint` (get/add/update/delete) plus the
  `WallabagAnnotation`, `AnnotationRange`, `WallabagAnnotationCollection` models.
- **Sync:** `AppSync.synchronizeAnnotations()` fetches `/api/annotations/{entry}.json`
  per entry (N+1 — there is no bulk endpoint) and upserts/deletes locally.
- **Reader UI:** the article renders in a `WKWebView` (`WebView.swift`) with helper
  JS/CSS in `App/Resources/html-ressources/annotation.{js,css}` (loaded by
  `article.html`). Selecting text shows "Add annotation" in the native edit menu
  (added by swizzling `WKContentView.buildMenuWithBuilder:` in `AnnotationEditMenu.swift`),
  which highlights the selection and posts `{type: "showAdd", quote, ranges}` to
  Swift. Tapping a highlight posts `{type: "showEdit", id, text, quote}`. Both open
  a native SwiftUI sheet — `AnnotationEditorView` (`AnnotationEditorView.swift`),
  modes `.add`/`.edit`, `.medium`/`.large` detents, title "New annotation" / "Edit
  annotation", Cancel/Save toolbar buttons, a "Selected text" section, an
  "Annotation" text editor, and a Delete button in edit mode. The JS ↔ Swift bridge
  is a `WKScriptMessageHandler` named `"annotation"`; Swift calls back into JS via
  `window.__wallinoOnAnnotationAdded`, `__wallinoOnAnnotationUpdated`,
  `__wallinoOnAnnotationAddCancelled`, and `__wallinoRemoveAnnotation`.
- **Range format:** annotation `ranges` match the wallabag web app's `xpath-range`
  format — an XPath **relative to the `<article>` element** (e.g. `/p[1]`) plus an
  element-wide character offset (summed across descendant text nodes), with
  `endOffset` "one past the end". This is what makes highlights interoperable with
  the web app; do not change it casually.
- **Edit/delete:** `WallabagSession.update(annotation:id:text:)` /
  `delete(annotation:id:)` hit `PUT`/`DELETE /api/annotations/{id}`. Deletion uses
  `WallabagKit.delete(to:)` and only removes the local highlight/Core Data object
  after the server call succeeds; failures are logged. Empty annotation text is
  allowed (highlight-only annotations).
- **Debug helper:** the Settings "Annotations" section (DEBUG builds only) exposes
  "Delete All Annotations", which removes every annotation both locally and on the
  server via `WallabagSession.deleteAllAnnotations()` (runs off the main queue).

## Shared library (`SharedLib/`)

- `Lib/WallabagUserDefaults.swift` — typed `UserDefaults` access; also defines
  `WallabagAppGroup.identifier`, which derives the App Group
  (`group.com.duoyun.wallino-reader` or `.debug`) from the bundle identifier.
  `@Setting` and `@Password` use it so debug and production stay isolated.
- `Lib/KeychainPasswordItem.swift` — keychain storage (password, keyed by the App
  Group as access group).
- `Extension/String.swift` — string helpers, including `detectedURLs`, which uses
  `NSDataDetector` to extract unique http/https URLs from arbitrary text (ignores
  mail/phone links, normalizes scheme-less domains to https). Shared by the app's
  Add-entry field (`AddEntryModel`) and the share extension.
- `Features/RetrieveMode/` — the "all / archived / starred" retrieval mode used
  for filtering entries.
- `Features/ArticleFetch/` — `ArticleFetcher` (device-side HTML fetch + title
  scraping) and `ArticleContent.isFetchingError(_:)`; the fallback used by the
  app and the share extension when wallabag can't retrieve content.

## Localization

UI strings **must always be localized**. English source is `App/Resources/en.lproj/Localizable.strings`.
There are ~28 language folders under `App/Resources/*.lproj`. When adding UI
strings, add the key to `en.lproj` and backfill all other languages to keep the
key sets in sync. Currently, only 12 languages are registered. When changing, adding or deleting localization key value pairs, only the 12 languages should be included. The About section keys are: `"Project page"`, `"Based on Maxime Marinel's Wallabag for iOS"` (includes Wallabag server developer credits), and `"Forked & developed by Dominik Butz"`.

## Tests

- iOS unit tests: `wallabagTests/` (organized by feature, e.g. `Features/Router/RouterTests.swift`).
- `WallabagKit/Tests/WallabagKitTests/` for the API client (e.g. add/update
  request bodies carry `content`/`title`).
- `SharedLib/Tests/SharedLibTests/` for shared utilities
  (e.g. `Features/ArticleFetch/ArticleFetcherTests.swift` for title scraping and
  `ArticleContent.isFetchingError`).
- UI tests: `WallinoReaderUITests/` (target `WallinoReaderUITests`, min iOS 26.2).
  `WallinoReaderUITests.swift` contains five tests — `testEntryList`, `testEntryDetail`,
  `testEntryDetailMenu`, `testEntryDetailAI`, `testTagsList` — which drive the app and
  save "plain" screenshots to `media/screenshots/<locale>/<device>-<name> plain.png`
  (git-ignored). The locale folder is derived from the app's localized "Entries" tab
  (`Entries`→en-US, `Einträge`→de-DE, `Articles`→fr-FR), overridable via the
  `SNAPSHOT_LOCALE` env var; set the language in the scheme's Run/Test App Language.
- UI-test hooks: the app is launched with `-skipLogin` (bypass registration) and
  `-uiTesting`; `AppState.initSession()` returns early on `-uiTesting` so no session
  refresh/sync/Core Data writes run during tests (avoids `_PFObjectIDFastHash64` crashes
  during XCUITest accessibility snapshots).
- UI-test accessibility identifiers: `entry_list`, `entry_detail`, `entry_option_menu`,
  `ai_actions_menu`, `tags_list`.

## Conventions & tooling

- **Swift version:** `.swift-version` = 5.9; packages use `swift-tools-version:5.7`.
  (`.swiftversion` still says 5.3 — legacy/ignore.)
- **SwiftLint:** config in `.swiftlint.yml` (line length 300, `force_try` warns,
  `trailing_comma` disabled).
- **Fastlane:** `fastlane/Fastfile` lanes:
  - `beta` — build + upload to TestFlight.
  - `release` — increment build number, build the App Store IPA, upload the latest version to
    App Store Connect with metadata only (no screenshots, no review submission). Metadata is
    limited to en-US/de-DE/fr-FR via `filtered_metadata_path` (temp dir symlinking only those
    locale folders + non-localized root files). Submit for review manually in ASC.
  - `upload_screenshots` — screenshots + metadata only (no binary, no submission). Final artboards
    go in `fastlane/screenshots/<locale>/` at exact ASC resolutions (folder = locale, pixel
    resolution = device slot).
  - plus `test`, `setversion`, `incrementbuildnumber`. ASC API key from `fastlane/.env`.
- **Code style:** follow existing patterns — MVVM-ish (a `*View` plus a
  `*ViewModel`), DI via Factory, no hardcoded UI strings, no external SDK
  dependencies beyond Factory.
