import 'package:flutter/material.dart';

import '../../../core/brand/swapvia_logo.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_spacing.dart';
import '../../crypto_wallet/data/wallet_repository.dart';
import '../../crypto_wallet/presentation/screens/crypto_wallet_screen.dart';
import '../../transactions/data/money_repository.dart';
import '../../transactions/presentation/money_action_screens.dart';
import '../../transactions/presentation/receipt_screen.dart';

const _destinations = [
  (Icons.home_outlined, Icons.home, 'Home'),
  (Icons.currency_bitcoin_outlined, Icons.currency_bitcoin, 'Crypto'),
  (Icons.receipt_long_outlined, Icons.receipt_long, 'Ledger'),
  (Icons.bar_chart_outlined, Icons.bar_chart, 'Analysis'),
];

/// Bottom navigation on phones and a side rail on wide screens and web.
class AppShell extends StatefulWidget {
  final String username;
  final WalletRepository wallet;
  final MoneyRepository money;
  final VoidCallback onSignOut;
  final bool showTestFunds;

  const AppShell({
    super.key,
    required this.username,
    required this.wallet,
    required this.money,
    required this.onSignOut,
    this.showTestFunds = false,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final _ledger = widget.money.watchLedger().asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        _HomeTab(widget: widget, ledger: _ledger),
        CryptoWalletScreen(
          repository: widget.wallet,
          onSignOut: widget.onSignOut,
        ),
        _LedgerTab(ledger: _ledger),
        _AnalysisTab(ledger: _ledger),
      ],
    );
    void select(int index) => setState(() => _index = index);

    if (MediaQuery.sizeOf(context).width >= 800) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: SwapviaLogo(size: 40),
              ),
              destinations: [
                for (final (icon, selected, label) in _destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: [
          for (final (icon, selected, label) in _destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final AppShell widget;
  final Stream<List<LedgerEntry>> ledger;

  const _HomeTab({required this.widget, required this.ledger});

  void _open(BuildContext context, Widget screen) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => screen),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, @${widget.username}', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: _Page(
          children: [
            Card(
              color: colors.primary,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: StreamBuilder<Map<String, int>>(
                  stream: widget.wallet.watchBalances(),
                  builder: (context, snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Naira balance',
                        style: TextStyle(color: colors.onPrimary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        snapshot.hasData
                            ? formatAmount(snapshot.data!['NGN'] ?? 0, 'NGN')
                            : '...',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Test mode: no real money',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _QuickAction(
                  Icons.north_east,
                  'Send',
                  () => _open(context, SendScreen(repository: widget.money)),
                ),
                _QuickAction(
                  Icons.south_west,
                  'Receive',
                  () => _open(context, ReceiveScreen(username: widget.username)),
                ),
                _QuickAction(
                  Icons.swap_horiz,
                  'Swap',
                  () => _open(context, SwapScreen(repository: widget.money)),
                ),
              ],
            ),
            if (widget.showTestFunds) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => widget.money.addTestFunds('NGN', 5000000),
                child: const Text('Add ₦50,000 test money'),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text('Pay bills', style: _heading(theme)),
            const SizedBox(height: AppSpacing.md),
            const Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _ComingSoon(Icons.phone_android, 'Airtime'),
                _ComingSoon(Icons.wifi, 'Data'),
                _ComingSoon(Icons.bolt, 'Electricity'),
                _ComingSoon(Icons.sports_soccer, 'Betting'),
                _ComingSoon(Icons.tv, 'Cable TV'),
                _ComingSoon(Icons.router, 'Internet'),
                _ComingSoon(Icons.water_drop, 'Water'),
                _ComingSoon(Icons.school, 'Education'),
                _ComingSoon(Icons.card_giftcard, 'Gift cards'),
                _ComingSoon(Icons.flight, 'Travel'),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Recent activity', style: _heading(theme)),
            const SizedBox(height: AppSpacing.sm),
            _EntryList(ledger: ledger, limit: 5, shrink: true),
          ],
        ),
      ),
    );
  }
}

TextStyle? _heading(ThemeData theme) =>
    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

class _Page extends StatelessWidget {
  final List<Widget> children;

  const _Page({required this.children});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: children,
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: colors.secondary.withValues(alpha: 0.18),
                child: Icon(icon, color: colors.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ComingSoon(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label is coming soon')),
      ),
    );
  }
}

class _LedgerTab extends StatelessWidget {
  final Stream<List<LedgerEntry>> ledger;

  const _LedgerTab({required this.ledger});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ledger')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _EntryList(ledger: ledger),
          ),
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  final Stream<List<LedgerEntry>> ledger;
  final int? limit;
  final bool shrink;

  const _EntryList({required this.ledger, this.limit, this.shrink = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<List<LedgerEntry>>(
      stream: ledger,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('Could not load transactions.'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final all = snapshot.data!;
        final entries = limit == null ? all : all.take(limit!).toList();
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: Text('No transactions yet')),
          );
        }
        return ListView.builder(
          shrinkWrap: shrink,
          physics: shrink ? const NeverScrollableScrollPhysics() : null,
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              leading: Icon(
                entry.isCredit ? Icons.south_west : Icons.north_east,
                color: colors.primary,
              ),
              title: Text(entry.title, overflow: TextOverflow.ellipsis),
              subtitle: Text(formatDateTime(entry.createdAt)),
              trailing: Text(
                entry.signedAmount,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ReceiptScreen(entry: entry)),
              ),
            );
          },
        );
      },
    );
  }
}

/// Money in and out by currency for one month.
Map<String, ({int moneyIn, int moneyOut})> monthlyTotals(
  List<LedgerEntry> entries,
  DateTime month,
) {
  final totals = <String, ({int moneyIn, int moneyOut})>{};
  for (final entry in entries) {
    final time = entry.createdAt?.toLocal();
    if (time == null || time.year != month.year || time.month != month.month) {
      continue;
    }
    final now = totals[entry.currency] ?? (moneyIn: 0, moneyOut: 0);
    totals[entry.currency] = entry.isCredit
        ? (moneyIn: now.moneyIn + entry.amount, moneyOut: now.moneyOut)
        : (moneyIn: now.moneyIn, moneyOut: now.moneyOut + entry.amount);
  }
  return totals;
}

class _AnalysisTab extends StatelessWidget {
  final Stream<List<LedgerEntry>> ledger;

  const _AnalysisTab({required this.ledger});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: SafeArea(
        child: StreamBuilder<List<LedgerEntry>>(
          stream: ledger,
          builder: (context, snapshot) {
            final totals = monthlyTotals(snapshot.data ?? [], DateTime.now());
            return _Page(
              children: [
                Text('This month', style: _heading(theme)),
                const SizedBox(height: AppSpacing.md),
                if (totals.isEmpty) const Text('No activity this month'),
                for (final MapEntry(key: symbol, value: total)
                    in totals.entries) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(symbol, style: _heading(theme)),
                          const SizedBox(height: AppSpacing.md),
                          _FlowBar('In', total.moneyIn, total, symbol),
                          const SizedBox(height: AppSpacing.md),
                          _FlowBar('Out', total.moneyOut, total, symbol),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FlowBar extends StatelessWidget {
  final String label;
  final int amount;
  final ({int moneyIn, int moneyOut}) total;
  final String symbol;

  const _FlowBar(this.label, this.amount, this.total, this.symbol);

  @override
  Widget build(BuildContext context) {
    final largest = total.moneyIn > total.moneyOut
        ? total.moneyIn
        : total.moneyOut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${formatAmount(amount, symbol)}'),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(
          value: largest == 0 ? 0 : amount / largest,
          minHeight: 8,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ],
    );
  }
}
