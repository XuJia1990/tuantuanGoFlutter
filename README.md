# tuantuanGoFlutter

Flutter migration scaffold for the existing uni-app project at:

`/Users/donghezhushihuishe/Desktop/tuan-tuan-app`

## Structure

- `lib/src/app`: app entry, router, theme
- `lib/src/core`: API client, endpoint constants, storage keys, QR parser
- `lib/src/features`: migration modules matching current uni-app pages
- `assets/static`: copied from `src/static` in the uni-app project

## Migration Order

1. API models and repositories
2. Login, auth storage, dynamic group-manager role
3. Home, station tabs, shop list, shop detail
4. Discounts and coupon order payment
5. Member cards, recharge, scan code, write-off
6. Profile, settings, version update, privacy pages

## Commands

```sh
flutter pub get
flutter analyze
flutter run
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
