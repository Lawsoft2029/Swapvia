# Swapvia — project guide for Claude

Swapvia is a Flutter app (Android, iOS, web, Windows, macOS, Linux) + Firebase
backend: a fiat (naira) and crypto wallet for sending, receiving, withdrawing and
swapping money, with live analysis and account statements. Owner and developer:
Lawrence Ita (Firebase project `swapvia-5a67e`, GitHub `Lawsoft2029/Swapvia`,
branch `main`, app ID `com.lawsoft.swapvia`).

**Keep this file updated:** after every change, record what was built or decided
here in the same turn, without being asked. Lawrence is on a borrowed Claude
account, and this file is how a future Claude account learns the project.

## Product scope (Lawrence's requirements)

Must behave like a real fintech app on test money, with nothing hardcoded, and
be professional and easy to navigate on app and web:
- Fiat (naira), crypto, send, receive, swap, withdraw, analysis and ledger
- Swapvia-to-Swapvia transfers by unique username, as in Pay Me
- Real-looking receipts on ledger entries
- Many crypto assets, as NOWPayments' supported list allows (no provider covers
  literally every coin; ETH-style 18-decimal precision needs care at 8 decimals)
- Shown as "Coming soon", needing funding: data, airtime, betting, electricity
  and other bill payments

## Origin and honesty rules

Swapvia is Lawrence's solo portfolio project. It grew out of **Pay Me**, a team
project at Wedigraf Technologies (training January to August 2026, defended
August 2026), built on Supabase because teammates could not use Firebase.

- Pay Me stays untouched at `C:\Users\USER\Documents\pay`
  (`Lawsoft2029/Pay-Me-Fintech-App`) and stays on the resume as the team project.
- **Lawrence's Pay Me work may be carried over:** crypto wallet, swap, withdraw,
  send, receive, ledger, add money, analysis, most of the account statement and
  the payment functions. Git commits there appear as "Your Name".
- **Teammates' work must be rewritten, not copied or restyled:** admin, auth, KYC,
  notifications, settings, splash, core theme, and `lib/features/fiat_wallet`.
- Say on the resume that Swapvia grew out of Pay Me. Lawrence asked to add it
  early, so the 2 November 2026 copies in Downloads, named "(Swapvia)", mark it
  "in progress". Keep claims to what is verified, and remove that label once built.

## Sandbox only

All payments use Flutterwave and NOWPayments sandbox/test mode. Real customer
money would need licensing and compliance work. Describe it as a portfolio app
with test payments.

## Brand

- Logo: an "S" made of two arrows going opposite ways, on a navy tile. Drawn in
  code at `lib/core/brand/swapvia_logo.dart`.
- Colours: ink `#0B1F3A`, mint `#2FE6A7`, white.
- Regenerate icons: `flutter test tool/generate_brand_assets_test.dart`, then
  `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
- Linux has the app name but no custom icon yet.

## Architecture

Full data model: `docs/data-model.md`.

- Only Cloud Functions change `wallets` and `ledger`; `firestore.rules` blocks the app.
- Each balance change and its ledger entries go in one Firestore transaction.
- Amounts are integers in the smallest unit (kobo; 8 decimals for crypto).
- Requests carry an idempotency key. Webhooks verify signatures and use
  `processedPayments`, so a payment cannot be credited twice.
- API keys are Firebase secrets, never in the app or the repo.

## Commands

- Rules tests: `cd rules_test && npm test` (needs Java; Temurin 25 is installed)
- Analyze: `flutter analyze`; app tests: `flutter test`
- Run locally: `firebase emulators:start --only "auth,firestore,functions"` (Java
  must be on PATH; run `npm install` in `functions` once), then `flutter run -d chrome`
- Backend check: `firebase emulators:exec --only "auth,firestore,functions" "node functions/emulator_check.js"`

## Status (update this)

Done:
- Project created with logo, icons, splash and app names on all platforms
- Firestore data model and rules written; 18 rules tests pass on the emulator
- Connected to `swapvia-5a67e` in `.firebaserc`; first commit made under
  Lawrence's real name and email; pushed to `Lawsoft2029/Swapvia`
- Design system in `lib/core/theme` (colours, spacing, light and dark themes,
  following the device setting); uses Flutter's default font for now
- First Pay Me screen moved: `lib/features/crypto_wallet` (wallet screen and
  asset tile, written by Lawrence per `git blame`), restyled, with integer amounts
- Wallet is live, not hardcoded (Lawrence's request: behave like a real fintech
  app, on test money): it streams `wallets` and `rates` from Firestore
- Cloud Functions in `functions/`: `ensureWallet`, `testDeposit`, `refreshRates`,
  `refreshRatesScheduled` (live prices from CoinGecko, no key needed).
  `functions/emulator_check.js` passes end to end
- Backend only, no screens yet: `claimUsername`, `send` (by username) and `swap`
  (crypto and NGN at live rates, zero fee), with receipt fields in the ledger
- App screens built fresh, not ported from Pay Me: bottom navigation or side
  rail, home, choose username, send, receive, swap, ledger, receipt, analysis and
  bills chips that say "coming soon" (`lib/features/home`, `lib/features/transactions`)
- Flutterwave test keys belong in `functions/.secret.local` (gitignored); no
  Flutterwave code exists yet. NOWPayments site would not open for Lawrence
- New email and password sign-in in `lib/features/authentication`, written fresh
- Firebase web and Android apps registered with `flutterfire configure`

Decisions on the crypto wallet screen:
- The app uses the local emulators by default; `--dart-define=USE_EMULATORS=false`
  needs deployed functions. Physical phones cannot reach the emulators as set up.
- `testDeposit` stands in for payment webhooks and refuses to run off the emulator.
- Pay Me's `AddressFrame` was left out: it showed a fake wallet address. Deposit
  addresses should come from NOWPayments; `docs/data-model.md` has no field yet.
- Pay Me's Supabase wallet bloc and API client were not moved.

Not verified or not done:
- Blaze plan active (Firebase email, 2 November 2026); Lawrence says a $5
  budget alert was set when upgrading (not seen by Claude); nothing deployed
- Icons not checked on a real device; app not yet clicked through by hand
- `firebase_options.dart` covers web and Android only
- No `users` document or username at sign-up yet

## Next steps

1. Click through the new screens on the emulators
2. Withdraw, then Flutterwave and NOWPayments sandbox webhooks and the wider
   coin list (needs Lawrence's sandbox keys)
3. Move Lawrence's other Pay Me screens across one by one, testing on the
   emulator: crypto swap and withdraw and deposit next
4. Finish sign-up, add PIN and biometrics, then KYC, notifications, settings and
   a small admin panel
5. More tests for the money logic, plus a README with screenshots
