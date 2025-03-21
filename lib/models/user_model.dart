import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String username;
  final String? phoneNumber;
  final String? address;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isEmailVerified;
  final Map<String, dynamic> metadata;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.username,
    this.phoneNumber,
    this.address,
    this.profileImageUrl,
    required this.createdAt,
    required this.lastLoginAt,
    required this.isEmailVerified,
    required this.metadata,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      username: map['username'] as String,
      phoneNumber: map['phoneNumber'] as String?,
      address: map['address'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp).toDate(),
      isEmailVerified: map['isEmailVerified'] as bool,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'username': username,
      'phoneNumber': phoneNumber,
      'address': address,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isEmailVerified': isEmailVerified,
      'metadata': metadata,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? username,
    String? phoneNumber,
    String? address,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isEmailVerified,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      metadata: metadata ?? this.metadata,
    );
  }
} 