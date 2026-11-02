import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// The app talks to the local emulators unless built with
/// `--dart-define=USE_EMULATORS=false`, which needs deployed Cloud Functions.
const useEmulators = bool.fromEnvironment('USE_EMULATORS', defaultValue: true);

Future<void> setUpFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!useEmulators) return;

  // The Android emulator reaches the host computer through 10.0.2.2.
  final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
}
