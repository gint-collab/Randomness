# Randomness

A native iOS application built with Swift and SwiftUI that serves up random content — cat pictures, cat facts and Chuck Norris jokes — from three public APIs.

## 📱 Features & Highlights

* **Coordinator-driven navigation:** A single `AppCoordinator` owns the `NavigationPath` and builds every destination from an `AppRoute` enum, so views never construct one another and the whole flow (landing → dashboard → cats/jokes → detail) is testable in isolation.
* **Cat gallery with a masonry layout:** A greedy waterfall algorithm places each image into the column that is currently shortest, using the intrinsic `width`/`height` returned by the API. Images wider than 640 px break out into a full-width row of their own.
* **Facebook-style cat feed:** An infinite-scrolling feed that pairs a random image with a random fact per post, with likes, relative timestamps, share actions and automatic pagination as you approach the end of the list.
* **Cat detail with a paging carousel:** Tapping a cat opens a full-bleed carousel seeded with the list already loaded by the gallery — no extra request — plus a refreshable cat fact.
* **Share & save to Photos:** A toolbar menu shares the decoded picture itself (not just a link) and writes it to the photo library using add-only `PHPhotoLibrary` access, with the image served straight from cache when it is already on screen.
* **Chuck Norris jokes:** A card-based screen with pull-to-refresh and a Liquid Glass "Another one" button.
* **Custom image pipeline:** An `actor`-based downloader with an `NSCache` layer (200 items / ~100 MB) and request coalescing, so concurrent requests for the same URL share a single download.
* **Shimmer loading states:** Every screen renders a skeleton that mirrors its real layout while the first page loads, instead of a bare spinner.
* **Liquid Glass UI:** Native `TabView` with `.tabBarMinimizeBehavior(.onScrollDown)`, soft scroll-edge effects and glass-prominent buttons.
* **Accessibility & Dark Mode:** Semantic labels and traits throughout, dynamic-type-friendly text, and system materials that adapt to the active appearance.

## 🛠 Tech Stack & Architecture

* **Language:** Swift 6 (strict concurrency, `Sendable` models, `nonisolated` value types)
* **UI Framework:** SwiftUI
* **Architecture:** MVVM + Coordinator
* **Concurrency:** Swift Concurrency (async/await, actors, `TaskGroup`)
* **Networking:** Custom `URLSession` layer — no third-party dependencies
* **Dependency Manager:** Swift Package Manager (SPM)
* **Minimum iOS:** 26.2

### Project structure

```
Randomness/
├── Coordinator/          AppCoordinator + AppRoute, the single navigation source of truth
├── Core/
│   ├── Common/           Carousel, Hero, RemoteImage, Shimmer, ImageActions
│   ├── DependencyInjection/  AppDependencies composition root + Environment key
│   ├── Networking/       EndpointProtocol, HTTPClientProtocol, HTTPClient, NetworkError
│   ├── Protocols/        ViewModelProtocol, LoadableViewModel, Coordinator protocols
│   └── Services/         CatService, ChuckNorrisService, ImageDownloader, ImageSaver
└── Module/
    ├── CatModule/        CatTabbar → CatList (gallery), CatFeeds (feed), CatDetails
    ├── ChuckNorrisMod/   Random joke screen
    ├── Dashboard/        Menu of available content
    └── LandingPage/      Entry screen
```

### Design notes

* **Protocol-oriented seams.** Every service is reached through a protocol (`CatServiceProtocol`, `HTTPClientProtocol`, `ImageDownloading`, `ImageSaving`), and `AppDependencies` is the only place concrete types are wired together. Views take view models via `@autoclosure` so previews and tests can inject doubles such as `MockCatService` or `MockHTTPClient`.
* **Declarative endpoints.** Each API is one enum conforming to `EndpointProtocol`, which knows how to turn itself into a `URLRequest`. Defaults cover `GET`, `Accept: application/json` and an empty body.
* **Uniform error handling.** All transport, status and decoding failures funnel into `NetworkError`, so screens can present `errorDescription` without inspecting framework errors.
* **Cache-free session.** These endpoints return random payloads for the same URL, so the client uses an ephemeral, cache-free `URLSession` — otherwise pull-to-refresh would look like a no-op.
* **Randomised fact pages.** `catfact.ninja/facts` is paginated rather than random, so the service requests a random page to keep refreshes interesting.
* **Deliberate task lifetimes.** View models capture `self` weakly, track their unstructured tasks and cancel them from `onDisappear`, so dismissing a screen never leaves a request retaining the view model.

### APIs used

| Source | Used for |
| --- | --- |
| `api.thecatapi.com` | Cat images with intrinsic dimensions |
| `catfact.ninja` | Random and paginated cat facts |
| `api.chucknorris.io` | Random Chuck Norris jokes |

No API keys are required.

## 📸 Screenshots / Demo

| Landing Page | Main Dashboard | Cat Gallery | Cat Feed | Cat Detail |
| --- | --- | --- | --- | --- |
| <img width="300" height="650" alt="Simulator Screenshot - iPhone 17 - 2026-08-13 at 03 03 04" src="https://github.com/user-attachments/assets/12f3b50b-d750-4c6e-8e48-cc2e09854c2f" /> | <img width="300" height="650" alt="Simulator Screenshot - iPhone 17 - 2026-08-13 at 03 03 09" src="https://github.com/user-attachments/assets/70ab3742-148c-47c2-9e4e-589a5ba2702d" /> | <img width="300" height="650" alt="Simulator Screenshot - iPhone 17 - 2026-08-13 at 03 03 29" src="https://github.com/user-attachments/assets/96465b1c-575c-481b-a45c-800c61a19ed1" /> | <img width="300" height="650" alt="Simulator Screenshot - iPhone 17 - 2026-08-13 at 03 12 32" src="https://github.com/user-attachments/assets/f1205205-e574-4689-96ac-3dbf64f9c9bd" /> | <img width="300" height="650" alt="Simulator Screenshot - iPhone 17 - 2026-08-13 at 03 06 16" src="https://github.com/user-attachments/assets/9f8d0340-4773-4206-baf1-f0986e9b2c39" /> |

## 📸 Churk Norris / Demo
| Landing Page |
| --- |
| <img width="300" height="650" alt="Simulator Screenshot - iPhone 17 - 2026-08-13 at 03 05 04" src="https://github.com/user-attachments/assets/cd616aa1-d0f0-4092-beb7-895c9b202401" /> |

## 🚀 How to Run the Project

1. Clone the repository: `git clone https://github.com`
2. Open `Randomness.xcodeproj` in **Xcode**.
3. Let Swift Package Manager resolve dependencies automatically (the app currently ships with none).
4. Select an iOS Simulator (**iOS 26.2+ required**) and press `Cmd + R` to run.
5. Tap **Get Started** on the landing screen to reach the dashboard.

> Saving an image to Photos prompts for add-only photo library access, described by `NSPhotoLibraryAddUsageDescription` in the target's build settings.

## ✅ Testing

Unit tests live in `RandomnessTests`, written with both **Swift Testing** and **XCTest**:

* `NetworkingTests` — request building, status validation and decoding failures in `HTTPClient`.
* `Services` — `CatService` and `ChuckNorrisService` driven entirely offline through `MockHTTPClient`.
* `AppCoordinatorTests` — routing, authentication flow and the view factory.
* `Mocks` — `MockHTTPClient` and `EndpointRecorder`, which captures the endpoints a service requests.

Run them with `Cmd + U`, or:

```bash
xcodebuild test -project Randomness.xcodeproj -scheme Randomness -destination 'platform=iOS Simulator,name=iPhone 17'
```
