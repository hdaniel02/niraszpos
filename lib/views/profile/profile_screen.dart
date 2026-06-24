import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onNotificationTapped;
  final bool hasNotification;
  final VoidCallback? onRefreshTapped;

  const ProfileScreen({
    super.key,
    this.onNotificationTapped,
    this.hasNotification = false,
    this.onRefreshTapped,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileViewModel profileVM = ProfileViewModel();

  static const Color primaryBlue = Color(0xFF059669); // Emerald Green system
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  bool isLoading = true;
  UserProfile? profile;

  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  bool obscure1 = true;
  bool obscure2 = true;
  bool hasChanges = false;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    phoneController = TextEditingController();
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
    
    void checkForChanges() {
      if (profile == null) return;
      final bool changed = nameController.text.trim() != profile!.name ||
          phoneController.text.trim() != profile!.phoneNumber ||
          passwordController.text.isNotEmpty ||
          confirmPasswordController.text.isNotEmpty;
      if (hasChanges != changed) {
        setState(() {
          hasChanges = changed;
        });
      }
    }

    nameController.addListener(checkForChanges);
    phoneController.addListener(checkForChanges);
    passwordController.addListener(checkForChanges);
    confirmPasswordController.addListener(checkForChanges);

    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await profileVM.getCurrentUserProfile();
      if (result != null) {
        profile = result;
        nameController.text = profile!.name;
        phoneController.text = profile!.phoneNumber;
        emailController.text = profile!.email;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load profile: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (profile == null) return;

    try {
      await profileVM.updateProfile(
        name: nameController.text.trim(),
        phoneNumber: phoneController.text.trim(),
      );

      final password = passwordController.text.trim();
      final confirm = confirmPasswordController.text.trim();

      if (password.isNotEmpty) {
        if (password.length < 6) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters")));
          return;
        }
        if (password != confirm) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
          return;
        }
        await profileVM.changePassword(newPassword: password);
        passwordController.clear();
        confirmPasswordController.clear();
      }

      await loadProfile();
      if (mounted) {
        setState(() {
          isEditing = false;
          hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          obscureText: isPassword && obscureText,
          keyboardType: keyboardType,
          style: TextStyle(color: readOnly ? textSecondary : textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: textSecondary),
                    onPressed: onToggleObscure,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : profile == null
                ? const Center(
                    child: Text(
                      "Profile not found",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Manage Profile",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "View and update your account information.",
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
                                      onPressed: widget.onRefreshTapped,
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
                      
                      // Body Layout
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Side: Avatar and Role
                              Expanded(
                                flex: 2,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 80,
                                      backgroundColor: primaryBlue,
                                      child: Text(
                                        profile!.name.isNotEmpty
                                            ? profile!.name[0].toUpperCase()
                                            : "U",
                                        style: const TextStyle(
                                          fontSize: 64,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      profile!.role.isEmpty
                                          ? "User"
                                          : profile!.role[0].toUpperCase() + profile!.role.substring(1),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (!isEditing) ...[
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            isEditing = true;
                                          });
                                        },
                                        icon: const Icon(Icons.edit_rounded, size: 16),
                                        label: const Text("Edit Profile"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: primaryBlue, // Also changing text/icon color to green to match border nicely
                                          elevation: 0,
                                          side: const BorderSide(color: primaryBlue, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              
                              // Vertical Divider
                              Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(horizontal: 32),
                                color: cardBorder,
                              ),
                              
                              // Right Side: Form
                              Expanded(
                                flex: 3,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildTextField(label: "Name", controller: nameController, readOnly: !isEditing),
                                            _buildTextField(label: "Phone Number", controller: phoneController, keyboardType: TextInputType.phone, readOnly: !isEditing),
                                            _buildTextField(label: "Email", controller: emailController, readOnly: true),
                                            
                                            AnimatedSize(
                                              duration: const Duration(milliseconds: 400),
                                              curve: Curves.easeOutCubic,
                                              alignment: Alignment.topCenter,
                                              child: AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 300),
                                                switchInCurve: Curves.easeOut,
                                                switchOutCurve: Curves.easeIn,
                                                child: !isEditing
                                                    ? const SizedBox(key: ValueKey('empty'), width: double.infinity)
                                                    : Column(
                                                        key: const ValueKey('edit_form'),
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          if (profile!.role != 'cashier') ...[
                                                            _buildTextField(
                                                              label: "New Password", 
                                                              controller: passwordController,
                                                              isPassword: true,
                                                              obscureText: obscure1,
                                                              onToggleObscure: () => setState(() => obscure1 = !obscure1),
                                                            ),
                                                            _buildTextField(
                                                              label: "Retype New Password", 
                                                              controller: confirmPasswordController,
                                                              isPassword: true,
                                                              obscureText: obscure2,
                                                              onToggleObscure: () => setState(() => obscure2 = !obscure2),
                                                            ),
                                                          ],
                                                          const SizedBox(height: 16),
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: SizedBox(
                                                                  height: 52,
                                                                  child: ElevatedButton(
                                                                    onPressed: () {
                                                                      // Reset changes
                                                                      nameController.text = profile!.name;
                                                                      phoneController.text = profile!.phoneNumber;
                                                                      passwordController.clear();
                                                                      confirmPasswordController.clear();
                                                                      setState(() {
                                                                        isEditing = false;
                                                                        hasChanges = false;
                                                                      });
                                                                    },
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: Colors.grey.shade200,
                                                                      foregroundColor: textPrimary,
                                                                      elevation: 0,
                                                                      shape: RoundedRectangleBorder(
                                                                        borderRadius: BorderRadius.circular(30),
                                                                      ),
                                                                    ),
                                                                    child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(width: 16),
                                                              Expanded(
                                                                child: SizedBox(
                                                                  height: 52,
                                                                  child: ElevatedButton(
                                                                    onPressed: _saveChanges,
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: primaryBlue,
                                                                      foregroundColor: Colors.white,
                                                                      elevation: 0,
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                                                    ),
                                                                    child: const Text("Save", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
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