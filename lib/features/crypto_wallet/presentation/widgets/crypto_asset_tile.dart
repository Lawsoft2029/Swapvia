import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../data/models/crypto_asset_model.dart';

class CryptoAssetTile extends StatelessWidget {
  final CryptoAssetModel asset;

  const CryptoAssetTile({super.key, required this.asset});

  IconData get _icon => switch (asset.symbol) {
    'USDC' => Icons.monetization_on,
    _ => Icons.token,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final strong = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.secondary.withValues(alpha: 0.18),
              child: Icon(_icon, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.name, style: strong),
                  const SizedBox(height: AppSpacing.xs),
                  Text(asset.symbol, style: muted),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    asset.formattedBalance,
                    textAlign: TextAlign.end,
                    style: strong?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    switch (asset.valueUsdCents) {
                      final cents? => formatUsdCents(cents),
                      null => 'Price unavailable',
                    },
                    textAlign: TextAlign.end,
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
