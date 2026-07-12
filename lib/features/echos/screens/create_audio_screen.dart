import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';

class AudioCreationResult {
  final File audioFile;
  final File? coverFile;
  final String? title;

  AudioCreationResult({
    required this.audioFile,
    this.coverFile,
    this.title,
  });
}

class CreateAudioScreen extends StatefulWidget {
  const CreateAudioScreen({super.key});

  @override
  State<CreateAudioScreen> createState() => _CreateAudioScreenState();
}

class _CreateAudioScreenState extends State<CreateAudioScreen> {
  File? _selectedAudioFile;
  String? _selectedAudioName;
  File? _selectedCoverFile;
  final _titleController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  VideoPlayerController? _previewPlayer;
  bool _isPlaying = false;

  @override
  void dispose() {
    _titleController.dispose();
    _previewPlayer?.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        setState(() {
          _selectedAudioFile = File(path);
          _selectedAudioName = result.files.single.name;
        });

        // Set up preview player
        await _previewPlayer?.dispose();
        _previewPlayer = VideoPlayerController.file(_selectedAudioFile!);
        await _previewPlayer!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking audio: $e')),
      );
    }
  }

  Future<void> _pickCover() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (file != null) {
        setState(() {
          _selectedCoverFile = File(file.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking cover: $e')),
      );
    }
  }

  Future<void> _togglePreview() async {
    if (_previewPlayer == null) return;
    if (_previewPlayer!.value.isPlaying) {
      await _previewPlayer!.pause();
      setState(() => _isPlaying = false);
    } else {
      await _previewPlayer!.play();
      setState(() => _isPlaying = true);
    }
  }

  void _save() {
    if (_selectedAudioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file first.')),
      );
      return;
    }

    final result = AudioCreationResult(
      audioFile: _selectedAudioFile!,
      coverFile: _selectedCoverFile,
      title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
    );
    Navigator.of(context).pop(result);
  }

  // ── Glass helper ─────────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child, EdgeInsets? padding, double radius = 20}) {
    final c = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: c.border.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Grouped empty-state block (icon + label + subtext) ───────────────────────
  Widget _emptyStateBlock({
    required IconData icon,
    required String label,
    required String subtitle,
    required AppColorsExtension c,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.primary.withValues(alpha: 0.15),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: c.primary),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textHi, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: _buildAppBar(c),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Audio File Card ──────────────────────────────────────────────
            _sectionLabel('Audio File', c),
            const SizedBox(height: 8),
            _glassCard(
              radius: 20,
              child: GestureDetector(
                onTap: _selectedAudioFile == null ? _pickAudio : null,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: _selectedAudioFile != null
                      ? Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: c.primary.withValues(alpha: 0.22),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(Icons.audiotrack_rounded, color: c.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedAudioName ?? 'audio_file',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: c.textHi, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 12, color: c.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ready to use',
                                        style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                color: c.primary,
                                size: 30,
                              ),
                              onPressed: _togglePreview,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              onPressed: () async {
                                await _previewPlayer?.pause();
                                setState(() {
                                  _selectedAudioFile = null;
                                  _selectedAudioName = null;
                                  _isPlaying = false;
                                });
                              },
                            ),
                          ],
                        )
                      : _emptyStateBlock(
                          icon: Icons.cloud_upload_outlined,
                          label: 'Select Audio File',
                          subtitle: '.mp3, .wav, .m4a supported',
                          c: c,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Soundtrack Name + Cover Art ──────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Soundtrack Name', c),
                      const SizedBox(height: 8),
                      _glassCard(
                        radius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _titleController,
                          maxLines: 1,
                          style: TextStyle(color: c.textHi, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g. Summer Breeze Remix',
                            hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'If empty, defaults to your video caption or profile name.',
                        style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Cover Art', c),
                      const SizedBox(height: 8),
                      _buildCoverArtCard(c),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // ── Save Button ──────────────────────────────────────────────────
            GestureDetector(
              onTap: _save,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedAudioFile == null
                          ? c.field.withValues(alpha: 0.5)
                          : c.primary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedAudioFile == null
                            ? c.border.withValues(alpha: 0.18)
                            : c.primary.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Apply Soundtrack',
                      style: TextStyle(
                        color: _selectedAudioFile == null ? c.textMuted : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColorsExtension c) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: c.surface.withValues(alpha: 0.6),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textHi, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Customize Soundtrack',
              style: TextStyle(
                color: c.textHi,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Divider(height: 0.5, thickness: 0.5, color: c.border.withValues(alpha: 0.18)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverArtCard(AppColorsExtension c) {
    return GestureDetector(
      onTap: _pickCover,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            gradient: _selectedCoverFile == null
                ? LinearGradient(
                    colors: [
                      c.primary.withValues(alpha: 0.08),
                      c.field.withValues(alpha: 0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedCoverFile == null
                  ? c.primary.withValues(alpha: 0.25)
                  : c.border.withValues(alpha: 0.25),
              width: _selectedCoverFile == null ? 1.2 : 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _selectedCoverFile != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_selectedCoverFile!, fit: BoxFit.cover),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add_photo_alternate_outlined, size: 18, color: c.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add Cover',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textHi, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, AppColorsExtension c) {
    return Text(text, style: TextStyle(color: c.textHi, fontSize: 13, fontWeight: FontWeight.bold));
  }
}