# ShopEase — Epics & User Stories

Derived from [README.md](../README.md) and [ARCHITECTURE.md](../ARCHITECTURE.md). Each epic maps to one feature module under `lib/features/`. Stories use the standard `As a / I want / So that` format with acceptance criteria; each story also notes the primary BLoC/use case involved so it can be sliced by layer (domain → data → presentation) during implementation.

---

## Epic 1: Authentication

**Goal:** Users can create an account, sign in, and stay signed in across app launches, via email/password or Google.
**BLoC:** `AuthBloc`

### Story 1.1 — Email/password sign-up
As a new user, I want to create an account with my email and password, so that I can access personalized features (cart, wishlist, orders).
- Acceptance:
  - Form validates email format and password strength before submit.
  - Duplicate email shows a clear inline error, not a generic failure.
  - On success, user is navigated to the product list and session persists.
- Use case: `SignUpWithEmail`

### Story 1.2 — Email/password sign-in
As a returning user, I want to sign in with my email and password, so that I can resume shopping with my saved cart/wishlist.
- Acceptance:
  - Invalid credentials show `AuthFailure(message)` without leaking whether the email exists.
  - Loading state disables the submit button to prevent double submission.
- Use case: `SignInWithEmail`

### Story 1.3 — Google Sign-In
As a user, I want to sign in with my Google account, so that I can skip manual registration.
- Acceptance:
  - Cancelling the Google account picker returns to the login screen without an error toast.
  - First-time Google sign-in creates a Firebase user record equivalent to email sign-up.
- Use case: `SignInWithGoogle`

### Story 1.4 — Persisted session on app start
As a returning user, I want the app to remember I'm signed in, so that I don't have to log in every time I open the app.
- Acceptance:
  - On cold start, `AuthBloc` checks `authStateChanges()` and emits `Authenticated`/`Unauthenticated` before the first frame renders a decision.
  - No flash of the login screen for an already-authenticated user.

### Story 1.5 — Sign out
As a signed-in user, I want to sign out, so that I can protect my account on a shared device.
- Acceptance:
  - Sign out clears the Firebase session and any locally cached cart/wishlist tied to the account.
  - User is returned to the login screen.
- Use case: `SignOut`

---

## Epic 2: Product Catalog

**Goal:** Users can browse the full product catalog with smooth infinite scroll.
**BLoC:** `ProductBloc`

### Story 2.1 — Paginated product list
As a shopper, I want to scroll through products without waiting for the whole catalog to load, so that browsing feels fast.
- Acceptance:
  - Initial load fetches the first page (e.g. limit 20).
  - Scrolling past 90% of the current extent triggers `ProductsFetched(page + 1)`.
  - Duplicate fetches are ignored while a page is already loading (`ProductLoadInProgress` guard).
  - Reaching the end of the catalog sets `hasReachedMax` and stops further requests, with a subtle "end of list" indicator.
- Use case: `GetPaginatedProducts`

### Story 2.2 — Pull-to-refresh
As a shopper, I want to refresh the product list, so that I see newly added or updated products.
- Acceptance:
  - Pull-to-refresh dispatches `ProductsRefreshed` and resets pagination to page 1.
  - Existing scroll position resets to top on refresh completion.

### Story 2.3 — Product list failure state
As a shopper, I want to know when products fail to load, so that I can retry instead of staring at a blank screen.
- Acceptance:
  - Network/API failure emits `ProductLoadFailure` with a retry action.
  - Retry re-dispatches the last failed page request.

### Story 2.4 — Product detail view
As a shopper, I want to view full details of a product (images, description, price, variants), so that I can decide whether to buy it.
- Acceptance:
  - Detail page loads from the tapped list item's data (no redundant network call if already available) or fetches by id otherwise.
  - Images use `cached_network_image` with a placeholder and error fallback.
  - "Add to Cart" and "Add to Wishlist" actions are visible without scrolling on standard screen sizes.

---

## Epic 3: Search

**Goal:** Users can find products quickly via debounced search-as-you-type.
**BLoC:** `SearchBloc` (or `SearchCubit`)

### Story 3.1 — Debounced search
As a shopper, I want search results to update as I type without spamming the network, so that search feels responsive and doesn't waste data.
- Acceptance:
  - Keystrokes dispatch `SearchQueryChanged(query)`.
  - Requests are debounced (300–500ms); only the latest query after the pause triggers an API call.
  - A stale in-flight request is cancelled/ignored if a newer query has since been typed (`restartable()` transformer).

### Story 3.2 — Empty and no-results states
As a shopper, I want clear feedback when my search has no matches or hasn't started yet, so that I'm not confused by a blank screen.
- Acceptance:
  - Empty query shows `SearchInitial` (e.g. recent searches or a prompt), not a spinner.
  - Zero results shows a distinct "no results for '{query}'" message, not the generic failure state.

---

## Epic 4: Cart

**Goal:** Users can manage a cart that persists across sessions.
**BLoC:** `CartBloc`

### Story 4.1 — Add item to cart
As a shopper, I want to add a product to my cart, so that I can purchase it later.
- Acceptance:
  - Adding an already-in-cart item increments quantity rather than duplicating the line item.
  - `CartUpdated(items, totalPrice)` reflects the change immediately in any visible cart badge/icon.
- Use case: `AddToCart`

### Story 4.2 — Update item quantity
As a shopper, I want to change the quantity of an item in my cart, so that I can buy the right amount.
- Acceptance:
  - Quantity cannot go below 1 via the stepper; removal is a separate explicit action.
  - Total price recalculates immediately on change.

### Story 4.3 — Remove item from cart
As a shopper, I want to remove an item from my cart, so that I can correct a mistake or change my mind.
- Acceptance:
  - Removal is confirmable (e.g. swipe + undo snackbar) to avoid accidental data loss.

### Story 4.4 — Cart persists across sessions
As a shopper, I want my cart to still have my items when I reopen the app, so that I don't lose my selections.
- Acceptance:
  - Cart state is written to local storage (e.g. Hive) on every mutation and rehydrated on app start.
  - Persisted cart is cleared on sign-out (see Story 1.5) if cart is scoped per-account.

### Story 4.5 — Clear cart
As a shopper, I want to clear my entire cart, so that I can start over easily.
- Acceptance:
  - Action requires confirmation before dispatching `CartCleared`.

---

## Epic 5: Wishlist

**Goal:** Users can save products for later without committing to purchase.
**BLoC:** `WishlistBloc`

### Story 5.1 — Toggle wishlist item
As a shopper, I want to add or remove a product from my wishlist with one tap, so that I can save items I'm interested in.
- Acceptance:
  - Wishlist icon on product cards/detail page reflects current state (filled vs outline) reactively via `WishlistUpdated(items)`.
  - Toggling is idempotent — rapid double-taps don't desync the icon from actual state.

### Story 5.2 — View wishlist
As a shopper, I want to see all my wishlisted products in one place, so that I can revisit and buy them later.
- Acceptance:
  - Wishlist page lists saved products with a direct "Add to Cart" action per item.
  - Empty wishlist shows a friendly empty state, not a blank list.

---

## Epic 6: Checkout & Payments

**Goal:** Users can complete a purchase through a sandbox/test payment flow.
**BLoC:** `OrderBloc`

### Story 6.1 — Start checkout
As a shopper, I want to review my cart and proceed to payment, so that I can complete my purchase.
- Acceptance:
  - Checkout page shows itemized cart, total, and (mock) shipping details before payment is triggered.
  - `CheckoutStarted` is only dispatchable with a non-empty cart.

### Story 6.2 — Complete sandbox payment
As a shopper, I want to pay using a test payment flow (Razorpay/Stripe test mode), so that I can experience the full purchase flow without real transactions.
- Acceptance:
  - Successful test payment dispatches `PaymentConfirmed` and emits `CheckoutSuccess(orderId)`.
  - Failed/cancelled payment emits `CheckoutFailure` with a retry path back to the payment step (cart is not cleared on failure).
- Use case: `PlaceOrder`

### Story 6.3 — Order confirmation
As a shopper, I want confirmation after a successful purchase, so that I know my order was placed.
- Acceptance:
  - On `CheckoutSuccess`, cart is cleared and user is navigated to an order confirmation/tracking screen showing the new `orderId`.

---

## Epic 7: Live Order Tracking

**Goal:** Order status updates made by an admin are reflected in the app in real time, without polling.
**BLoC:** `OrderBloc` (subscription side)

### Story 7.1 — Subscribe to order status
As a shopper, I want to see my order's current status update automatically, so that I don't have to refresh the page to check progress.
- Acceptance:
  - `OrderStatusSubscriptionRequested(orderId)` opens a Firestore stream via `WatchOrderStatus` and emits `OrderStatusUpdated(status)` on every change.
  - Subscription is cancelled when leaving the tracking page (`close()`), no leaked listeners.
- Use case: `WatchOrderStatus`; Data source: `FirestoreOrderDataSource`

### Story 7.2 — Visual order timeline
As a shopper, I want to see my order's progress as a visual timeline (placed → shipped → delivered), so that I understand where my order is.
- Acceptance:
  - Each known `OrderStatus` maps to a distinct step in the UI; unknown/unexpected status values fail gracefully (e.g. shown as "Processing") rather than crashing the widget.

### Story 7.3 — Admin-triggered status change (demo/admin side)
As an admin (via Firebase Console or an admin tool), I want to update an order's status, so that the customer sees real-time progress without me needing to notify them manually.
- Acceptance:
  - A write to `orders/{orderId}.status` in Firestore is reflected in the customer's open tracking page within the same event-loop tick Firestore delivers the snapshot.

---

## Epic 8: Push Notifications

**Goal:** Users receive real-time notifications about order status changes.
**Data source:** `FCMDataSource`

### Story 8.1 — Register for push notifications
As a user, I want the app to register my device for notifications, so that I can receive order updates even when the app is closed.
- Acceptance:
  - FCM token is obtained on first app launch (post permission grant) and refreshed on token rotation.
  - Token registration failure doesn't block app usage (non-fatal, logged only).

### Story 8.2 — Receive order status notification
As a shopper, I want to be notified when my order status changes, so that I stay informed without keeping the app open.
- Acceptance:
  - Foreground messages show an in-app banner/snackbar; background/terminated messages show a system notification.
  - Tapping the notification deep-links to the relevant order's tracking page.

---

## Epic 9: Cross-Cutting — Error Handling & Reliability

**Goal:** Failures are handled consistently across every feature per the architecture's `Result`/`Either` pipeline.

### Story 9.1 — Consistent failure surfacing
As a user, I want clear, non-technical error messages when something goes wrong (network, auth, server), so that I understand what happened and what to do next.
- Acceptance:
  - Data sources throw typed exceptions (`ServerException`, `AuthException`, `CacheException`); repositories convert these to `Failure` via `Either`/`Result`.
  - No raw exception text or stack traces are ever shown in the UI.

### Story 9.2 — Offline awareness
As a shopper, I want to know when I've lost connectivity, so that I understand why actions aren't completing.
- Acceptance:
  - `network_info` check surfaces a distinct "no connection" failure state distinguishable from a server error, on any network-dependent action (product fetch, search, checkout).

---

## Epic 10: Testing & Quality (supports all epics above)

**Goal:** Each layer is independently testable per the Clean Architecture boundaries.

### Story 10.1 — Use case unit tests
As a developer, I want unit tests for every use case with a mocked repository, so that business logic is verified without any Flutter/Firebase dependency.
- Tooling: `mocktail`

### Story 10.2 — Repository unit tests
As a developer, I want unit tests for each repository implementation with mocked data sources, so that mapping and error-conversion logic is verified in isolation.
- Tooling: `mocktail`

### Story 10.3 — BLoC tests
As a developer, I want `bloc_test` coverage for every BLoC's event → state sequence, so that regressions in state transitions are caught automatically.
- Tooling: `bloc_test`, `mocktail`

### Story 10.4 — Widget tests for critical pages
As a developer, I want widget tests for login, product list, and checkout, so that the most business-critical screens are protected against UI regressions.
- Tooling: `flutter_test`, `BlocProvider.value` with fake/mock BLoCs

---

## Roadmap Epics (from README "Nice-to-Haves" — not yet scoped into stories)

- **Epic 11: Offline-First Cart** — persist cart with `hive`/`drift` beyond the current session-persistence story (4.4), including conflict resolution when reconnecting.
- **Epic 12: Product Reviews & Ratings** — new `reviews` feature slice (data/domain/presentation) allowing users to rate and review purchased products.
- **Epic 13: Multi-Language Support** — `intl`-based localization across all existing feature UIs.
- **Epic 14: Dark Mode Theming** — theme toggle persisted per-user, applied via `core/theme`.
- **Epic 15: CI/CD** — GitHub Actions running lint + `flutter test` on every PR.

These are intentionally left as epic-level placeholders until prioritized; they should be broken into stories using the same format when scheduled.
