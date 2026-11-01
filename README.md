# Inventory Tracker

A beginner-friendly Flutter app for one shop on one device. Products are stored locally in SQLite using `sqflite`; the app works offline.

## Features

- Create, view, edit, and delete products with name, category, unit price in naira, stock, and minimum stock.
- Dashboard cards show total products and low-stock items.
- Quick stock buttons adjust the saved quantity atomically, preventing lost updates and negative quantities.
- Products at or below their minimum stock are highlighted; zero stock has an out-of-stock badge.
- Search by name or category, filter low-stock products, and refresh the list.
- Forms validate required fields, finite non-negative prices, and whole-number quantities from 0 to 2,147,483,647.
- Delete confirmation, loading states, retry after load failures, and feedback for saves and failed operations.

## Run and check

Use the Flutter SDK compatible with the Dart SDK constraint in `pubspec.yaml`.

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
```

The configured SQLite backend supports Android, iOS, and macOS. Windows, Linux, and web need an additional database backend before use. This Windows workspace can build the Android app.

## Structure

- `lib/screens/product_list_screen.dart`: dashboard, product list, filters, and stock controls.
- `lib/screens/product_form_screen.dart`: shared creation/editing form.
- `lib/services/product_service.dart`: validation and product operations.
- `lib/database/product_repository.dart`: storage contract, also used by test fakes.
- `lib/database/database_helper.dart`: SQLite persistence, preserving the existing version 1 database.
- `lib/models/product.dart`: product fields, serialization, and low-stock calculation.

Service and widget tests use an in-memory fake repository. On a device, also check that a product survives closing/reopening the app and that stock changes persist. Local inventory is lost if app data is cleared or the app is uninstalled; backup/export is not included.

Firebase authentication, cloud sync, charts, multi-branch support, supplier orders, barcode scanning, and sales reporting are outside this first version.
