import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/audio_service.dart';
import '../../../providers/sound_provider.dart';

class SoundSelectionResult {
  final String soundId;
  final String soundName;
  final String? soundFilePath;

  const SoundSelectionResult({
    required this.soundId,
    required this.soundName,
    this.soundFilePath,
  });
}

class SoundPickerSheet extends StatefulWidget {
  final String currentSoundId;
  final String? currentSoundFilePath;

  const SoundPickerSheet({
    super.key,
    required this.currentSoundId,
    this.currentSoundFilePath,
  });

  static Future<SoundSelectionResult?> show(
    BuildContext context, {
    required String currentSoundId,
    String? currentSoundFilePath,
  }) {
    return showModalBottomSheet<SoundSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SoundPickerSheet(
        currentSoundId: currentSoundId,
        currentSoundFilePath: currentSoundFilePath,
      ),
    );
  }

  @override
  State<SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<SoundPickerSheet> {
  late String _selectedSoundId;
  late String? _selectedFilePath;
  final AudioService _previewPlayer = AudioService();
  String? _currentlyPreviewingId;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _selectedSoundId = widget.currentSoundId;
    _selectedFilePath = widget.currentSoundFilePath;
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  void _togglePreview(String soundId, {String? filePath}) {
    if (_currentlyPreviewingId == soundId) {
      _previewPlayer.stop();
      setState(() {
        _currentlyPreviewingId = null;
      });
    } else {
      setState(() {
        _currentlyPreviewingId = soundId;
      });
      _previewPlayer.previewTone(soundId, 0.9, customFilePath: filePath);
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    final soundProvider = Provider.of<SoundProvider>(context, listen: false);
    final imported = await soundProvider.pickAndImportSound();
    setState(() => _isImporting = false);

    if (imported != null && mounted) {
      setState(() {
        _selectedSoundId = imported.id;
        _selectedFilePath = imported.filePath;
      });
      _togglePreview(imported.id, filePath: imported.filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final soundProvider = Provider.of<SoundProvider>(context);
    final customSounds = soundProvider.customSounds;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF16171D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Alarm Ringtone',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Import Device Audio Button
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _handleImport,
            icon: _isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_upload_outlined, color: Colors.white),
            label: Text(
              _isImporting
                  ? 'Importing Audio...'
                  : 'Import Custom Audio (MP3 / WAV)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // List of Sounds
          Expanded(
            child: ListView(
              children: [
                // Custom Imported Section
                if (customSounds.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'CUSTOM IMPORTED SOUNDS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...customSounds.map((sound) {
                    final isSelected = _selectedSoundId == sound.id;
                    final isPlaying = _currentlyPreviewingId == sound.id;

                    return Card(
                      color: isSelected
                          ? AppColors.accent.withOpacity(0.12)
                          : const Color(0xFF1E2028),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          Icons.audio_file_rounded,
                          color: isSelected
                              ? AppColors.accent
                              : const Color(0xFF8E929E),
                        ),
                        title: Text(
                          sound.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFFE2E4E9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          sound.formattedSize,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8E929E)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.stop_circle_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: isPlaying
                                    ? AppColors.error
                                    : AppColors.accent,
                                size: 28,
                              ),
                              onPressed: () => _togglePreview(
                                sound.id,
                                filePath: sound.filePath,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Color(0xFF8E929E)),
                              onPressed: () {
                                soundProvider.deleteCustomSound(sound.id);
                                if (_selectedSoundId == sound.id) {
                                  setState(() {
                                    _selectedSoundId = 'rooster_dawn';
                                    _selectedFilePath = null;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedSoundId = sound.id;
                            _selectedFilePath = sound.filePath;
                          });
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // Built-in Tones Section
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'BUILT-IN RINGTONES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8E929E),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...AudioService.availableTones.map((tone) {
                  final id = tone['id']!;
                  final name = tone['name']!;
                  final isSelected = _selectedSoundId == id;
                  final isPlaying = _currentlyPreviewingId == id;

                  return Card(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.12)
                        : const Color(0xFF1E2028),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.music_note_rounded,
                        color: isSelected
                            ? AppColors.primaryLight
                            : const Color(0xFF8E929E),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFFE2E4E9),
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.stop_circle_rounded
                              : Icons.play_circle_fill_rounded,
                          color: isPlaying
                              ? AppColors.error
                              : AppColors.primaryLight,
                          size: 28,
                        ),
                        onPressed: () => _togglePreview(id),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedSoundId = id;
                          _selectedFilePath = null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Confirm Button
          ElevatedButton(
            onPressed: () {
              _previewPlayer.stop();
              final name = soundProvider.getSoundDisplayName(_selectedSoundId);
              Navigator.of(context).pop(
                SoundSelectionResult(
                  soundId: _selectedSoundId,
                  soundName: name,
                  soundFilePath: _selectedFilePath,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Select Sound',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

