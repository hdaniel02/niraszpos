import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/shift_viewmodel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isCashierLogin = true; // Default to cashier passcode login for POS
  // 1 = sliding to Owner/Manager (left), -1 = sliding to Cashier (right)
  int _slideDirection = 1;
  String passcode = "";
  
  bool isLoading = false;
  bool obscurePassword = true;
  String firebaseStatus = "Initializing Firebase...";

  static const Color primaryBlue = Color(0xFF059669); // Emerald Green system
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
// Cashier state variables
String? cashierName;
String? cashierUid;
String? cashierEmail;
bool hasClockedIn = false;
String? clockRecordId;
bool isClocking = false;

  @override
  void initState() {
    super.initState();
    initializeFirebase();
  }

  Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      if (!mounted) return;
      setState(() {
        firebaseStatus = "Firebase connected";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        firebaseStatus = "Firebase connection failed";
      });
    }
  }

  Future<void> lookupCashierByPasscode() async {
    if (passcode.length != 6) return;

    setState(() => isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'cashier')
          .where('passcode', isEqualTo: passcode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception("Invalid passcode. Please try again.");
      }

      final userDoc = snapshot.docs.first;
      final email = userDoc['email'];
      
      // Derive display name from email
      String namePart = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
      String displayName = namePart.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

      // Query shifts for active shift
      final shiftSnapshot = await FirebaseFirestore.instance
          .collection('shifts')
          .where('userId', isEqualTo: userDoc.id)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (!mounted) return;

      setState(() {
        cashierUid = userDoc.id;
        cashierName = displayName;
        cashierEmail = email;
        if (shiftSnapshot.docs.isNotEmpty) {
          hasClockedIn = true;
          clockRecordId = shiftSnapshot.docs.first.id;
        } else {
          hasClockedIn = false;
          clockRecordId = null;
        }
      });
    } catch (e) {
      showError(e.toString().replaceAll("Exception: ", ""));
      setState(() {
        passcode = "";
        cashierUid = null;
        cashierName = null;
        cashierEmail = null;
        hasClockedIn = false;
        clockRecordId = null;
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleCashierAction() async {
    if (cashierUid == null || cashierEmail == null) return;

    if (hasClockedIn) {
      // Already has an active shift, just log in
      setState(() => isClocking = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: cashierEmail!,
          password: "CashierSecurePass@123!",
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/dashboard", arguments: {"role": "cashier"});
      } catch (e) {
        showError("Login failed: $e");
      } finally {
        if (mounted) setState(() => isClocking = false);
      }
      return;
    }

    // Needs to start a new shift: show modal bottom sheet
    // TODO(Hardware): Call your Receipt Printer's openCashDrawer() method here.
    // This will pop the physical cash drawer open so the cashier can count the starting cash.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildStartShiftDrawer(),
    );
  }

  Widget _buildStartShiftDrawer() {
    String cashAmountStr = "";
    bool isLoadingDrawer = false;
    final ShiftViewModel shiftVM = ShiftViewModel();

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
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
                "Start Shift",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter the starting cash amount in the drawer",
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                child: Center(
                  child: Text(
                    cashAmountStr.isEmpty ? "RM 0.00" : "RM $cashAmountStr",
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Custom Numeric Keypad for amount
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDrawerKeypadButton("1", (val) => setModalState(() => cashAmountStr += val)),
                        _buildDrawerKeypadButton("2", (val) => setModalState(() => cashAmountStr += val)),
                        _buildDrawerKeypadButton("3", (val) => setModalState(() => cashAmountStr += val)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDrawerKeypadButton("4", (val) => setModalState(() => cashAmountStr += val)),
                        _buildDrawerKeypadButton("5", (val) => setModalState(() => cashAmountStr += val)),
                        _buildDrawerKeypadButton("6", (val) => setModalState(() => cashAmountStr += val)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDrawerKeypadButton("7", (val) => setModalState(() => cashAmountStr += val)),
                        _buildDrawerKeypadButton("8", (val) => setModalState(() => cashAmountStr += val)),
                        _buildDrawerKeypadButton("9", (val) => setModalState(() => cashAmountStr += val)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDrawerKeypadButton(".", (val) {
                          if (!cashAmountStr.contains(".")) {
                            setModalState(() => cashAmountStr += cashAmountStr.isEmpty ? "0." : ".");
                          }
                        }),
                        _buildDrawerKeypadButton("0", (val) => setModalState(() => cashAmountStr += val)),
                        _buildDrawerKeypadButton("del", (val) {
                          if (cashAmountStr.isNotEmpty) {
                            setModalState(() => cashAmountStr = cashAmountStr.substring(0, cashAmountStr.length - 1));
                          }
                        }, icon: Icons.backspace_outlined),
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
                        side: const BorderSide(color: cardBorder),
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
                              double startingCash = double.tryParse(cashAmountStr) ?? 0.0;
                              setModalState(() => isLoadingDrawer = true);

                              try {
                                // 1. Authenticate with Firebase Auth
                                await FirebaseAuth.instance.signInWithEmailAndPassword(
                                  email: cashierEmail!,
                                  password: "CashierSecurePass@123!",
                                );
                                
                                // 2. Start the shift via ViewModel
                                await shiftVM.startShift(startingCash, cashierName ?? "Cashier", "cashier");

                                if (!context.mounted) return;
                                Navigator.pop(context); // Close drawer
                                Navigator.pushReplacementNamed(context, "/dashboard", arguments: {"role": "cashier"});
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
                              } finally {
                                if (context.mounted) setModalState(() => isLoadingDrawer = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isLoadingDrawer
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Start Shift", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawerKeypadButton(String label, Function(String) onTap, {IconData? icon}) {
    return InkWell(
      onTap: () => onTap(label),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: const Color(0xFF334155), size: 28)
              : Text(
                  label,
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

  Future<void> handleLogin() async {
    final String email = usernameController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showError("Email and password cannot be empty");
      return;
    }

    setState(() => isLoading = true);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final String uid = userCredential.user!.uid;

      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) throw Exception("User record not found in Firestore");

      final data = userDoc.data() as Map<String, dynamic>;
      final String role = (data['role'] ?? '').toString().toLowerCase();

      if (role.isEmpty) throw Exception("User role is missing");
      if (role == 'cashier') throw Exception("Cashiers must sign in using a Passcode.");

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/dashboard", arguments: {"role": role});
    } on FirebaseAuthException catch (e) {
      String message = "Login failed: ${e.message}";
      if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        message = "Invalid email or password.";
      }
      showError(message);
    } catch (e) {
      showError(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
    );
  }

  void onKeypadPress(String value) {
    if (value == "delete") {
      if (passcode.isNotEmpty) {
        setState(() {
          passcode = passcode.substring(0, passcode.length - 1);
        });
      }
      if (cashierName != null) {
        setState(() {
          cashierName = null;
          cashierUid = null;
          cashierEmail = null;
          hasClockedIn = false;
          clockRecordId = null;
        });
      }
    } else {
      if (passcode.length < 6) {
        setState(() {
          passcode += value;
        });
        
        // Auto-lookup when 6 digits are entered
        if (passcode.length == 6) {
          lookupCashierByPasscode();
        }
      }
    }
  }

  Widget buildKeypadButton(String text, {IconData? icon}) {
    bool isAction = text == "del" || text == "empty";
    if (text == "empty") return const Expanded(child: SizedBox());
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: InkWell(
            onTap: () {
              if (text == "del") {
                onKeypadPress("delete");
              } else {
                onKeypadPress(text);
              }
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: primaryBlue.withOpacity(0.1),
            child: Ink(
              decoration: BoxDecoration(
                color: isAction ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isAction ? Colors.transparent : cardBorder),
                boxShadow: isAction ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 28, color: const Color(0xFF64748B))
                    : Text(
                        text,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPasscodeDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        bool isActive = index < passcode.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? primaryBlue : Colors.white,
            border: Border.all(color: isActive ? primaryBlue : const Color(0xFFCBD5E1), width: 2),
            boxShadow: isActive ? [
              BoxShadow(color: primaryBlue.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))
            ] : [],
          ),
        );
      }),
    );
  }

  Future<void> _showForgotPasscodeDialog() async {
    // Fetch cashiers for selection
    List<Map<String, dynamic>> cashiers = [];
    bool fetching = true;
    String? selectedCashierId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (fetching) {
              FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'cashier').get().then((snapshot) {
                if (mounted) {
                  setDialogState(() {
                    cashiers = snapshot.docs.map((doc) {
                      String email = doc['email'];
                      // Extract name: john.doe@email.com -> John Doe
                      String namePart = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
                      String displayName = namePart.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
                      
                      return {"id": doc.id, "email": email, "displayName": displayName};
                    }).toList();
                    fetching = false;
                  });
                }
              }).catchError((e) {
                if (mounted) {
                  setDialogState(() {
                    fetching = false;
                  });
                }
              });
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(color: Color(0xFFFFFBEB), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFD97706), size: 32),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Forgot Passcode",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Select your account to send a passcode reset request to the Store Manager.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    if (fetching)
                      const CircularProgressIndicator()
                    else if (cashiers.isEmpty)
                      const Text("No cashier accounts found.", style: TextStyle(color: Colors.red))
                    else
                      DropdownButtonFormField<String>(
                        value: selectedCashierId,
                        decoration: InputDecoration(
                          hintText: "Select your account",
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                        ),
                        items: cashiers.map((c) {
                          return DropdownMenuItem<String>(
                            value: c["id"],
                            child: Text(c["displayName"]),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedCashierId = val;
                          });
                        },
                      ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                side: const BorderSide(color: cardBorder),
                              ),
                              child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (selectedCashierId == null) {
                                  // Must use dialogContext here so it displays over the dialog
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text("Please select an account")));
                                  return;
                                }

                                final cashier = cashiers.firstWhere((c) => c["id"] == selectedCashierId);

                                try {
                                  await FirebaseFirestore.instance.collection('passcode_requests').add({
                                    'cashierUid': cashier["id"],
                                    'cashierEmail': cashier["email"],
                                    'status': 'pending_manager',
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                                  if (!mounted) return;
                                  Navigator.pop(dialogContext); // Close dialog first
                                  
                                  // Show snackbar on main screen context so it's not destroyed with the dialog
                                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Request sent to Store Manager"), behavior: SnackBarBehavior.floating));
                                } catch (e) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text("Error: $e")));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text("Request Reset", style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
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
      },
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                  child: const Icon(Icons.email_outlined, color: primaryBlue, size: 32),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Reset Password",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Enter your email address to receive a password reset link.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Enter your email",
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: cardBorder),
                          ),
                          child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSending ? null : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text("Please enter your email")));
                              return;
                            }
                            setDialogState(() => isSending = true);
                            try {
                              await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                              if (!mounted) return;
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text("Password reset email sent! Check your inbox."),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
                            } finally {
                              if (mounted) setDialogState(() => isSending = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Send Link", style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildBrandingPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B), // Emerald 900
            Color(0xFF047857), // Emerald 700
            Color(0xFF059669), // Emerald 600
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background ambient light circles for premium visual feel
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.02),
              ),
            ),
          ),
          // Centered content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // App Logo Badge Container
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: -5,
                                )
                              ],
                            ),
                            child: const Icon(
                              Icons.point_of_sale_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            "NiraszPOS",
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          // Soft elegant separator
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 24),
                            width: 60,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const Text(
                            "Welcome",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Sign in to your account",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom footer
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "© 2026 NiraszPOS",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBranding() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.point_of_sale_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "NiraszPOS",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Welcome Back",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Sign in to your account",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle Buttons
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _slideDirection = 1;
                    isCashierLogin = true;
                    passcode = "";
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isCashierLogin ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isCashierLogin
                          ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]
                          : [],
                    ),
                    child: Text(
                      "Cashier Passcode",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: isCashierLogin ? FontWeight.w700 : FontWeight.w500,
                        color: isCashierLogin ? primaryBlue : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _slideDirection = -1;
                    isCashierLogin = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: !isCashierLogin ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: !isCashierLogin
                          ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]
                          : [],
                    ),
                    child: Text(
                      "Owner / Manager",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: !isCashierLogin ? FontWeight.w700 : FontWeight.w500,
                        color: !isCashierLogin ? primaryBlue : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        // Animated slide between Cashier and Owner/Manager views
        // ClipRect keeps the transition contained so the outer border stays static
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              // Incoming slides from the correct direction
              final isIncoming = child.key == ValueKey<bool>(isCashierLogin);
              final offsetBegin = isIncoming
                  ? Offset(-_slideDirection.toDouble(), 0)
                  : Offset(_slideDirection.toDouble(), 0);
              final slideIn = Tween<Offset>(
                begin: offsetBegin,
                end: Offset.zero,
              ).animate(animation);
              return SlideTransition(
                position: slideIn,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: isCashierLogin
                ? _buildCashierView()
                : _buildOwnerView(),
          ),
        ),
      ],
    );
  }



  Widget _buildCashierView() {
    return Column(
      key: const ValueKey<bool>(true),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Passcode dots or identified greeting
        if (cashierName != null)
          Center(
            child: Text(
              "Hi, $cashierName!",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
          )
        else
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(6, (index) {
                bool filled = index < passcode.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? primaryBlue : Colors.grey.shade300,
                  ),
                );
              }),
            ),
          ),
        const SizedBox(height: 24),
        // Keypad
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
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
                    buildKeypadButton("empty"),
                    buildKeypadButton("0"),
                    buildKeypadButton("del", icon: Icons.backspace_outlined),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (cashierName != null) ...[
          Center(
            child: SizedBox(
              width: 320,
              height: 56,
              child: ElevatedButton(
                onPressed: isClocking ? null : handleCashierAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isClocking
                    ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                    : Text(
                        hasClockedIn ? "Continue Shift" : "Clock In",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Center(
          child: TextButton(
            onPressed: _showForgotPasscodeDialog,
            child: const Text("Forgot Passcode?", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerView() {
    return Column(
      key: const ValueKey<bool>(false),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Admin/Manager Email UI
        const Text(
          "Email Address",
          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: usernameController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: "admin@niraszpos.com",
            prefixIcon: const Icon(Icons.email_outlined),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "Password",
          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            hintText: "Enter your password",
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => obscurePassword = !obscurePassword),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            child: const Text("Forgot Password?", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : handleLogin,
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: isLoading
                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                : const Text("Sign In to NiraszPOS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 840;

          if (isWide) {
            return Row(
              children: [
                // Left Panel (Branding)
                Expanded(
                  flex: 4,
                  child: _buildBrandingPanel(),
                ),

                // Right Panel (Login Form)
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: _buildLoginForm(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Mobile/Portrait Layout
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF064E3B), // Emerald 900
                    Color(0xFF047857), // Emerald 700
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Mobile Branding (Centered at the top)
                        _buildMobileBranding(),
                        const SizedBox(height: 32),
                        // Mobile Form Container
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 36,
                          ),
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _buildLoginForm(),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "© 2026 NiraszPOS",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
