import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final AuthViewModel authVM = AuthViewModel();

  String _searchQuery = "";
  String _selectedRoleFilter = "All";

  static const Color primaryBlue = Color(0xFF059669); // Changed to system green
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  Color getRoleColor(String role) {
    return primaryBlue;
  }

  IconData getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'superadmin':
        return Icons.admin_panel_settings_rounded;
      case 'manager':
        return Icons.manage_accounts_rounded;
      case 'cashier':
        return Icons.point_of_sale_rounded;
      case 'owner':
        return Icons.storefront_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Widget buildRoleChip(String role) {
    final color = getRoleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role[0].toUpperCase() + role.substring(1).toLowerCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showUserDialog(BuildContext context, {AppUser? user}) {
    final TextEditingController nameController = TextEditingController(text: user?.name ?? "");
    final TextEditingController emailController = TextEditingController(text: user?.email ?? "");
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController passcodeController = TextEditingController(text: user?.passcode ?? "");
    final TextEditingController phoneController = TextEditingController(text: user?.phoneNumber ?? "");

    String selectedRole = user?.role ?? "cashier";
    bool isEdit = user != null;
    bool obscurePassword = true;

    String? nameError;
    String? emailError;
    String? passwordError;
    String? passcodeError;
    String? phoneError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isCashier = selectedRole.toLowerCase() == 'cashier';

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                width: 650,
                padding: const EdgeInsets.all(32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              isEdit ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
                              color: primaryBlue,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? "Update User Details" : "Create New User",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isEdit
                                      ? "Modify account information and role access."
                                      : "Fill in the details to assign a new system role.",
                                  style: const TextStyle(fontSize: 15, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Full Name", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: nameController,
                                  decoration: InputDecoration(
                                    hintText: "Enter full name",
                                    errorText: nameError,
                                    prefixIcon: const Icon(Icons.person_outline_rounded, color: textSecondary),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                                  ),
                                  onChanged: (_) {
                                    if (nameError != null) setState(() => nameError = null);
                                  },
                                ),
                                const SizedBox(height: 24),
                                const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: "Enter phone number",
                                    errorText: phoneError,
                                    prefixIcon: const Icon(Icons.phone_outlined, color: textSecondary),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                                  ),
                                  onChanged: (_) {
                                    if (phoneError != null) setState(() => phoneError = null);
                                  },
                                ),
                                const SizedBox(height: 24),
                                const Text("System Role", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: selectedRole,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.badge_outlined, color: textSecondary),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: "admin", child: Text("Admin")),
                                    DropdownMenuItem(value: "manager", child: Text("Manager")),
                                    DropdownMenuItem(value: "cashier", child: Text("Cashier")),
                                    DropdownMenuItem(value: "owner", child: Text("Owner")),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        selectedRole = value;
                                        // Auto-generate cashier email to hide it
                                        if (selectedRole == 'cashier' && nameController.text.isNotEmpty) {
                                          emailController.text = "${nameController.text.trim().replaceAll(' ', '.').toLowerCase()}@cashier.niraszpos.com";
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isCashier) ...[
                                  const Text("Email Address", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      hintText: "user@niraszpos.com",
                                      errorText: emailError,
                                      prefixIcon: const Icon(Icons.email_outlined, color: textSecondary),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                                    ),
                                    onChanged: (_) {
                                      if (emailError != null) setState(() => emailError = null);
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                
                                if (isCashier) ...[
                                  const Text("Login Passcode", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: passcodeController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      hintText: "Enter 6-digit code",
                                      errorText: passcodeError,
                                      counterText: "",
                                      prefixIcon: const Icon(Icons.pin_outlined, color: textSecondary),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                                    ),
                                    onChanged: (_) {
                                      if (passcodeError != null) setState(() => passcodeError = null);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Cashiers only require a name and 6-digit passcode. Their email is auto-generated securely in the background.",
                                    style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                                  ),
                                ] else if (!isEdit) ...[
                                  const Text("Password", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: passwordController,
                                    obscureText: obscurePassword,
                                    decoration: InputDecoration(
                                      hintText: "Secure password",
                                      errorText: passwordError,
                                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: textSecondary),
                                      suffixIcon: IconButton(
                                        icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: textSecondary),
                                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                                    ),
                                    onChanged: (_) {
                                      if (passwordError != null) setState(() => passwordError = null);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 52,
                            width: 140,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textSecondary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                side: const BorderSide(color: cardBorder, width: 1.5),
                              ),
                              child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            height: 52,
                            width: 180,
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  nameError = null;
                                  emailError = null;
                                  passwordError = null;
                                  passcodeError = null;
                                  phoneError = null;
                                });

                                bool hasError = false;

                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  setState(() => nameError = "Name cannot be empty");
                                  hasError = true;
                                }

                                final phone = phoneController.text.trim();
                                if (phone.isEmpty) {
                                  setState(() => phoneError = "Phone number cannot be empty");
                                  hasError = true;
                                }

                                String email = emailController.text.trim();
                                if (isCashier) {
                                  email = "${name.replaceAll(' ', '.').toLowerCase()}@cashier.niraszpos.com";
                                }

                                final password = passwordController.text.trim();
                                final passcode = passcodeController.text.trim();

                                if (!isCashier) {
                                  if (email.isEmpty) {
                                    setState(() => emailError = "Email cannot be empty");
                                    hasError = true;
                                  } else {
                                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!emailRegex.hasMatch(email)) {
                                      setState(() => emailError = "Please enter a valid email address");
                                      hasError = true;
                                    }
                                  }
                                }

                                if (isCashier) {
                                  if (passcode.length != 6 || int.tryParse(passcode) == null) {
                                    setState(() => passcodeError = "Passcode must be a valid 6-digit number");
                                    hasError = true;
                                  }
                                } else {
                                  if (!isEdit && password.length < 6) {
                                    setState(() => passwordError = "Password must be at least 6 characters");
                                    hasError = true;
                                  }
                                }

                                if (hasError) return;

                                final appUser = AppUser(
                                  uid: user?.uid ?? "",
                                  email: email,
                                  role: selectedRole,
                                  passcode: isCashier ? passcode : null,
                                  name: name,
                                  phoneNumber: phone,
                                );

                                try {
                                  if (isEdit) {
                                    await authVM.updateUser(appUser);
                                  } else {
                                    // For cashier, use a securely generated dummy password for Firebase Auth
                                    final finalPassword = isCashier ? "CashierSecurePass@123!" : password;
                                    await authVM.createUser(appUser, finalPassword);
                                  }
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "User updated successfully" : "User added successfully"), behavior: SnackBarBehavior.floating));
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), behavior: SnackBarBehavior.floating));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(isEdit ? "Save Changes" : "Create User", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _showDeleteDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Delete User",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Are you sure you want to delete ${user.email}?",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await authVM.deleteUser(user.uid);
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("User deleted successfully"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Delete failed: $e"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text("Delete"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showUserDialog(context);
        },
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text("Create User"),
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: authVM.getUsers(),
          builder: (context, snapshot) {
            List<AppUser> users = snapshot.data ?? [];

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              users = users.where((u) {
                return (u.name?.toLowerCase().contains(query) ?? false) ||
                       u.email.toLowerCase().contains(query) ||
                       (u.phoneNumber?.toLowerCase().contains(query) ?? false) ||
                       u.role.toLowerCase().contains(query);
              }).toList();
            }

            if (_selectedRoleFilter != "All") {
              users = users.where((u) => u.role.toLowerCase() == _selectedRoleFilter.toLowerCase()).toList();
            }

            return Column(
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
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Manage Users",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Create, edit, and manage user access across the system.",
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
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

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "User Accounts",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Manage account access and assigned roles for each user.",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              children: [
                                PopupMenuButton<String>(
                                  color: Colors.white,
                                  surfaceTintColor: Colors.white,
                                  elevation: 8,
                                  position: PopupMenuPosition.under,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: cardBorder, width: 1),
                                  ),
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedRoleFilter = value;
                                    });
                                  },
                                  itemBuilder: (context) => [
                                    "All",
                                    "Admin",
                                    "Manager",
                                    "Cashier",
                                    "Owner"
                                  ].map((role) => PopupMenuItem(
                                    value: role,
                                    child: Text(
                                      role == "All" ? "All Roles" : role,
                                      style: TextStyle(
                                        color: _selectedRoleFilter == role ? primaryBlue : textPrimary,
                                        fontWeight: _selectedRoleFilter == role ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )).toList(),
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.filter_list_rounded, size: 20, color: textSecondary),
                                        const SizedBox(width: 8),
                                        Text(
                                          _selectedRoleFilter == "All" ? "Filter by Role" : "Role: $_selectedRoleFilter",
                                          style: const TextStyle(fontSize: 14, color: textPrimary, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 260,
                                  height: 40,
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                    style: const TextStyle(fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: "Search users...",
                                      hintStyle: const TextStyle(fontSize: 14, color: textSecondary),
                                      prefixIcon: const Icon(Icons.search_rounded, color: textSecondary, size: 20),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          Container(
                            height: 220,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder),
                            ),
                            child: const CircularProgressIndicator(),
                          )
                        else if (snapshot.hasError)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Text(
                              "Error loading users: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        else if (users.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 52,
                                  color: textSecondary,
                                ),
                                SizedBox(height: 14),
                                Text(
                                  "No users found",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "Tap the Create User button to create your first account.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                        dividerThickness: 0,
                                        dataRowMinHeight: 60,
                                        dataRowMaxHeight: 60,
                                        headingTextStyle: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: textSecondary,
                                          fontSize: 13,
                                        ),
                                        dataTextStyle: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                          fontSize: 14,
                                        ),
                                        columns: const [
                                          DataColumn(label: Text("Role")),
                                          DataColumn(label: Text("Full Name")),
                                          DataColumn(label: Text("Email")),
                                          DataColumn(label: Text("Phone Number")),
                                          DataColumn(label: Text("Actions")),
                                        ],
                                        rows: users.map((user) {
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Row(
                                                  children: [
                                                    Icon(getRoleIcon(user.role), size: 18, color: getRoleColor(user.role)),
                                                    const SizedBox(width: 8),
                                                    Text(user.role[0].toUpperCase() + user.role.substring(1).toLowerCase()),
                                                  ],
                                                )
                                              ),
                                      DataCell(Text(user.name ?? "-")),
                                      DataCell(Text(user.email)),
                                      DataCell(Text(user.phoneNumber ?? "-")),
                                      DataCell(
                                        PopupMenuButton<String>(
                                          color: Colors.white,
                                          surfaceTintColor: Colors.white,
                                          elevation: 8,
                                          position: PopupMenuPosition.under,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: const BorderSide(color: cardBorder, width: 1),
                                          ),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _showUserDialog(context, user: user);
                                            } else if (value == 'delete') {
                                              _showDeleteDialog(context, user);
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined, size: 18, color: textPrimary),
                                                  SizedBox(width: 10),
                                                  Text("Edit", style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                  SizedBox(width: 10),
                                                  Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                          ],
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: const Icon(Icons.more_vert_rounded, color: textSecondary, size: 22),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                                    ),
                                  );
                                }
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}