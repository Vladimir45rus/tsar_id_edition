import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'bootstrap_sqlcipher_stub.dart'
    if (dart.library.io) 'bootstrap_sqlcipher_io.dart' as sqlcipher_boot;
import 'app.dart';
import 'core/media/media_intro_service.dart';
import 'core/offline/offline_status_service.dart';
import 'core/security/camera_trap_service.dart';
import 'core/security/duress_mode_service.dart';
import 'core/trusted/trusted_contacts_service.dart';
import 'state/auth_controller.dart';
import 'state/generator_controller.dart';
import 'state/security_controller.dart';
import 'state/vault_repository.dart';
import 'state/vault_documents_repository.dart'; // 👈 ДОБАВЛЕНО

/// Точка входа приложения «Царь-ID».
///
/// Здесь поднимаются все [ChangeNotifier]-сервисы и (опционально) загружается `.env`
/// для ключей SMS/облака без хардкода в репозитории.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Необязательный файл с секретами; при отсутствии — тихий пропуск.
  try {
    await dotenv.load(fileName: '.env');
  } on Object catch (_) {}

  await sqlcipher_boot.initSqlcipherIfNeeded();

  final security = SecurityController();
  await security.restoreFromStorage();

  final vault = VaultRepository();
  await vault.init();

  final vaultDocs = VaultDocumentsRepository(); // 👈 ДОБАВЛЕНО
  await vaultDocs.init(); // 👈 ДОБАВЛЕНО

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(),
        ),
        ChangeNotifierProvider<SecurityController>.value(
          value: security,
        ),
        ChangeNotifierProvider<CameraTrapService>(
          create: (_) => CameraTrapService(),
        ),
        ChangeNotifierProvider<DuressModeService>(
          create: (_) => DuressModeService(),
        ),
        ChangeNotifierProvider<VaultRepository>.value(
          value: vault,
        ),
        ChangeNotifierProvider<VaultDocumentsRepository>.value( // 👈 ДОБАВЛЕНО
          value: vaultDocs,
        ),
        ChangeNotifierProvider<TrustedContactsService>(
          create: (_) => TrustedContactsService(),
        ),
        ChangeNotifierProvider<MediaIntroService>(
          create: (_) => MediaIntroService(),
        ),
        ChangeNotifierProvider<OfflineStatusService>(
          create: (_) => OfflineStatusService(),
        ),
        ChangeNotifierProvider<GeneratorController>(
          create: (_) => GeneratorController(),
        ),
      ],
      child: const TsarIdApp(),
    ),
  );
}