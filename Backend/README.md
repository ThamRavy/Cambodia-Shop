# Cambodia Shop API — Dart Frog + MongoDB + ABA PayWay

A runnable starter backend for an e-commerce shop. It includes customer auth, public product browsing, admin-only product creation, server-priced order creation, stock decrement, order lookup, an ABA PayWay hosted-checkout adapter, Google Maps directions URL generation, Docker Compose and unit tests.

## Code structure

Requests flow from an external client through a Dart Frog route, then a controller and domain service, with MongoDB connection setup kept in the database layer:

```text
External clients
  -> routes/                 URL mapping and middleware
  -> lib/controllers/        HTTP handling and response mapping
  -> lib/services/           Authentication, orders, products, payments, geo
  -> lib/database/           MongoDB connection and indexes
```

Route files stay under `routes/` because Dart Frog uses their paths to define URLs. Add route adapters there, put request/response handling in `lib/controllers/`, domain operations in `lib/services/`, and database connection/index initialization in `lib/database/`.

> **Payment production gate:** The ABA PayWay adapter creates purchase transactions and signs the documented request fields. Verify the integration against your merchant's current guide and credentials before launch. The return route does **not** mark orders paid; the authenticated verification endpoint checks status server-to-server. Add transactional/idempotent order-payment reconciliation and test it with your merchant sandbox before production fulfillment. Never fulfill from a browser redirect alone.

## Requirements
- Docker Engine + Docker Compose plugin
- Dart SDK 3.3+ and Dart Frog CLI for local development (`dart pub global activate dart_frog_cli`)
- ABA PayWay sandbox merchant ID and HMAC signing key (from PayWay sandbox onboarding; some older docs call it an API key)
- Google Maps browser key if the storefront embeds Maps (not required for the directions URL endpoint)

## Start with Docker Compose
1. Copy `.env.example` to `.env`.
2. Replace `JWT_SECRET`, `MONGO_ROOT_PASSWORD`, and `SHOP_DB_PASSWORD` with strong random secrets. Keep `.env` out of source control.
3. Configure `ABA_PAYWAY_MERCHANT_ID` and `ABA_PAYWAY_HMAC_KEY` with credentials confirmed by ABA for your merchant account. Some older PayWay onboarding docs call this the API key; the adapter accepts either `ABA_PAYWAY_HMAC_KEY` or `ABA_PAYWAY_API_KEY` for compatibility. The signing key must be the HMAC key; do not use an RSA or public key. Use sandbox credentials and URLs first.
4. Run `docker compose up --build -d`.
5. Check `curl http://localhost:8080/health`.

Compose creates a least-privilege MongoDB application user using `mongo-init.sh`. Change the example root/app passwords before exposing the service. For production, place a TLS reverse proxy/load balancer in front and use a managed secret store.

## Local development
Run MongoDB separately and set `MONGODB_URI=mongodb://localhost:27017` in `.env` for local development, then start Dart Frog from the project root:
```bash
dart pub get
dart_frog dev
```
The app reads process environment variables first and uses `.env` from the project root as a local-development fallback. In deployment, configure secrets through the process environment or your platform's secret manager. For browser clients, set `CORS_ALLOWED_ORIGINS` to a comma-separated list of exact HTTPS storefront origins. Local HTTP development origins on `localhost`, `127.0.0.1`, and `[::1]` are allowed by default.

## Render environment variables
For a Render deployment using MongoDB Atlas, configure `MONGODB_URI`, `MONGODB_DATABASE`, and a strong `JWT_SECRET` in the service's environment settings. Render supplies `PORT`. For PayWay, set `ABA_PAYWAY_MERCHANT_ID` and `ABA_PAYWAY_HMAC_KEY` only to the merchant credentials ABA has confirmed for your account; never substitute an RSA key or public key for the HMAC signing key. The default PayWay URLs use the sandbox. Set `ABA_PAYWAY_BASE_URL` or the explicit purchase/check URLs only to the endpoints provided for your environment. Also set `PUBLIC_API_BASE_URL` to the deployed HTTPS API origin, `FRONTEND_SUCCESS_URL` and `FRONTEND_CANCEL_URL` to your storefront routes, and `CORS_ALLOWED_ORIGINS` to the exact HTTPS storefront origin when browser clients call the API. The `MONGO_ROOT_*` and `SHOP_DB_*` variables are for the included Docker Compose MongoDB service and are not needed for Atlas.

## Flutter storefront
The mobile storefront is in `frontend/`. Start the API first, configure ABA PayWay sandbox credentials in the API `.env`, then run the Flutter app from that directory:
```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```
Use `http://localhost:8080/api/v1` for Flutter desktop or web, or replace `10.0.2.2` with your computer's LAN IP when using a physical Android phone. The Android emulator uses `10.0.2.2` to reach services running on the host. Android's debug build permits local HTTP for development; release builds should use HTTPS. iOS devices should also use an HTTPS API endpoint unless you configure an appropriate local-development transport exception. The app supports product browsing, account registration and login, a local shopping cart, order placement, ABA KHQR checkout, and order history. After scanning the QR in ABA Mobile, use the app's payment status button to verify server-side; never fulfill an order from the QR scan or browser redirect alone. Use PayWay sandbox merchant credentials while testing.

## API routes
All JSON APIs are under `/api/v1` unless stated otherwise.

| Method | Route | Auth | Purpose |
|---|---|---|---|
| GET | `/health` | No | Liveness check |
| POST | `/api/v1/auth/register` | No | `{ "email", "password", "name" }` |
| POST | `/api/v1/auth/login` | No | Returns JWT |
| GET | `/api/v1/products` | No | Active products; optional `?category=` |
| GET | `/api/v1/products/:id` | No | Product detail |
| POST | `/api/v1/products` | Admin JWT | Create product (`name`, `slug`, `priceCents`, `stock`, etc.) |
| POST | `/api/v1/orders` | Customer JWT | Create order from `items:[{productId,quantity}]` and `shippingAddress` |
| GET | `/api/v1/orders` | Customer JWT | Current user's orders |
| GET | `/api/v1/orders/:id` | Owner JWT | Order details |
| POST | `/api/v1/payments/checkout` | Owner JWT | Creates a PayWay transaction for an unpaid order and selected payment option |
| POST | `/api/v1/payments/verify` | Transaction owner JWT | Calls PayWay Check Transaction once and records the provider status |
| GET/POST | `/api/v1/payments/return` | PayWay callback/return | Redirect acknowledgement only; not payment confirmation |
| POST | `/api/v1/addresses/directions` | No | `{ "latitude": 11.55, "longitude": 104.92 }` returns Google Maps directions URL |

### Example: register
```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
 -H 'Content-Type: application/json' \
 -d '{"email":"customer@example.com","password":"replace-with-a-long-passphrase","name":"Shop Customer"}'
```

### Example: browse products
```bash
curl http://localhost:8080/api/v1/products
```

### Example: create an order
Pass a bearer token and a shipping address. The API reads product prices from MongoDB; client prices are ignored.
```json
{
  "items": [{"productId":"REPLACE_WITH_24_CHAR_PRODUCT_ID","quantity":2}],
  "shippingAddress": {
    "recipient":"Shop Customer", "phone":"012345678", "addressLine":"Street 123",
    "city":"Phnom Penh", "latitude":11.55,"longitude":104.92
  }
}
```

### Example: create a PayWay transaction
After creating an order, call `POST /api/v1/payments/checkout` with the customer's bearer token:
```json
{
  "orderId": "REPLACE_WITH_ORDER_ID",
  "paymentOption": "abapay_khqr_deeplink",
  "returnDeeplink": {
    "ios_scheme": "myshop://payment/complete",
    "android_scheme": "myshop://payment/complete"
  }
}
```
`returnDeeplink` is optional for web clients. Mobile and hybrid clients should provide both app URLs so PayWay can return to the app after payment in ABA Mobile. The API encodes them in PayWay's required Base64 JSON format and requests `view_type=hosted`. Supported `paymentOption` values are `cards`, `abapay_khqr`, `abapay_khqr_deeplink`, `alipay`, and `wechat`. The response may contain hosted checkout HTML or QR/deeplink fields, depending on the selected option. The order amount, currency, items, and customer details are loaded from the database; clients cannot override them.

After the customer completes or cancels checkout, call `POST /api/v1/payments/verify` with the same customer's bearer token:
```json
{
  "tranId": "TRANSACTION_ID_FROM_CHECKOUT_RESPONSE"
}
```
This makes one server-to-server Check Transaction API request. Do not poll in a tight loop; use the returned status and stop when it is terminal. The API marks the order paid only when PayWay reports `APPROVED` with a matching amount and currency. A `PENDING` response is not payment confirmation. PayWay only permits status checks for transactions created in the last seven days.

### Admin access
Registration always creates a `customer`. For initial development, promote a known account through an authenticated, audited database admin operation; do not expose an unauthenticated role-change endpoint. Example after connecting with a privileged Mongo shell:
```javascript
db.users.updateOne({email: "admin@example.com"}, {$set: {role: "admin"}})
```

## Data models (MongoDB documents)
- `users`: `_id`, `email` (unique, normalized), `name`, `passwordHash`, `role`, `createdAt`
- `products`: `_id`, `name`, `slug` (unique), `description`, `category`, `imageUrl`, `priceCents` (integer), `currency`, `stock`, `active`, timestamps
- `orders`: `_id`, `orderNumber` (unique), `userId`, immutable item snapshots, `subtotalCents`, `shippingCents`, `totalCents`, `currency`, `status`, `paymentStatus`, `shippingAddress`, timestamps
- `payments`: `_id`, `provider`, `tranId` (unique), `orderId`, `userId`, `amountCents`, `currency`, `status`, timestamps, provider verification metadata

## Security and reliability checklist before production
- [ ] Verify PayWay signing and status response handling against your merchant's sandbox; use the server-side Check Transaction response and verify transaction ID, amount, currency, and final approved status.
- [ ] Make payment/order reconciliation transactional and idempotent; restore stock for failed/cancelled orders and handle payment timeout.
- [ ] Wrap stock reservation/order creation in a MongoDB transaction (requires replica set) or a reservation/compensation workflow. Current sample decrements stock before order insert; add rollback on every failure.
- [ ] Add rate limiting, request size limits, CORS allowlist, TLS, security headers, structured redacted logs, monitoring, backups and restore drills.
- [ ] Add email verification, password reset, account lockout/abuse controls, pagination, product update/archive, admin audit logs, shipping fees/tax, refunds and fulfillment workflows.
- [ ] Restrict Google Maps browser key by website referrer and only required APIs. Keep server-side web-service keys separate and private.
- [ ] Do not store card data. PayWay hosted checkout should collect payment details.
- [ ] Use HTTPS for all public callbacks; configure production URLs and test sandbox payment methods before launch.

## Tests
```bash
dart test
```
Tests cover geo-coordinate order/range, directions URLs, integer-cent arithmetic and slug validation. Integration tests against MongoDB and PayWay sandbox still need to be added and run in your environment.

## Official integration references
- ABA PayWay Developer Suite: https://developer.payway.com.kh/
- Purchase endpoint: https://developer.payway.com.kh/purchase-14530820e0
- Transaction details: https://developer.payway.com.kh/get-a-transaction-details-14530824e0
- Google Maps Platform API key security: https://developers.google.com/maps/api-security-best-practices