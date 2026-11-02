# Swapvia — project guide for Claude

Swapvia is a Flutter app (Android, iOS, web, Windows, macOS, Linux) + Firebase
backend: a fiat (naira) and crypto wallet for sending, receiving, withdrawing and
swapping money, with live analysis and account statements. Owner and developer:
Lawrence Ita (Firebase project `swapvia-5a67e`, GitHub `Lawsoft2029/Swapvia`,
branch `main`, app ID `com.lawsoft.swapvia`).

**Keep this file updated:** after every change, record what was built or decided
here in the same turn, without being asked. Lawrence is on a borrowed Claude
account, and this file is how a future Claude account learns the project.

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
- Say on the resume that Swapvia grew out of Pay Me. Only add it once it is built.

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
- Analyze: `flutter analyze`

## Status (update this)

Done:
- Project created with logo, icons, splash and app names on all platforms
- Firestore data model and rules written; 18 rules tests pass on the emulator
- Connected to `swapvia-5a67e` in `.firebaserc`; first commit made under
  Lawrence's real name and email

Not verified or not done:
- GitHub repo was created as `-Swapvia` by mistake and must be renamed to
  `Swapvia`; nothing has been pushed yet
- Blaze plan and budget alert not confirmed
- Rules not deployed; icons not checked on a real device; no platform build yet
- The app is still the default Flutter starter screen

## Next steps

1. Push to GitHub after the rename
2. Cloud Functions for send, swap and withdraw, then payment webhooks
3. Design system (colours, type, spacing, light and dark)
4. Move Lawrence's Pay Me screens across one by one, testing on the emulator
5. Rewrite sign-in, PIN and biometrics, then KYC, notifications, settings and a
   small admin panel
6. Tests for the money logic, plus a README with screenshots
