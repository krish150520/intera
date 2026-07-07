import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../shared/widgets/custom_avatar.dart';
import 'user_profile_screen.dart';

class ConnectionsListScreen extends StatelessWidget {
  final String userId;
  final bool isFollowersMode;
  final String profileOwnerName;

  const ConnectionsListScreen({
    super.key,
    required this.userId,
    required this.isFollowersMode,
    required this.profileOwnerName,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Define the subcollection path based on your FollowService structure
    final CollectionReference collectionRef = isFollowersMode
        ? FirebaseFirestore.instance.collection('users').doc(userId).collection('followers')
        : FirebaseFirestore.instance.collection('users').doc(userId).collection('following');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isFollowersMode ? "$profileOwnerName's Followers" : "Following",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: collectionRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final connectionDocs = snapshot.data?.docs ?? [];

          if (connectionDocs.isEmpty) {
            return Center(
              child: Text(
                isFollowersMode ? 'No followers listed yet.' : 'Not following any profiles yet.',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            );
          }

          return ListView.separated(
            itemCount: connectionDocs.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              // The Document ID in your subcollection IS the target user's UID.
              final String targetUid = connectionDocs[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(targetUid).get(),
                builder: (context, userSnapshot) {
                  // Handle loading and empty states for the specific profile
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(leading: CircularProgressIndicator(strokeWidth: 2));
                  }
                  
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox.shrink(); // Hide if profile doesn't exist
                  }

                  final data = userSnapshot.data!.data() as Map<String, dynamic>;
                  final String name = data['name'] ?? 'User';
                  final String username = data['username'] ?? 'user';
                  final String avatar = data['avatarUrl'] ?? '';

                  return ListTile(
                    leading: CustomAvatar(name: name, imageUrl: avatar, userId: targetUid, radius: 18),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      username.startsWith('@') ? username : '@$username',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            userId: targetUid,
                            userName: name,
                            userAvatar: avatar,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}