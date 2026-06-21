import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PasscodeRequestsWidget extends StatelessWidget {
  final String role;

  const PasscodeRequestsWidget({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final r = role.toLowerCase();
    // Only Managers, Owners, and Admins should see this
    if (r != 'manager' && r != 'owner' && r != 'admin' && r != 'superadmin') {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('passcode_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final allRequests = snapshot.data!.docs;

        // Filter based on role
        List<QueryDocumentSnapshot> visibleRequests = [];
        if (r == 'manager' || r == 'owner') {
          visibleRequests = allRequests.where((doc) {
            final status = doc['status'];
            return status == 'pending_manager' || status == 'completed';
          }).toList();
        } else if (r == 'admin' || r == 'superadmin') {
          visibleRequests = allRequests.where((doc) {
            return doc['status'] == 'pending_admin';
          }).toList();
        }

        if (visibleRequests.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    "Action Required",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      visibleRequests.length.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...visibleRequests.map((doc) => _buildRequestCard(context, doc)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String;
    final email = data['cashierEmail'] as String;
    
    IconData icon;
    Color iconColor;
    Color bgColor;
    String title;
    String subtitle;
    Widget actionButton;

    if (status == 'pending_manager') {
      icon = Icons.key_off_rounded;
      iconColor = const Color(0xFFD97706);
      bgColor = const Color(0xFFFFFBEB);
      title = "Passcode Reset Requested";
      subtitle = "Cashier $email forgot their passcode.";
      actionButton = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _rejectRequest(context, doc.id),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _forwardToAdmin(context, doc.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Forward", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      );
    } else if (status == 'pending_admin') {
      icon = Icons.admin_panel_settings_rounded;
      iconColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFFEF2F2);
      title = "Reset Passcode for Cashier";
      subtitle = "Manager forwarded a reset request for $email.";
      actionButton = ElevatedButton(
        onPressed: () => _resetPasscode(context, doc.id, data['cashierUid']),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Generate New Passcode", style: TextStyle(fontWeight: FontWeight.w600)),
      );
    } else if (status == 'completed') {
      icon = Icons.check_circle_rounded;
      iconColor = const Color(0xFF059669);
      bgColor = const Color(0xFFECFDF5);
      title = "Passcode Reset Successful";
      subtitle = "Admin generated new passcode for $email.";
      actionButton = ElevatedButton(
        onPressed: () => _viewAndDismiss(context, doc.id, data['newPasscode']),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("View & Dismiss", style: TextStyle(fontWeight: FontWeight.w600)),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          actionButton,
        ],
      ),
    );
  }

  Future<void> _forwardToAdmin(BuildContext context, String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('passcode_requests').doc(requestId).update({
        'status': 'pending_admin',
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request forwarded to Admin.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _rejectRequest(BuildContext context, String requestId) async {
    try {
      await FirebaseFirestore.instance.collection('passcode_requests').doc(requestId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request rejected and deleted.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _resetPasscode(BuildContext context, String requestId, String cashierUid) async {
    final TextEditingController newPasscodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.password_rounded, size: 48, color: Color(0xFF059669)),
                const SizedBox(height: 24),
                const Text("Set New Passcode", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text("Enter a new 6-digit passcode for this cashier. This will be sent back to the manager.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 24),
                TextField(
                  controller: newPasscodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: "6-digit passcode",
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final newPasscode = newPasscodeController.text.trim();
                          if (newPasscode.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode must be 6 digits")));
                            return;
                          }

                          try {
                            // Update the user's passcode in Firestore
                            await FirebaseFirestore.instance.collection('users').doc(cashierUid).update({
                              'passcode': newPasscode,
                            });

                            // Update request status
                            await FirebaseFirestore.instance.collection('passcode_requests').doc(requestId).update({
                              'status': 'completed',
                              'newPasscode': newPasscode,
                            });

                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode updated and sent back to Manager")));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
                        child: const Text("Confirm"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _viewAndDismiss(BuildContext context, String requestId, String newPasscode) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF059669)),
                const SizedBox(height: 24),
                const Text("Passcode Ready", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text("The Admin has successfully generated a new passcode. Please manually communicate this to the cashier:", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    newPasscode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 36, letterSpacing: 8, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance.collection('passcode_requests').doc(requestId).delete();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Dismiss Notification", style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
