import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'security_journal_service.dart';
import 'trap_photo_storage.dart';

/// Камера-ловушка: после серии неудачных попыток PIN/биометрии — тихий кадр с фронтальной камеры.
///
/// Съёмка только пока открыт экран ввода (активный [context]); фоновая съёмка ОС запрещает.
class CameraTrapService extends ChangeNotifier {
  int _consecutiveFailures = 0;

  int get consecutiveFailures => _consecutiveFailures;

  /// Сброс счётчика после успешной аутентификации.
  void resetFailures() {
    if (_consecutiveFailures == 0) return;
    _consecutiveFailures = 0;
    notifyListeners();
  }

  /// Неудачная попытка PIN или биометрии.
  Future<void> registerFailure(BuildContext context) async {
    _consecutiveFailures++;
    notifyListeners();
    if (_consecutiveFailures < 3) return;
    _consecutiveFailures = 0;
    notifyListeners();
    await _captureOnce(context);
  }

  Future<void> _captureOnce(BuildContext context) async {
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      await SecurityJournalService.instance.log(
        event: 'camera_trap_skipped',
        details: {'reason': 'camera_denied'},
      );
      return;
    }

    CameraController? controller;
    try {
      final cams = await availableCameras();
      CameraDescription? front;
      for (final c in cams) {
        if (c.lensDirection == CameraLensDirection.front) {
          front = c;
          break;
        }
      }
      front ??= cams.isNotEmpty ? cams.first : null;
      if (front == null) {
        await SecurityJournalService.instance.log(
          event: 'camera_trap_skipped',
          details: {'reason': 'no_camera'},
        );
        return;
      }

      controller = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      if (!context.mounted) return;

      // Короткий кадр на активном экране (без UI затвора).
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final file = await controller.takePicture();
      final bytes = await File(file.path).readAsBytes();

      await TrapPhotoStorage.instance.saveCapture(
        jpegBytes: bytes,
        timestampUtc: DateTime.now().toUtc(),
        latitude: null,
        longitude: null,
      );

      await SecurityJournalService.instance.log(
        event: 'camera_trap_capture',
        details: {
          'bytes': bytes.length,
          'has_gps': false,
        },
      );

      try {
        await File(file.path).delete();
      } on Object catch (_) {}
    } on Object catch (e, st) {
      debugPrint('CameraTrapService: $e\n$st');
      await SecurityJournalService.instance.log(
        event: 'camera_trap_failed',
        details: {'error': e.toString()},
      );
    } finally {
      await controller?.dispose();
    }
  }
}
