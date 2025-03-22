import 'package:cloud_firestore/cloud_firestore.dart';

class Blogger {
  final String id;
  final String name;
  final String username;
  final String? bio;
  final String? profileImageUrl;
  final String? coverImageUrl;
  final List<String> followers;
  final List<String> following;
  final List<String> specialties;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> metadata;

  const Blogger({
    required this.id,
    required this.name,
    required this.username,
    this.bio,
    this.profileImageUrl,
    this.coverImageUrl,
    required this.followers,
    required this.following,
    required this.specialties,
    required this.stats,
    required this.metadata,
  });

  factory Blogger.fromMap(Map<String, dynamic> map) {
    return Blogger(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      bio: map['bio'],
      profileImageUrl: map['profileImageUrl'],
      coverImageUrl: map['coverImageUrl'],
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      specialties: List<String>.from(map['specialties'] ?? []),
      stats: Map<String, dynamic>.from(map['stats'] ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'bio': bio,
      'profileImageUrl': profileImageUrl,
      'coverImageUrl': coverImageUrl,
      'followers': followers,
      'following': following,
      'specialties': specialties,
      'stats': stats,
      'metadata': metadata,
    };
  }

  bool isFollowedBy(String userId) {
    return followers.contains(userId);
  }
} 