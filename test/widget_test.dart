import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swapvia/core/theme/app_theme.dart';
import 'package:swapvia/features/crypto_wallet/data/models/crypto_asset_model.dart';
import 'package:swapvia/features/crypto_wallet/data/wallet_repository.dart';
import 'package:swapvia/features/crypto_wallet/presentation/screens/crypto_wallet_screen.dart';

class FakeWalletRepository implements WalletRepository {
  final balances = StreamController<Map<String, int>>.broadcast();
  final prices = StreamController<Map<String, int>>.broadcast();
  Object? ensureError;
  int testFundCalls = 0;

  @override
  Stream<Map<String, int>> watchBalances() => balances.stream;

  @override
  Stream<Map<String, int>> watchPrices() => prices.stream;

  @override
  Future<void> ensureWallet() async {
    if (ensureError != null) throw ensureError!;
  }

  @override
  Future<void> refreshPrices() async {}

  @override
  Future<void> addTestFunds({
    required String symbol,
    required int units,
  }) async {
    testFundCalls++;
  }
}

void main() {
  group('CryptoAssetModel', () {
    test('formats balances and values', () {
      const asset = CryptoAssetModel(
        name: 'Ethereum',
        symbol: 'ETH',
        balanceUnits: 145020000,
        priceUsdCents: 334450,
      );
      expect(asset.formattedBalance, '1.4502');
      expect(asset.valueUsdCents, 485019);
    });

    test('formats whole and very small balances', () {
      CryptoAssetModel withUnits(int units) => CryptoAssetModel(
        name: 'Test',
        symbol: 'TST',
        balanceUnits: units,
        priceUsdCents: 100,
      );
      expect(withUnits(250000000000).formattedBalance, '2500');
      expect(withUnits(1).formattedBalance, '0.00000001');
      expect(withUnits(0).formattedBalance, '0');
    });

    test('keeps value exact for large balances', () {
      const asset = CryptoAssetModel(
        name: 'Test',
        symbol: 'TST',
        balanceUnits: 2100000000000000,
        priceUsdCents: 10000000,
      );
      expect(asset.valueUsdCents, 210000000000000);
    });

    test('has no value until a price arrives', () {
      final assets = buildAssets({'ETH': 100000000}, {});
      expect(assets.first.valueUsdCents, isNull);
      expect(assets.map((a) => a.symbol), ['ETH', 'USDC', 'SOL']);
    });

    test('formats US cents', () {
      expect(formatUsdCents(927056), r'$9,270.56');
      expect(formatUsdCents(5), r'$0.05');
      expect(formatUsdCents(100000000), r'$1,000,000.00');
    });
  });

  Future<FakeWalletRepository> pumpWallet(
    WidgetTester tester, {
    ThemeData? theme,
    FakeWalletRepository? repository,
  }) async {
    final repo = repository ?? FakeWalletRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: CryptoWalletScreen(repository: repo, showTestFunds: true),
      ),
    );
    await tester.pump();
    return repo;
  }

  testWidgets('updates live when balances and prices change', (tester) async {
    final repo = await pumpWallet(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.balances.add({'USDC': 10000000000});
    await tester.pump();
    await tester.pump();
    expect(find.text('100'), findsOneWidget);
    expect(find.text('Price unavailable'), findsNWidgets(3));

    repo.prices.add({'USDC': 100, 'ETH': 334450, 'SOL': 10242});
    await tester.pump();
    await tester.pump();
    expect(find.text(r'$100.00'), findsNWidgets(2));

    repo.balances.add({'USDC': 20000000000});
    await tester.pump();
    await tester.pump();
    expect(find.text('200'), findsOneWidget);
    expect(find.text(r'$200.00'), findsNWidgets(2));
  });

  testWidgets('test funds button calls the repository', (tester) async {
    final repo = await pumpWallet(tester);
    repo.balances.add({});
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Add 100 test USDC'));
    await tester.tap(find.text('Add 100 test USDC'));
    await tester.pump();
    expect(repo.testFundCalls, 1);
  });

  testWidgets('shows a retry when the wallet cannot be set up', (tester) async {
    final repo = FakeWalletRepository()..ensureError = Exception('offline');
    await pumpWallet(tester, repository: repo);
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);

    repo.ensureError = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Try again'), findsNothing);
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('wallet fits a small phone in $name theme', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = await pumpWallet(tester, theme: theme);
      repo.balances.add({'ETH': 145020000});
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
