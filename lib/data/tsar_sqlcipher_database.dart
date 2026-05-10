import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Локальная БД SQLCipher (ключ — парольная фраза, производная от PIN/мнемоники на уровне приложения).
///
/// Подключение к основному потоку данных: после ввода PIN открывайте [openEncrypted]
/// и синхронизируйте [VaultRepository]. Сейчас таблица `kv` — базовый каркас.
class TsarSqlcipherDatabase {
  TsarSqlcipherDatabase._();
  static Database? _instance;

  static Future<Database> openEncrypted(String passphrase) async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'tsar_vault_encrypted.db');
    _instance = await openDatabase(
      path,
      password: passphrase,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE kv (
            key TEXT PRIMARY KEY,
            value BLOB NOT NULL
          )
        ''');
      },
    );
    return _instance!;
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }

  /// Удалить файл БД (после перезаписи — см. [AccountWipeService]).
  static Future<void> deleteDatabaseFile() async {
    await close();
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'tsar_vault_encrypted.db');
    await databaseFactory.deleteDatabase(path);
  }
}
