# Outwit Games — iOS Engineering Rules

## Purpose

These rules apply to every change in this repository. The Android application
is the current product and behavior reference, but this is a native iOS app.
Preserve product rules and backend contracts while using Apple platform
conventions rather than mechanically translating Compose code.

Before editing, trace the existing flow, search for reusable code, and make the
smallest correct change. Keep exceptions local and document why they exist.

## Architecture

Use a feature-oriented SwiftUI application with:

- MVVM for screen state and user intents
- domain-oriented repositories where data orchestration justifies them
- a coordinator/router for cross-screen navigation
- constructor injection from a lightweight `AppEnvironment`
- project-owned protocols at meaningful replacement and test boundaries
- Swift Concurrency and Observation
- composition over inheritance
- clear presentation, domain, data, and infrastructure responsibilities

Primary dependency direction:

```text
SwiftUI View
    ↓
@Observable ViewModel
    ↓
Repository / focused service protocol
    ↓
Implementation
    ↓
API, realtime, storage, or platform abstraction
    ↓
URLSession, WebKit, Keychain, or product SDK adapter
```

Navigation direction:

```text
View / ViewModel → AppCoordinator → NavigationStack / sheet / alert
```

Feature code must not import or expose Firebase, Google Mobile Ads, Meta,
PostHog, raw WebSocket, Keychain, or WebKit implementation types. Those belong
behind project-owned infrastructure adapters.

## Simplicity

Architecture must make the app easier to change, test, and understand.

- Organize by product feature, not global `Views`, `ViewModels`, or `Managers`
  directories.
- Keep the app entry point small; it assembles and injects the environment.
- Do not create empty folders to satisfy a diagram.
- Do not create a protocol merely because a concrete type exists.
- Do not create a repository per endpoint.
- Do not add a DI, networking, navigation, or state-management framework.
- Add use cases or new layers only when real business complexity earns them.
- Prefer files around 100 lines where that improves responsibility boundaries;
  do not split cohesive code artificially.

## Reuse Scope

Place code at the narrowest level where it is genuinely reused:

```text
One screen             → Features/<Feature>/Components
Several feature screens → Features/<Feature>
Multiple features       → Core
Application assembly    → App
Assets/localization     → Resources
```

Search locally, then within the feature, then in `Core` before adding a new
component, model, service, mapper, or token. Promote code only after reuse is
real.

## SwiftUI Views

Views may own small presentation-only behavior such as focus, animation state,
or whether a local confirmation is visible.

Views must not:

- call backend APIs
- parse transport payloads
- read or write credentials
- contain business decisions
- manage token refresh
- decode Phoenix frames
- use product SDKs directly
- decide cross-feature navigation stacks

Keep observable reads narrowly scoped. Frequent HUD or media updates must not
rebuild a `WKWebView` or unrelated screen regions.

## ViewModels and State

ViewModels are normally `@MainActor @Observable` reference types. They own
screen state, handle user intents, call repositories/services, map results into
view data, and request navigation.

Prefer explicit states such as `idle`, `loading`, `loaded`, `empty`, and
`failed` over contradictory Boolean combinations. Feature-specific state is
preferred when a universal state would hide meaning.

ViewModels must not construct infrastructure, manipulate `NavigationPath`
directly, know endpoint URLs, parse raw JSON, or import platform product SDKs.

Cancel or ignore stale tasks, prevent duplicate requests, and avoid state
updates after the owning feature has gone away.

## Data Boundaries

Do not pass raw API payloads into UI:

```text
JSON → Decodable DTO → mapper → domain model → view state / view data
```

Keep DTOs, domain models, persistence records, and presentation models separate
when they represent different concerns. Do not manufacture duplicate models
when their shapes and responsibilities are genuinely identical.

Models should be simple value types. Add `Codable`, `Hashable`, `Identifiable`,
or `Sendable` only when the type needs the capability.

## Networking

Use a small generic `APIClient` built on `URLSession`. Each request describes
its path, method, headers, query, body, authentication requirement, and response
decoding. The client must never branch on a feature or endpoint type.

Authentication behavior belongs below repositories:

```text
request → bearer token → API → 401 → synchronized refresh → one safe retry
```

Only one refresh may be in flight. Never create infinite retry loops. Map
transport failures into `AppError` before they reach feature code. Debug logs
must redact authorization headers and private payloads.

## Storage and Security

- Store access, refresh, and socket tokens in Keychain.
- Use `UserDefaults` only for non-sensitive preferences.
- Never log tokens, OTPs, phone numbers, passwords, or private user data.
- Treat game results, rewards, balances, and competitive scores as
  server-authoritative.
- Do not put secrets in source-controlled `.xcconfig` or plist files.

## Realtime and Hosted Games

Keep these boundaries separate:

```text
Feature / Repository
    ↓
Phoenix protocol
    ↓
URLSessionWebSocketTask transport
```

The socket layer owns connection mechanics. Phoenix owns frames, topics,
heartbeats, replies, and reconnect behavior. Features own game rules and UI
state. Raw frames must never reach a ViewModel or View.

`WKWebView` is a trust boundary. Restrict navigation to approved origins,
validate every bridge message, inject credentials only at document start, and
never place tokens in URLs. Lifecycle subscriptions, channels, continuations,
and web views must be disposed by their owners.

## Concurrency

Use `async`/`await` and structured concurrency. UI state belongs on the main
actor. Networking and infrastructure must not be placed on the main actor
without a UI reason.

Use actors for shared mutable resources such as token-refresh coordination,
session state, account-scoped caches, and socket ownership. Prefer actor
isolation over manual locks. Preserve cancellation and never swallow
`CancellationError` as an ordinary failure.

## Dependency Injection

Create shared dependencies in `AppEnvironment` and inject them explicitly.
Use lazy construction where startup does not need the dependency. Do not use a
global service locator throughout features. Resolve dependencies at app or
feature composition boundaries.

Third-party product SDKs are allowed for required integrations such as Firebase,
Google Mobile Ads, Meta, and PostHog. They must be localized in infrastructure
adapters and may not determine the app architecture.

## Navigation

Use typed, `Hashable` routes and centralized coordinator intents. Route payloads
must carry what a restored destination needs, or carry a stable identifier only
when the data can always be fetched again. Avoid string route names and random
path mutations from Views.

Use native iOS navigation, sheets, alerts, swipe-back behavior, safe areas, and
accessibility. Match Android product flow and branding, not Android platform UI.

## Design System and Localization

Reuse brand colors, typography, spacing, radii, motion timings, assets, and
shared controls. Keep the design system small and grow it from actual repeated
UI. Do not hardcode recurring visual values across features.

All user-facing text belongs in the String Catalog with English and Hindi
localizations. Support Dynamic Type, VoiceOver, sufficient contrast, and Reduce
Motion. Any deliberate game-HUD scaling limit must be local and documented.

## Analytics, Ads, Push, and Observability

Feature code emits typed project-owned events and requests. Infrastructure maps
them to Firebase, Meta, PostHog, Google Mobile Ads, APNs/FCM, MetricKit, and
OSLog as appropriate.

- Keep cross-platform event names and parameters consistent when required.
- Never send sensitive data without product/privacy approval.
- Use official Google test ad identifiers in Debug.
- Release builds must require real production identifiers before shipping.
- Backend reward verification remains authoritative for rewarded ads.
- Measure meaningful user-facing operations, not every method.

## Testing

Use Swift Testing for unit and integration tests. XCTest is allowed only where
Apple's `XCUIApplication` UI-automation APIs require it, such as application
smoke tests. Important tests include:

- ViewModel state transitions
- request construction and DTO mapping
- repository orchestration and account-scoped caches
- token refresh and error mapping
- coordinator route intents
- Phoenix protocol and socket lifecycle
- hosted-game bridge validation
- challenge HUD and reward rules

Tests must use protocols, fakes, and custom URL loading where appropriate. Unit
tests must not require a production backend, product SDK account, physical
device, or live socket.

## Workflow and Reversibility

Before editing:

1. Inspect the relevant structure and existing flow.
2. Search for reusable code.
3. Identify dependencies and ownership.
4. Choose the smallest coherent change.

While editing:

- keep changes focused
- preserve unrelated user changes
- do not modify the Android repository
- keep product SDK additions in separate commits
- do not introduce undocumented backend behavior
- stop and discuss any unplanned product, architecture, dependency, or privacy
  decision before implementing it

Use additive, reviewable commits. Revert commits rather than rewriting shared
history. Do not use destructive git commands without explicit approval.

## Completion Checklist

Before declaring a checkpoint complete:

- [ ] Feature and dependency boundaries are respected.
- [ ] Navigation goes through the coordinator.
- [ ] Infrastructure is injected, not constructed by feature UI.
- [ ] UI, domain, transport, and persistence concerns are appropriately split.
- [ ] Async tasks and resources have explicit ownership and cancellation.
- [ ] Sensitive values are neither committed nor logged.
- [ ] Relevant tests cover meaningful logic.
- [ ] Debug and Release build successfully.
- [ ] Unit tests pass.
- [ ] Swift files are formatted and warnings reviewed.
- [ ] No unrelated refactor or Android change was introduced.
