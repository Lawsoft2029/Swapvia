# Swapvia data model

Amounts are stored as integers in the smallest unit (kobo for NGN, and 8
decimal places for crypto), so totals have no floating-point rounding errors.

| Collection | Key | Fields | App access |
|---|---|---|---|
| `users` | uid | `fullName`, `email`, `createdAt` | Owner reads, edits `fullName` |
| `usernames` | username (lowercase) | `uid` | Signed-in users read |
| `wallets` | uid | `balances` (map of currency to amount), `updatedAt` | Owner reads |
| `ledger` | auto ID | `uid`, `type`, `currency`, `amount`, `direction`, `status`, `reference`, `createdAt` | Owner reads |
| `notifications` | auto ID | `uid`, `title`, `message`, `read`, `createdAt` | Owner reads, marks read |
| `rates` | pair, such as `USDT_NGN` | `rate`, `source`, `updatedAt` | Signed-in users read |
| `processedPayments` | provider and payment ID | `processedAt` | None |

For `*_USD` pairs in `rates`, `rate` is US cents per coin. `*_NGN` pairs are kobo per
coin. Ledger IDs are `{uid}_{idempotencyKey}`, so a repeated request finds the
earlier entry. For receipts, ledger entries also hold `fee`, `balanceAfter` and,
where relevant, `counterparty`, `note`, `from`, `to`, `amountIn` and `amountOut`.
`users` also holds `username`, written only by the `claimUsername` function.

## Money rules

- Only Cloud Functions change `wallets` and `ledger`.
- Every balance change and its ledger entries are written in one Firestore
  transaction, so a failure cannot leave them out of step.
- Each request carries an idempotency key, so a retry cannot run twice.
- Webhooks verify the provider's signature, then record the payment in
  `processedPayments` in the same transaction that credits the wallet.
- API keys are stored as Firebase secrets and never included in the app.
- All payments run in sandbox mode.
