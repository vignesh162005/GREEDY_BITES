import 'package:cloud_firestore/cloud_firestore.dart';

class Reel {
  final String id;
  final String userId;
  final String userName;
  final String userImage;
  final String videoUrl;
  final String? thumbnailUrl;
  final String description;
  final DateTime createdAt;
  final List<String> likes;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const Reel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.description,
    required this.createdAt,
    required this.likes,
    required this.tags,
    required this.metadata,
  });

  factory Reel.fromMap(Map<String, dynamic> map) {
    return Reel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userImage: map['userImage'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(map['likes'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'tags': tags,
      'metadata': metadata,
    };
  }
} 