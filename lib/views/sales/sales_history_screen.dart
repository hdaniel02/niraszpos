import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/sales.dart';
import '../../viewmodels/sales_viewmodel.dart';

class SalesHistoryScreen extends StatefulWidget {
  final String role;
  const SalesHistoryScreen({super.key, required this.role});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
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

  String getCashierDisplayName(Sale sale) {
    final name = _cashierNames[sale.cashierId];
    if (name != null && name.isNotEmpty) {
      return toTitleCase(name);
    }
    if (sale.cashierEmail.contains('@')) {
      return toTitleCase(sale.cashierEmail.split('@').first);
    }
    return toTitleCase(sale.cashierEmail);
  }

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  String _searchQuery = '';
  String _sortOption = 'Date: Newest';

  String formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
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
            style: TextStyle(fontSize: 14, color: valueColor, fontWeight: bold ? FontWeight.bold : FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // Refund dialog with dynamic text input for bank details
  void _showRefundItemsDialog(BuildContext context, Sale sale, bool isImmediate) {
    final Map<String, int> selectedQuantities = {};
    for (final item in sale.items) {
      selectedQuantities[item.productId] = 0;
    }

    final isCardOrQr = sale.paymentMethod.toLowerCase() == 'card' ||
        sale.paymentMethod.toLowerCase() == 'qr';

    final nameController = TextEditingController();
    final bankNoController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double totalRefund = 0.0;
            int totalQty = 0;

            for (final item in sale.items) {
              final qty = selectedQuantities[item.productId] ?? 0;
              totalRefund += qty * item.price;
              totalQty += qty;
            }

            // Validation: must select at least one item, and if Card/QR, must provide bank transfer info
            bool isFormValid = totalQty > 0;
            if (isFormValid && isCardOrQr) {
              isFormValid = nameController.text.trim().isNotEmpty &&
                  bankNoController.text.trim().isNotEmpty &&
                  phoneController.text.trim().isNotEmpty;
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.assignment_return_rounded, color: Colors.orange.shade700, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Select Refund Items",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textPrimary),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Specify the quantities to refund:",
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                      const SizedBox(height: 14),

                      // List of items
                      ...sale.items.map((item) {
                        final maxRefundable = item.quantity - item.refundedQuantity;
                        final currentSelected = selectedQuantities[item.productId] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "RM ${item.price.toStringAsFixed(2)}  •  Purchased: ${item.quantity} (${item.refundedQuantity} ref)",
                                      style: const TextStyle(fontSize: 12, color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: currentSelected > 0
                                        ? () {
                                            setDialogState(() {
                                              selectedQuantities[item.productId] = currentSelected - 1;
                                            });
                                          }
                                        : null,
                                  ),
                                  Text(
                                    "$currentSelected",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: currentSelected < maxRefundable
                                        ? () {
                                            setDialogState(() {
                                              selectedQuantities[item.productId] = currentSelected + 1;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      if (isCardOrQr) ...[
                        const SizedBox(height: 16),
                        const Divider(color: cardBorder),
                        const SizedBox(height: 12),
                        const Text(
                          "CUSTOMER TRANSFER INFORMATION",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textSecondary, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: "Customer Full Name",
                            labelStyle: const TextStyle(fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: bankNoController,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: "Bank Account Number",
                            labelStyle: const TextStyle(fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: phoneController,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: "Phone Number",
                            labelStyle: const TextStyle(fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Refund", style: TextStyle(fontWeight: FontWeight.w600, color: textSecondary)),
                            Text(
                              "RM ${totalRefund.toStringAsFixed(2)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryBlue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isFormValid
                      ? () async {
                          Navigator.pop(dialogContext);
                          final List<SaleItem> refundItems = [];
                          selectedQuantities.forEach((prodId, qty) {
                            if (qty > 0) {
                              final originalItem = sale.items.firstWhere((i) => i.productId == prodId);
                              refundItems.add(SaleItem(
                                productId: prodId,
                                name: originalItem.name,
                                price: originalItem.price,
                                quantity: qty,
                                refundedQuantity: 0,
                              ));
                            }
                          });

                          try {
                            if (isImmediate) {
                              await salesVM.processImmediateRefund(
                                sale: sale,
                                refundItems: refundItems,
                                refundAmount: totalRefund,
                                bankAccountNumber: isCardOrQr ? bankNoController.text.trim() : null,
                                customerFullName: isCardOrQr ? nameController.text.trim() : null,
                                customerPhoneNumber: isCardOrQr ? phoneController.text.trim() : null,
                              );
                            } else {
                              await salesVM.submitRefundRequest(
                                sale: sale,
                                refundItems: refundItems,
                                refundAmount: totalRefund,
                                bankAccountNumber: isCardOrQr ? bankNoController.text.trim() : null,
                                customerFullName: isCardOrQr ? nameController.text.trim() : null,
                                customerPhoneNumber: isCardOrQr ? phoneController.text.trim() : null,
                              );
                            }

                            if (context.mounted) {
                              Navigator.pop(context); // Close details dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isImmediate 
                                      ? "Refund processed successfully!" 
                                      : "Refund request submitted to manager."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Failed to request refund: $e"), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(isImmediate ? "Confirm Refund" : "Request Approval"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Transactions details dialog showing items and refund button
  void showSaleDetailsDialog(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) {
        final isImmediate = widget.role.toLowerCase() != 'cashier';
        final isFullyRefunded = sale.refundStatus == 'full';

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: primaryBlue),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipt Details',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'View full transaction information.',
                                style: TextStyle(fontSize: 14, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        children: [
                          _detailRow('Receipt No', sale.receiptNo),
                          const SizedBox(height: 12),
                          _detailRow('Payment', sale.paymentMethod),
                          const SizedBox(height: 12),
                          _detailRow('Cashier', sale.cashierEmail),
                          const SizedBox(height: 12),
                          _detailRow('Date', formatDateTime(sale.createdAt)),
                          const SizedBox(height: 12),
                          _detailRow(
                            'Total',
                            'RM ${sale.total.toStringAsFixed(2)}',
                            valueColor: primaryBlue,
                            bold: true,
                          ),
                          if (sale.refundStatus != null) ...[
                            const SizedBox(height: 12),
                            _detailRow(
                              'Refund Status',
                              sale.refundStatus == 'full' ? 'Fully Refunded' : 'Partially Refunded',
                              valueColor: sale.refundStatus == 'full' ? Colors.red : Colors.orange,
                              bold: true,
                            ),
                            const SizedBox(height: 12),
                            _detailRow(
                              'Total Refunded',
                              'RM ${sale.refundedAmount.toStringAsFixed(2)}',
                              valueColor: Colors.red,
                              bold: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Refund Request History (StreamBuilder)
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: salesVM.getRefundRequestsForSale(sale.id),
                      builder: (context, snapshot) {
                        final requests = snapshot.data ?? [];
                        final hasPending = requests.any((r) => r['status'] == 'pending');

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (requests.isNotEmpty) ...[
                              const Text(
                                "Refund Request History",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
                              ),
                              const SizedBox(height: 10),
                              ...requests.map((req) {
                                final status = req['status'] as String;
                                final total = (req['total'] ?? 0.0).toDouble();
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Refund Value: RM ${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(
                                            req['bankAccountNumber'] != null 
                                                ? "Bank: ${req['bankAccountNumber']}" 
                                                : "Method: Cash",
                                            style: const TextStyle(fontSize: 11, color: textSecondary),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: status == 'approved' 
                                              ? Colors.green.shade50 
                                              : (status == 'rejected' ? Colors.red.shade50 : Colors.orange.shade50),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: status == 'approved' 
                                                ? Colors.green.shade700 
                                                : (status == 'rejected' ? Colors.red.shade700 : Colors.orange.shade800),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                            ],

                            if (hasPending) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.hourglass_empty_rounded, color: Colors.orange.shade800),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        "Refund request pending manager approval.",
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                          ],
                        );
                      },
                    ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Items Purchased',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(height: 14),
                          ...sale.items.map((item) {
                            final subtotal = item.price * item.quantity;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'RM ${item.price.toStringAsFixed(2)} x ${item.quantity}${item.refundedQuantity > 0 ? ' (${item.refundedQuantity} refunded)' : ''}',
                                          style: const TextStyle(fontSize: 13, color: textSecondary),
                                        ),
                                      ),
                                      Text(
                                        'RM ${subtotal.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryBlue),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: const BorderSide(color: cardBorder),
                              ),
                              child: const Text('Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textSecondary)),
                            ),
                          ),
                        ),
                        if (!isFullyRefunded) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  _showRefundItemsDialog(context, sale, isImmediate);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(
                                  isImmediate ? 'Process Refund' : 'Request Refund',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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



  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: StreamBuilder<List<Sale>>(
          stream: salesVM.getSales(),
          builder: (context, salesSnapshot) {
            if (salesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final sales = salesSnapshot.data ?? [];

            // Filter by role
            List<Sale> displaySales = widget.role.toLowerCase() == 'cashier'
                ? sales.where((s) => s.cashierId == currentUserId).toList()
                : sales;

            // Search query filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              displaySales = displaySales.where((s) =>
                s.receiptNo.toLowerCase().contains(query) ||
                s.cashierEmail.toLowerCase().contains(query) ||
                s.paymentMethod.toLowerCase().contains(query)
              ).toList();
            }

            // Sorting
            if (_sortOption == 'Date: Newest') {
              displaySales.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            } else if (_sortOption == 'Date: Oldest') {
              displaySales.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            } else if (_sortOption == 'Amount: Highest') {
              displaySales.sort((a, b) => b.total.compareTo(a.total));
            } else if (_sortOption == 'Amount: Lowest') {
              displaySales.sort((a, b) => a.total.compareTo(b.total));
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
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales History',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Search past transactions, view receipt details, and request or process refunds.',
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

                // Filters & Grid Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search & Sort bar
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                                  child: TextField(
                                    textAlignVertical: TextAlignVertical.center,
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                    decoration: const InputDecoration(
                                      hintText: "Search receipt, cashier, or payment method...",
                                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                                      prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
                                      prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 36),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _sortOption,
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary),
                                    items: ['Date: Newest', 'Date: Oldest', 'Amount: Highest', 'Amount: Lowest'].map((e) {
                                      return DropdownMenuItem(value: e, child: Text(e));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _sortOption = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (displaySales.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: Text("No transactions found.", style: TextStyle(color: textSecondary))),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final double tableWidth = constraints.maxWidth > 950 ? constraints.maxWidth : 950;
                                const headerStyle = TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13);
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Table Header
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          child: Row(
                                            children: [
                                              Expanded(flex: 1, child: Text('#', style: headerStyle)),
                                              Expanded(flex: 3, child: Text('RECEIPT NO', style: headerStyle)),
                                              Expanded(flex: 5, child: Text('CASHIER', style: headerStyle, textAlign: TextAlign.center)),
                                              Expanded(flex: 3, child: Text('DATE & TIME', style: headerStyle, textAlign: TextAlign.center)),
                                              Expanded(flex: 2, child: Text('PAYMENT', style: headerStyle, textAlign: TextAlign.center)),
                                              Expanded(flex: 2, child: Text('TOTAL', style: headerStyle, textAlign: TextAlign.center)),
                                              Expanded(flex: 3, child: Text('STATUS', style: headerStyle, textAlign: TextAlign.center)),
                                              Expanded(flex: 2, child: Text('ACTION', style: headerStyle, textAlign: TextAlign.center)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // Table Rows
                                        ...displaySales.asMap().entries.map((entry) {
                                          final index = entry.key;
                                          final sale = entry.value;

                                          // Refund status color & text
                                          Color badgeColor = Colors.green.shade700;
                                          Color badgeBg = Colors.green.shade50;
                                          String statusText = "Completed";

                                          if (sale.refundStatus == 'full') {
                                            badgeColor = Colors.red.shade700;
                                            badgeBg = Colors.red.shade50;
                                            statusText = "Fully Refunded";
                                          } else if (sale.refundStatus == 'partial') {
                                            badgeColor = Colors.orange.shade800;
                                            badgeBg = Colors.orange.shade50;
                                            statusText = "Partially Refunded";
                                          }

                                          return Container(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: index % 2 == 0 ? const Color(0xFFF8FAFC) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: Row(
                                              children: [
                                                  Expanded(
                                                    flex: 1,
                                                    child: Text(
                                                      '${index + 1}',
                                                      style: const TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13),
                                                    ),
                                                  ),
                                                // Receipt No
                                                Expanded(
                                                  flex: 3,
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.receipt_long_outlined, size: 16, color: primaryBlue),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          sale.receiptNo,
                                                          style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 13),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                  Expanded(
                                                    flex: 5,
                                                    child: Text(
                                                      getCashierDisplayName(sale),
                                                      style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 13),
                                                      textAlign: TextAlign.center,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                // Date & Time
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    formatDateTime(sale.createdAt),
                                                    style: const TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                // Payment Method
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    sale.paymentMethod.toUpperCase(),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 13),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                // Total
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    "RM ${sale.total.toStringAsFixed(2)}",
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 13),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                // Status badge
                                                Expanded(
                                                  flex: 3,
                                                  child: Align(
                                                    alignment: Alignment.center,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: badgeBg,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        statusText.toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: badgeColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Action View Details Button
                                                Expanded(
                                                  flex: 2,
                                                  child: Align(
                                                    alignment: Alignment.center,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.visibility_outlined, size: 20, color: textSecondary),
                                                      onPressed: () => showSaleDetailsDialog(context, sale),
                                                      tooltip: "View Receipt Details",
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
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