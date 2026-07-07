import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/shimmer.dart';
import '../../home/widgets/post_card.dart';
import '../../../core/routes/app_routes.dart';

class CommunitySearchScreen extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunitySearchScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.field,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: c.primary),
          ),
        ),
        title: Text(
          'Search in ${widget.communityName}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: c.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search input field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search title, body, or tags...',
                hintStyle: TextStyle(color: c.textDim, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: c.primary, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        child: Icon(Icons.clear_rounded, color: c.textDim, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: c.field,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: c.textPrimary, fontSize: 14),
            ),
          ),

          // Search results
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('communityId', isEqualTo: widget.communityId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const PostCardShimmer(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final allPosts = docs.map((d) => Post.fromFirestore(d, currentUid)).toList();
                final query = _searchController.text.trim().toLowerCase();

                final filteredPosts = allPosts.where((p) {
                  if (query.isEmpty) return true;
                  final matchTitle = p.title.toLowerCase().contains(query);
                  final matchBody = p.body.toLowerCase().contains(query);
                  final matchTags = p.tags.any((t) => t.toLowerCase().contains(query));
                  return matchTitle || matchBody || matchTags;
                }).toList();

                if (filteredPosts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded, size: 36, color: c.textDim),
                        const SizedBox(height: 10),
                        Text(
                          query.isEmpty
                              ? 'Start typing to search community posts'
                              : 'No posts matching "$query"',
                          style: TextStyle(color: c.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredPosts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final post = filteredPosts[index];
                    final String heroTag = 'community_search_post_${post.id}';
                    return PostCard(
                      post: post,
                      heroTag: heroTag,
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.postDetail,
                        arguments: {
                          'post': post,
                          'heroTag': heroTag,
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
