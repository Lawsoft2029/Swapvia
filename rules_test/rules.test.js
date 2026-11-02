import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;
const db = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-swapvia',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const s = ctx.firestore();
    await setDoc(doc(s, 'users/alice'), { fullName: 'Alice', email: 'a@x.co' });
    await setDoc(doc(s, 'wallets/alice'), { balances: { NGN: 100 } });
    await setDoc(doc(s, 'ledger/e1'), { uid: 'alice', amount: 100 });
    await setDoc(doc(s, 'notifications/n1'), {
      uid: 'alice',
      title: 'Hi',
      read: false,
    });
    await setDoc(doc(s, 'rates/USDT_NGN'), { rate: 1500 });
    await setDoc(doc(s, 'processedPayments/p1'), { ok: true });
  });
});

test('owner can read own wallet', () =>
  assertSucceeds(getDoc(doc(db('alice'), 'wallets/alice'))));
test('another user cannot read wallet', () =>
  assertFails(getDoc(doc(db('bob'), 'wallets/alice'))));
test('signed-out visitor cannot read wallet', () =>
  assertFails(getDoc(doc(anon(), 'wallets/alice'))));
test('owner cannot change own balance', () =>
  assertFails(updateDoc(doc(db('alice'), 'wallets/alice'), { 'balances.NGN': 999 })));
test('owner cannot create a wallet', () =>
  assertFails(setDoc(doc(db('bob'), 'wallets/bob'), { balances: { NGN: 999 } })));
test('owner can read own ledger entry', () =>
  assertSucceeds(getDoc(doc(db('alice'), 'ledger/e1'))));
test('another user cannot read ledger entry', () =>
  assertFails(getDoc(doc(db('bob'), 'ledger/e1'))));
test('user cannot write ledger', () =>
  assertFails(setDoc(doc(db('alice'), 'ledger/e2'), { uid: 'alice', amount: 5 })));
test('user can create own profile', () =>
  assertSucceeds(setDoc(doc(db('bob'), 'users/bob'), {
    fullName: 'Bob',
    email: 'b@x.co',
    createdAt: serverTimestamp(),
  })));
test('profile cannot carry extra fields', () =>
  assertFails(setDoc(doc(db('bob'), 'users/bob'), {
    fullName: 'Bob',
    email: 'b@x.co',
    createdAt: serverTimestamp(),
    isAdmin: true,
  })));
test('user can edit own name', () =>
  assertSucceeds(updateDoc(doc(db('alice'), 'users/alice'), { fullName: 'A' })));
test('user cannot edit own email field', () =>
  assertFails(updateDoc(doc(db('alice'), 'users/alice'), { email: 'z@x.co' })));
test('user cannot claim username directly', () =>
  assertFails(setDoc(doc(db('alice'), 'usernames/alice'), { uid: 'alice' })));
test('owner can mark notification read', () =>
  assertSucceeds(updateDoc(doc(db('alice'), 'notifications/n1'), { read: true })));
test('owner cannot rewrite notification text', () =>
  assertFails(updateDoc(doc(db('alice'), 'notifications/n1'), { title: 'x' })));
test('signed-in user can read rates', () =>
  assertSucceeds(getDoc(doc(db('bob'), 'rates/USDT_NGN'))));
test('user cannot change rates', () =>
  assertFails(setDoc(doc(db('alice'), 'rates/USDT_NGN'), { rate: 1 })));
test('processed payments are hidden', () =>
  assertFails(getDoc(doc(db('alice'), 'processedPayments/p1'))));
