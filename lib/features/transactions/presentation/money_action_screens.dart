import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/money_repository.dart';
import 'receipt_screen.dart';

Widget _form(List<Widget> children) => SafeArea(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: children,
      ),
    ),
  ),
);

Widget _currencyField(
  String label,
  String value,
  ValueChanged<String> onChanged,
) => DropdownButtonFormField<String>(
  initialValue: value,
  isExpanded: true,
  decoration: InputDecoration(labelText: label),
  items: [
    for (final c in currencies)
      DropdownMenuItem(value: c.symbol, child: Text('${c.name} (${c.symbol})')),
  ],
  onChanged: (next) => onChanged(next!),
);

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  return answer ?? false;
}

class SendScreen extends StatefulWidget {
  final MoneyRepository repository;

  const SendScreen({super.key, required this.repository});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _username = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  // Kept until the send succeeds, so retrying a lost response is safe.
  String _key = newIdempotencyKey();
  String _currency = 'NGN';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim().replaceFirst('@', '').toLowerCase();
    final amount = parseAmount(_amount.text, _currency);
    if (username.isEmpty || amount == null) {
      setState(() => _error = 'Enter a username and a valid amount.');
      return;
    }
    final ok = await _confirm(
      context,
      'Confirm transfer',
      'Send ${formatAmount(amount, _currency)} to @$username?',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entry = await widget.repository.send(
        toUsername: username,
        currency: _currency,
        amount: amount,
        note: _note.text.trim(),
        idempotencyKey: _key,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(entry: entry)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // A changed request is a new transfer, so it needs a new key.
  void _changed([String? _]) => _key = newIdempotencyKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send money')),
      body: _form([
        TextField(
          controller: _username,
          onChanged: _changed,
          decoration: const InputDecoration(
            labelText: 'Swapvia username',
            prefixText: '@',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _currencyField('Currency', _currency, (next) {
          _changed();
          setState(() => _currency = next);
        }),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _amount,
          onChanged: _changed,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _note,
          onChanged: _changed,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Continue'),
        ),
      ]),
    );
  }
}

class SwapScreen extends StatefulWidget {
  final MoneyRepository repository;

  const SwapScreen({super.key, required this.repository});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _amount = TextEditingController();
  String _key = newIdempotencyKey();
  String _from = 'USDC';
  String _to = 'NGN';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = parseAmount(_amount.text, _from);
    if (amount == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_from == _to) {
      setState(() => _error = 'Choose two different currencies.');
      return;
    }
    final ok = await _confirm(
      context,
      'Confirm swap',
      'Swap ${formatAmount(amount, _from)} to $_to at the live market rate? '
          'The receipt shows the exact amount received.',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entry = await widget.repository.swap(
        from: _from,
        to: _to,
        amount: amount,
        idempotencyKey: _key,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(entry: entry)),
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Swap')),
      body: _form([
        _currencyField('From', _from, (next) {
          _key = newIdempotencyKey();
          setState(() => _from = next);
        }),
        const SizedBox(height: AppSpacing.md),
        _currencyField('To', _to, (next) {
          _key = newIdempotencyKey();
          setState(() => _to = next);
        }),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _amount,
          onChanged: (_) => _key = newIdempotencyKey(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        if (_error != null) _ErrorText(_error!),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Continue'),
        ),
      ]),
    );
  }
}

class ReceiveScreen extends StatelessWidget {
  final String username;

  const ReceiveScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Receive money')),
      body: _form([
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const Text('Your Swapvia username'),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  '@$username',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Anyone on Swapvia can send you money with this username.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Builder(
          builder: (context) => FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy username'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '@$username'));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username copied')),
                );
              }
            },
          ),
        ),
      ]),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;

  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(message, style: TextStyle(color: colors.error)),
    );
  }
}
