# ShopEase — Architecture

This document describes the architectural decisions, layer responsibilities, and data flow for **ShopEase**, a BLoC-driven Flutter e-commerce app.

---

## 1. Architectural Style: Clean Architecture + Feature-First Organization

ShopEase combines two well-known ideas:

1. **Clean Architecture** (data / domain / presentation layering) — for testability and separation of concerns.
2. **Feature-first folder structure** — each business capability (`auth`, `product`, `cart`, `wishlist`, `order`, `notifications`) is a self-contained module with its own three layers, rather than grouping all blocs together, all repositories together, etc.

This makes each feature independently understandable, testable, and (mostly) removable/replaceable without ripple effects across the codebase.

```
Presentation  →  Domain  →  Data
   (BLoC)      (UseCases,      (Repository Impl,
                Entities,       Remote/Local
                Repo interface) Data Sources)
```

Dependency direction always points **inward**: `presentation` depends on `domain`, `data` depends on `domain` — `domain` depends on nothing. This is what allows the UI/BLoC layer to swap a Firestore-backed repository for a fake/in-memory one during tests.

---

## 2. Layer Responsibilities

### 2.1 Domain Layer (innermost — pure Dart, no Flutter/Firebase imports)

- **Entities** — plain Dart classes representing core business objects (`Product`, `User`, `CartItem`, `Order`, `OrderStatus`)
- **Repository interfaces (abstract classes)** — contracts like `ProductRepository`, `AuthRepository`, `CartRepository`, `OrderRepository`
- **Use Cases** — single-responsibility classes encapsulating one business action, e.g. `GetPaginatedProducts`, `SignInWithEmail`, `SignInWithGoogle`, `AddToCart`, `PlaceOrder`, `WatchOrderStatus`

Use cases are what BLoCs call — BLoCs never talk to repositories or data sources directly. This keeps BLoC classes thin and business logic testable in isolation from Flutter.

### 2.2 Data Layer

- **Models** — `ProductModel`, `UserModel`, `OrderModel` — extend/implement domain entities and add `fromJson` / `toJson` / `fromFirestore` mapping
- **Data Sources**
  - `RemoteProductDataSource` — wraps `dio` calls to FakeStoreAPI/DummyJSON
  - `FirebaseAuthDataSource` — wraps `firebase_auth` + `google_sign_in`
  - `FirestoreOrderDataSource` — exposes a `Stream<OrderModel>` from a Firestore document/collection listener for real-time order status updates
  - `FCMDataSource` — handles token registration and foreground/background message handling
- **Repository Implementations** — implement the domain's abstract repository, deciding how to combine/cache data source calls, convert models → entities, and map exceptions → domain `Failure` objects

### 2.3 Presentation Layer

- **BLoC** — one BLoC (or Cubit, where simpler) per feature, translating UI events into use case calls and use case results into UI state
- **Pages / Widgets** — purely reactive to BLoC state via `BlocBuilder` / `BlocListener` / `BlocConsumer`; no business logic in widgets

---

## 3. BLoC Breakdown

| BLoC | Events (examples) | States (examples) | Notes |
|---|---|---|---|
| `AuthBloc` | `SignInRequested`, `GoogleSignInRequested`, `SignUpRequested`, `SignOutRequested`, `AuthStatusChecked` | `AuthInitial`, `AuthLoading`, `Authenticated(user)`, `Unauthenticated`, `AuthFailure(message)` | Listens to `authStateChanges()` stream from Firebase on app start |
| `ProductBloc` | `ProductsFetched(page)`, `ProductsRefreshed` | `ProductLoadInProgress`, `ProductLoadSuccess(items, hasReachedMax)`, `ProductLoadFailure` | Implements infinite-scroll pagination pattern; tracks `hasReachedMax` |
| `SearchBloc` (or `SearchCubit`) | `SearchQueryChanged(query)` | `SearchInitial`, `SearchLoading`, `SearchSuccess(results)`, `SearchFailure` | Uses `Bloc`'s `transformer` (e.g. `restartable()` from `bloc_concurrency` + a `Debouncer`/`debounceTime` on the event stream) to avoid firing a request per keystroke |
| `CartBloc` | `ItemAdded`, `ItemRemoved`, `QuantityUpdated`, `CartCleared` | `CartUpdated(items, totalPrice)` | Cart state can be persisted locally (e.g. Hive) so it survives app restarts |
| `WishlistBloc` | `ItemToggled` | `WishlistUpdated(items)` | Simple toggle-based state |
| `OrderBloc` | `CheckoutStarted`, `PaymentConfirmed`, `OrderStatusSubscriptionRequested(orderId)` | `CheckoutInProgress`, `CheckoutSuccess(orderId)`, `CheckoutFailure`, `OrderStatusUpdated(status)` | Subscribes to a Firestore stream (via a use case returning `Stream<Order>`) so admin-side status changes push straight into the BLoC and UI in real time |

### Why BLoC (not Cubit) for most features

Full `Bloc` classes (event + state) are used for features with multiple distinct triggers and cross-cutting async flows (`Auth`, `Product` pagination, `Order` checkout + live tracking), since named events make the audit trail of "what happened" explicit and testable with `bloc_test`. Simpler, single-trigger features (`Wishlist` toggle) could reasonably use a lighter `Cubit` instead — this is a legitimate simplification if you want to reduce boilerplate.

---

## 4. Dependency Injection (`get_it` + `injectable`)

- `injectable` uses build-time code generation (`@injectable`, `@LazySingleton`, `@module`) to auto-register classes into a `GetIt` instance, avoiding hand-written registration for every repository/data source/use case.
- Typical registration hierarchy:
  - **External singletons** (registered manually in an `@module` class): `FirebaseAuth.instance`, `FirebaseFirestore.instance`, `FirebaseMessaging.instance`, a configured `Dio` instance, `SharedPreferences`/`Hive` box instances
  - **Data sources** — `@LazySingleton(as: ...)` implementations
  - **Repositories** — `@LazySingleton(as: ...)` implementations, injected with their data source(s)
  - **Use cases** — `@injectable`, injected with their repository
  - **BLoCs** — `@injectable` (factory, since a new instance is typically created per screen via `BlocProvider`), injected with their use cases

```dart
// injection.dart
final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() => getIt.init();
```

```dart
// Usage in a page
BlocProvider(
  create: (_) => getIt<ProductBloc>()..add(ProductsFetched(page: 1)),
  child: ProductListPage(),
)
```

This means widgets never call `RepositoryImpl()` or `Dio()` directly — they resolve fully-wired BLoCs from `get_it`, which makes swapping a real repository for a fake one in tests a one-line change in a test-specific injection module.

---

## 5. Real-Time Order Status Flow (Admin → Firestore → App)

This is the most "enterprise" piece of the demo, so it's worth diagramming explicitly:

```
┌─────────────────┐        write         ┌───────────────────┐
│  Admin Console /  │ ───────────────────▶ │  Firestore         │
│  Firebase Console │   status: "shipped"  │  orders/{orderId}  │
└─────────────────┘                        └─────────┬──────────┘
                                                       │ onSnapshot
                                                       │ (stream)
                                                       ▼
                                          ┌────────────────────────┐
                                          │ FirestoreOrderDataSource│
                                          │ .watchOrder(orderId)    │
                                          └───────────┬────────────┘
                                                       │ Stream<OrderModel>
                                                       ▼
                                          ┌────────────────────────┐
                                          │ OrderRepositoryImpl     │
                                          │ maps Model → Entity     │
                                          └───────────┬────────────┘
                                                       │ Stream<Order>
                                                       ▼
                                          ┌────────────────────────┐
                                          │ WatchOrderStatus        │
                                          │ (UseCase)               │
                                          └───────────┬────────────┘
                                                       │
                                                       ▼
                                          ┌────────────────────────┐
                                          │ OrderBloc                │
                                          │ emits OrderStatusUpdated │
                                          └───────────┬────────────┘
                                                       │
                                                       ▼
                                          ┌────────────────────────┐
                                          │ OrderTrackingPage        │
                                          │ (BlocBuilder rebuilds)   │
                                          └────────────────────────┘

In parallel, Firestore write can also trigger a Cloud Function
(or the admin action directly calls FCM) → push notification
delivered via FirebaseMessaging → handled by FCMDataSource →
shown as a local notification / updates in-app badge.
```

Key point: the `OrderBloc` doesn't poll — it subscribes once (`emit.forEach` / `StreamSubscription` inside the bloc, cancelled on `close()`), so any admin-side write to the Firestore document is reflected in the UI within the same event loop tick Firestore delivers it.

---

## 6. Pagination & Infinite Scroll (`ProductBloc`)

- The product list page attaches a `ScrollController` listener that checks `pixels >= maxScrollExtent * 0.9`
- On threshold, it dispatches `ProductsFetched(page: currentPage + 1)`
- `ProductBloc` guards against duplicate/overlapping fetches by checking current state (`ProductLoadInProgress` → ignore new fetch events) and tracks `hasReachedMax` once the API returns an empty/short page
- Underlying data source calls FakeStoreAPI/DummyJSON with `limit` + `skip` (or `page`) query params via `dio`

## 7. Debounced Search

- The search field's `onChanged` dispatches `SearchQueryChanged(query)` on every keystroke
- The `SearchBloc`'s event transformer applies a debounce (e.g., 300–500ms) before calling the use case, using either:
  - a `Debouncer` utility wrapping `Timer` before `add()`, or
  - `bloc`'s `EventTransformer` with `restartable()` combined with a stream `debounceTime` from `rxdart`
- This avoids firing a network request on every character typed and cancels in-flight stale requests when a newer query arrives

---

## 8. Error Handling Strategy

- Data sources throw typed exceptions (`ServerException`, `AuthException`, `CacheException`)
- Repositories catch these and return `Either<Failure, T>` (using `dartz` or a custom `Result` sealed class) up to use cases
- BLoCs pattern-match on `Either`/`Result` and emit corresponding `*Failure` states with a user-friendly message
- This keeps try/catch blocks out of BLoCs and widgets entirely — failures are just another data shape flowing through the same pipeline as success values

---

## 9. Testing Strategy Mapped to Architecture

| Layer | Test type | Tooling |
|---|---|---|
| Domain (use cases) | Unit tests, mock repository | `mocktail` |
| Data (repositories) | Unit tests, mock data sources | `mocktail` |
| Presentation (BLoCs) | `blocTest` verifying event → state sequences, mock use cases | `bloc_test`, `mocktail` |
| Widgets | Pump widget with a fake/mock BLoC via `BlocProvider.value` | `flutter_test` |

Because domain layer has zero Flutter/Firebase dependencies, its tests run fast and don't need any Firebase emulator — only the data layer's integration tests (optional) would benefit from the **Firebase Local Emulator Suite**.

---

## 10. Summary Diagram — Full Feature Slice (Product example)

```
UI (ProductListPage)
   │  dispatches ProductsFetched
   ▼
ProductBloc  ──uses──▶  GetPaginatedProducts (UseCase)
   ▲                            │ calls
   │ emits states               ▼
   │                    ProductRepository (abstract, domain)
   │                            ▲ implements
   │                            │
   │                    ProductRepositoryImpl (data)
   │                            │ calls
   │                            ▼
   │                    RemoteProductDataSource (dio → FakeStoreAPI)
   └────────────────────────────┘
```

This same slice shape is repeated for `auth`, `cart`, `wishlist`, and `order` — once you understand one feature end-to-end, you understand the whole app.