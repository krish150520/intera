import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/post_model.dart';
import '../../home/widgets/post_card.dart';
import '../../home/screens/post_detail_screen.dart';

class HelpRequestScreen extends StatelessWidget {
  const HelpRequestScreen({super.key});

  static const Color _bg = Color(0xFFF5F3FF);
  static const Color _primary = Color(0xFF7C3AED);
  static const Color _textHi = Color(0xFF2D1B69);

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Help Requests', 
            style: TextStyle(color: _textHi, fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('type', isEqualTo: 'helpRequest') // Ensure this matches your DB field name
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _primary));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('No active help requests.', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final postItem = Post.fromFirestore(docs[index], currentUid);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: postItem,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PostDetailScreen(post: postItem)),
                  ),
                  onLike: () {}, // Add your engine calls here
                  onSave: () {}, 
                  onComment: () {},
                ),
              );
            },
          );
        },
      ),
    );
  }
}