import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/shift.dart';
import '../../../viewmodels/shift_viewmodel.dart';
import '../../../viewmodels/profile_viewmodel.dart';

class ShiftWidget extends StatefulWidget {
  final String userRole;
  const ShiftWidget({super.key, required this.userRole});

  @override
  State<ShiftWidget> createState() => _ShiftWidgetState();
}

class _ShiftWidgetState extends State<ShiftWidget> {
  final ShiftViewModel shiftVM = ShiftViewModel();
  final ProfileViewModel profileVM = ProfileViewModel();
  
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  Timer? _timer;
  Stream<List<Shift>>? _activeShiftsStream;
  
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && (widget.userRole == 'manager' || widget.userRole == 'cashier')) {
      _activeShiftsStream = shiftVM.getActiveShifts(user.uid);
    }
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(DateTime start) {
    final diff = DateTime.now().difference(start);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  void _onKeypadPress(String value, TextEditingController controller) {
    if (value == "delete") {
      if (controller.text.isNotEmpty) {
        controller.text = controller.text.substring(0, controller.text.length - 1);
      }
    } else if (value == ".") {
      if (!controller.text.contains(".")) {
        if (controller.text.isEmpty) {
          controller.text = "0.";
        } else {
          controller.text += ".";
        }
      }
    } else {
      // Limit decimal places to 2
      if (controller.text.contains(".")) {
        final parts = controller.text.split(".");
        if (parts.length > 1 && parts[1].length >= 2) return;
      }
      if (controller.text == "0") {
         controller.text = value;
      } else {
         controller.text += value;
      }
    }
  }

  Widget _buildKeypadButton(String text, TextEditingController controller, {IconData? icon}) {
    bool isAction = text == "del";
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: AspectRatio(
          aspectRatio: 2.0,
          child: InkWell(
            onTap: () {
              if (text == "del") {
                _onKeypadPress("delete", controller);
              } else {
                _onKeypadPress(text, controller);
              }
            },
            borderRadius: BorderRadius.circular(12),
            splashColor: primaryBlue.withOpacity(0.1),
            child: Ink(
              decoration: BoxDecoration(
                color: isAction ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isAction ? Colors.transparent : cardBorder),
                boxShadow: isAction ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 24, color: const Color(0xFF64748B))
                    : Text(
                        text,
                        style: const TextStyle(
                          fontSize: 22,
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

  Future<void> _showStartShiftDialog() async {
    final cashController = TextEditingController();
    bool isLoading = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.play_circle_fill_rounded, color: Colors.green, size: 32),
                    SizedBox(width: 12),
                    Text("Start Shift", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Enter the starting cash amount in the drawer.", style: TextStyle(color: textSecondary)),
                const SizedBox(height: 24),
                TextField(
                  controller: cashController,
                  readOnly: true, // Show our own keypad instead of system keyboard
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryBlue),
                  decoration: InputDecoration(
                    hintText: "0.00",
                    hintStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textSecondary),
                    prefixIcon: const Icon(Icons.attach_money_rounded, color: primaryBlue, size: 28),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                // Custom Numeric Keypad
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(children: [_buildKeypadButton("1", cashController), _buildKeypadButton("2", cashController), _buildKeypadButton("3", cashController)]),
                      Row(children: [_buildKeypadButton("4", cashController), _buildKeypadButton("5", cashController), _buildKeypadButton("6", cashController)]),
                      Row(children: [_buildKeypadButton("7", cashController), _buildKeypadButton("8", cashController), _buildKeypadButton("9", cashController)]),
                      Row(children: [_buildKeypadButton(".", cashController), _buildKeypadButton("0", cashController), _buildKeypadButton("del", cashController, icon: Icons.backspace_outlined)]),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isLoading ? null : () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        final val = double.tryParse(cashController.text.trim());
                        if (val == null || val < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid amount")));
                          return;
                        }
                        setDialogState(() => isLoading = true);
                        try {
                          final profile = await profileVM.getCurrentUserProfile();
                          final pName = profile?.name ?? '';
                          final pEmail = profile?.email ?? '';
                          final fallback = pEmail.isNotEmpty ? pEmail.split('@')[0] : 'Unknown User';
                          final finalName = pName.isEmpty ? fallback : pName;
                          await shiftVM.startShift(val, finalName, widget.userRole);
                          if (!mounted) return;
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                        } finally {
                          if (mounted) setDialogState(() => isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Clock In", style: TextStyle(fontWeight: FontWeight.w700)),
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

  Future<void> _showEndShiftDialog(String shiftId) async {
    final cashController = TextEditingController();
    final cardController = TextEditingController();
    final qrController = TextEditingController();
    bool isLoading = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stop_circle_rounded, color: Colors.red, size: 32),
                    SizedBox(width: 12),
                    Text("End Shift", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textPrimary)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text("Enter the ending totals from your drawer and terminals.", style: TextStyle(color: textSecondary)),
                const SizedBox(height: 24),
                TextField(
                  controller: cashController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Ending Cash (Drawer)",
                    hintText: "0.00",
                    prefixIcon: const Icon(Icons.attach_money_rounded, color: Colors.green),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cardController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Ending Card (EDC Terminal)",
                    hintText: "0.00",
                    prefixIcon: const Icon(Icons.credit_card_rounded, color: Colors.blue),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qrController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Ending QR (QR Terminal)",
                    hintText: "0.00",
                    prefixIcon: const Icon(Icons.qr_code_rounded, color: Colors.purple),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isLoading ? null : () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        final cashVal = double.tryParse(cashController.text.trim()) ?? 0.0;
                        final cardVal = double.tryParse(cardController.text.trim()) ?? 0.0;
                        final qrVal = double.tryParse(qrController.text.trim()) ?? 0.0;

                        setDialogState(() => isLoading = true);
                        try {
                          await shiftVM.endShift(shiftId, cashVal, cardVal, qrVal);
                          if (!mounted) return;
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                        } finally {
                          if (mounted) setDialogState(() => isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Clock Out", style: TextStyle(fontWeight: FontWeight.w700)),
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

  @override
  Widget build(BuildContext context) {
    if (_activeShiftsStream == null) {
      return const SizedBox.shrink(); // Only Managers and Cashiers clock in
    }

    return StreamBuilder<List<Shift>>(
      stream: _activeShiftsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
        }

        final activeShifts = snapshot.data ?? [];
        final hasActiveShift = activeShifts.isNotEmpty;

        if (hasActiveShift) {
          final shift = activeShifts.first;
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.timer_rounded, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Active Shift", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF166534))),
                      const SizedBox(height: 4),
                      Text("Clocked in at: ${shift.startTime.hour.toString().padLeft(2, '0')}:${shift.startTime.minute.toString().padLeft(2, '0')}", style: const TextStyle(color: Color(0xFF15803D), fontSize: 13)),
                      Text("Duration: ${_formatDuration(shift.startTime)}", style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEndShiftDialog(shift.id),
                  icon: const Icon(Icons.stop_circle_rounded, size: 18),
                  label: const Text("Clock Out"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cardBorder),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.play_circle_fill_rounded, color: textSecondary, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("No Active Shift", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textPrimary)),
                      SizedBox(height: 4),
                      Text("Please clock in to start your shift and process transactions.", style: TextStyle(color: textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showStartShiftDialog,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text("Clock In"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
