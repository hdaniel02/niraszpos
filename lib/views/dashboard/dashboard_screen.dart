import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product.dart';
import '../../models/shift.dart';
import '../../models/sales.dart';
import '../../viewmodels/product_viewmodel.dart';
import '../../viewmodels/sales_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/shift_viewmodel.dart';
import 'widgets/passcode_requests_widget.dart';
import 'widgets/owner_dashboard_widget.dart';
import '../shell/app_shell.dart';
import '../product/products_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  final VoidCallback? onNotificationTapped;
  final bool hasNotification;
  final VoidCallback? onRefreshTapped;

  const DashboardScreen({
    super.key, 
    required this.role,
    this.onNotificationTapped,
    this.hasNotification = false,
    this.onRefreshTapped,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color primaryBlue = Color(0xFF059669); // Emerald Green system
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
  DateTimeRange? _selectedDateRange;
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

  String formatDisplayRange(DateTimeRange range) {
    if (range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day) {
      return formatDisplayDate(range.start);
    }
    const months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final startDay = range.start.day.toString();
    final startMonth = months[range.start.month];
    final endDay = range.end.day.toString();
    final endMonth = months[range.end.month];
    
    if (range.start.year == range.end.year) {
      return '$startDay $startMonth - $endDay $endMonth ${range.start.year}';
    } else {
      return '$startDay $startMonth ${range.start.year.toString().substring(2)} - $endDay $endMonth ${range.end.year.toString().substring(2)}';
    }
  }

  Future<void> _selectDate() async {
    final DateTimeRange? picked = await showGeneralDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "DatePicker",
      barrierColor: Colors.black.withOpacity(0.30),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim, _) => _CustomCalendarDialog(
        initialRange: _selectedDateRange ?? DateTimeRange(
          start: DateTime.now(),
          end: DateTime.now(),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            alignment: Alignment.topRight, // same anchor as notification popup
            child: child,
          ),
        );
      },
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Notifications",
      barrierColor: Colors.black.withOpacity(0.20),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return NotificationPanel(
          animation: animation,
          pendingRefundRequests: _pendingRefundRequests,
          pendingPasscodeRequests: _pendingPasscodeRequests,
          lowStockProducts: _lowStockProducts,
          salesVM: salesVM,
          onAdminReset: (docId, cashierUid, setState) =>
              _showAdminResetDialog(docId, cashierUid, setState),
          onViewDismiss: (docId, passcode, setState) =>
              _showViewAndDismissDialog(docId, passcode, setState),
          onNavigateToProducts: (productName) {
            Navigator.pop(dialogContext);
            ProductsScreen.initialSearchQuery = productName;
            AppShell.of(context)?.navigateToTab('Products');
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Scale from top-right (where the bell icon lives) + fade in simultaneously
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
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
                Icon(Icons.password_rounded, size: 48, color: primaryBlue),
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
                        style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
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
                    style: TextStyle(fontSize: 36, letterSpacing: 8, fontWeight: FontWeight.w800, color: primaryBlue),
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
                      backgroundColor: primaryBlue,
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
    final today = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(today.year, today.month, today.day),
      end: DateTime(today.year, today.month, today.day),
    );
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
      final range = _selectedDateRange ?? DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now(),
      );
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
      final sales = await salesVM.getSalesForDateRange(start, end);
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
    final isSingleDay = _selectedDateRange == null ||
        (_selectedDateRange!.start.year == _selectedDateRange!.end.year &&
            _selectedDateRange!.start.month == _selectedDateRange!.end.month &&
            _selectedDateRange!.start.day == _selectedDateRange!.end.day);

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
            "title": isSingleDay ? "Today Sales" : "Period Sales",
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
            "title": isSingleDay ? "Today Transactions" : "Period Transactions",
            "value": todayTransactions.toString(),
            "icon": Icons.receipt_long_rounded,
          },
          {
            "title": isSingleDay ? "Today Sales" : "Period Sales",
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

  Widget itemRow({
    required IconData icon,
    required String label,
    required double value,
    required double percent,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
            ),
            const Spacer(),
            Text(
              "RM ${value.toStringAsFixed(2)}",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  String formatTimeOnly(DateTime dateTime) {
    final hourNum = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hourNum >= 12 ? 'PM' : 'AM';
    final displayHour = hourNum == 0 ? 12 : (hourNum > 12 ? hourNum - 12 : hourNum);
    return '$displayHour:$minute $period';
  }

  Widget _detailRow(String label, String value, {Color valueColor = textPrimary, bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: textSecondary))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              color: valueColor,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> showDuplicateReceiptDialog(BuildContext context, Sale sale) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: primaryBlue,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Duplicate Receipt',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow('Receipt No', sale.receiptNo),
                          const SizedBox(height: 12),
                          _detailRow('Payment Method', sale.paymentMethod),
                          const SizedBox(height: 12),
                          _detailRow('Cashier', sale.cashierEmail),
                          const SizedBox(height: 12),
                          _detailRow('Date', formatDisplayDate(sale.createdAt) + " " + formatTimeOnly(sale.createdAt)),
                          if (sale.refundStatus != null) ...[
                            const SizedBox(height: 12),
                            _detailRow(
                              'Refund Status',
                              sale.refundStatus == 'full' ? 'Fully Refunded' : 'Partially Refunded',
                              valueColor: Colors.red,
                              bold: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'ITEMS PURCHASED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sale.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = sale.items[index];
                        final subTotal = item.price * item.quantity;
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.quantity} x RM ${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'RM ${subTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: cardBorder, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Paid',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        Text(
                          'RM ${sale.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textSecondary,
                          side: const BorderSide(color: cardBorder, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildRecentTransactionsCard(BuildContext context, List<Sale> shiftSales) {
    final recentSales = shiftSales.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_rounded, color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Live Activity Feed",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Recent transactions from your current active shift",
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 16),
          if (recentSales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  "No transactions processed yet in this shift.",
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: Text("TIME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                      Expanded(flex: 3, child: Text("RECEIPT NO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                      Expanded(flex: 2, child: Text("AMOUNT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                      Expanded(flex: 2, child: Text("STATUS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentSales.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                  itemBuilder: (context, index) {
                    final sale = recentSales[index];
                    
                    String statusText = 'Paid';
                    Color statusBg = const Color(0xFFDCFCE7);
                    Color statusTextCol = const Color(0xFF15803D);
                    
                    if (sale.refundStatus == 'full') {
                      statusText = 'Refunded';
                      statusBg = const Color(0xFFFEE2E2);
                      statusTextCol = const Color(0xFFB91C1C);
                    } else if (sale.refundStatus == 'partial') {
                      statusText = 'Partial Ref';
                      statusBg = const Color(0xFFFEF3C7);
                      statusTextCol = const Color(0xFFD97706);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              formatTimeOnly(sale.createdAt),
                              style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              sale.receiptNo,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "RM ${sale.total.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusTextCol,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.receipt_long_rounded, size: 20, color: textSecondary),
                            onPressed: () => showDuplicateReceiptDialog(context, sale),
                            tooltip: "Duplicate Receipt",
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCashierShiftDrawerStatus(String userId) {
    return StreamBuilder<List<Shift>>(
      stream: ShiftViewModel().getActiveShifts(userId),
      builder: (context, shiftSnapshot) {
        if (shiftSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final activeShifts = shiftSnapshot.data ?? [];
        if (activeShifts.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "No Active Shift",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Please clock in or start a shift to track your cash drawer status.",
                        style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final shift = activeShifts.first;
        return StreamBuilder<List<Sale>>(
          stream: SalesViewModel().getSales(),
          builder: (context, salesSnapshot) {
            if (salesSnapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final allSales = salesSnapshot.data ?? [];
            final shiftSales = allSales.where((sale) =>
                sale.cashierId == userId &&
                sale.createdAt.isAfter(shift.startTime)).toList();

            double startingFloat = shift.startingCash;
            double cashSales = 0.0;
            double cardSales = 0.0;
            double qrSales = 0.0;

            for (final sale in shiftSales) {
              final netAmount = sale.total - sale.refundedAmount;
              if (sale.paymentMethod == 'Cash') {
                cashSales += netAmount;
              } else if (sale.paymentMethod == 'Card') {
                cardSales += netAmount;
              } else if (sale.paymentMethod == 'QR') {
                qrSales += netAmount;
              }
            }

            double expectedCash = startingFloat + cashSales;
            double totalShiftSales = cashSales + cardSales + qrSales;

            double cashPct = 0.0;
            double cardPct = 0.0;
            double qrPct = 0.0;

            if (totalShiftSales > 0) {
              cashPct = (cashSales > 0 ? cashSales / totalShiftSales : 0.0).clamp(0.0, 1.0);
              cardPct = (cardSales > 0 ? cardSales / totalShiftSales : 0.0).clamp(0.0, 1.0);
              qrPct = (qrSales > 0 ? qrSales / totalShiftSales : 0.0).clamp(0.0, 1.0);
            }

            Widget buildCashStatusCard() {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF22C55E), size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Current Cash Status",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Expected cash currently in drawer",
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Expected Cash in Drawer",
                          style: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          "RM ${expectedCash.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF22C55E)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Starting Float", style: TextStyle(fontSize: 13, color: textSecondary)),
                        Text("RM ${startingFloat.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Net Cash Sales", style: TextStyle(fontSize: 13, color: textSecondary)),
                        Text("RM ${cashSales.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      ],
                    ),
                  ],
                ),
              );
            }

            Widget buildBreakdownCard() {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.payments_rounded, color: Color(0xFF3B82F6), size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Payment Method Breakdown",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Sales breakdown for current shift",
                                style: TextStyle(fontSize: 12, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    itemRow(
                      icon: Icons.money_rounded,
                      label: "Cash Sales",
                      value: cashSales,
                      percent: cashPct,
                      color: const Color(0xFF22C55E),
                    ),
                    const SizedBox(height: 18),
                    itemRow(
                      icon: Icons.credit_card_rounded,
                      label: "Card Sales",
                      value: cardSales,
                      percent: cardPct,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 18),
                    itemRow(
                      icon: Icons.qr_code_rounded,
                      label: "E-Wallet (TNG/GrabPay)",
                      value: qrSales,
                      percent: qrPct,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useSideBySide = constraints.maxWidth > 580;

                    if (useSideBySide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: buildCashStatusCard()),
                          const SizedBox(width: 20),
                          Expanded(child: buildBreakdownCard()),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          buildCashStatusCard(),
                          const SizedBox(height: 20),
                          buildBreakdownCard(),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                buildRecentTransactionsCard(context, shiftSales),
              ],
            );
          },
        );
      },
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
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: cardBorder),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            formatDisplayRange(_selectedDateRange ?? DateTimeRange(
                              start: DateTime.now(),
                              end: DateTime.now(),
                            )),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: IconButton(
                            onPressed: widget.onNotificationTapped,
                            tooltip: "Notifications",
                            icon: Icon(
                              widget.hasNotification
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              size: 20,
                            ),
                            color: const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: IconButton(
                            onPressed: () {
                              if (widget.onRefreshTapped != null) {
                                widget.onRefreshTapped!();
                              } else {
                                loadDashboardData();
                              }
                            },
                            tooltip: "Refresh",
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            color: const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 20,
                          ),
                        ),
                      ),
                    ],
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
                            OwnerDashboardWidget(
                              selectedRange: _selectedDateRange ?? DateTimeRange(
                                start: DateTime.now(),
                                end: DateTime.now(),
                              ),
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (role.toLowerCase() == 'cashier') ...[
                                    _buildCashierShiftDrawerStatus(FirebaseAuth.instance.currentUser?.uid ?? ''),
                                    const SizedBox(height: 24),
                                  ],
                                  if (role.toLowerCase() != 'cashier') ...[
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

// ─── Beautiful animated notification panel ──────────────────────────────────

class NotificationPanel extends StatefulWidget {
  final Animation<double> animation;
  final List<Map<String, dynamic>> pendingRefundRequests;
  final List<QueryDocumentSnapshot> pendingPasscodeRequests;
  final List<Product> lowStockProducts;
  final SalesViewModel salesVM;
  final Future<void> Function(String docId, String cashierUid, StateSetter setState) onAdminReset;
  final Future<void> Function(String docId, String passcode, StateSetter setState) onViewDismiss;
  final void Function(String productName) onNavigateToProducts;

  const NotificationPanel({
    required this.animation,
    required this.pendingRefundRequests,
    required this.pendingPasscodeRequests,
    required this.lowStockProducts,
    required this.salesVM,
    required this.onAdminReset,
    required this.onViewDismiss,
    required this.onNavigateToProducts,
  });

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  static const Color _primary = Color(0xFF059669);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _bg = Color(0xFFF8FAFC);

  bool _showUnreadOnly = false;

  /// Build a coloured avatar circle with an icon in the center.
  Widget _avatar(IconData icon, Color bg, Color fg) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: 20),
    );
  }

  /// Dot in the top-right corner of the avatar.
  Widget _dotBadge(Color color, Widget child) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 72, right: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 400,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height - 120,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                  child: Row(
                    children: [
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                      const Spacer(),
                      // All / Unread toggle pills
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            _pill("All", !_showUnreadOnly),
                            _pill("Unread", _showUnreadOnly),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ─── Body ─────────────────────────────────────────────────
                Flexible(
                  child: _buildBody(),
                ),

                // ─── Footer close button ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textSecondary,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      child: const Text("Close"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _showUnreadOnly = label == "Unread"),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? _textPrimary : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final passcodes = widget.pendingPasscodeRequests;
    final refunds = widget.pendingRefundRequests;
    final lowStock = widget.lowStockProducts;

    final hasAny =
        passcodes.isNotEmpty || refunds.isNotEmpty || lowStock.isNotEmpty;

    if (!hasAny) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: Colors.green.shade500, size: 52),
            const SizedBox(height: 16),
            const Text("All caught up!",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            const Text("No new notifications.",
                style: TextStyle(fontSize: 13, color: _textSecondary)),
          ],
        ),
      );
    }

    return StatefulBuilder(
      builder: (context, setS) {
        return ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            // Passcode resets
            ...passcodes.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String;
              final email = data['cashierEmail'] as String;
              final cashierUid = data['cashierUid'] as String;
              final newPasscode = data['newPasscode'] as String?;

              String title;
              String subtitle;
              Color badgeColor;
              IconData badgeIcon;
              if (status == 'pending_manager') {
                title = "Passcode Reset Requested";
                subtitle = "Cashier $email forgot their passcode.";
                badgeColor = const Color(0xFFD97706);
                badgeIcon = Icons.lock_reset_rounded;
              } else if (status == 'pending_admin') {
                title = "Reset Passcode for Cashier";
                subtitle = "Manager forwarded request for $email.";
                badgeColor = const Color(0xFFDC2626);
                badgeIcon = Icons.admin_panel_settings_rounded;
              } else {
                title = "Passcode Reset Successful";
                subtitle = "New passcode ready for $email.";
                badgeColor = _primary;
                badgeIcon = Icons.check_circle_rounded;
              }

              return _NotificationTile(
                avatar: _dotBadge(
                  const Color(0xFFEF4444),
                  _avatar(
                    badgeIcon,
                    badgeColor.withOpacity(0.12),
                    badgeColor,
                  ),
                ),
                title: title,
                subtitle: subtitle,
                timeAgo: "just now",
                actions: _passcodeActions(
                    doc.id, cashierUid, status, newPasscode, setS),
              );
            }),

            // Refund requests
            ...refunds.map((req) {
              final reqId = req['id'] as String;
              final receiptNo = req['receiptNo'] as String;
              final cashierEmail = req['cashierEmail'] as String;
              final total = (req['total'] ?? 0.0).toDouble();
              final bankNo = req['bankAccountNumber'] as String?;
              final custName = req['customerFullName'] as String?;
              final custPhone = req['customerPhoneNumber'] as String?;

              return _NotificationTile(
                avatar: _dotBadge(
                  const Color(0xFFEF4444),
                  _avatar(Icons.receipt_long_rounded,
                      Colors.orange.withOpacity(0.12), Colors.orange.shade700),
                ),
                title: "Refund Approval Required",
                subtitle:
                    "Receipt $receiptNo • Cashier: $cashierEmail • RM ${total.toStringAsFixed(2)}",
                detail: (custName != null || bankNo != null || custPhone != null)
                    ? _buildTransferDetail(custName, bankNo, custPhone)
                    : null,
                timeAgo: "pending",
                actions: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _declineBtn("Reject", () async {
                      try {
                        await widget.salesVM.rejectRefundRequest(reqId);
                        setS(() {});
                      } catch (_) {}
                    }),
                    const SizedBox(width: 8),
                    _acceptBtn("Approve", () async {
                      try {
                        await widget.salesVM.approveRefundRequest(reqId);
                        setS(() {});
                      } catch (_) {}
                    }),
                  ],
                ),
              );
            }),

            // Low stock
            ...lowStock.map((product) {
              final isOut = product.stock == 0;
              return _NotificationTile(
                avatar: _avatar(
                  Icons.inventory_2_rounded,
                  isOut
                      ? Colors.red.withOpacity(0.1)
                      : Colors.amber.withOpacity(0.12),
                  isOut ? Colors.red.shade700 : Colors.amber.shade800,
                ),
                title: isOut ? "Out of Stock" : "Low Stock Warning",
                subtitle: isOut
                    ? "${product.name} is completely out of stock."
                    : "${product.name} — only ${product.stock} left.",
                timeAgo: "",
                actions: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        widget.onNavigateToProducts(product.name),
                    style: TextButton.styleFrom(
                      foregroundColor: _primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("View Product"),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildTransferDetail(
      String? custName, String? bankNo, String? custPhone) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Customer Transfer Details",
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _textSecondary,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          if (custName != null)
            Text("Name: $custName",
                style: const TextStyle(
                    fontSize: 12,
                    color: _textPrimary,
                    fontWeight: FontWeight.w600)),
          if (bankNo != null)
            Text("Bank Acc: $bankNo",
                style: const TextStyle(
                    fontSize: 12,
                    color: _textPrimary,
                    fontWeight: FontWeight.w600)),
          if (custPhone != null)
            Text("Phone: $custPhone",
                style: const TextStyle(
                    fontSize: 12,
                    color: _textPrimary,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _passcodeActions(String docId, String cashierUid, String status,
      String? newPasscode, StateSetter setS) {
    if (status == 'pending_manager') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _declineBtn("Reject", () async {
            try {
              await FirebaseFirestore.instance
                  .collection('passcode_requests')
                  .doc(docId)
                  .delete();
              setS(() {});
            } catch (_) {}
          }),
          const SizedBox(width: 8),
          _acceptBtn("Forward", () async {
            try {
              await FirebaseFirestore.instance
                  .collection('passcode_requests')
                  .doc(docId)
                  .update({'status': 'pending_admin'});
              setS(() {});
            } catch (_) {}
          }, color: const Color(0xFFD97706)),
        ],
      );
    } else if (status == 'pending_admin') {
      return Align(
        alignment: Alignment.centerRight,
        child: _acceptBtn("Generate Passcode", () async {
          await widget.onAdminReset(docId, cashierUid, setS);
        }, color: const Color(0xFFDC2626)),
      );
    } else {
      return Align(
        alignment: Alignment.centerRight,
        child: _acceptBtn("View & Dismiss", () async {
          await widget.onViewDismiss(docId, newPasscode ?? '', setS);
        }),
      );
    }
  }

  Widget _declineBtn(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFDC2626),
        side: const BorderSide(color: Color(0xFFDC2626)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      child: Text(label),
    );
  }

  Widget _acceptBtn(String label, VoidCallback onTap,
      {Color color = const Color(0xFF059669)}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      child: Text(label),
    );
  }
}

// ─── Individual notification tile ───────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final Widget avatar;
  final String title;
  final String subtitle;
  final String timeAgo;
  final Widget? detail;
  final Widget? actions;

  const _NotificationTile({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    this.detail,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (timeAgo.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                ),
                if (detail != null) detail!,
                if (actions != null) ...[
                  const SizedBox(height: 10),
                  actions!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Calendar Dialog ──────────────────────────────────────────────────

class _CustomCalendarDialog extends StatefulWidget {
  final DateTimeRange initialRange;
  const _CustomCalendarDialog({required this.initialRange});

  @override
  State<_CustomCalendarDialog> createState() => _CustomCalendarDialogState();
}

class _CustomCalendarDialogState extends State<_CustomCalendarDialog> {
  static const _primary = Color(0xFF059669);          // emerald green
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFFCBD5E1);        // greyed out (other-month)
  static const _textSecondary = Color(0xFF64748B);

  late DateTime _viewing;   // month being shown
  DateTime? _startDate;     // start of picked range
  DateTime? _endDate;       // end of picked range

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialRange.start;
    _endDate = widget.initialRange.end;
    _viewing = DateTime(_startDate!.year, _startDate!.month, 1);
  }

  void _prevMonth() => setState(
      () => _viewing = DateTime(_viewing.year, _viewing.month - 1, 1));

  void _nextMonth() => setState(
      () => _viewing = DateTime(_viewing.year, _viewing.month + 1, 1));

  /// Returns a flat list of days to display (42 cells = 6 weeks),
  /// including leading/trailing days from adjacent months.
  List<DateTime> _buildCells() {
    final firstDay = _viewing;
    // weekday: Mon=1..Sun=7 → we want Sun=0 as first column
    final startOffset = (firstDay.weekday % 7); // Sun=0, Mon=1 … Sat=6
    final cells = <DateTime>[];
    for (var i = startOffset; i > 0; i--) {
      cells.add(firstDay.subtract(Duration(days: i)));
    }
    final daysInMonth =
        DateTime(_viewing.year, _viewing.month + 1, 0).day;
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_viewing.year, _viewing.month, d));
    }
    // Fill remaining rows to complete the last row
    var extra = 1;
    while (cells.length % 7 != 0) {
      cells.add(DateTime(_viewing.year, _viewing.month + 1, extra++));
    }
    return cells;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isCurrentMonth(DateTime d) =>
      d.year == _viewing.year && d.month == _viewing.month;

  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  void _onDayTapped(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = normalized;
        _endDate = null;
      } else {
        if (normalized.isBefore(_startDate!)) {
          _startDate = normalized;
        } else {
          _endDate = normalized;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildCells();

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 72, right: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 360,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Month/Year header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      // Left arrow
                      _navBtn(Icons.chevron_left_rounded, _prevMonth),
                      const Spacer(),
                      // Month + Year
                      Text(
                        '${_monthNames[_viewing.month]} ${_viewing.year}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const Spacer(),
                      // Right arrow
                      _navBtn(Icons.chevron_right_rounded, _nextMonth),
                    ],
                  ),
                ),

                // ── Day-of-week labels ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map(
                          (d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Calendar grid ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cells.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisExtent: 44,
                    ),
                    itemBuilder: (_, i) {
                      final cellDate = cells[i];
                      final isSelected = (_startDate != null && _isSameDay(cellDate, _startDate!)) ||
                                         (_endDate != null && _isSameDay(cellDate, _endDate!));
                      final isInRange = _startDate != null &&
                                        _endDate != null &&
                                        cellDate.isAfter(_startDate!) &&
                                        cellDate.isBefore(_endDate!) &&
                                        !_isSameDay(cellDate, _startDate!) &&
                                        !_isSameDay(cellDate, _endDate!);
                      return _DayCell(
                        date: cellDate,
                        isCurrentMonth: _isCurrentMonth(cellDate),
                        isSelected: isSelected,
                        isInRange: isInRange,
                        isToday: _isToday(cellDate),
                        onTap: () => _onDayTapped(cellDate),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ── Apply button ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_startDate != null) {
                          Navigator.of(context).pop(DateTimeRange(
                            start: _startDate!,
                            end: _endDate ?? _startDate!,
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary, // system emerald green
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // light grey tint
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: _textSecondary),
      ),
    );
  }
}

// ─── Single day cell ─────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isSelected;
  final bool isInRange;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isSelected,
    required this.isInRange,
    required this.isToday,
    required this.onTap,
  });

  static const _primary = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color textColor;

    if (isSelected) {
      bgColor = _primary;
      textColor = Colors.white;
    } else if (isInRange) {
      bgColor = const Color(0xFFECFDF5); // light emerald tint
      textColor = _primary;
    } else {
      bgColor = Colors.transparent;
      textColor = isToday
          ? _primary
          : isCurrentMonth
              ? const Color(0xFF0F172A)
              : const Color(0xFFCBD5E1);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(isSelected || isInRange ? 22 : 10),
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected || isInRange || isToday
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}