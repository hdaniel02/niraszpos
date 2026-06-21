import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await profileVM.getCurrentUserProfile();
      setState(() {
        profile = result;
      });
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

  void showEditProfileDialog() {
    if (profile == null) return;

    final nameController = TextEditingController(text: profile!.name);
    final phoneController = TextEditingController(text: profile!.phoneNumber);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.manage_accounts_rounded, color: primaryBlue, size: 28),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Edit Profile", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary)),
                          SizedBox(height: 4),
                          Text("Update your personal details below.", style: TextStyle(fontSize: 14, color: textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
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
                              hintText: "Enter your name",
                              prefixIcon: const Icon(Icons.person_outline_rounded, color: textSecondary),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: "Enter phone number",
                              prefixIcon: const Icon(Icons.phone_outlined, color: textSecondary),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                            ),
                          ),
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
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await profileVM.updateProfile(
                              name: nameController.text.trim(),
                              phoneNumber: phoneController.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            await loadProfile();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
                          }
                        },
                        icon: const Icon(Icons.save_rounded, size: 20),
                        label: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscure1 = true;
    bool obscure2 = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: Colors.red, size: 28),
                      ),
                      const SizedBox(width: 18),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Change Password", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary)),
                            SizedBox(height: 4),
                            Text("Secure your account with a new password.", style: TextStyle(fontSize: 14, color: textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("New Password", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: passwordController,
                              obscureText: obscure1,
                              decoration: InputDecoration(
                                hintText: "Enter new password",
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: textSecondary),
                                suffixIcon: IconButton(
                                  icon: Icon(obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: textSecondary),
                                  onPressed: () => setDialogState(() => obscure1 = !obscure1),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Confirm Password", style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: obscure2,
                              decoration: InputDecoration(
                                hintText: "Confirm new password",
                                prefixIcon: const Icon(Icons.lock_reset_rounded, color: textSecondary),
                                suffixIcon: IconButton(
                                  icon: Icon(obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: textSecondary),
                                  onPressed: () => setDialogState(() => obscure2 = !obscure2),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                              ),
                            ),
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
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final password = passwordController.text.trim();
                            final confirm = confirmPasswordController.text.trim();
                            if (password.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password must be at least 6 characters")));
                              return;
                            }
                            if (password != confirm) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
                              return;
                            }
                            try {
                              await profileVM.changePassword(newPassword: password);
                              if (!mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated successfully")));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
                            }
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: const Text("Update Password", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
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
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? "-" : value,
                  style: const TextStyle(
                    fontSize: 16,
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
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: primaryBlue,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
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
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
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
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 42,
                                      backgroundColor: const Color(0xFFECFDF5),
                                      child: Text(
                                        profile!.name.isNotEmpty
                                            ? profile!.name[0].toUpperCase()
                                            : "U",
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      profile!.name.isEmpty
                                          ? "No Name"
                                          : profile!.name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      profile!.role.isEmpty
                                          ? "User"
                                          : profile!.role[0].toUpperCase() +
                                              profile!.role.substring(1),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              buildInfoTile(
                                icon: Icons.person_outline_rounded,
                                label: "Full Name",
                                value: profile!.name,
                              ),
                              const SizedBox(height: 14),
                              buildInfoTile(
                                icon: Icons.email_outlined,
                                label: "Email Address",
                                value: profile!.email,
                              ),
                              const SizedBox(height: 14),
                              buildInfoTile(
                                icon: Icons.phone_outlined,
                                label: "Phone Number",
                                value: profile!.phoneNumber,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: showEditProfileDialog,
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text("Edit Profile"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              if (profile!.role != 'cashier') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: showChangePasswordDialog,
                                    icon: const Icon(Icons.lock_reset_rounded),
                                    label: const Text("Change Password"),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      side: const BorderSide(color: cardBorder),
                                    ),
                                  ),
                                ),
                              ],
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