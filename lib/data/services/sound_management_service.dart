import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/custom_sound.dart';

class SoundManagementService {
  /// Prompts user to pick an audio file and copies it to internal storage.
  static Future<CustomSound?> pickAndImportAudio() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'aac'],
      );

      if (files.isEmpty) {
        return null; // user cancelled
      }

      final pickedFile = files.first;
      final originalPath = pickedFile.path;
      if (originalPath == null) return null;

      final sourceFile = File(originalPath);
      if (!await sourceFile.exists()) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final soundsDir = Directory('${appDir.path}/custom_sounds');
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      final fileExt = pickedFile.extension ?? 'mp3';
      final soundId = 'custom_${const Uuid().v4()}';
      final cleanName = pickedFile.name;
      final targetFilePath = '${soundsDir.path}/$soundId.$fileExt';

      // Copy to persistent internal directory
      final copiedFile = await sourceFile.copy(targetFilePath);
      final fileSize = await copiedFile.length();

      return CustomSound(
        id: soundId,
        name: cleanName,
        filePath: targetFilePath,
        fileSizeBytes: fileSize,
        importedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Deletes imported custom sound file from device storage
  static Future<void> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
