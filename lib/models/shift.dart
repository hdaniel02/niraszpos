import 'package:cloud_firestore/cloud_firestore.dart';

class Shift {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final DateTime startTime;
  final DateTime? endTime;
  final double startingCash;
  final double? endingCash;
  final double? endingCard;
  final double? endingQR;
  final String status; // 'active', 'completed'

  Shift({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.startTime,
    this.endTime,
    required this.startingCash,
    this.endingCash,
    this.endingCard,
    this.endingQR,
    required this.status,
  });

  factory Shift.fromMap(Map<String, dynamic> data, String documentId) {
    return Shift(
      id: documentId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userRole: data['userRole'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
      startingCash: (data['startingCash'] ?? 0.0).toDouble(),
      endingCash: data['endingCash'] != null ? (data['endingCash'] as num).toDouble() : null,
      endingCard: data['endingCard'] != null ? (data['endingCard'] as num).toDouble() : null,
      endingQR: data['endingQR'] != null ? (data['endingQR'] as num).toDouble() : null,
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'startingCash': startingCash,
      'endingCash': endingCash,
      'endingCard': endingCard,
      'endingQR': endingQR,
      'status': status,
    };
  }
}
