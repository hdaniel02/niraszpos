import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatelessWidget {
  final String role;
  const DashboardScreen({super.key, required this.role});

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

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
        return [
          {
            "title": "Today Sales",
            "value": "RM 0.00",
            "icon": Icons.attach_money_rounded,
          },
          {
            "title": "Low Stock",
            "value": "0 Items",
            "icon": Icons.warning_amber_rounded,
          },
          {
            "title": "Products",
            "value": "0",
            "icon": Icons.inventory_2_rounded,
          },
        ];
      case "cashier":
        return [
          {
            "title": "Today Transactions",
            "value": "0",
            "icon": Icons.receipt_long_rounded,
          },
          {
            "title": "Current Role",
            "value": "Cashier",
            "icon": Icons.badge_rounded,
          },
        ];
      case "owner":
        return [
          {
            "title": "Today Sales",
            "value": "RM 0.00",
            "icon": Icons.attach_money_rounded,
          },
          {
            "title": "Revenue",
            "value": "RM 0.00",
            "icon": Icons.bar_chart_rounded,
          },
          {
            "title": "Low Stock",
            "value": "0 Items",
            "icon": Icons.warning_amber_rounded,
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

  List<Map<String, dynamic>> getMenuByRole() {
    switch (role.toLowerCase()) {
      case "admin":
      case "superadmin":
        return [
          {
            "title": "Manage Users",
            "subtitle": "Create, edit, and manage user accounts.",
            "icon": Icons.people_rounded,
            "route": "/users",
          },
        ];
      case "manager":
        return [
          {
            "title": "POS",
            "subtitle": "Start and manage sales transactions.",
            "icon": Icons.point_of_sale_rounded,
            "route": "/pos",
          },
          {
            "title": "Products",
            "subtitle": "View and manage product inventory.",
            "icon": Icons.inventory_2_rounded,
            "route": "/products",
          },
          {
            "title": "Sales History",
            "subtitle": "Review past sales and transactions.",
            "icon": Icons.receipt_long_rounded,
            "route": "/sales",
          },
        ];
      case "cashier":
        return [
          {
            "title": "POS",
            "subtitle": "Process customer purchases quickly.",
            "icon": Icons.point_of_sale_rounded,
            "route": "/pos",
          },
        ];
      case "owner":
        return [
          {
            "title": "POS",
            "subtitle": "Access transaction processing.",
            "icon": Icons.point_of_sale_rounded,
            "route": "/pos",
          },
          {
            "title": "Products",
            "subtitle": "Monitor stock and product details.",
            "icon": Icons.inventory_2_rounded,
            "route": "/products",
          },
          {
            "title": "Sales History",
            "subtitle": "Review past sales and transactions.",
            "icon": Icons.receipt_long_rounded,
            "route": "/sales",
          },
          {
            "title": "Manage Users",
            "subtitle": "Manage authorized system users.",
            "icon": Icons.people_rounded,
            "route": "/users",
          },
        ];
      default:
        return [];
    }
  }

  Widget buildSummaryCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
    );
  }

  Widget buildMenuCard(BuildContext context, Map<String, dynamic> item) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.pushNamed(context, item["route"] as String);
      },
      child: Ink(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                item["icon"] as IconData,
                color: primaryBlue,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              item["title"] as String,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item["subtitle"] as String,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: textSecondary,
              ),
            ),
          ],
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
    Navigator.pushNamedAndRemoveUntil(context, "/", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final summaryCards = getSummaryCards();
    final menuItems = getMenuByRole();

    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: cardBorder),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.dashboard_rounded,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back, $displayRole",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          welcomeSubtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, "/profile");
                        },
                        icon:
                            const Icon(Icons.person_outline_rounded, size: 18),
                        label: const Text("Profile"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: cardBorder),
                          foregroundColor: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => handleLogout(context),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text("Logout"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 1;
                        if (constraints.maxWidth > 1100) {
                          crossAxisCount = 3;
                        } else if (constraints.maxWidth > 700) {
                          crossAxisCount = 2;
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: summaryCards.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.6,
                          ),
                          itemBuilder: (context, index) {
                            return buildSummaryCard(summaryCards[index]);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (menuItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                        ),
                        child: const Text(
                          "No dashboard actions available for this role.",
                          style: TextStyle(color: textSecondary),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 1;
                          if (constraints.maxWidth > 1100) {
                            crossAxisCount = 3;
                          } else if (constraints.maxWidth > 700) {
                            crossAxisCount = 2;
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: menuItems.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 18,
                              mainAxisSpacing: 18,
                              childAspectRatio: 1.4,
                            ),
                            itemBuilder: (context, index) {
                              return buildMenuCard(context, menuItems[index]);
                            },
                          );
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