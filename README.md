# Inventory Tracker

A Flutter inventory and sales app with two explicit storage modes: local SQLite (offline, one device), or Supabase (online, one account per shop).

## Features

- Create, view, edit, and delete products with name, category, unit price in naira, stock, and minimum stock.
- Dashboard cards show total products and low-stock items.
- Quick stock buttons adjust the saved quantity atomically, preventing lost updates and negative quantities.
- Products at or below their minimum stock are highlighted; zero stock has an out-of-stock badge.
- Search by name or category, filter low-stock products, and refresh the list.
- Forms validate required fields, prices from ₦1 to ₦999,999,999,999.99 with at most two decimal places, and whole-number quantities from 0 to 2,147,483,647.
- Delete confirmation, loading states, retry after load failures, and feedback for saves and failed operations.
- Sell a product by choosing a quantity and recording cash or transfer payment. The total uses its saved unit price.
- Save the sale and reduce stock in one transaction; reject insufficient stock and stale prices. Retrying the same checkout uses its original reference to avoid duplicate sales.
- View sales history with product name, quantity, price, payment method, receipt number, and local date/time. Historical prices and names survive product edits/deletions.
- Supabase mode adds email/password accounts and account-specific products and sales, protected by Row Level Security.

The Sell button records a payment received outside the app. It does not process a bank transfer or charge a card. Stock +/- buttons are manual corrections, not sales.

## Connect Supabase

1. Create a project at [Supabase Dashboard](https://supabase.com/dashboard).
2. Open **SQL Editor**, create a query, paste `supabase/migrations/202611040001_inventory_and_sales.sql`, and run it once in a new project. It creates the tables, access policies, and transactional functions. Do not run it over an unrelated existing schema.
3. Open the project's **Connect** dialog for the project URL and publishable key. Keys are also available under **Settings → API Keys**. Use a publishable key (`sb_publishable_...`) or a legacy anon key; never put a secret/service-role key or database password in the app.
4. Copy `supabase.config.example.json` to `supabase.config.json` and replace its two placeholder values. The real config file is ignored by Git.
5. Run the configured app:

```sh
flutter pub get
flutter run --dart-define-from-file=supabase.config.json
```

For an Android APK connected to this project:

```sh
flutter build apk --release --dart-define-from-file=supabase.config.json
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`. The current Android release build uses the development signing key, suitable for a demonstration; configure your own signing key before app-store distribution.

Create an account in the app. If email confirmation is enabled in Supabase, confirm the email, then return to the app and sign in. Each account has its own shop inventory; creating a second account does not grant access to the first. Shared staff roles are not part of this version. Keep the password private.

Supabase mode needs internet. Existing SQLite products remain on the original device and are **not automatically uploaded**. Local mode and cloud mode do not synchronize. Running without any configuration uses local mode and clearly labels it. Incomplete/failed cloud setup shows a startup error rather than silently switching to local storage.

Setup references: [Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [API keys](https://supabase.com/docs/guides/getting-started/api-keys), [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Run and check

Use the Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml`.

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
```

Local SQLite mode supports Android, iOS, and macOS. Windows, Linux, and web need an additional SQLite backend for local mode. Supabase does not depend on SQLite for its data operations. This workspace targets the Android demonstration build.

## Structure

- `lib/screens/product_list_screen.dart`: dashboard, product list, filters, and stock controls.
- `lib/screens/product_form_screen.dart`: shared creation/editing form.
- `lib/screens/sell_product_screen.dart`: sale quantity, payment choice, total, confirmation, and retry.
- `lib/screens/sales_history_screen.dart`: saved receipts.
- `lib/screens/auth_screen.dart`: email signup/sign-in in cloud mode.
- `lib/services/product_service.dart`: validation and product operations.
- `lib/database/product_repository.dart`: storage contract, also used by test fakes.
- `lib/database/database_helper.dart`: SQLite persistence; version 2 adds sales while preserving version 1 products.
- `lib/database/supabase_product_repository.dart`: Supabase queries and transactional function calls.
- `supabase/migrations/202611040001_inventory_and_sales.sql`: PostgreSQL tables, account access rules, and stock/sale functions.
- `lib/models/product.dart`: product fields, serialization, and low-stock calculation.

Service and widget tests use an in-memory fake repository. They check sales, retries, insufficient stock, stale prices, and sale history in addition to the inventory flows. These tests do not prove a live Supabase project is configured correctly.

The SQL migration can also be checked in an isolated PostgreSQL engine without credentials:

```sh
npm.cmd install --prefix .dart_tool/sql-validation --no-audit --no-fund @electric-sql/pglite
node test/supabase_schema_test.mjs
```

This runs the actual migration and checks account isolation, sale retries, insufficient stock, immutable receipts, and transaction rollback. It does not test Supabase's hosted Auth service or simultaneous requests from separate devices.

Before presenting the connected app, create a product with stock 3 and price 1500, sell 2, and check that stock becomes 1 and history shows a total of 3000. Close/reopen, check persistence, sign out, and verify a different account cannot see the first account's data. Test selling the last item from two devices: only one request should succeed. Disable internet and verify errors are visible and a failed sale is not presented as successful. Reconnect and use **Retry same sale** if the confirmation response was lost. If you leave checkout after an uncertain result, check history before starting another sale.

Local inventory is lost if app data is cleared or the app is uninstalled. Cloud backup/export, automatic offline/cloud synchronization, payment processing, refunds, shared staff roles, multi-branch support, barcode scanning, and charts are outside this version.

## How to explain the project

“My app helps a shop track products, stock, and sales. Flutter provides the screens. Supabase provides login and a PostgreSQL database. When I confirm a sale, the database checks the available quantity, records the receipt, and reduces stock together. If any step fails, the whole transaction is cancelled. Each account can only access its own records.”

Example: Rice costs ₦1,500 and stock is 3. Selling 2 records a ₦3,000 sale and leaves 1. The minimum-stock indicator warns when replenishment is needed.

- **Screen:** collects input and shows the result.
- **Service:** validates input, such as positive whole-number quantities.
- **Repository:** sends the request to the selected storage backend.
- **Transaction:** groups the receipt and stock change into one successful operation.
- **Row Level Security:** database rules that keep one account's inventory separate from another's.
- **Sale reference:** identifies one checkout so retrying it does not sell the items twice.

Saving the product's name and price on the receipt preserves what was actually sold, even if the product is renamed or repriced later. Cash/transfer is a manually selected payment label; the app does not verify that money arrived.
