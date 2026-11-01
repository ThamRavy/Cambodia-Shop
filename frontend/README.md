# Cambodia Shop Flutter storefront

Flutter client for the Cambodia Shop Dart Frog API. The app includes product browsing and search, a local shopping cart, customer sign-in and registration, order placement, ABA KHQR payment, and order history.

## Run locally

Start the API first, then run the client from this directory:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

The Android emulator uses `10.0.2.2` to reach the host computer. Use `http://localhost:8080/api/v1` for desktop or web, or your computer's LAN IP for a physical Android device. The app defaults to the deployed HTTPS API. Override it with the `API_BASE_URL` Dart define for local development or another deployment. For example, use `http://localhost:8080/api/v1` for local desktop/web, `http://10.0.2.2:8080/api/v1` for the Android emulator, or your computer's LAN IP for a physical Android device. The API allows local web development origins by default. For deployed web clients, configure `CORS_ALLOWED_ORIGINS` on the API with the exact storefront origins.

For production, build the web app with the deployed HTTPS API endpoint using `--dart-define=API_BASE_URL=https://ecommerce-backend-man4.onrender.com/api/v1` and explicitly allow the web app's exact origin in the backend's `CORS_ALLOWED_ORIGINS`.

The Vercel project is linked to `frontend/`. Keep its Root Directory set to `frontend`; [`vercel.json`](vercel.json) configures the Flutter web release build and `build/web` output directory. The Vercel build environment must have the Flutter SDK installed.

After placing an order, the app requests an ABA KHQR checkout and displays the returned QR. Scan it in ABA Mobile, then tap **I've paid — check status**. The app verifies the transaction with the API; it does not treat scanning the QR or a browser redirect as proof of payment. You can also start payment for an existing unpaid order from the Orders tab.

Configure valid ABA PayWay sandbox merchant credentials and sandbox endpoints in the API's `.env` before testing payment. Do not put PayWay secrets in the Flutter app. If checkout reports that credentials are missing or unavailable, check the API terminal and PayWay sandbox configuration.
