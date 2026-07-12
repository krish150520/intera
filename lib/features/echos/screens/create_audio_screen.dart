import 'dart:io';
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

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Audio File Card ──────────────────────────────────────────────
            Text(
              'Audio File',
              style: TextStyle(color: c.textHi, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectedAudioFile == null ? _pickAudio : null,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border.withValues(alpha: 0.3)),
                ),
                child: _selectedAudioFile != null
                    ? Row(
                        children: [
                          Icon(Icons.audiotrack_rounded, color: c.primary, size: 36),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedAudioName ?? 'audio_file',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: c.textHi, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ready to use',
                                  style: TextStyle(color: c.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: c.primary,
                              size: 32,
                            ),
                            onPressed: _togglePreview,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
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
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 40, color: c.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            'Select Audio File (.mp3/.wav/.m4a)',
                            style: TextStyle(color: c.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Symmetrical Cover Picker ─────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soundtrack Name',
                        style: TextStyle(color: c.textHi, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.border.withValues(alpha: 0.3)),
                        ),
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
                      const SizedBox(height: 12),
                      Text(
                        'If empty, defaults to your video caption or profile name.',
                        style: TextStyle(color: c.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audio Cover Art',
                        style: TextStyle(color: c.textHi, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickCover,
                        child: Container(
                          height: 110,
                          decoration: BoxDecoration(
                            color: c.field,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: c.border.withValues(alpha: 0.5), width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedCoverFile != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.file(_selectedCoverFile!, fit: BoxFit.cover),
                                    Container(
                                      color: Colors.black26,
                                      child: const Center(
                                        child: Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 28, color: c.textMuted),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Add Cover',
                                      style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // ── Save Button ──────────────────────────────────────────────────
            GestureDetector(
              onTap: _save,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _selectedAudioFile == null ? c.field : const Color(0xFF8870EE),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedAudioFile == null
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFF8870EE).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
          ],
        ),
      ),
    );
  }
}
