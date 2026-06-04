import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/api/api_client.dart';
import 'core/theme/datetime_utils.dart';
import 'core/storage/prefs_storage.dart';
import 'core/storage/secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DateTimeUtils.initialize();
  final sharedPrefs = await SharedPreferences.getInstance();
  const securePrefs = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  runApp(
    ProviderScope(
      overrides: [
        prefsStorageProvider.overrideWithValue(PrefsStorage(sharedPrefs)),
        secureStorageProvider.overrideWithValue(SecureStorage(securePrefs)),
      ],
      child: const TelpoztApp(),
    ),
  );
}
