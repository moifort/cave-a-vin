# iOS Development Guide

## Tech Stack

- **SwiftUI** with iOS 26.0 deployment target
- **Swift 6** with strict concurrency
- **Apollo iOS** (via SPM) — the app talks to the backend over GraphQL
- **Firebase Auth** — requests carry a Firebase ID token
- **Sentry** for crash reporting and performance monitoring

## Project Structure

```
ios/Vinarium/
├── VinariumApp.swift           # Entry point + Firebase/Sentry init
├── ContentView.swift           # Root view
├── Assets.xcassets/            # App icon, accent color
├── Generated/GraphQL/          # Apollo codegen output (schema types + operations)
├── Shared/
│   ├── APIClient.swift             # Base URL + REST helper
│   ├── GraphQLClient.swift         # Apollo singleton (Firebase Bearer auth)
│   ├── FirebaseTokenInterceptor.swift # Injects Authorization: Bearer <ID token>
│   ├── ErrorReporting.swift        # Sentry error reporting
│   ├── Secrets.swift               # API tokens (gitignored)
│   └── Components/                 # Cross-feature reusable atoms
│       ├── WineColorBadge.swift
│       ├── StarRatingView.swift
│       └── LabeledInfoRow.swift
└── Features/                   # Feature modules
    └── {Feature}/
        ├── {Feature}View.swift        # Coordinator: owns the ViewModel, NavigationStack, sheets, domain→primitive mapping
        ├── {Feature}Models.swift      # Swift model structs (Wine, UserWineDetail …)
        ├── {Feature}API.swift         # Feature API enum (wraps GraphQL operations)
        ├── {Feature}ViewModel.swift   # ViewModel
        ├── GraphQL/                   # .graphql query/mutation operation files
        └── components/
            ├── pages/                 # Pure, previewable screen layouts (bindings + primitives + closures)
            ├── organisms/             # Composite sections, forms, content views
            └── molecules/             # Small composed views (rows, badges)
```

Two layers split the "screen": the feature-root **`{Feature}View`** is the coordinator (it owns the `@State` ViewModel, the `NavigationStack`, sheet presentation, and maps domain models to primitives), and **`components/pages/{Feature}Page`** is a pure presentational view driven only by bindings, primitive data, and closures — so the whole screen stays previewable without a running server. `ContentView` wires the `{Feature}View` coordinators together.

Xcode uses `fileSystemSynchronizedGroups`, so new files are picked up automatically — no manual project edits.

## Feature Pattern

### ViewModel

> Every network call shows a loading state (lists, buttons, sections) — never a silent fetch.

```swift
import SwiftUI

@MainActor @Observable
final class WineListViewModel {
    private(set) var wines: [Wine] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await WineAPI.list(/* … */)
            wines = page.items
        } catch {
            errorMessage = reportError(error)
        }
    }
}
```

Key conventions:
- `@MainActor` on all ViewModels
- `@Observable` (not `ObservableObject`)
- `private(set)` for published state
- Error reporting via `reportError()` (Sentry)

### Coordinator (`{Feature}View`)

The feature-root `*View` owns the ViewModel and all side effects (loading, navigation, sheets), maps the ViewModel's domain models to the primitives its `Page` expects, and holds nothing presentational itself:

```swift
struct WineListView: View {
    @State private var viewModel = WineListViewModel()
    @State private var selectedWineId: String?

    var body: some View {
        NavigationStack {
            WineListPage(
                groups: mappedGroups,               // domain → primitives happens here
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.error,
                onWineTapped: { selectedWineId = $0 },
                onRefresh: { await viewModel.load() }
            )
            .task { await viewModel.load() }
            .sheet(item: /* selectedWineId */) { WineDetailView(wineId: $0.id) }
        }
    }
}
```

### Page (pure, previewable)

The `Page` under `components/pages/` takes only bindings, primitives, and closures — no ViewModel, no API calls — and adds the navigation chrome. It renders in a `#Preview` with mock data:

```swift
struct WineListPage: View {
    let groups: [WineListContent.Group]
    var isLoading = false
    var errorMessage: String?
    var onWineTapped: (String) -> Void
    var onRefresh: () async -> Void

    var body: some View {
        WineListContent(groups: groups, isLoading: isLoading, onWineTapped: onWineTapped)
            .navigationTitle("Cave")
            .refreshable { await onRefresh() }
    }
}
```

### Primitive-First Views

Leaf views (atoms, molecules) receive only primitive types — never domain structs:

```swift
// Good — takes only what it displays
struct WineListRow: View {
    let name: String
    let color: WineColor  // simple enum without logic = tolerated
    let vintage: Int?

    var body: some View {
        HStack {
            WineColorBadge(color: color)
            Text(name)
        }
    }
}

// Bad — takes the full model (many fields, only 3 used)
struct WineListRow: View {
    let wine: Wine  // Don't do this
}
```

**Allowed types in leaf views:**
- `String`, `Int`, `Int?`, `Double?`, `Bool`, `Date?`
- Simple enums without logic (like `WineColor` — equivalent to a typed String)
- Closures (`() -> Void`, `(String) -> Void`)
- **Never** domain structs (`Wine`, `UserWineDetail`, `CellarBottle`)

### Item Pattern (5+ Parameters)

When a component needs more than ~5 parameters, define a nested `Item` struct:

```swift
struct WineListContent: View {
    let items: [Item]

    var body: some View {
        List(items) { item in
            WineListRow(name: item.name, color: item.color, vintage: item.vintage)
        }
    }
}

extension WineListContent {
    struct Item: Identifiable {
        let id: String
        let name: String
        let color: WineColor
        let vintage: Int?
        let isFavorite: Bool
    }
}
```

The mapping from domain models to `Item` happens at the **page level** (coordinator):

```swift
struct WineListPage: View {
    @State private var viewModel = WineListViewModel()

    var body: some View {
        WineListContent(
            items: viewModel.wines.map { wine in
                .init(id: wine.id, name: wine.name, color: wine.color,
                      vintage: wine.vintage, isFavorite: wine.isFavorite)
            }
        )
    }
}
```

### Atomic Design Layers

| Layer | Location | Receives | Examples |
|-------|----------|----------|----------|
| **Coordinator** | `Features/{F}/{F}View.swift` | Owns the ViewModel | `WineListView`, `WineDetailView` |
| **Pages** | `Features/{F}/components/pages/` | Bindings + primitives + closures | `WineListPage`, `WineDetailPage` |
| **Organisms** | `Features/{F}/components/organisms/` | Primitives or `Item` / domain struct at the mapping boundary | `WineListContent`, `WineEditForm`, `WineDetailContent` |
| **Molecules** | `Features/{F}/components/molecules/` | Primitives | `WineListRow`, `LocationSection` |
| **Atoms** | `Shared/Components/` | Primitives | `WineColorBadge`, `StarRatingView` |

**Atoms** in `Shared/Components/` are cross-feature. A molecule used in 2+ features should be promoted to `Shared/Components/`.

### Coordinator vs Page

The feature-root `{Feature}View` is the coordinator: it handles loading, error states, sheets, navigation, and the domain→primitive mapping, and is the only layer that holds the `@State` ViewModel and triggers API calls. The `{Feature}Page` it renders stays pure — bindings, primitives, and closures only — so it (and everything below it) is previewable. This is one layer more than a Page-owns-the-ViewModel setup, and the payoff is that the full screen layout previews without a server.

### Organisms as Mapping Boundaries

An organism like `WineDetailContent` can accept a domain struct when it's the **mapping boundary** — the point where the domain model is broken down into primitives for child sections:

```swift
struct WineDetailContent: View {
    let detail: UserWineDetail          // OK at organism level
    var onRemoveRequested: () -> Void = {}

    var body: some View {
        List {
            WineDetailHeader(name: detail.name, color: detail.color)       // primitives
            WineOriginSection(region: detail.region, country: detail.country) // primitives
        }
    }
}
```

The key: child sections within the organism only receive primitives.

### Edit Form Pattern

Extract edit forms into standalone organisms with a `Fields` struct:

```swift
struct WineEditForm: View {
    let initial: Fields
    let onSave: (UpdateRequest) async throws -> Void
    let onCancel: () -> Void

    @State private var name: String
    // … @State per field, initialized from `initial` via State(initialValue:)

    struct Fields {
        var name: String
        var color: WineColor
        // … all primitive values
    }
}
```

Benefits: previewable in isolation, testable independently, the parent page stays lean.

### Toolbar / navigation CTAs

Top-of-screen CTAs (navigation bars, sheet headers) follow one convention across the whole app:
**icon-only**, positioned by role. Never a text label — the `title` is passed only for accessibility
(VoiceOver), never rendered.

| Side | Role | Icon | Placement |
|------|------|------|-----------|
| Left | Cancel / Close / dismiss | `xmark` | `.cancellationAction` |
| Left | Back (onboarding navigation) | `chevron.left` | `.topBarLeading` |
| Right | Confirm / Save | `checkmark` | `.confirmationAction` |
| Right | Add | `plus` | `.primaryAction` |
| Right | Secondary actions (view modes, sort, move/remove) | domain icon | `ToolbarItemGroup` |

Render every toolbar CTA through the two shared atoms in `Shared/Components/` — never an inline
`Button` with a visible label:

- **`ToolbarIconButton(title:systemImage:role:action:)`** — synchronous icon-only button for
  cancel / close / back and secondary actions. Applies `.labelStyle(.iconOnly)`; keeps `title` for VoiceOver.
- **`AsyncToolbarButton(title:systemImage:action:)`** — async confirm button; shows a `ProgressView`
  while the action runs, icon-only otherwise.

For a `Button`/`Menu`/mode-toggle that can't use these atoms, force `.labelStyle(.iconOnly)` yourself
and keep the `Label`'s text for accessibility.

### Previews as Storybook

**Every view has a `#Preview`** — pages, organisms, molecules, shared atoms, private
sub-views of a file, and the feature-root coordinators. Preview names are dev-facing,
so they are written in **English** like the rest of the repo, even though the on-screen
copy inside them is French.

Everything from the page level down previews **without a running server**, since none
of it holds a ViewModel:

```swift
// The pure Page previews with inline data
#Preview("In cellar") {
    WineDetailContent(detail: UserWineDetail(id: "1", name: "Margaux", /* … */), onRemoveRequested: {})
}
```

The feature-root `{Feature}View` coordinator owns the ViewModel, so its preview is a
**smoke preview**: it renders the loading or empty state the canvas can reach on its own
and never proves the data path. Keep it cheap and never make it the place where a screen
is designed — that stays the `Page`'s job. Two coordinators need a nudge to get there:

- `AuthRoot` calls `FirebaseApp.configure()` first, because the canvas does not run
  `VinariumApp.init` and `AuthSession` traps on an unconfigured Firebase.
- `ScanView` renders its controls over an empty preview layer: the canvas has no camera,
  and `CameraView` wires no input in that case.

One documented exception: `OfferButton` (in `PremiumSheet`) has no preview, because
StoreKit's `Product` has no public initializer and cannot be built by hand. Anything else
that resists previewing is a design smell — pull the presentational part out rather than
skip the preview.

## GraphQL Client (Apollo iOS)

The app talks to the backend over GraphQL only. `GraphQLClient.shared` wraps Apollo's `ApolloClient`, pointed at `<baseURL>/graphql`, with a `FirebaseTokenInterceptor` that injects `Authorization: Bearer <Firebase ID token>` on every request.

Feature APIs are enums that wrap the generated operations and return the app's own model types, so ViewModels never touch Apollo generated types:

```swift
enum WineAPI {
    static func list(/* … */) async throws -> WinePage {
        let query = VinariumGraphQL.WineListQuery(/* … */)
        // execute, then map generated types → Wine
    }
    static func delete(id: String) async throws { /* mutation */ }
}
```

**Architecture:**
- `Shared/GraphQLClient.swift` — the Apollo singleton (Firebase Bearer auth, logging interceptor)
- `Features/{Feature}/{Feature}API.swift` — feature API enum returning app model types
- `.graphql` operation files in `Features/{Feature}/GraphQL/` — queries and mutations
- Generated types in `Generated/GraphQL/` — schema namespace `VinariumGraphQL`

**Codegen:** after changing the server schema, regenerate the SDL (`bun run generate:graphql`), then run `cd ios && apollo-ios-cli generate` (config `ios/apollo-codegen-config.json`). When adding a branded type, also update the custom scalar mapping under `Generated/GraphQL/`.

## Model Types

App model types are plain `Sendable` structs mapped from the GraphQL responses (Swift 6 requires `Sendable`):

```swift
struct Wine: Sendable, Identifiable {
    let id: String
    let name: String
    let color: WineColor
    let vintage: Int?
    // …
}
```

## Secrets Setup

Copy the examples and fill in your values:

```bash
cp ios/Vinarium/Shared/Secrets.swift.example ios/Vinarium/Shared/Secrets.swift
cp ios/VinariumUITests/Support/TestSecrets.swift.example ios/VinariumUITests/Support/TestSecrets.swift
```

## Build

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ios/Vinarium.xcodeproj -scheme Vinarium \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build
```

`DEVELOPER_DIR` is required because `xcode-select` points to the CommandLineTools. The simulator is iPhone 17, OS 26.2.
