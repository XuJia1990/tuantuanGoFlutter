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
```

Run UAT:

Android Studio: select `UAT` or `PROD` in the toolbar's run configuration dropdown,
then Run or Debug. These shared configurations are saved in `.run/` and pass
`APP_ENV` to `lib/main.dart`. Stop the current app and run again when switching
environments; hot reload does not change compile-time environment values.

```sh
flutter run --dart-define=APP_ENV=uat
```

Run production:

```sh
flutter run --dart-define=APP_ENV=prod
```

Build UAT:

```sh
flutter build apk --dart-define=APP_ENV=uat
flutter build ios --dart-define=APP_ENV=uat
```

Build production:

```sh
flutter build apk --dart-define=APP_ENV=prod
flutter build ios --dart-define=APP_ENV=prod
```

## Getting Started

### Alipay return to app

The app accepts `tuantuango://app/payment-return` on iOS and Android. When the
original recharge page is still open, this link preserves that page and checks
the pending order with the server. Otherwise it opens the member page. The link
itself never marks an order as paid. An app restart cannot restore a pending
order that only exists in the previous recharge page's memory.

The backend must supply the merchant return URL when creating the payment.
Verify how the IntaPay integration maps `tuan.pay.ecReturnUrl` to the payment
provider's return URL; the temporary Google URL in the API document cannot open
this app. If that checkout flow only permits HTTPS return URLs, deploy an HTTPS
return page with a user-tappable link to `tuantuango://app/payment-return` and
configure that page as the merchant return URL. Do not replace the asynchronous
payment notification URL with an app link. The payment result still requires a
server-side check.

For IntaPay EC `/WeChatPayJSAPI/main/jsapi`, verify the actual outgoing form
contains `return_url`; `ecReturnUrl` is only this backend's configuration name.
The vendor EC specification also uses `code_url` for the payment URL response,
so that response field alone does not indicate that the wrong API was used.
At the Alipay+ layer, WAP checkout requires an HTTPS merchant return URL;
custom app schemes are supported for APP checkout. Confirm the gateway's actual
integration mode rather than assuming that setting a scheme in configuration
changes the payment mode.

To diagnose a return failure without making another payment, open
`tuantuango://app/payment-return` in Safari on the same installed device.
Debug builds print `[AlipayReturn]` with the received scheme, host, path and
matching result (without query parameters). If the app can open directly but
the cashier's return button does not open it, inspect the actual gateway return
parameter, checkout mode and redirect chain. If the app cannot open directly,
first verify the installed app's URL registration and reinstall the new native
build. Do not disable TLS verification to work around a failing HTTPS return page.

`scripts/alipay-return.html` is a self-contained HTTPS return-page template ready
to host on the merchant's website. It does not need URL parameters or a login
token. Configure the backend with its actual deployed HTTPS URL; this repository
change does not publish the page or update the backend configuration.

iOS URL scheme and Android manifest changes require rebuilding and reinstalling
the app; hot reload does not install these native registrations. The router also
recognizes `https://share.tuantuan-go.com/payment-return` for future Universal
Link integration. It is not enabled on Android by this change. The website's
Apple association file must authorize this path and the installed app identity
before iOS can open that HTTPS URL in the app.

Reference: [Alipay+ merchant return URL guidance](https://docs.alipayplus.com/alipayplus/alipayplus/redirection_acq_tile/redirection_acq_beta).

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
