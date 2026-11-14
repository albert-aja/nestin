import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Secret input mode for diary locks.
enum DiaryLockType {
  pin,
  password,
}

/// Configured per-entry custom lock credentials stored on a [JournalEntry].
class CustomEntryLockConfig {
  final DiaryLockType type;
  final String hash;
  final String salt;
  final String? hint;

  const CustomEntryLockConfig({
    required this.type,
    required this.hash,
    required this.salt,
    this.hint,
  });
}

/// Pure-Dart validation, salted SHA-256 hashing, and verification helpers for
/// global 4-8 digit diary PINs and per-entry custom PIN/password locks.
class DiaryLockHelper {
  DiaryLockHelper._();

  static const int minPinLength = 4;
  static const int maxPinLength = 8;
  static const int minPasswordLength = 4;

  static final RegExp _pinRegex = RegExp(r'^\d{4,8}$');
  static final Random _secureRandom = _createRandom();

  static Random _createRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Validates a numeric PIN containing between 4 and 8 digits.
  static bool isValidPin(String input) => _pinRegex.hasMatch(input);

  /// Validates a custom diary password (at least 4 chars, not whitespace-only).
  static bool isValidPassword(String input) =>
      input.length >= minPasswordLength && input.trim().isNotEmpty;

  /// Validates [secret] according to [type].
  static bool isValidSecret(DiaryLockType type, String secret) {
    return switch (type) {
      DiaryLockType.pin => isValidPin(secret),
      DiaryLockType.password => isValidPassword(secret),
    };
  }

  /// Normalizes an optional password/PIN clue, returning `null` if blank.
  static String? normalizeHint(String? rawHint) {
    final trimmed = rawHint?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Generates a 16-byte hex salt for hashing per-entry secrets.
  static String generateSalt() {
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      buffer.write(_secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Computes a salted SHA-256 digest of [secret] combined with [salt].
  static String hashSecret(String secret, String salt) {
    return sha256Hex('$salt:$secret');
  }

  /// Creates a ready-to-persist [CustomEntryLockConfig] for a diary entry.
  static CustomEntryLockConfig createCustomLock({
    required DiaryLockType type,
    required String secret,
    String? hint,
  }) {
    final salt = generateSalt();
    return CustomEntryLockConfig(
      type: type,
      hash: hashSecret(secret, salt),
      salt: salt,
      hint: normalizeHint(hint),
    );
  }

  /// Verifies [attempt] against [expectedHash] using [salt] in constant time.
  static bool verifySecret({
    required String attempt,
    required String salt,
    required String expectedHash,
  }) {
    final candidate = hashSecret(attempt, salt);
    return _constantTimeEquals(candidate, expectedHash);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Standard FIPS 180-4 / RFC 6234 pure-Dart SHA-256 hex digest.
  static String sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final bitLength = bytes.length * 8;
    // Pad with 0x80, zeros to 56 mod 64 bytes, plus 8-byte big-endian length.
    final paddedLength = ((bytes.length + 9 + 63) ~/ 64) * 64;
    final padded = Uint8List(paddedLength);
    padded.setRange(0, bytes.length, bytes);
    padded[bytes.length] = 0x80;

    final dataView = ByteData.sublistView(padded);
    final highBits = bitLength ~/ 0x100000000;
    final lowBits = bitLength & 0xFFFFFFFF;
    dataView.setUint32(paddedLength - 8, highBits, Endian.big);
    dataView.setUint32(paddedLength - 4, lowBits, Endian.big);

    final h = Uint32List.fromList([
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ]);

    const k = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    final w = Uint32List(64);
    for (int offset = 0; offset < paddedLength; offset += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = dataView.getUint32(offset + i * 4, Endian.big);
      }
      for (int i = 16; i < 64; i++) {
        final s0 = _rotr32(w[i - 15], 7) ^ _rotr32(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final s1 = _rotr32(w[i - 2], 17) ^ _rotr32(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h[0];
      int b = h[1];
      int c = h[2];
      int d = h[3];
      int e = h[4];
      int f = h[5];
      int g = h[6];
      int hh = h[7];

      for (int i = 0; i < 64; i++) {
        final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
        final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
        final temp1 = (hh + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        hh = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h[0] = (h[0] + a) & 0xFFFFFFFF;
      h[1] = (h[1] + b) & 0xFFFFFFFF;
      h[2] = (h[2] + c) & 0xFFFFFFFF;
      h[3] = (h[3] + d) & 0xFFFFFFFF;
      h[4] = (h[4] + e) & 0xFFFFFFFF;
      h[5] = (h[5] + f) & 0xFFFFFFFF;
      h[6] = (h[6] + g) & 0xFFFFFFFF;
      h[7] = (h[7] + hh) & 0xFFFFFFFF;
    }

    final result = StringBuffer();
    for (final word in h) {
      result.write(word.toRadixString(16).padLeft(8, '0'));
    }
    return result.toString();
  }

  static int _rotr32(int value, int bits) {
    return ((value >> bits) | (value << (32 - bits))) & 0xFFFFFFFF;
  }
}
