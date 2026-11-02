import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/brand/swapvia_logo.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/crypto_asset_model.dart';
import '../../data/wallet_repository.dart';
import '../widgets/crypto_asset_tile.dart';

class CryptoWalletScreen extends StatefulWidget {
  final WalletRepository repository;
  final VoidCallback? onSignOut;

  /// Shows the test funds button, which only works on the emulator.
  final bool showTestFunds;

  const CryptoWalletScreen({
    super.key,
    required this.repository,
    this.onSignOut,
    this.showTestFunds = false,
  });

  @override
  State<CryptoWalletScreen> createState() => _CryptoWalletScreenState();
}

class _CryptoWalletScreenState extends State<CryptoWalletScreen> {
  static const _testDepositUnits = 100 * CryptoAssetModel.unitsPerCoin;

  late final Stream<Map<String, int>> _balances;
  late final Stream<Map<String, int>> _prices;
  Timer? _priceTimer;
  Object? _setupError;
  bool _addingFunds = false;

  @override
  void initState() {
    super.initState();
    _balances = widget.repository.watchBalances();
    _prices = widget.repository.watchPrices();
    _setUp();
    _priceTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshPrices(),
    );
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }

  Future<void> _setUp() async {
    setState(() => _setupError = null);
    try {
      await widget.repository.ensureWallet();
    } catch (error) {
      if (mounted) setState(() => _setupError = error);
      return;
    }
    await _refreshPrices();
  }

  /// A failed refresh is not fatal: the last published prices stay on screen.
  Future<void> _refreshPrices() async {
    try {
      await widget.repository.refreshPrices();
    } catch (_) {}
  }

  Future<void> _addTestFunds() async {
    setState(() => _addingFunds = true);
    try {
      await widget.repository.addTestFunds(
        symbol: 'USDC',
        units: _testDepositUnits,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add test funds. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingFunds = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            SwapviaLogo(size: 32),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('Crypto wallet', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: widget.onSignOut,
            ),
        ],
      ),
      body: SafeArea(
        child: _setupError != null
            ? _ErrorView(onRetry: _setUp)
            : StreamBuilder<Map<String, int>>(
                stream: _balances,
                builder: (context, balances) {
                  if (balances.hasError) return _ErrorView(onRetry: _setUp);
                  if (!balances.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return StreamBuilder<Map<String, int>>(
                    stream: _prices,
                    builder: (context, prices) => _content(
                      context,
                      buildAssets(balances.data!, prices.data ?? const {}),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _content(BuildContext context, List<CryptoAssetModel> assets) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final totalCents = assets.fold<int>(
      0,
      (sum, asset) => sum + (asset.valueUsdCents ?? 0),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Total value',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          formatUsdCents(totalCents),
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Test mode: no real money',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Assets',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final asset in assets) ...[
          CryptoAssetTile(asset: asset),
          const SizedBox(height: AppSpacing.md),
        ],
        if (widget.showTestFunds) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _addingFunds ? null : _addTestFunds,
            child: const Text('Add 100 test USDC'),
          ),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We could not load your wallet.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
