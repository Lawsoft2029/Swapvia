import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/brand/swapvia_logo.dart';
import '../../../../core/theme/app_spacing.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    final email = _email.text.trim();
    try {
      if (_creatingAccount) {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _message(error.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Use a password of at least 6 characters.',
    'email-already-in-use' => 'An account with this email already exists.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Incorrect email or password.',
    'network-request-failed' => 'Could not connect. Check your connection.',
    _ => 'Something went wrong. Try again.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: SwapviaLogo(size: 72)),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      _creatingAccount ? 'Create your account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _creatingAccount ? 'Create account' : 'Sign in',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _creatingAccount = !_creatingAccount;
                              _error = null;
                            }),
                      child: Text(
                        _creatingAccount
                            ? 'I already have an account'
                            : 'Create an account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
