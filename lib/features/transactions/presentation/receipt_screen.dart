import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/brand/swapvia_logo.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/money_repository.dart';

String formatDateTime(DateTime? time) {
  if (time == null) return 'Processing';
  String two(int n) => n.toString().padLeft(2, '0');
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = time.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}, '
      '${two(local.hour)}:${two(local.minute)}';
}

class ReceiptScreen extends StatelessWidget {
  final LedgerEntry entry;

  const ReceiptScreen({super.key, required this.entry});

  List<(String, String)> get _rows => [
    ('Status', entry.status == 'completed' ? 'Successful' : entry.status),
    ('Date', formatDateTime(entry.createdAt)),
    if (entry.type == 'transfer')
      (entry.isCredit ? 'From' : 'To', '@${entry.counterparty}'),
    if (entry.type == 'swap') ...[
      ('You swapped', formatAmount(entry.amountIn!, entry.from!)),
      ('You received', formatAmount(entry.amountOut!, entry.to!)),
    ],
    ('Fee', formatAmount(entry.fee, entry.currency)),
    if (entry.balanceAfter != null)
      ('Balance after', formatAmount(entry.balanceAfter!, entry.currency)),
    if (entry.note?.isNotEmpty ?? false) ('Note', entry.note!),
    ('Reference', entry.reference),
  ];

  Future<void> _copy(BuildContext context) async {
    final text = [
      'Swapvia receipt (test mode, no real money)',
      '${entry.title}: ${entry.signedAmount}',
      for (final (label, value) in _rows) '$label: $value',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Receipt copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        const SwapviaLogo(size: 48),
                        const SizedBox(height: AppSpacing.lg),
                        Text(entry.title, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          entry.signedAmount,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        for (final (label, value) in _rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  flex: 2,
                                  child: SelectableText(
                                    value,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Test mode: no real money moved',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy receipt'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
