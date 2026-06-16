import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product.dart';
import '../../viewmodels/product_viewmodel.dart';
import '../../viewmodels/sales_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import 'widgets/passcode_requests_widget.dart';
import 'widgets/owner_dashboard_widget.dart';
import 'widgets/low_stock_alerts_widget.dart';
import '../shell/app_shell.dart';
import '../product/products_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  const DashboardScreen({super.key, required this.role});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  final ProductViewModel productVM = ProductViewModel();
  final SalesViewModel salesVM = SalesViewModel();
  final ProfileViewModel profileVM = ProfileViewModel();

  int totalProducts = 0;
  int lowStock = 0;
  double todaySales = 0;
  int todayTransactions = 0;
  String userName = "";
  DateTime? _selectedDate;
  bool isLoading = true;
  bool _hasNotification = false;
  StreamSubscription<List<Product>>? _productsSubscription;
  List<Product> _lowStockProducts = [];
  int _lastLowStockCount = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _refundSubscription;
  List<Map<String, dynamic>> _pendingRefundRequests = [];
  int _lastRefundCount = 0;
  StreamSubscription<QuerySnapshot>? _passcodeSubscription;
  List<QueryDocumentSnapshot> _pendingPasscodeRequests = [];
  int _lastPasscodeCount = 0;

  String get role => widget.role;

  String formatDisplayDate(DateTime dateTime) {
    const months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final day = dateTime.day.toString();
    final month = months[dateTime.month];
    final year = dateTime.year.toString();
    return '$day $month $year';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (pickerContext, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB), // Vibrant blue for active selections
              onPrimary: Colors.white,
              onSurface: textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: Colors.white,
              headerForegroundColor: textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              dayStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              weekdayStyle: const TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 13),
              headerHeadlineStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
              headerHelpStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
              todayForegroundColor: WidgetStateProperty.all(const Color(0xFF2563EB)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      loadDashboardData();
    }
  }

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return _buildImagePlaceholder();
    }
    
    final isBase64 = imageUrl.startsWith('data:image/') || imageUrl.contains('base64,');
    try {
      if (isBase64) {
        final base64Str = imageUrl.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          fit: BoxFit.contain,
          width: 40,
          height: 40,
        );
      } else {
        return Image.network(
          imageUrl,
          fit: BoxFit.contain,
          width: 40,
          height: 40,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        );
      }
    } catch (_) {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: textSecondary, size: 20),
    );
  }

  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasRefundRequests = _pendingRefundRequests.isNotEmpty;
            final hasLowStock = _lowStockProducts.isNotEmpty;
            final hasPasscodeRequests = _pendingPasscodeRequests.isNotEmpty;

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Notifications",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasRefundRequests && !hasLowStock && !hasPasscodeRequests) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade600, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                "All caught up!",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "No new notifications found.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (hasPasscodeRequests) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Passcode Reset Actions Required",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingPasscodeRequests.length,
                          separatorBuilder: (context, index) => const Divider(color: cardBorder, height: 1),
                          itemBuilder: (context, index) {
                            final doc = _pendingPasscodeRequests[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final status = data['status'] as String;
                            final email = data['cashierEmail'] as String;
                            final cashierUid = data['cashierUid'] as String;
                            final newPasscode = data['newPasscode'] as String?;

                            String title;
                            String subtitle;
                            if (status == 'pending_manager') {
                              title = "Passcode Reset Requested";
                              subtitle = "Cashier $email forgot passcode.";
                            } else if (status == 'pending_admin') {
                              title = "Reset Passcode for Cashier";
                              subtitle = "Manager forwarded reset request for $email.";
                            } else {
                              title = "Passcode Reset Successful";
                              subtitle = "Admin generated passcode for $email.";
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              subtitle,
                                              style: const TextStyle(fontSize: 12, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (status == 'pending_manager') ...[
                                        TextButton(
                                          onPressed: () async {
                                            try {
                                              await FirebaseFirestore.instance.collection('passcode_requests').doc(doc.id).delete();
                                              setDialogState(() {});
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                            }
                                          },
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () async {
                                            try {
                                              await FirebaseFirestore.instance.collection('passcode_requests').doc(doc.id).update({
                                                'status': 'pending_admin',
                                              });
                                              setDialogState(() {});
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFD97706),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text("Forward", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        ),
                                      ] else if (status == 'pending_admin') ...[
                                        ElevatedButton(
                                          onPressed: () async {
                                            await _showAdminResetDialog(doc.id, cashierUid, setDialogState);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFDC2626),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text("Generate Passcode", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        ),
                                      ] else if (status == 'completed') ...[
                                        ElevatedButton(
                                          onPressed: () async {
                                            await _showViewAndDismissDialog(doc.id, newPasscode ?? '', setDialogState);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF059669),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text("View & Dismiss", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (hasLowStock || hasRefundRequests) const SizedBox(height: 24),
                      ],
                      if (hasRefundRequests) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Refund Approvals Required",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingRefundRequests.length,
                          separatorBuilder: (context, index) => const Divider(color: cardBorder, height: 1),
                          itemBuilder: (context, index) {
                            final req = _pendingRefundRequests[index];
                            final reqId = req['id'] as String;
                            final receiptNo = req['receiptNo'] as String;
                            final cashierEmail = req['cashierEmail'] as String;
                            final total = (req['total'] ?? 0.0).toDouble();
                            final bankNo = req['bankAccountNumber'] as String?;
                            final custName = req['customerFullName'] as String?;
                            final custPhone = req['customerPhoneNumber'] as String?;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Receipt: $receiptNo",
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Cashier: $cashierEmail",
                                              style: const TextStyle(fontSize: 12, color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        "RM ${total.toStringAsFixed(2)}",
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.orange),
                                      ),
                                    ],
                                  ),
                                  if (custName != null || bankNo != null || custPhone != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Customer Transfer Details:",
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
                                          ),
                                          const SizedBox(height: 4),
                                          if (custName != null)
                                            Text("Name: $custName", style: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
                                          if (bankNo != null)
                                            Text("Bank Acc: $bankNo", style: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
                                          if (custPhone != null)
                                            Text("Phone: $custPhone", style: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          try {
                                            await salesVM.rejectRefundRequest(reqId);
                                            setDialogState(() {});
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                          }
                                        },
                                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            await salesVM.approveRefundRequest(reqId);
                                            setDialogState(() {});
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text("Approve", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (hasLowStock) const SizedBox(height: 24),
                      ],
                      if (hasLowStock) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            "Low Stock Warning",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _lowStockProducts.length,
                          separatorBuilder: (context, index) => const Divider(color: cardBorder, height: 1),
                          itemBuilder: (context, index) {
                            final product = _lowStockProducts[index];
                            final isOutOfStock = product.stock == 0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildProductImage(product.imageUrl),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                              subtitle: Text(
                                isOutOfStock ? "Out of Stock" : "Only ${product.stock} left",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isOutOfStock ? Colors.red.shade700 : Colors.amber.shade800,
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                ProductsScreen.initialSearchQuery = product.name;
                                AppShell.of(context)?.navigateToTab('Products');
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: const BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAdminResetDialog(String requestId, String cashierUid, StateSetter setDialogState) async {
    final TextEditingController newPasscodeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.password_rounded, size: 48, color: Color(0xFF1E3A8A)),
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
                        onPressed: () => Navigator.pop(dialogContext),
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

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            setDialogState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode updated and sent back to Manager")));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
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

  Future<void> _showViewAndDismissDialog(String requestId, String newPasscode, StateSetter setDialogState) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
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
                    style: const TextStyle(fontSize: 36, letterSpacing: 8, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
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
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        setDialogState(() {});
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
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

  @override
  void initState() {
    super.initState();
    loadDashboardData();
    _subscribeToProducts();
  }

  void _subscribeToProducts() {
    _productsSubscription = productVM.getProducts().listen((products) {
      if (!mounted) return;
      final lowStockItems = products.where((p) => p.stock <= 5).toList();
      setState(() {
        _lowStockProducts = lowStockItems;
        if (lowStockItems.length > _lastLowStockCount) {
          _hasNotification = true;
        }
        _lastLowStockCount = lowStockItems.length;
      });
    });

    _refundSubscription = salesVM.getPendingRefundRequests().listen((requests) {
      if (!mounted) return;
      setState(() {
        _pendingRefundRequests = requests;
        if (requests.length > _lastRefundCount) {
          _hasNotification = true;
        }
        _lastRefundCount = requests.length;
      });
    });

    final r = role.toLowerCase();
    _passcodeSubscription = FirebaseFirestore.instance
        .collection('passcode_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final allRequests = snapshot.docs;
      List<QueryDocumentSnapshot> visibleRequests = [];
      if (r == 'manager' || r == 'owner') {
        visibleRequests = allRequests.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          return status == 'pending_manager' || status == 'completed';
        }).toList();
      } else if (r == 'admin' || r == 'superadmin') {
        visibleRequests = allRequests.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          return status == 'pending_admin';
        }).toList();
      }
      setState(() {
        _pendingPasscodeRequests = visibleRequests;
        if (visibleRequests.length > _lastPasscodeCount) {
          _hasNotification = true;
        }
        _lastPasscodeCount = visibleRequests.length;
      });
    });
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _refundSubscription?.cancel();
    _passcodeSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadDashboardData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final products = await productVM.getProductsOnce();
      final targetDate = _selectedDate ?? DateTime.now();
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
      final sales = await salesVM.getSalesForDateRange(startOfDay, endOfDay);
      final profile = await profileVM.getCurrentUserProfile();

      if (!mounted) return;

      setState(() {
        totalProducts = products.length;
        lowStock = products.where((p) => p.stock <= 5).length;
        todayTransactions = sales.length;
        todaySales = sales.fold(0.0, (sum, sale) => sum + sale.total);
        if (profile != null) {
          userName = profile.name;
        }
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load dashboard data: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String get displayRole {
    if (role.isEmpty) return "User";
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  String get welcomeSubtitle {
    switch (role.toLowerCase()) {
      case "admin":
      case "superadmin":
        return "Manage system users and access control.";
      case "manager":
        return "Monitor store operations and manage products.";
      case "cashier":
        return "Process transactions quickly and efficiently.";
      case "owner":
        return "Track performance and oversee store activity.";
      default:
        return "Welcome to NiraszPOS.";
    }
  }

  List<Map<String, dynamic>> getSummaryCards() {
    switch (role.toLowerCase()) {
      case "admin":
      case "superadmin":
        return [
          {
            "title": "System Role",
            "value": "Admin",
            "icon": Icons.admin_panel_settings_rounded,
          },
          {
            "title": "Main Focus",
            "value": "Users",
            "icon": Icons.people_alt_rounded,
          },
        ];

      case "manager":
      case "owner":
        return [
          {
            "title": "Today Sales",
            "value": "RM ${todaySales.toStringAsFixed(2)}",
            "icon": Icons.attach_money_rounded,
          },
          {
            "title": "Low Stock",
            "value": "$lowStock Items",
            "icon": Icons.warning_amber_rounded,
          },
          {
            "title": "Products",
            "value": totalProducts.toString(),
            "icon": Icons.inventory_2_rounded,
          },
        ];

      case "cashier":
        return [
          {
            "title": "Today Transactions",
            "value": todayTransactions.toString(),
            "icon": Icons.receipt_long_rounded,
          },
          {
            "title": "Today Sales",
            "value": "RM ${todaySales.toStringAsFixed(2)}",
            "icon": Icons.point_of_sale_rounded,
          },
        ];

      default:
        return [
          {
            "title": "Status",
            "value": "Unknown",
            "icon": Icons.info_outline_rounded,
          },
        ];
    }
  }

  Widget buildSummaryCard(Map<String, dynamic> item) {
    final title = item["title"] as String;
    final isLowStockCard = title == "Low Stock";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: isLowStockCard
              ? () {
                  _showNotificationDialog();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    item["icon"] as IconData,
                    color: primaryBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item["title"] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item["value"] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAlertBox() {
    String title;
    String description;
    IconData icon;

    switch (role.toLowerCase()) {
      case "admin":
      case "superadmin":
        title = "User Access Management";
        description =
            "Use the Manage Users module to create accounts and assign roles securely.";
        icon = Icons.security_rounded;
        break;
      case "manager":
        title = "Operations Overview";
        description =
            "Keep product stock updated and monitor sales activity throughout the day.";
        icon = Icons.storefront_rounded;
        break;
      case "cashier":
        title = "Ready for Transactions";
        description =
            "Open POS to begin processing customer purchases and sales records.";
        icon = Icons.shopping_cart_checkout_rounded;
        break;
      case "owner":
        title = "Business Monitoring";
        description =
            "Review sales, stock movement, and key store activity from one place.";
        icon = Icons.insights_rounded;
        break;
      default:
        title = "System Information";
        description = "No specific dashboard content available for this role.";
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final summaryCards = getSummaryCards();

    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Dashboard",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName.isNotEmpty ? userName : displayRole,
                          style: const TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: cardBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            formatDisplayDate(_selectedDate ?? DateTime.now()),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 40,
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _hasNotification = false;
                            });
                            _showNotificationDialog();
                          },
                          tooltip: "Notifications",
                          icon: Icon(
                            _hasNotification
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
                            size: 20,
                          ),
                          color: textSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        if (_hasNotification)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 40,
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: loadDashboardData,
                      tooltip: "Refresh",
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      color: textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PasscodeRequestsWidget(role: role),
                          if (role.toLowerCase() == 'owner' || role.toLowerCase() == 'manager') ...[
                            OwnerDashboardWidget(selectedDate: _selectedDate ?? DateTime.now()),
                          ] else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Overview",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: summaryCards.length,
                                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 320,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      mainAxisExtent: 100, // Sleek, compact height
                                    ),
                                    itemBuilder: (context, index) {
                                      return buildSummaryCard(summaryCards[index]);
                                    },
                                  ),
                                  const SizedBox(height: 28),
                                  const Text(
                                    "Information",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  buildAlertBox(),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}