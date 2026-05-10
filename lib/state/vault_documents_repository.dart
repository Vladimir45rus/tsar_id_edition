import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Модель документа в сейфе (паспорт, ИНН, СНИЛС и т.д.)
class VaultDocument {
  final String id;
  final String title;
  final String category;
  final String fileName;
  final DateTime createdAt;

  VaultDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.fileName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'fileName': fileName,
        'createdAt': createdAt.toIso8601String(),
      };

  static VaultDocument fromJson(Map<String, dynamic> json) {
    return VaultDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      fileName: json['fileName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Репозиторий для хранения документов (фото) в Сейфе
class VaultDocumentsRepository extends ChangeNotifier {
  static const _prefsKey = 'vault_documents_meta_v1';
  static const _folderName = 'vault_docs';

  final List<VaultDocument> _documents = [];
  bool _initialized = false;

  List<VaultDocument> get documents => List.unmodifiable(_documents);
  bool get isInitialized => _initialized;

  /// Инициализация: загрузка списка документов из метаданных
  Future<void> init() async {
    if (_initialized) return;
    await _loadMetadata();
    _initialized = true;
    notifyListeners();
  }

  /// Загрузка метаданных из SharedPreferences
  Future<void> _loadMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      
      if (raw == null || raw == '[]') {
        _documents.clear();
        return;
      }

      final list = jsonDecode(raw) as List<dynamic>;
      _documents
        ..clear()
        ..addAll(list.map((e) => VaultDocument.fromJson(e as Map<String, dynamic>)))
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка загрузки метаданных документов: $e');
    }
  }

  /// Сохранение метаданных в SharedPreferences
  Future<void> _saveMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_documents.map((d) => d.toJson()).toList());
      await prefs.setString(_prefsKey, raw);
    } catch (e) {
      debugPrint('Ошибка сохранения метаданных: $e');
    }
  }

  /// Получение пути к папке для хранения файлов
  Future<String> _getDocsFolder() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = path.join(dir.path, _folderName);
    final dirObj = Directory(folder);
    if (!await dirObj.exists()) {
      await dirObj.create(recursive: true);
    }
    return folder;
  }

  /// Сохранение документа (файл + метаданные)
  Future<bool> saveDocument({
    required File file,
    required String title,
    required String category,
  }) async {
    try {
      // Генерируем уникальное имя файла
      final fileId = DateTime.now().millisecondsSinceEpoch.toString();
      final ext = path.extension(file.path);
      final newFileName = '$fileId$ext';
      
      // Копируем файл в защищённую папку
      final folder = await _getDocsFolder();
      final newPath = path.join(folder, newFileName);
      await file.copy(newPath);

      // Создаём запись метаданных
      final doc = VaultDocument(
        id: fileId,
        title: title.trim(),
        category: category,
        fileName: newFileName,
        createdAt: DateTime.now(),
      );

      // Добавляем в список и сохраняем
      _documents.insert(0, doc);
      await _saveMetadata();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Ошибка сохранения документа: $e');
      return false;
    }
  }

  /// Удаление документа (файл + метаданные)
  Future<bool> deleteDocument(String id) async {
    try {
      // Находим документ
      final index = _documents.indexWhere((d) => d.id == id);
      if (index == -1) return false;
      
      final doc = _documents[index];

      // Удаляем файл
      final folder = await _getDocsFolder();
      final filePath = path.join(folder, doc.fileName);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Удаляем из списка
      _documents.removeAt(index);
      await _saveMetadata();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Ошибка удаления документа: $e');
      return false;
    }
  }

  /// Получение пути к файлу документа
  Future<String?> getDocumentFilePath(String fileName) async {
    try {
      final folder = await _getDocsFolder();
      final filePath = path.join(folder, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка получения пути к файлу: $e');
      return null;
    }
  }
}