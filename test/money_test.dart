import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swapvia/core/money/money.dart';
import 'package:swapvia/core/theme/app_theme.dart';
import 'package:swapvia/features/home/presentation/app_shell.dart';
import 'package:swapvia/features/transactions/data/money_repository.dart';
import 'package:swapvia/features/transactions/presentation/receipt_screen.dart';

void main() {
  test('parseAmount uses exact smallest units', () {
    expect(parseAmount('1,234.50', 'NGN'), 123450);
    expect(parseAmount('0.1', 'ETH'), 10000000);
    expect(parseAmount('0.00000001', 'ETH'), 1);
    expect(parseAmount('1.234', 'NGN'), isNull);
    expect(parseAmount('0', 'NGN'), isNull);
    expect(parseAmount('abc', 'NGN'), isNull);
    expect(parseAmount('-5', 'NGN'), isNull);
    expect(parseAmount('', 'NGN'), isNull);
  });

  test('formatAmount shows currency style', () {
    expect(formatAmount(123450, 'NGN'), '₦1,234.50');
    expect(formatAmount(145020000, 'ETH'), '1.4502 ETH');
    expect(formatAmount(250000000000, 'USDC'), '2,500 USDC');
  });

  test('monthlyTotals separates in and out for that month only', () {
    LedgerEntry entry(int amount, bool credit, DateTime time) => LedgerEntry(
      type: 'transfer',
      currency: 'NGN',
      amount: amount,
      isCredit: credit,
      status: 'completed',
      reference: 'R',
      createdAt: time,
    );
    final totals = monthlyTotals([
      entry(100, true, DateTime(2026, 11, 2)),
      entry(40, false, DateTime(2026, 11, 3)),
      entry(999, true, DateTime(2026, 10, 3)),
    ], DateTime(2026, 11, 15));
    expect(totals['NGN'], (moneyIn: 100, moneyOut: 40));
  });

  testWidgets('receipt shows transfer details on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ReceiptScreen(
          entry: LedgerEntry(
            type: 'transfer',
            currency: 'NGN',
            amount: 500000,
            isCredit: false,
            status: 'completed',
            reference: 'SVABC123',
            counterparty: 'ada',
            balanceAfter: 100,
            note: 'Lunch',
            createdAt: DateTime(2026, 11, 2, 9, 5),
          ),
        ),
      ),
    );

    expect(find.text('Sent to @ada'), findsOneWidget);
    expect(find.text('-₦5,000.00'), findsOneWidget);
    expect(find.text('SVABC123'), findsOneWidget);
    expect(find.text('Successful'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
