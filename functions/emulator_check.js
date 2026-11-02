// End-to-end check against the emulators. Run from the project root:
// firebase emulators:exec --only auth,firestore,functions "node functions/emulator_check.js"
const assert = require("node:assert");

const project = "swapvia-5a67e";
const fn = (name) => `http://127.0.0.1:5001/${project}/us-central1/${name}`;
const docs = `http://127.0.0.1:8080/v1/projects/${project}/databases/(default)/documents`;

async function signUp(email) {
  const response = await fetch(
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password: "password123", returnSecureToken: true }),
    },
  );
  const body = await response.json();
  return { uid: body.localId, token: body.idToken };
}

async function call(name, token, data = {}) {
  const response = await fetch(fn(name), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  return { status: response.status, body: await response.json() };
}

const read = (path, token) =>
  fetch(`${docs}/${path}`, { headers: { Authorization: `Bearer ${token}` } });

async function main() {
  const stamp = Date.now();
  const a = await signUp(`a${stamp}@test.dev`);
  const b = await signUp(`b${stamp}@test.dev`);
  const deposit = { currency: "USDC", amount: 10000000000, idempotencyKey: `key-${stamp}` };

  assert.equal((await call("ensureWallet")).status, 401, "needs sign-in");
  assert.equal((await call("ensureWallet", a.token)).status, 200);
  assert.equal((await call("ensureWallet", a.token)).status, 200, "repeat is safe");
  await call("ensureWallet", b.token);

  assert.equal((await call("testDeposit", a.token, deposit)).body.result.applied, true);
  assert.equal(
    (await call("testDeposit", a.token, deposit)).body.result.applied,
    false,
    "same key does not credit twice",
  );
  const bad = await call("testDeposit", a.token, { ...deposit, amount: 1.5, idempotencyKey: `bad-${stamp}` });
  assert.equal(bad.status, 400, "fractional amount rejected");

  const wallet = await (await read(`wallets/${a.uid}`, a.token)).json();
  assert.equal(wallet.fields.balances.mapValue.fields.USDC.integerValue, "10000000000");
  const entry = await read(`ledger/${a.uid}_${deposit.idempotencyKey}`, a.token);
  assert.equal(entry.status, 200, "ledger entry written");

  assert.equal((await read(`wallets/${a.uid}`, b.token)).status, 403, "other users blocked");

  const rates = await call("refreshRates", a.token);
  assert.equal(rates.status, 200, `rates: ${JSON.stringify(rates.body)}`);
  const eth = await (await read("rates/ETH_USD", a.token)).json();
  console.log("Live ETH price in cents:", eth.fields.rate.integerValue);
  assert.ok(Number(eth.fields.rate.integerValue) > 0);

  const balance = async (user, currency) => {
    const doc = await (await read(`wallets/${user.uid}`, user.token)).json();
    return Number(doc.fields.balances.mapValue.fields[currency]?.integerValue ?? 0);
  };
  const nameA = `a${stamp}`;
  const nameB = `b${stamp}`;
  assert.equal((await call("claimUsername", a.token, { username: nameA })).status, 200);
  assert.equal((await call("claimUsername", b.token, { username: nameA })).status, 409, "username is unique");
  assert.equal((await call("claimUsername", b.token, { username: nameB })).status, 200);
  assert.equal((await call("claimUsername", b.token, { username: `c${stamp}` })).status, 400 + 0, "one username only");

  const send = {
    toUsername: nameB,
    currency: "USDC",
    amount: 2500000000,
    idempotencyKey: `send-${stamp}`,
    note: "Lunch",
  };
  const sent = await call("send", a.token, send);
  assert.equal(sent.body.result.applied, true);
  assert.equal((await call("send", a.token, send)).body.result.applied, false, "send retry is safe");
  assert.equal(await balance(a, "USDC"), 7500000000);
  assert.equal(await balance(b, "USDC"), 2500000000);
  const receipt = await (await read(`ledger/${a.uid}_${send.idempotencyKey}`, a.token)).json();
  assert.equal(receipt.fields.counterparty.stringValue, nameB);
  assert.equal(receipt.fields.balanceAfter.integerValue, "7500000000");

  const tooMuch = await call("send", a.token, { ...send, amount: 99900000000, idempotencyKey: `over-${stamp}` });
  assert.equal(tooMuch.status, 400, "cannot overspend");
  assert.equal(await balance(a, "USDC"), 7500000000);
  const self = await call("send", a.token, { ...send, toUsername: nameA, idempotencyKey: `self-${stamp}` });
  assert.equal(self.status, 400, "cannot send to yourself");

  const swap = { from: "USDC", to: "NGN", amount: 1000000000, idempotencyKey: `swap-${stamp}` };
  const swapped = await call("swap", a.token, swap);
  assert.equal(swapped.status, 200, `swap: ${JSON.stringify(swapped.body)}`);
  assert.equal((await call("swap", a.token, swap)).body.result.applied, false, "swap retry is safe");
  assert.equal(await balance(a, "USDC"), 6500000000);
  assert.equal(await balance(a, "NGN"), swapped.body.result.received);
  console.log("10 USDC swapped to kobo:", swapped.body.result.received);
  const back = await call("swap", a.token, {
    from: "NGN",
    to: "USDC",
    amount: swapped.body.result.received,
    idempotencyKey: `back-${stamp}`,
  });
  assert.equal(back.status, 200, `swap back: ${JSON.stringify(back.body)}`);
  const cross = await call("swap", a.token, { from: "USDC", to: "ETH", amount: 100000000, idempotencyKey: `cross-${stamp}` });
  assert.equal(cross.status, 200, `cross: ${JSON.stringify(cross.body)}`);

  console.log("All emulator checks passed");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
