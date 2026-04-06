import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/user.dart';

class AuthViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all users
  Stream<List<AppUser>> getUsers() {
    return _firestore.collection('users').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Create user in Firebase Auth + Firestore
  Future<void> createUser(AppUser user, String password) async {
    FirebaseApp? secondaryApp;

    try {
      // Create secondary Firebase app so admin stays logged in
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      // Step 1: create auth account
      UserCredential userCredential =
          await secondaryAuth.createUserWithEmailAndPassword(
        email: user.email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Step 2: save user data in Firestore using UID as doc id
      await _firestore.collection('users').doc(uid).set({
        'email': user.email,
        'role': user.role,
      });

      // Step 3: sign out from secondary auth
      await secondaryAuth.signOut();
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  // Update user in Firestore
  Future<void> updateUser(AppUser user) async {
    await _firestore.collection('users').doc(user.uid).update({
      'email': user.email,
      'role': user.role,
    });
  }

  // Delete user from Firestore only
  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }
}