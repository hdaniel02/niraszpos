import 'package:flutter/material.dart';
import '../../../models/shift.dart';
import '../../../viewmodels/shift_viewmodel.dart';

class OwnerShiftsWidget extends StatelessWidget {
  final String role;
  
  const OwnerShiftsWidget({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    if (role != 'owner') {
      return const SizedBox.shrink();
    }

    final shiftVM = ShiftViewModel();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Shift Activity",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/shifts'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text("View All Records"),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1E3A8A)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<Shift>>(
          stream: shiftVM.getAllShifts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final shifts = snapshot.data ?? [];
            if (shifts.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text("No shifts recorded today.", style: TextStyle(color: Color(0xFF64748B))),
              );
            }

            // Take the 3 most recent
            final recentShifts = shifts.take(3).toList();

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentShifts.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, index) {
                  final shift = recentShifts[index];
                  final isCompleted = shift.status == 'completed';
                  
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isCompleted ? Icons.history_rounded : Icons.timer_rounded,
                            color: isCompleted ? const Color(0xFF64748B) : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shift.userName.isEmpty ? 'Unknown User' : shift.userName,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isCompleted ? "Shift Ended" : "Currently Active",
                                style: TextStyle(color: isCompleted ? const Color(0xFF64748B) : Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Start: RM ${shift.startingCash.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isCompleted ? "End: RM ${shift.endingCash!.toStringAsFixed(2)}" : "-",
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A), fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
