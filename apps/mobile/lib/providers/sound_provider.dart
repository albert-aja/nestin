import 'package:flutter/material.dart';
import '../data/models/custom_sound.dart';
import '../data/services/storage_service.dart';
import '../data/services/sound_management_service.dart';
import '../data/services/audio_service.dart';

class SoundProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<CustomSound> _customSounds = [];

  SoundProvider(this._storageService) {
    _loadCustomSounds();
  }

  List<CustomSound> get customSounds => List.unmodifiable(_customSounds);

  void _loadCustomSounds() {
    _customSounds = _storageService.loadCustomSounds();
  }

  Future<void> _save() async {
    await _storageService.saveCustomSounds(_customSounds);
    notifyListeners();
  }

  /// Launches system file picker to select an MP3/WAV/M4A/OGG file
  Future<CustomSound?> pickAndImportSound() async {
    final sound = await SoundManagementService.pickAndImportAudio();
    if (sound != null) {
      _customSounds.add(sound);
      await _save();
      return sound;
    }
    return null;
  }

  /// Removes custom sound from database and cleans up disk storage
  Future<void> deleteCustomSound(String id) async {
    final index = _customSounds.indexWhere((s) => s.id == id);
    if (index != -1) {
      final sound = _customSounds[index];
      await SoundManagementService.deleteAudioFile(sound.filePath);
      _customSounds.removeAt(index);
      await _save();
    }
  }

  /// Resolves display label for any tone ID
  String getSoundDisplayName(String soundId) {
    final defaultTone = AudioService.availableTones.firstWhere(
      (t) => t['id'] == soundId,
      orElse: () => {},
    );
    if (defaultTone.isNotEmpty) {
      return defaultTone['name']!;
    }

    final customMatches = _customSounds.where((s) => s.id == soundId);
    if (customMatches.isNotEmpty) {
      return customMatches.first.name;
    }
    return 'Selected Tone';
  }

  /// Resolves file path if custom
  String? getSoundFilePath(String soundId) {
    final index = _customSounds.indexWhere((s) => s.id == soundId);
    if (index != -1) {
      return _customSounds[index].filePath;
    }
    return null;
  }
}
