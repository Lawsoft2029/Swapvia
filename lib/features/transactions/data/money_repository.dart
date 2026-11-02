import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/money/money.dart';

/// One ledger row, holding everything its receipt shows.
class LedgerEntry {
  final String type;
  final String currency;
  final int amount;
  final bool isCredit;
  final String status;
  final String reference;
  final int fee;
  final int? balanceAfter;
  final String? counterparty;
  final String? note;
  final String? from;
  final String? to;
  final int? amountIn;
  final int? amountOut;
  final DateTime? createdAt;

  const LedgerEntry({
    required this.type,
    required this.currency,
    required this.amount,
    required this.isCredit,
    required this.status,
    required this.reference,
    this.fee = 0,
    this.balanceAfter,
    this.counterparty,
    this.note,
    this.from,
    this.to,
    this.amountIn,
    this.amountOut,
    this.createdAt,
  });

  factory LedgerEntry.fromMap(Map<String, dynamic> data) => LedgerEntry(
    type: data['type'] as String,
    currency: data['currency'] as String,
    amount: data['amount'] as int,
    isCredit: data['direction'] == 'credit',
    status: data['status'] as String,
    reference: data['reference'] as String,
    fee: data['fee'] as int? ?? 0,
    balanceAfter: data['balanceAfter'] as int?,
    counterparty: data['counterparty'] as String?,
    note: data['note'] as String?,
    from: data['from'] as String?,
    to: data['to'] as String?,
    amountIn: data['amountIn'] as int?,
    amountOut: data['amountOut'] as int?,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
  );

  String get title => switch (type) {
    'transfer' when isCredit => 'Received from @$counterparty',
    'transfer' => 'Sent to @$counterparty',
    'swap' => 'Swap $from to $to',
    'test_deposit' => 'Test deposit',
    _ => 'Transaction',
  };

  String get signedAmount =>
      '${isCredit ? '+' : '-'}${formatAmount(amount, currency)}';
}

abstract class MoneyRepository {
  Stream<String?> watchUsername();
  Stream<List<LedgerEntry>> watchLedger();
  Future<void> claimUsername(String username);

  /// Each returns the finished ledger entry for the receipt screen.
  Future<LedgerEntry> send({
    required String toUsername,
    required String currency,
    required int amount,
    required String note,
    required String idempotencyKey,
  });
  Future<LedgerEntry> swap({
    required String from,
    required String to,
    required int amount,
    required String idempotencyKey,
  });
  Future<void> addTestFunds(String currency, int amount);
}

class FirebaseMoneyRepository implements MoneyRepository {
  final String uid;
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

  FirebaseMoneyRepository({required this.uid});

  @override
  Stream<String?> watchUsername() => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['username'] as String?);

  @override
  Stream<List<LedgerEntry>> watchLedger() => _db
      .collection('ledger')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => LedgerEntry.fromMap(doc.data()))
            .toList(),
      );

  @override
  Future<void> claimUsername(String username) => _functions
      .httpsCallable('claimUsername')
      .call<void>({'username': username});

  Future<LedgerEntry> _entry(String key) async {
    final doc = await _db.collection('ledger').doc('${uid}_$key').get();
    return LedgerEntry.fromMap(doc.data()!);
  }

  @override
  Future<LedgerEntry> send({
    required String toUsername,
    required String currency,
    required int amount,
    required String note,
    required String idempotencyKey,
  }) async {
    await _functions.httpsCallable('send').call<void>({
      'toUsername': toUsername,
      'currency': currency,
      'amount': amount,
      'note': note,
      'idempotencyKey': idempotencyKey,
    });
    return _entry(idempotencyKey);
  }

  @override
  Future<LedgerEntry> swap({
    required String from,
    required String to,
    required int amount,
    required String idempotencyKey,
  }) async {
    await _functions.httpsCallable('swap').call<void>({
      'from': from,
      'to': to,
      'amount': amount,
      'idempotencyKey': idempotencyKey,
    });
    return _entry(idempotencyKey);
  }

  @override
  Future<void> addTestFunds(String currency, int amount) =>
      _functions.httpsCallable('testDeposit').call<void>({
        'currency': currency,
        'amount': amount,
        'idempotencyKey': newIdempotencyKey(),
      });
}

/// The server's message for a failed request, which is written for users.
String friendlyError(Object error) {
  if (error is FirebaseFunctionsException) {
    return switch (error.code) {
      'unavailable' || 'internal' || 'deadline-exceeded' =>
        error.code == 'unavailable' && error.message != null
            ? error.message!
            : 'Could not reach Swapvia. Try again.',
      _ => error.message ?? 'Something went wrong. Try again.',
    };
  }
  return 'Something went wrong. Try again.';
}
