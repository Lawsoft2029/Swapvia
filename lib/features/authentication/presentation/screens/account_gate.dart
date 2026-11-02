import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/firebase/firebase_setup.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../crypto_wallet/data/wallet_repository.dart';
import '../../../home/presentation/app_shell.dart';
import '../../../transactions/data/money_repository.dart';

/// Makes sure a signed-in user has a wallet and a username, then opens the app.
class AccountGate extends StatefulWidget {
  final String uid;

  const AccountGate({super.key, required this.uid});

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late final _wallet = FirebaseWalletRepository(uid: widget.uid);
  late final _money = FirebaseMoneyRepository(uid: widget.uid);
  late final _username = _money.watchUsername();
  late Future<void> _ready = _wallet.ensureWallet();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, ready) {
        if (ready.hasError) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => _ready = _wallet.ensureWallet()),
                child: const Text('Could not connect. Try again'),
              ),
            ),
          );
        }
        if (ready.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return StreamBuilder<String?>(
          stream: _username,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final username = snapshot.data;
            if (username == null) return _ChooseUsername(money: _money);
            return AppShell(
              username: username,
              wallet: _wallet,
              money: _money,
              showTestFunds: useEmulators,
              onSignOut: FirebaseAuth.instance.signOut,
            );
          },
        );
      },
    );
  }
}

class _ChooseUsername extends StatefulWidget {
  final MoneyRepository money;

  const _ChooseUsername({required this.money});

  @override
  State<_ChooseUsername> createState() => _ChooseUsernameState();
}

class _ChooseUsernameState extends State<_ChooseUsername> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.money.claimUsername(_controller.text);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your username')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              const Text(
                'People send you money with this. It cannot be changed later.',
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
