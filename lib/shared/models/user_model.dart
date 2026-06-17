import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an INTERA user.
class UserModel {
  final String id;
  final String name;
  final String username;
  final String? bio;
  final String? avatarUrl;
  final int karmaPoints;
  final int followersCount;
  final int followingCount;
  final List<String> skills;
  final bool isAnonymous;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.bio,
    this.avatarUrl,
    this.karmaPoints = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.skills = const [],
    this.isAnonymous = false,
  });

  /// Decodes standard JSON maps (e.g. from local storage, shared preferences, or REST calls)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      karmaPoints: json['karmaPoints'] as int? ?? 0,
      followersCount: json['followersCount'] as int? ?? 0,
      followingCount: json['followingCount'] as int? ?? 0,
      skills: (json['skills'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      isAnonymous: json['isAnonymous'] as bool? ?? false,
    );
  }

  /// Factory constructor to safely map live Cloud Firestore Document Snapshots
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return UserModel(
      id: doc.id, // Uses the actual Firestore Document ID string directly
      name: data['name'] as String? ?? 'New User',
      username: data['username'] as String? ?? '@user',
      bio: data['bio'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      karmaPoints: data['karmaPoints'] as int? ?? 0,
      followersCount: data['followersCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      skills: (data['skills'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isAnonymous: data['isAnonymous'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'bio': bio,
        'avatarUrl': avatarUrl,
        'karmaPoints': karmaPoints,
        'followersCount': followersCount,
        'followingCount': followingCount,
        'skills': skills,
        'isAnonymous': isAnonymous,
      };

  /// A placeholder user, useful for previews before backend integration.
  static const UserModel placeholder = UserModel(
    id: 'u_001',
    name: 'Krish Sharma',
    username: '@krish.dev',
    bio: 'Flutter & RF tinkerer. Building INTERA 🚀',
    karmaPoints: 1240,
    followersCount: 312,
    followingCount: 98,
    skills: ['Flutter', 'Python', 'React'],
  );
}