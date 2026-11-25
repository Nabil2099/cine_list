import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/storage/preferences_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final preferencesService = await PreferencesService.init();
  await configureDependencies(preferencesService: preferencesService);

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (_) => const CineListApp(),
    ),
  );
}
