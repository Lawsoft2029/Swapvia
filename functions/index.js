const { randomUUID } = require("node:crypto");
const { initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

initializeApp();
const db = getFirestore();

const COINGECKO_IDS = { ETH: "ethereum", USDC: "usd-coin", SOL: "solana" };
const RATE_MAX_AGE_MS = 60 * 1000;
const MAX_TEST_DEPOSIT_UNITS = 1000 * 100000000;
const SWAP_RATE_MAX_AGE_MS = 15 * 60 * 1000;
// Smallest units per whole coin. NGN is held in kobo.
const UNITS = { NGN: 100n, ETH: 100000000n, USDC: 100000000n, SOL: 100000000n };

function requireKey(key) {
  if (typeof key !== "string" || !/^[\w-]{8,64}$/.test(key)) {
    throw new HttpsError("invalid-argument", "Invalid idempotency key.");
  }
}

function requireAmount(currency, amount) {
  if (!Object.hasOwn(UNITS, currency)) {
    throw new HttpsError("invalid-argument", "Unsupported currency.");
  }
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Invalid amount.");
  }
}

const newReference = () =>
  `SV${randomUUID().replaceAll("-", "").slice(0, 16).toUpperCase()}`;

/** Fields a receipt needs, shared by every ledger entry. */
function ledgerEntry(uid, fields) {
  return {
    uid,
    status: "completed",
    createdAt: FieldValue.serverTimestamp(),
    ...fields,
  };
}

/** Claims a unique username for the signed-in user. It cannot be changed. */
exports.claimUsername = onCall(async (request) => {
  const uid = requireUid(request);
  const username = String(request.data?.username ?? "").trim().toLowerCase();
  if (!/^[a-z0-9_]{3,20}$/.test(username)) {
    throw new HttpsError("invalid-argument", "Use 3 to 20 letters, numbers or underscores.");
  }
  const nameRef = db.collection("usernames").doc(username);
  const userRef = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const [name, user] = await Promise.all([tx.get(nameRef), tx.get(userRef)]);
    if (name.exists && name.get("uid") === uid) return;
    if (name.exists) throw new HttpsError("already-exists", "That username is taken.");
    if (user.get("username")) {
      throw new HttpsError("failed-precondition", "You already have a username.");
    }
    tx.create(nameRef, { uid });
    tx.set(userRef, { username }, { merge: true });
  });
  return { username };
});

/** Sends money to another user by username. */
exports.send = onCall(async (request) => {
  const uid = requireUid(request);
  const { currency, amount, idempotencyKey, note } = request.data ?? {};
  requireAmount(currency, amount);
  requireKey(idempotencyKey);
  const toUsername = String(request.data?.toUsername ?? "").trim().toLowerCase();
  const cleanNote = String(note ?? "").slice(0, 100);

  const nameRef = db.collection("usernames").doc(toUsername || "-");
  const debitRef = db.collection("ledger").doc(`${uid}_${idempotencyKey}`);
  const senderRef = db.collection("wallets").doc(uid);
  const senderUserRef = db.collection("users").doc(uid);

  return db.runTransaction(async (tx) => {
    const existing = await tx.get(debitRef);
    if (existing.exists) return { reference: existing.get("reference"), applied: false };

    const name = await tx.get(nameRef);
    if (!name.exists) throw new HttpsError("not-found", "No user has that username.");
    const toUid = name.get("uid");
    if (toUid === uid) throw new HttpsError("invalid-argument", "You cannot send to yourself.");

    const receiverRef = db.collection("wallets").doc(toUid);
    const [sender, receiver, senderUser] = await Promise.all([
      tx.get(senderRef),
      tx.get(receiverRef),
      tx.get(senderUserRef),
    ]);
    const fromUsername = senderUser.get("username");
    if (!fromUsername) throw new HttpsError("failed-precondition", "Choose a username first.");
    if (!receiver.exists) throw new HttpsError("failed-precondition", "Recipient has no wallet.");
    const balance = (sender.exists && sender.get(`balances.${currency}`)) || 0;
    if (balance < amount) throw new HttpsError("failed-precondition", "Insufficient balance.");
    const receiverBalance = receiver.get(`balances.${currency}`) ?? 0;

    const reference = newReference();
    const updatedAt = FieldValue.serverTimestamp();
    tx.update(senderRef, { [`balances.${currency}`]: balance - amount, updatedAt });
    tx.update(receiverRef, { [`balances.${currency}`]: receiverBalance + amount, updatedAt });
    const shared = { type: "transfer", currency, amount, reference, fee: 0, note: cleanNote };
    tx.create(debitRef, ledgerEntry(uid, {
      ...shared,
      direction: "debit",
      counterparty: toUsername,
      balanceAfter: balance - amount,
    }));
    tx.create(db.collection("ledger").doc(`${toUid}_${reference}`), ledgerEntry(toUid, {
      ...shared,
      direction: "credit",
      counterparty: fromUsername,
      balanceAfter: receiverBalance + amount,
    }));
    return { reference, applied: true };
  });
});

/** Price of one whole coin of `from` in `to`, as a fraction from live rates. */
async function swapRate(tx, from, to) {
  const crypto = from === "NGN" ? to : from;
  const pair = to === "NGN" || from === "NGN" ? `${crypto}_NGN` : null;
  const refs = pair
    ? [db.collection("rates").doc(pair)]
    : [db.collection("rates").doc(`${from}_USD`), db.collection("rates").doc(`${to}_USD`)];
  const docs = await Promise.all(refs.map((ref) => tx.get(ref)));
  for (const doc of docs) {
    const age = Date.now() - (doc.updateTime?.toMillis() ?? 0);
    if (!doc.exists || age > SWAP_RATE_MAX_AGE_MS) {
      throw new HttpsError("unavailable", "Live rate unavailable. Try again.");
    }
  }
  if (!pair) return { num: BigInt(docs[0].get("rate")), den: BigInt(docs[1].get("rate")) };
  // NGN rates are kobo per coin, so convert to naira per coin.
  const rate = BigInt(docs[0].get("rate"));
  return from === "NGN" ? { num: 100n, den: rate } : { num: rate, den: 100n };
}

/** Converts one balance to another at the live rate, rounding down. */
exports.swap = onCall(async (request) => {
  const uid = requireUid(request);
  const { from, to, amount, idempotencyKey } = request.data ?? {};
  requireAmount(from, amount);
  requireAmount(to, 1);
  requireKey(idempotencyKey);
  if (from === to) throw new HttpsError("invalid-argument", "Choose two different currencies.");

  const walletRef = db.collection("wallets").doc(uid);
  const debitRef = db.collection("ledger").doc(`${uid}_${idempotencyKey}`);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(debitRef);
    if (existing.exists) return { reference: existing.get("reference"), applied: false };
    const wallet = await tx.get(walletRef);
    const { num, den } = await swapRate(tx, from, to);

    const balance = (wallet.exists && wallet.get(`balances.${from}`)) || 0;
    if (balance < amount) throw new HttpsError("failed-precondition", "Insufficient balance.");
    const received = Number((BigInt(amount) * num * UNITS[to]) / (den * UNITS[from]));
    if (!Number.isSafeInteger(received) || received <= 0) {
      throw new HttpsError("invalid-argument", "Amount is too small or too large to swap.");
    }
    const toBalance = wallet.get(`balances.${to}`) ?? 0;

    const reference = newReference();
    tx.update(walletRef, {
      [`balances.${from}`]: balance - amount,
      [`balances.${to}`]: toBalance + received,
      updatedAt: FieldValue.serverTimestamp(),
    });
    const shared = { type: "swap", reference, fee: 0, from, to, amountIn: amount, amountOut: received };
    tx.create(debitRef, ledgerEntry(uid, {
      ...shared,
      currency: from,
      amount,
      direction: "debit",
      balanceAfter: balance - amount,
    }));
    tx.create(db.collection("ledger").doc(`${uid}_${reference}`), ledgerEntry(uid, {
      ...shared,
      currency: to,
      amount: received,
      direction: "credit",
      balanceAfter: toBalance + received,
    }));
    return { reference, applied: true, received };
  });
});

function requireUid(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  return request.auth.uid;
}

/** Creates the signed-in user's empty wallet. Safe to call repeatedly. */
exports.ensureWallet = onCall(async (request) => {
  const uid = requireUid(request);
  const ref = db.collection("wallets").doc(uid);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.create(ref, { balances: {}, updatedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
});

/**
 * Credits test funds, standing in for the payment webhook until sandbox keys
 * are added. Refuses to run anywhere except the local emulator.
 */
exports.testDeposit = onCall(async (request) => {
  const uid = requireUid(request);
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    throw new HttpsError("failed-precondition", "Only runs on the emulator.");
  }
  const { currency, amount, idempotencyKey } = request.data ?? {};
  if (!Object.hasOwn(UNITS, currency)) {
    throw new HttpsError("invalid-argument", "Unsupported currency.");
  }
  if (!Number.isSafeInteger(amount) || amount <= 0 || amount > MAX_TEST_DEPOSIT_UNITS) {
    throw new HttpsError("invalid-argument", "Invalid amount.");
  }
  if (typeof idempotencyKey !== "string" || !/^[\w-]{8,64}$/.test(idempotencyKey)) {
    throw new HttpsError("invalid-argument", "Invalid idempotency key.");
  }

  const walletRef = db.collection("wallets").doc(uid);
  const ledgerRef = db.collection("ledger").doc(`${uid}_${idempotencyKey}`);
  const applied = await db.runTransaction(async (tx) => {
    const [wallet, entry] = await Promise.all([tx.get(walletRef), tx.get(ledgerRef)]);
    if (entry.exists) return false;
    if (!wallet.exists) {
      throw new HttpsError("failed-precondition", "Wallet not found.");
    }
    const balance = wallet.get(`balances.${currency}`) ?? 0;
    tx.update(walletRef, {
      [`balances.${currency}`]: balance + amount,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(ledgerRef, {
      uid,
      type: "test_deposit",
      currency,
      amount,
      direction: "credit",
      status: "completed",
      fee: 0,
      balanceAfter: balance + amount,
      reference: idempotencyKey,
      createdAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
  return { applied };
});

async function publishRates() {
  const ids = Object.values(COINGECKO_IDS).join(",");
  const response = await fetch(
    `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd,ngn`,
  );
  if (!response.ok) throw new Error(`CoinGecko returned ${response.status}`);
  const prices = await response.json();

  const batch = db.batch();
  for (const [symbol, id] of Object.entries(COINGECKO_IDS)) {
    const usd = prices[id]?.usd;
    const ngn = prices[id]?.ngn;
    if (typeof usd !== "number" || typeof ngn !== "number") {
      throw new Error(`No price for ${symbol}`);
    }
    batch.set(db.collection("rates").doc(`${symbol}_NGN`), {
      rate: Math.round(ngn * 100), // kobo per coin
      source: "coingecko",
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection("rates").doc(`${symbol}_USD`), {
      rate: Math.round(usd * 100), // US cents per coin
      source: "coingecko",
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

exports.refreshRatesScheduled = onSchedule("every 5 minutes", publishRates);

/** Scheduled functions do not fire on the emulator, so the app asks instead. */
exports.refreshRates = onCall(async (request) => {
  requireUid(request);
  const latest = await db.collection("rates").doc("ETH_USD").get();
  const age = Date.now() - (latest.updateTime?.toMillis() ?? 0);
  if (age < RATE_MAX_AGE_MS) return { refreshed: false };
  try {
    await publishRates();
  } catch (error) {
    throw new HttpsError("unavailable", error.message);
  }
  return { refreshed: true };
});
