import 'dart:math';

/// A currency Swapvia holds, with the decimal places of its smallest unit.
class Currency {
  final String symbol;
  final String name;
  final int decimals;

  const Currency(this.symbol, this.name, this.decimals);
}

const currencies = [
  Currency('NGN', 'Nigerian Naira', 2),
  Currency('ETH', 'Ethereum', 8),
  Currency('USDC', 'USD Coin', 8),
  Currency('SOL', 'Solana', 8),
];

int decimalsOf(String symbol) =>
    currencies.firstWhere((c) => c.symbol == symbol).decimals;

/// Turns typed text into smallest units without floating point. Returns null
/// for invalid text, zero, or more decimal places than the currency has.
int? parseAmount(String text, String symbol) {
  final clean = text.trim().replaceAll(',', '');
  final match = RegExp(r'^(\d*)(?:\.(\d*))?$').firstMatch(clean);
  if (match == null || clean.isEmpty || clean == '.') return null;
  final decimals = decimalsOf(symbol);
  final fraction = match.group(2) ?? '';
  if (fraction.length > decimals) return null;
  final units = BigInt.parse(
    '${match.group(1)}${fraction.padRight(decimals, '0')}',
  );
  if (units == BigInt.zero || units.bitLength > 53) return null;
  return units.toInt();
}

String _withCommas(String digits) => digits.replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+$)'),
  (_) => ',',
);

/// Formats smallest units as text, such as `₦1,234.50` or `1.4502 ETH`.
String formatAmount(int units, String symbol) {
  final decimals = decimalsOf(symbol);
  final scale = pow(10, decimals).toInt();
  final whole = _withCommas((units ~/ scale).toString());
  final fraction = (units % scale).toString().padLeft(decimals, '0');
  if (symbol == 'NGN') return '₦$whole.$fraction';
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.isEmpty ? '$whole $symbol' : '$whole.$trimmed $symbol';
}

/// A key for one money request, kept across retries so it cannot run twice.
String newIdempotencyKey() {
  final random = Random.secure();
  return List.generate(24, (_) => random.nextInt(16).toRadixString(16)).join();
}
