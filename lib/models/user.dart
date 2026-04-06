// lib/models/user.dart
class AppUser {
  String uid;
  String email;
  String role;

  AppUser({required this.uid, required this.email, required this.role});

  // Convert Firebase snapshot to AppUser
  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      role: data['role'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
    };
  }
}