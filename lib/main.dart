import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'core/firebase/firebase_setup.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/presentation/screens/account_gate.dart';
import 'features/authentication/presentation/screens/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUpFirebase();
  runApp(const SwapviaApp());
}

class SwapviaApp extends StatelessWidget {
  const SwapviaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swapvia',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          if (user == null) return const SignInScreen();
          return AccountGate(key: ValueKey(user.uid), uid: user.uid);
        },
      ),
    );
  }
}
