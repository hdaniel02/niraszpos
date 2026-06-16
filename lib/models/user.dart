// lib/models/user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  String uid;
  String email;
  String role;
  String? passcode;
  String? name;
  String? phoneNumber;
  DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.passcode,
    this.name,
    this.phoneNumber,
    this.createdAt,
  });

  // Convert Firebase snapshot to AppUser
  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? '',
      passcode: data['passcode'],
      name: data['name'],
      phoneNumber: data['phoneNumber'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      if (passcode != null) 'passcode': passcode,
      if (name != null) 'name': name,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }
}