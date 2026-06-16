import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/sales.dart';
import '../../viewmodels/sales_viewmodel.dart';

class RefundsScreen extends StatefulWidget {
  final String role;
  const RefundsScreen({super.key, required this.role});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  final SalesViewModel salesVM = SalesViewModel();

  Map<String, String> _cashierNames = {};

  @override
  void initState() {
    super.initState();
    _loadCashierNames();
  }

  Future<void> _loadCashierNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final Map<String, String> names = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) {
          names[doc.id] = name;
        }
      }
      if (mounted) {
        setState(() {
          _cashierNames = names;
        });
      }
    } catch (e) {
      // fallback
    }
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }

  String getCashierDisplayName(String cashierId, String cashierEmail) {
    final name = _cashierNames[cashierId];
    if (name != null && name.isNotEmpty) {
      return toTitleCase(name);
    }
    if (cashierEmail.contains('@')) {
      return toTitleCase(cashierEmail.split('@').first);
    }
    return toTitleCase(cashierEmail);
  }

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  String _searchQuery = '';
  String _selectedStatus = 'Pending Approval'; // 'All', 'Pending Approval', 'Approved', 'Rejected'

  String formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Widget _statCard({required IconData icon, required String title, required String value, required Color color, required Color bg}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary),
                  overflow: TextOverflow.ellipsis,
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCashier = widget.role.toLowerCase() == 'cashier';

    final Stream<List<Map<String, dynamic>>> refundStream = isCashier
        ? salesVM.getCashierRefundRequestsStream(currentUserId ?? '')
        : salesVM.getAllRefundRequestsStream();

    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: refundStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allRequests = snapshot.data ?? [];

            // Compute statistics
            final pendingCount = allRequests.where((r) => r['status'] == 'pending').length;
            final approvedRequests = allRequests.where((r) => r['status'] == 'approved').toList();
            final approvedCount = approvedRequests.length;
            final double totalRefunded = approvedRequests.fold(0.0, (acc, r) => acc + (r['total'] ?? 0.0));

            // Filtering based on status & search
            List<Map<String, dynamic>> filteredRequests = allRequests;

            if (_selectedStatus == 'Pending Approval') {
              filteredRequests = filteredRequests.where((r) => r['status'] == 'pending').toList();
            } else if (_selectedStatus == 'Approved') {
              filteredRequests = filteredRequests.where((r) => r['status'] == 'approved').toList();
            } else if (_selectedStatus == 'Rejected') {
              filteredRequests = filteredRequests.where((r) => r['status'] == 'rejected').toList();
            }

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              filteredRequests = filteredRequests.where((r) {
                final receiptNo = (r['receiptNo'] ?? '').toString().toLowerCase();
                final cashierEmail = (r['cashierEmail'] ?? '').toString().toLowerCase();
                final customerName = (r['customerFullName'] ?? '').toString().toLowerCase();
                final bankAccount = (r['bankAccountNumber'] ?? '').toString().toLowerCase();
                return receiptNo.contains(query) ||
                    cashierEmail.contains(query) ||
                    customerName.contains(query) ||
                    bankAccount.contains(query);
              }).toList();
            }

            return Column(
              children: [
                // Header Area
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: cardBorder)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.assignment_return_rounded,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Refund Requests',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Track customer refund requests, view transfer information, and manage approvals.',
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

                // Main Scrollable Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Section
                        LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 1;
                            if (constraints.maxWidth > 950) {
                              crossAxisCount = 3;
                            } else if (constraints.maxWidth > 600) {
                              crossAxisCount = 2;
                            }

                            return GridView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 3.2,
                              ),
                              children: [
                                _statCard(
                                  icon: Icons.hourglass_top_rounded,
                                  title: "PENDING APPROVALS",
                                  value: pendingCount.toString(),
                                  color: Colors.orange.shade800,
                                  bg: Colors.orange.shade50,
                                ),
                                _statCard(
                                  icon: Icons.check_circle_rounded,
                                  title: "APPROVED REFUNDS",
                                  value: approvedCount.toString(),
                                  color: Colors.green.shade700,
                                  bg: Colors.green.shade50,
                                ),
                                _statCard(
                                  icon: Icons.monetization_on_rounded,
                                  title: "TOTAL REFUNDED AMOUNT",
                                  value: "RM ${totalRefunded.toStringAsFixed(2)}",
                                  color: primaryBlue,
                                  bg: const Color(0xFFEFF6FF),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Search and Filter Hub
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Filter tabs
                              Row(
                                children: ['All', 'Pending Approval', 'Approved', 'Rejected'].map((status) {
                                  final isSelected = _selectedStatus == status;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(status),
                                      selected: isSelected,
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() => _selectedStatus = status);
                                        }
                                      },
                                      selectedColor: primaryBlue,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      side: const BorderSide(color: Colors.transparent),
                                      showCheckmark: false,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),

                              // Search Bar
                              Container(
                                height: 38,
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                                child: TextField(
                                  textAlignVertical: TextAlignVertical.center,
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  decoration: const InputDecoration(
                                    hintText: "Search receipt, cashier, customer full name, or bank account...",
                                    hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                                    prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
                                    prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 38),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              if (filteredRequests.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 60),
                                  child: Center(
                                    child: Text(
                                      "No refund requests found.",
                                      style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                )
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    int columns = 1;
                                    if (constraints.maxWidth > 1050) {
                                      columns = 3;
                                    } else if (constraints.maxWidth > 700) {
                                      columns = 2;
                                    }

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: filteredRequests.length,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 0.85,
                                      ),
                                      itemBuilder: (context, index) {
                                        return _buildRefundRequestCard(filteredRequests[index]);
                                      },
                                    );
                                  },
                                ),
                            ],
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

  Widget _buildRefundRequestCard(Map<String, dynamic> req) {
    final reqId = req['id'] as String;
    final receiptNo = req['receiptNo'] as String;
    final cashierId = (req['cashierId'] ?? '') as String;
    final cashierEmail = req['cashierEmail'] as String;
    final total = (req['total'] ?? 0.0).toDouble();
    final status = req['status'] as String;
    final rawTime = req['createdAt'];
    final DateTime createdAt = rawTime is Timestamp ? rawTime.toDate() : DateTime.now();

    final bankNo = req['bankAccountNumber'] as String?;
    final custName = req['customerFullName'] as String?;
    final custPhone = req['customerPhoneNumber'] as String?;

    final itemsList = (req['items'] as List<dynamic>? ?? [])
        .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    // Status Styling
    Color statusBg = Colors.orange.shade50;
    Color statusColor = Colors.orange.shade800;
    if (status == 'approved') {
      statusBg = Colors.green.shade50;
      statusColor = Colors.green.shade700;
    } else if (status == 'rejected') {
      statusBg = Colors.red.shade50;
      statusColor = Colors.red.shade700;
    }

    final isCardOrQr = bankNo != null || custName != null;
    final isManager = widget.role.toLowerCase() != 'cashier';
    final isCashier = widget.role.toLowerCase() == 'cashier';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Receipt No and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        receiptNo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cashier & Time
          Text(
            "Cashier: ${getCashierDisplayName(cashierId, cashierEmail)}",
            style: const TextStyle(fontSize: 12, color: textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            "Date: ${formatDateTime(createdAt)}",
            style: const TextStyle(fontSize: 12, color: textSecondary),
          ),
          const Divider(height: 20, color: cardBorder),

          // Customer Transfer Details / Method
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("REFUND METHOD & DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  if (isCardOrQr) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: cardBorder)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (custName != null) Text("Name: $custName", style: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
                          if (bankNo != null) Text("Bank Account: $bankNo", style: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
                          if (custPhone != null) Text("Phone: $custPhone", style: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text("Refund Method: Cash", style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 12),

                  // Refund items list
                  const Text("ITEMS TO REFUND", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  ...itemsList.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(item.name, style: const TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                            Text("x${item.quantity}", style: const TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          const Divider(height: 20, color: cardBorder),

          // Total and Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Refund Value", style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold)),
              Text(
                "RM ${total.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryBlue),
              ),
            ],
          ),

          if (isManager && status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await salesVM.rejectRefundRequest(reqId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund request rejected."), backgroundColor: Colors.orange));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text("Reject", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await salesVM.approveRefundRequest(reqId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund request approved and processed."), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text("Approve", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else if (isCashier && status == 'pending') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
              child: Text(
                "Pending Manager Approval",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
