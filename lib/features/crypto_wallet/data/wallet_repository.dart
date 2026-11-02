import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Live wallet data. The app only reads here; every change to a balance goes
/// through a Cloud Function.
abstract class WalletRepository {
  /// Balances by symbol, in units with 8 decimal places.
  Stream<Map<String, int>> watchBalances();

  /// Prices by symbol, in US cents per coin.
  Stream<Map<String, int>> watchPrices();

  Future<void> ensureWallet();
  Future<void> refreshPrices();
  Future<void> addTestFunds({required String symbol, required int units});
}

class FirebaseWalletRepository implements WalletRepository {
  final String uid;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  FirebaseWalletRepository({
    required this.uid,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _db = db ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  @override
  Stream<Map<String, int>> watchBalances() {
    return _db.collection('wallets').doc(uid).snapshots().map((doc) {
      final balances = doc.data()?['balances'] as Map<String, dynamic>? ?? {};
      return balances.map((symbol, units) => MapEntry(symbol, units as int));
    });
  }

  @override
  Stream<Map<String, int>> watchPrices() {
    return _db.collection('rates').snapshots().map((snapshot) {
      return {
        for (final doc in snapshot.docs)
          if (doc.id.endsWith('_USD'))
            doc.id.replaceFirst('_USD', ''): doc.data()['rate'] as int,
      };
    });
  }

  @override
  Future<void> ensureWallet() =>
      _functions.httpsCallable('ensureWallet').call<void>();

  @override
  Future<void> refreshPrices() =>
      _functions.httpsCallable('refreshRates').call<void>();

  @override
  Future<void> addTestFunds({required String symbol, required int units}) {
    return _functions.httpsCallable('testDeposit').call<void>({
      'currency': symbol,
      'amount': units,
      'idempotencyKey': _newIdempotencyKey(),
    });
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }
}
