import 'package:meta/meta.dart';

/// Именованный профиль параметров KDF. Храните идентификатор профиля рядом с
/// обёрткой ключа, чтобы при смене параметров старые данные можно было
/// расшифровать тем же профилем.
@immutable
class KdfProfile {
  const KdfProfile({
    required this.id,
    required this.algorithm,
    required this.iterations,
    this.memoryKiB,
    this.parallelism,
    this.hashAlgorithm,
  });

  /// Уникальный идентификатор профиля в вашей БД (например, `argon2id-v1-2026`).
  final String id;

  /// `argon2id` или `pbkdf2-hmac-sha256`.
  final String algorithm;

  /// Итерации (для Argon2 — time cost).
  final int iterations;

  /// Память в KiB (только Argon2).
  final int? memoryKiB;

  /// Параллелизм (lanes, только Argon2).
  final int? parallelism;

  /// Для PBKDF2: имя хэша, например `sha256`.
  final String? hashAlgorithm;
}
