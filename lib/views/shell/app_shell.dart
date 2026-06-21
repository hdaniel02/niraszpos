import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/shift_viewmodel.dart';
import '../dashboard/dashboard_screen.dart';
import '../pos/pos_screen.dart';
import '../product/products_screen.dart';
import '../sales/sales_history_screen.dart';
import '../sales/closing_reports_screen.dart';
import '../sales/refunds_screen.dart';
import '../users/manage_users_screen.dart';
import '../profile/profile_screen.dart';
import '../shifts/shifts_screen.dart';
import '../insights/ai_insights_screen.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../models/product.dart';
import '../../viewmodels/product_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppShell — persistent sidebar layout wrapping a nested light canvas card
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  final String role;

  const AppShell({super.key, required this.role});

  @override
  State<AppShell> createState() => AppShellState();

  static AppShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<AppShellState>();
  }
}

class AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  // ── Colours ──────────────────────────────────────────────────────────────
  static const Color _sidebarBg = Colors.white; // Premium Slate 900 -> White
  static const Color _activeItem = Color(0xFFA7F3D0); // Soft Light Green

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isCollapsed = false;
  int _selectedIndex = 0;
  String? _userName;

  static const double _expandedWidth = 240;
  static const double _collapsedWidth = 68;

  // ── Owner Notification Listener State ─────────────────────────────────────
  StreamSubscription<List<Product>>? _productsSubscription;
  final Set<String> _notifiedSoldOutProductIds = {};
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _setupOwnerNotificationListener();
  }

  Future<void> _loadUserName() async {
    final profile = await ProfileViewModel().getCurrentUserProfile();
    if (profile != null && mounted) {
      setState(() {
        _userName = profile.name;
      });
    }
  }

  void _setupOwnerNotificationListener() {
    debugPrint("AppShell: setupOwnerNotificationListener: role = ${widget.role}");
    if (widget.role.toLowerCase() != 'owner') return;

    _productsSubscription = ProductViewModel().getProducts().listen((products) {
      if (!mounted) return;

      final currentSoldOutIds = <String>{};

      for (final product in products) {
        if (product.stock == 0) {
          currentSoldOutIds.add(product.id);
          if (!_isInitialLoad && !_notifiedSoldOutProductIds.contains(product.id)) {
            _triggerPushNotification(
              "Product Sold Out",
              "${product.name} has been sold out!",
            );
          }
        }
      }

      _notifiedSoldOutProductIds.clear();
      _notifiedSoldOutProductIds.addAll(currentSoldOutIds);
      _isInitialLoad = false;
    });
  }

  void _triggerPushNotification(String title, String message) {
    // 1. Show local native OS notification on macOS
    if (!kIsWeb && Platform.isMacOS) {
      try {
        Process.run('osascript', [
          '-e',
          'display notification "$message" with title "$title" sound name "Glass"'
        ]);
      } catch (e) {
        debugPrint("Failed to send macOS notification: $e");
      }

      // 2. Send free push notification to physical iOS device via iMessage
      _sendIMessageNotification(message);
    }

    // 3. Send free push notification to physical iOS device via ntfy.sh
    _sendNtfyNotification(title, message);

    // 4. Fallback/complementary: Show a SnackBar in the app if it's currently active/open
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text("$title: $message")),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _sendIMessageNotification(String message) {
    try {
      final ownerEmail = FirebaseAuth.instance.currentUser?.email;
      if (ownerEmail != null && ownerEmail.contains('@')) {
        Process.run('osascript', [
          '-e',
          'tell application "Messages" to send "$message" to buddy "$ownerEmail"'
        ]);
      }
    } catch (e) {
      debugPrint("Failed to send iMessage: $e");
    }
  }

  Future<void> _sendNtfyNotification(String title, String message) async {
    try {
      final topic = 'niraszpos_alerts_${_userName?.replaceAll(' ', '_').toLowerCase() ?? 'hafiy'}';
      await http.post(
        Uri.parse('https://ntfy.sh/$topic'),
        headers: {
          'Title': title,
          'Priority': 'high',
          'Tags': 'warning,shopping_cart',
        },
        body: message,
      );
    } catch (e) {
      debugPrint("Failed to send ntfy notification: $e");
    }
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }

  // ── Tab definitions per role ──────────────────────────────────────────────
  List<_NavTab> get _tabs {
    final r = widget.role.toLowerCase();

    // Dashboard is always the first tab
    final dashboard = _NavTab(
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      iconOutline: Icons.dashboard_outlined,
    );

    switch (r) {
      case 'admin':
      case 'superadmin':
        return [
          dashboard,
          _NavTab(
            label: 'Manage Users',
            icon: Icons.people_rounded,
            iconOutline: Icons.people_outline_rounded,
          ),
          _NavTab(
            label: 'Profile',
            icon: Icons.person_rounded,
            iconOutline: Icons.person_outline_rounded,
          ),
        ];

      case 'manager':
        return [
          dashboard,
          _NavTab(
            label: 'POS',
            icon: Icons.point_of_sale_rounded,
            iconOutline: Icons.point_of_sale_outlined,
          ),
          _NavTab(
            label: 'Products',
            icon: Icons.inventory_2_rounded,
            iconOutline: Icons.inventory_2_outlined,
          ),
          _NavTab(
            label: 'Closing Reports',
            icon: Icons.receipt_long_rounded,
            iconOutline: Icons.receipt_long_outlined,
          ),
          _NavTab(
            label: 'Sales History',
            icon: Icons.history_rounded,
            iconOutline: Icons.history_outlined,
          ),
          _NavTab(
            label: 'Refunds',
            icon: Icons.assignment_return_rounded,
            iconOutline: Icons.assignment_return_outlined,
          ),
          _NavTab(
            label: 'Cashier Performance',
            icon: Icons.leaderboard_rounded,
            iconOutline: Icons.leaderboard_outlined,
          ),
          _NavTab(
            label: 'AI Analyst',
            icon: Icons.auto_awesome,
            iconOutline: Icons.auto_awesome_outlined,
          ),
          _NavTab(
            label: 'Profile',
            icon: Icons.person_rounded,
            iconOutline: Icons.person_outline_rounded,
          ),
        ];

      case 'owner':
        return [
          dashboard,
          _NavTab(
            label: 'Products',
            icon: Icons.inventory_2_rounded,
            iconOutline: Icons.inventory_2_outlined,
          ),
          _NavTab(
            label: 'Closing Reports',
            icon: Icons.receipt_long_rounded,
            iconOutline: Icons.receipt_long_outlined,
          ),
          _NavTab(
            label: 'Sales History',
            icon: Icons.history_rounded,
            iconOutline: Icons.history_outlined,
          ),
          _NavTab(
            label: 'Refunds',
            icon: Icons.assignment_return_rounded,
            iconOutline: Icons.assignment_return_outlined,
          ),
          _NavTab(
            label: 'Cashier Performance',
            icon: Icons.leaderboard_rounded,
            iconOutline: Icons.leaderboard_outlined,
          ),
          _NavTab(
            label: 'AI Analyst',
            icon: Icons.auto_awesome,
            iconOutline: Icons.auto_awesome_outlined,
          ),
          _NavTab(
            label: 'Profile',
            icon: Icons.person_rounded,
            iconOutline: Icons.person_outline_rounded,
          ),
        ];

      case 'cashier':
        return [
          dashboard,
          _NavTab(
            label: 'POS',
            icon: Icons.point_of_sale_rounded,
            iconOutline: Icons.point_of_sale_outlined,
          ),
          _NavTab(
            label: 'Closing Reports',
            icon: Icons.receipt_long_rounded,
            iconOutline: Icons.receipt_long_outlined,
          ),
          _NavTab(
            label: 'Sales History',
            icon: Icons.history_rounded,
            iconOutline: Icons.history_outlined,
          ),
          _NavTab(
            label: 'Refunds',
            icon: Icons.assignment_return_rounded,
            iconOutline: Icons.assignment_return_outlined,
          ),
          _NavTab(
            label: 'Profile',
            icon: Icons.person_rounded,
            iconOutline: Icons.person_outline_rounded,
          ),
        ];

      default:
        return [
          dashboard,
          _NavTab(
            label: 'Profile',
            icon: Icons.person_rounded,
            iconOutline: Icons.person_outline_rounded,
          ),
        ];
    }
  }

  // ── Build the page for each tab ───────────────────────────────────────────
  Widget _pageForTab(_NavTab tab) {
    switch (tab.label) {
      case 'Dashboard':
        return DashboardScreen(role: widget.role);
      case 'POS':
        return const PosScreen();
      case 'Products':
        return ProductsScreen();
      case 'Closing Reports':
        return ClosingReportsScreen(role: widget.role);
      case 'Sales History':
        return SalesHistoryScreen(role: widget.role);
      case 'Refunds':
        return RefundsScreen(role: widget.role);
      case 'Manage Users':
        return ManageUsersScreen();
      case 'Cashier Performance':
        return const ShiftsScreen();
      case 'AI Analyst':
        return const AiInsightsScreen();
      case 'Profile':
        return const ProfileScreen();
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  String get _displayRole {
    if (widget.role.isEmpty) return 'User';
    return widget.role[0].toUpperCase() +
        widget.role.substring(1).toLowerCase();
  }

  Future<void> _handleLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.role.toLowerCase() == 'cashier') {
      final shiftSnapshot = await FirebaseFirestore.instance
          .collection('shifts')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (shiftSnapshot.docs.isNotEmpty) {
        final shiftId = shiftSnapshot.docs.first.id;
        if (!mounted) return;
        
        // TODO(Hardware): Call your Receipt Printer's openCashDrawer() method here.
        // This will pop the physical cash drawer open so the cashier can count the ending cash.
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _buildEndShiftDrawer(shiftId),
        );
        return;
      }
    }

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Widget _buildEndShiftDrawer(String shiftId) {
    final cashController = TextEditingController();
    bool isLoadingDrawer = false;
    final ShiftViewModel shiftVM = ShiftViewModel();

    return StatefulBuilder(
      builder: (context, setModalState) {
        Widget buildKeypadButton(String text, {IconData? icon}) {
          return InkWell(
            onTap: () {
              setModalState(() {
                if (text == "del") {
                  if (cashController.text.isNotEmpty) {
                    cashController.text = cashController.text.substring(0, cashController.text.length - 1);
                  }
                } else if (text == ".") {
                  if (!cashController.text.contains(".")) {
                    cashController.text += cashController.text.isEmpty ? "0." : ".";
                  }
                } else {
                  if (cashController.text.contains(".")) {
                    final parts = cashController.text.split(".");
                    if (parts.length > 1 && parts[1].length >= 2) return;
                  }
                  if (cashController.text == "0") {
                    cashController.text = text;
                  } else {
                    cashController.text += text;
                  }
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: const Color(0xFF334155), size: 28)
                    : Text(
                        text,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.only(
            bottom: 32,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "End Shift",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter the ending cash total from your drawer",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Cash Display styled like Start Shift
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Center(
                    child: Text(
                      cashController.text.isEmpty ? "RM 0.00" : "RM ${cashController.text}",
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                // Custom Numeric Keypad
                SizedBox(
                  width: 320,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          buildKeypadButton("1"),
                          buildKeypadButton("2"),
                          buildKeypadButton("3"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          buildKeypadButton("4"),
                          buildKeypadButton("5"),
                          buildKeypadButton("6"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          buildKeypadButton("7"),
                          buildKeypadButton("8"),
                          buildKeypadButton("9"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          buildKeypadButton("."),
                          buildKeypadButton("0"),
                          buildKeypadButton("del", icon: Icons.backspace_outlined),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoadingDrawer
                          ? null
                          : () async {
                              double cashVal = double.tryParse(cashController.text.trim()) ?? 0.0;
                              
                              setModalState(() => isLoadingDrawer = true);

                              try {
                                await shiftVM.endShift(shiftId, cashVal, 0.0, 0.0);
                                await FirebaseAuth.instance.signOut();
                                if (!context.mounted) return;
                                Navigator.pop(context); // Close drawer
                                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
                              } finally {
                                if (context.mounted) setModalState(() => isLoadingDrawer = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isLoadingDrawer
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("End Shift & Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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

  void navigateToTab(String label) {
    final index = _tabs.indexWhere((t) => t.label.toLowerCase() == label.toLowerCase());
    if (index != -1) {
      setState(() => _selectedIndex = index);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    // Clamp selectedIndex in case role changed
    final safeIndex = _selectedIndex.clamp(0, tabs.length - 1);
    if (safeIndex != _selectedIndex) _selectedIndex = safeIndex;

    final sidebarWidth =
        _isCollapsed ? _collapsedWidth : _expandedWidth;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // ── Sidebar (Flush to top, left, bottom) ─────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: _sidebarBg,
              border: const Border(
                right: BorderSide(
                  color: Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              right: false,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: _isCollapsed ? _collapsedWidth : _expandedWidth,
                  child: _buildSidebar(tabs, safeIndex),
                ),
              ),
            ),
          ),

          // ── Content canvas (Fully white) ─────────────────────────────
          Expanded(
            child: Container(
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                left: false,
                child: IndexedStack(
                  index: safeIndex,
                  children: tabs.map((tab) => _pageForTab(tab)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar widget ────────────────────────────────────────────────────────
  Widget _buildSidebar(List<_NavTab> tabs, int activeIndex) {
    final collapsed = _isCollapsed;

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── User role badge or Collapse Toggle (Header) ───────────
          if (!collapsed) _buildRoleBadge(),
          if (collapsed) _buildCollapseButton(collapsed),

          const SizedBox(height: 16),

          // ── Divider ───────────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFE2E8F0),
          ),

          const SizedBox(height: 16),

          // ── Nav label ─────────────────────────────────────────────
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'NAVIGATION',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),

          // ── Nav items ─────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: tabs.where((t) => t.label != 'Profile').length,
              separatorBuilder: (_, index) => const SizedBox(height: 2),
              itemBuilder: (ctx, i) {
                final visibleTabs = tabs.where((t) => t.label != 'Profile').toList();
                final tab = visibleTabs[i];
                final actualIndex = tabs.indexOf(tab);
                final isActive = actualIndex == activeIndex;
                return _NavItem(
                  tab: tab,
                  isActive: isActive,
                  collapsed: collapsed,
                  activeColor: _activeItem,
                  onTap: () => setState(() => _selectedIndex = actualIndex),
                );
              },
            ),
          ),

          // ── Divider ───────────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 8),

          // ── Settings ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildSettingsItem(collapsed),
          ),
          const SizedBox(height: 4),

          // ── Logout ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildLogoutItem(collapsed),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRoleBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA7F3D0), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayRole,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _userName ?? 'Signed in',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Collapse sidebar',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: const Icon(
                      Icons.view_sidebar_outlined,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(bool collapsed) {
    final profileIndex = _tabs.indexWhere((t) => t.label == 'Profile');
    final isActive = profileIndex != -1 && _selectedIndex == profileIndex;

    return Tooltip(
      message: collapsed ? 'Settings' : '',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (profileIndex != -1) {
              setState(() {
                _selectedIndex = profileIndex;
              });
            }
          },
          splashColor: const Color(0xFFE2E8F0),
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: isActive ? _activeItem : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? const Color(0xFF0F172A) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutItem(bool collapsed) {
    return Tooltip(
      message: collapsed ? 'Logout' : '',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _handleLogout,
          splashColor: Colors.red.withValues(alpha: 0.10),
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 12 : 14,
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 19,
                  color: Colors.redAccent.withValues(alpha: 0.80),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(bool collapsed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Tooltip(
        message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          child: InkWell(
            borderRadius: BorderRadius.circular(21),
            onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            splashColor: const Color(0xFFE2E8F0),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: collapsed
                      ? Stack(
                          key: const ValueKey('collapsed'),
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.view_sidebar_outlined, size: 20, color: Color(0xFF64748B)),
                            Positioned(
                              left: 1.5,
                              child: Container(
                                color: const Color(0xFFF8FAFC),
                                width: 7,
                                height: 12,
                              ),
                            ),
                            const Positioned(
                              left: -1.5,
                              child: Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF64748B)),
                            ),
                          ],
                        )
                      : const Icon(
                          Icons.view_sidebar_outlined,
                          key: ValueKey('expanded'),
                          size: 20,
                          color: Color(0xFF64748B),
                         ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NavTab — data class
// ─────────────────────────────────────────────────────────────────────────────

class _NavTab {
  final String label;
  final IconData icon;
  final IconData iconOutline;

  _NavTab({
    required this.label,
    required this.icon,
    required this.iconOutline,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// NavItem — individual sidebar item with animation
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final _NavTab tab;
  final bool isActive;
  final bool collapsed;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.collapsed,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final collapsed = widget.collapsed;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 14),
      decoration: BoxDecoration(
        color: active
            ? widget.activeColor
            : _hovered
                ? const Color(0xFFF1F5F9)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: active
            ? null
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(
            active ? widget.tab.icon : widget.tab.iconOutline,
            size: 20,
            color: active
                ? const Color(0xFF0F172A)
                : const Color(0xFF64748B),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.tab.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );

    if (collapsed) {
      content = Tooltip(
        message: widget.tab.label,
        preferBelow: false,
        child: content,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}
