import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shift.dart';

class ShiftViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream to get all active shifts (for checking if current user has one)
  Stream<List<Shift>> getActiveShifts(String userId) {
    return _firestore
        .collection('shifts')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Shift.fromMap(doc.data(), doc.id)).toList());
  }

  // Stream all shifts for Admin/Owner tracking
  Stream<List<Shift>> getAllShifts() {
    return _firestore
        .collection('shifts')
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Shift.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> startShift(double startingCash, String userName, String userRole) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Check if an active shift already exists
    final activeShifts = await _firestore
        .collection('shifts')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .get();
        
    if (activeShifts.docs.isNotEmpty) {
      throw Exception('You already have an active shift.');
    }

    final newShift = Shift(
      id: '',
      userId: user.uid,
      userName: userName,
      userRole: userRole,
      startTime: DateTime.now(),
      startingCash: startingCash,
      status: 'active',
    );

    await _firestore.collection('shifts').add(newShift.toMap());
  }

  Future<void> endShift(String shiftId, double endingCash, double endingCard, double endingQR) async {
    await _firestore.collection('shifts').doc(shiftId).update({
      'endTime': Timestamp.fromDate(DateTime.now()),
      'endingCash': endingCash,
      'endingCard': endingCard,
      'endingQR': endingQR,
      'status': 'completed',
    });
  }
}
