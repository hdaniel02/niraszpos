import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class ProfileViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserProfile?> getCurrentUserProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    final doc = await _firestore.collection('users').doc(currentUser.uid).get();

    if (!doc.exists) return null;

    return UserProfile.fromMap(doc.data()!, doc.id);
  }

  Future<void> updateProfile({
    required String name,
    required String phoneNumber,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("No logged in user");
    }

    await _firestore.collection('users').doc(currentUser.uid).update({
      'name': name,
      'phoneNumber': phoneNumber,
    });
  }

  Future<void> updateEmail({
    required String newEmail,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("No logged in user");
    }

    await currentUser.verifyBeforeUpdateEmail(newEmail);
    await _firestore.collection('users').doc(currentUser.uid).update({
      'email': newEmail,
    });
  }

  Future<void> changePassword({
    required String newPassword,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("No logged in user");
    }

    await currentUser.updatePassword(newPassword);
  }
}