# ShopEase 🛍️

A full-featured e-commerce Flutter application demonstrating enterprise-grade architecture with **BLoC state management**, **Firebase Authentication**, **FCM push notifications**, and real-time order tracking via Firestore.

This project is designed as a portfolio/demo app to showcase production-quality patterns: clean architecture, repository abstraction, dependency injection, and scalable feature-based state management.

---

## ✨ Features

- **Product Catalog** — Infinite-scroll product listing with pagination
- **Product Details** — Rich product detail page with images, description, and variants
- **Cart & Wishlist** — Add/remove/update items, persisted across sessions
- **Authentication** — Firebase email/password + Google Sign-In
- **Checkout** — Mock/sandbox payment flow (Razorpay or Stripe test mode)
- **Push Notifications** — Real-time order status updates via FCM
- **Search** — Debounced search-as-you-type
- **Live Order Tracking** — Admin-triggered order status changes reflected instantly via a Firestore stream listener

---

## 🧱 Tech Stack

| Layer | Technology |
|---|---|
| State Management | `flutter_bloc` + `equatable` |
| Networking | `dio` |
| Backend (Products) | [FakeStoreAPI](https://fakestoreapi.com/) or [DummyJSON](https://dummyjson.com/) |
| Auth & Realtime DB | Firebase (Auth, Firestore, Cloud Messaging) — Spark (free) tier |
| Dependency Injection | `get_it` + `injectable` |
| Payments | Razorpay / Stripe (sandbox/test mode) |
| Image Caching | `cached_network_image` |

---

## 📂 Project Structure

```
lib/
├── main.dart
├── app.dart                          # MaterialApp, routing, theme
├── injection/                        # get_it + injectable setup
│   ├── injection.dart
│   └── injection.config.dart         # generated
│
├── core/
│   ├── constants/
│   ├── error/                        # Failure, Exception classes
│   ├── network/                      # Dio client, interceptors, network_info
│   ├── theme/
│   ├── utils/                        # debouncer, validators, formatters
│   └── widgets/                      # shared reusable widgets
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/          # firebase_auth_datasource.dart
│   │   │   ├── models/
│   │   │   └── repositories/         # AuthRepositoryImpl
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/         # AuthRepository (abstract)
│   │   │   └── usecases/             # SignIn, SignUp, GoogleSignIn, SignOut
│   │   └── presentation/
│   │       ├── bloc/                 # AuthBloc, AuthEvent, AuthState
│   │       ├── pages/                # LoginPage, SignupPage
│   │       └── widgets/
│   │
│   ├── product/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── bloc/                 # ProductBloc (pagination), SearchBloc
│   │       ├── pages/                # ProductListPage, ProductDetailPage
│   │       └── widgets/
│   │
│   ├── cart/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── bloc/                 # CartBloc
│   │       ├── pages/                # CartPage
│   │       └── widgets/
│   │
│   ├── wishlist/
│   │   └── ...                       # same layered structure
│   │
│   ├── order/
│   │   ├── data/
│   │   │   └── datasources/          # firestore_order_datasource.dart (stream)
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── bloc/                 # OrderBloc (listens to Firestore stream)
│   │       ├── pages/                # CheckoutPage, OrderTrackingPage
│   │       └── widgets/
│   │
│   └── notifications/
│       ├── data/                     # fcm_service.dart
│       └── presentation/
│
└── routes/
    └── app_router.dart

test/
├── features/
│   ├── auth/
│   ├── product/
│   ├── cart/
│   └── order/
└── helpers/                          # mocks, fixtures
```

---

## 🏗️ Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full architecture write-up, including layer responsibilities, data flow diagrams, and BLoC design decisions.

**In short:** each feature follows **Clean Architecture** (`data` → `domain` → `presentation`), with a `BLoC` per feature, `Repository` interfaces defined in `domain` and implemented in `data`, and dependencies wired centrally through `get_it` + `injectable`.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.19.0`
- Dart `>=3.3.0`
- A Firebase project (free Spark plan is sufficient)
- Android Studio / Xcode for platform builds

### 1. Clone & Install

```bash
git clone https://github.com/<your-username>/shopease.git
cd shopease
flutter pub get
```

### 2. Firebase Setup

1. Create a project at [Firebase Console](https://console.firebase.google.com/)
2. Enable **Authentication** → Email/Password + Google
3. Enable **Cloud Firestore** (start in test mode for development)
4. Enable **Cloud Messaging**
5. Install FlutterFire CLI and configure:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and platform config files (`google-services.json`, `GoogleService-Info.plist`).

### 3. Environment Variables

Create a `.env` file at the project root (loaded via `flutter_dotenv`):

```env
API_BASE_URL=https://fakestoreapi.com
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx
# or
STRIPE_PUBLISHABLE_KEY=pk_test_xxxxxxxxxxxx
```

### 4. Generate Code (DI, JSON models)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 5. Run the App

```bash
flutter run
```

---

## 📦 Key Packages

```yaml
dependencies:
  flutter_bloc: ^8.1.5
  equatable: ^2.0.5
  dio: ^5.4.3
  get_it: ^7.7.0
  injectable: ^2.4.1
  firebase_core: ^2.31.0
  firebase_auth: ^4.19.0
  cloud_firestore: ^4.17.0
  firebase_messaging: ^14.9.0
  google_sign_in: ^6.2.1
  cached_network_image: ^3.3.1
  flutter_dotenv: ^5.1.0
  razorpay_flutter: ^1.3.7   # or flutter_stripe: ^10.1.1

dev_dependencies:
  build_runner: ^2.4.9
  injectable_generator: ^2.6.1
  bloc_test: ^9.1.7
  mocktail: ^1.0.3
```

---

## 🧪 Testing

- **Unit tests** for use cases and repositories (mocked data sources via `mocktail`)
- **BLoC tests** using `bloc_test` for every Bloc (`AuthBloc`, `ProductBloc`, `CartBloc`, `OrderBloc`)
- **Widget tests** for critical pages (login, product list, checkout)

```bash
flutter test
```

---

## 🔌 Free/Sandbox Resources Used

| Purpose | Resource | Notes |
|---|---|---|
| Product data API | [FakeStoreAPI](https://fakestoreapi.com/) / [DummyJSON](https://dummyjson.com/) | No backend needed, free REST endpoints |
| Auth + DB + Push | Firebase Spark Plan | Free tier, no credit card required for basic usage |
| Payments | Razorpay / Stripe Test Mode | Sandbox keys, no real transactions |

---

## 🗺️ Roadmap / Nice-to-Haves

- [ ] Offline-first cart persistence with `hive` or `drift`
- [ ] Product reviews & ratings
- [ ] Multi-language support (`intl`)
- [ ] Dark mode theming
- [ ] CI/CD via GitHub Actions (lint + test on PR)

---

## 📄 License

MIT — free to use for learning, portfolio, or as a project template.