import 'package:cloud_firestore/cloud_firestore.dart';

class BlogPost {
  final String id;
  final String userId;
  final String userName;
  final String userImage;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> likes;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  const BlogPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.likes,
    required this.tags,
    required this.metadata,
  });

  factory BlogPost.fromMap(Map<String, dynamic> map) {
    return BlogPost(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userImage: map['userImage'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
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
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'tags': tags,
      'metadata': metadata,
    };
  }
} 