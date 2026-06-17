import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedMedia;
  bool _isVideo = false;
  bool _isUploading = false;

  // Premium linear gradient options for text-only style variations
  int _selectedGradientIndex = 0;
  final List<List<Color>> _gradients = [
    [Colors.indigo.shade900, Colors.purple.shade900],
    [Colors.deepOrange.shade800, Colors.pink.shade900],
    [Colors.teal.shade900, Colors.green.shade900],
    [Colors.grey.shade900, Colors.black],
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  /// Media Pipeline: Slices dynamic files from the device gallery core memory
  Future<void> _pickMedia(ImageSource source, bool pickVideo) async {
    try {
      final XFile? file = pickVideo 
          ? await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 15))
          : await _picker.pickImage(source: source, imageQuality: 85);

      if (file != null) {
        setState(() {
          _selectedMedia = File(file.path);
          _isVideo = pickVideo;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error grabbing media: $e')),
      );
    }
  }

  /// Cloud Publish Engine: Uploads files to Storage and registers document metadata
  Future<void> _publishStory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);
    String? downloadUrl;

    try {
      // 1. Upload file if media was explicitly selected
      if (_selectedMedia != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('stories')
            .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.${_isVideo ? 'mp4' : 'jpg'}');

        final uploadTask = await storageRef.putFile(_selectedMedia!);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

      // 2. Prepare standardized payload map data sheet
      final storyPayload = {
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Anonymous',
        'authorAvatar': user.photoURL ?? '',
        'mediaUrl': downloadUrl,
        'isVideo': _isVideo,
        'caption': _captionController.text.trim(),
        'gradientColors': downloadUrl == null 
            ? _gradients[_selectedGradientIndex].map((c) => c.value).toList()
            : null,
        'viewedBy': [], // Array tracking metric entries
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))), // Automates expiration
      };

      // 3. Atomically register document inside global stories stream collection
      await FirebaseFirestore.instance.collection('stories').add(storyPayload);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story posted successfully! 🔥')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish story: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. DYNAMIC BACKGROUND VISUAL LAYER
          Positioned.fill(
            child: _selectedMedia != null
                ? (_isVideo 
                    ? Container(
                        color: Colors.grey.shade900, 
                        child: const Center(
                          child: Icon(Icons.video_library_rounded, size: 48, color: Colors.white54)
                        )
                      )
                    : Image.file(_selectedMedia!, fit: BoxFit.cover))
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _gradients[_selectedGradientIndex],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
          ),

          // 2. INTERACTIVE CONTROLS OVERLAY
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Custom Floating Header Control Rows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const CircleAvatar(
                            backgroundColor: Colors.black38, 
                            child: Icon(Icons.close_rounded, color: Colors.white)
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        if (_isUploading)
                          const CircularProgressIndicator(color: Colors.white)
                        else
                          ElevatedButton(
                            onPressed: _publishStory,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    
                    // FIXED: Replaced loose Spacers with an explicit Center + Expanded layout block 
                    // to resolve the hit-test size assertion error from image_ea4810.jpg
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: TextField(
                            controller: _captionController,
                            maxLines: null,
                            textAlign: TextAlign.center,
                            maxLength: 120,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Type something...',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 24),
                              border: InputBorder.none,
                              counterText: "",
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. BOTTOM UTILITY ACTIONS HUD TOOLBAR
                    if (_selectedMedia == null) ...[
                      // Color Changer Row (only displays for text layout stories)
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
                          itemCount: _gradients.length,
                          itemBuilder: (context, idx) => GestureDetector(
                            onTap: () => setState(() => _selectedGradientIndex = idx),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedGradientIndex == idx ? Colors.white : Colors.transparent, 
                                  width: 2
                                ),
                                gradient: LinearGradient(colors: _gradients[idx]),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black45, 
                        borderRadius: BorderRadius.circular(30)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image_outlined, color: Colors.white),
                            onPressed: () => _pickMedia(ImageSource.gallery, false),
                            tooltip: 'Photo Library',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
                            onPressed: () => _pickMedia(ImageSource.gallery, true),
                            tooltip: 'Video Clip',
                          ),
                          if (_selectedMedia != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () => setState(() {
                                _selectedMedia = null;
                                _isVideo = false;
                              }),
                              tooltip: 'Remove Selection',
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}