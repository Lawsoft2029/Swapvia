/// One crypto balance. Amounts are integers so totals have no rounding errors:
/// [balanceUnits] has 8 decimal places and [priceUsdCents] is in US cents.
class CryptoAssetModel {
  static const unitsPerCoin = 100000000;

  final String name;
  final String symbol;
  final int balanceUnits;

  /// Null until a live price has arrived.
  final int? priceUsdCents;

  const CryptoAssetModel({
    required this.name,
    required this.symbol,
    required this.balanceUnits,
    required this.priceUsdCents,
  });

  /// Value in US cents, rounded down. Uses BigInt because the multiplication
  /// can pass the largest safe integer on web.
  int? get valueUsdCents {
    final price = priceUsdCents;
    if (price == null) return null;
    return (BigInt.from(balanceUnits) *
            BigInt.from(price) ~/
            BigInt.from(unitsPerCoin))
        .toInt();
  }

  /// The balance as text with trailing zeros removed, such as `1.4502`.
  String get formattedBalance {
    final whole = balanceUnits ~/ unitsPerCoin;
    final fraction = (balanceUnits % unitsPerCoin)
        .toString()
        .padLeft(8, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole.$fraction';
  }
}

/// The coins Swapvia supports, as (symbol, name).
const supportedCoins = [
  ('ETH', 'Ethereum'),
  ('USDC', 'USD Coin'),
  ('SOL', 'Solana'),
];

/// Combines live balances and prices into one entry per supported coin.
List<CryptoAssetModel> buildAssets(
  Map<String, int> balances,
  Map<String, int> prices,
) {
  return [
    for (final (symbol, name) in supportedCoins)
      CryptoAssetModel(
        name: name,
        symbol: symbol,
        balanceUnits: balances[symbol] ?? 0,
        priceUsdCents: prices[symbol],
      ),
  ];
}

/// Formats US cents as text, such as `$9,270.56`.
String formatUsdCents(int cents) {
  final dollars = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => ',',
  );
  return '\$$dollars.${(cents % 100).toString().padLeft(2, '0')}';
}
