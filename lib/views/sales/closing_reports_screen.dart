import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/sales.dart';
import '../../models/shift.dart';
import '../../models/product.dart';
import '../../viewmodels/sales_viewmodel.dart';
import '../../viewmodels/shift_viewmodel.dart';
import '../../viewmodels/product_viewmodel.dart';

class ClosingReportsScreen extends StatefulWidget {
  final String role;
  const ClosingReportsScreen({super.key, required this.role});

  @override
  State<ClosingReportsScreen> createState() => _ClosingReportsScreenState();
}

class _ClosingReportsScreenState extends State<ClosingReportsScreen> {
  final ShiftViewModel shiftVM = ShiftViewModel();
  final SalesViewModel salesVM = SalesViewModel();
  final ProductViewModel productVM = ProductViewModel();

  static const Color primaryBlue = Color(0xFF059669); // Emerald Green system
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

  String formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    return '$day/$month/$year';
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }

  void _showClosingReportDialog(Shift shift, List<Sale> shiftSales) {
    final displayName = toTitleCase(shift.userName.isEmpty ? 'Unknown Cashier' : shift.userName);
    final endTime = shift.endTime ?? DateTime.now();

    // 1. Calculate actual expected sales from sales transactions during this shift
    double expectedCash = 0.0;
    double expectedCard = 0.0;
    double expectedQR = 0.0;

    Map<String, int> itemsSold = {};

    for (var sale in shiftSales) {
      final method = sale.paymentMethod.toLowerCase();
      if (method == 'cash') {
        expectedCash += sale.total;
      } else if (method == 'card') {
        expectedCard += sale.total;
      } else if (method == 'qr') {
        expectedQR += sale.total;
      } else {
        expectedCash += sale.total; // fallback
      }

      for (var item in sale.items) {
        itemsSold[item.name] = (itemsSold[item.name] ?? 0) + item.quantity;
      }
    }

    final double declaredCash = shift.endingCash ?? 0.0;
    final double declaredCard = shift.endingCard ?? 0.0;
    final double declaredQR = shift.endingQR ?? 0.0;

    // Variance calculation
    final double cashExpectedTotal = shift.startingCash + expectedCash;
    final double cashVariance = declaredCash - cashExpectedTotal;
    final double cardVariance = declaredCard - expectedCard;
    final double qrVariance = declaredQR - expectedQR;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 650,
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Cash Closing Report",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Cashier: $displayName  •  Date: ${formatDate(shift.startTime)}",
                              style: const TextStyle(fontSize: 13, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: shift.endTime != null ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          shift.endTime != null ? "Closed" : "Active",
                          style: TextStyle(
                            color: shift.endTime != null ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: cardBorder),
                  const SizedBox(height: 16),

                  // Section: Timeline info
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("CLOCK IN", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                            const SizedBox(height: 4),
                            Text(formatDateTime(shift.startTime), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("CLOCK OUT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                            const SizedBox(height: 4),
                            Text(
                              shift.endTime != null ? formatDateTime(shift.endTime!) : "Ongoing",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: shift.endTime != null ? textPrimary : Colors.green),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("START FLOAT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
                            const SizedBox(height: 4),
                            Text("RM ${shift.startingCash.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: cardBorder),
                  const SizedBox(height: 16),

                  // Section: Expected vs Declared Cash Closing Details
                  const Text("CASH CLOSING SUMMARY & AUDIT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  _auditHeaderRow(),
                  const Divider(color: cardBorder),
                  _auditDetailRow(
                    icon: Icons.money_rounded,
                    name: "Cash",
                    iconColor: Colors.green,
                    expected: cashExpectedTotal,
                    declared: declaredCash,
                    variance: cashVariance,
                  ),
                  _auditDetailRow(
                    icon: Icons.credit_card_rounded,
                    name: "Card",
                    iconColor: Colors.blue,
                    expected: expectedCard,
                    declared: declaredCard,
                    variance: cardVariance,
                  ),
                  _auditDetailRow(
                    icon: Icons.qr_code_rounded,
                    name: "QR Pay",
                    iconColor: Colors.orange,
                    expected: expectedQR,
                    declared: declaredQR,
                    variance: qrVariance,
                  ),
                  const Divider(color: cardBorder),
                  _auditTotalRow(
                    expectedTotal: cashExpectedTotal + expectedCard + expectedQR,
                    declaredTotal: declaredCash + declaredCard + declaredQR,
                    netVariance: cashVariance + cardVariance + qrVariance,
                  ),

                  const SizedBox(height: 28),
                  const Divider(color: cardBorder),
                  const SizedBox(height: 16),

                  // Section: Items sold
                  const Text("ITEMS SOLD ON THIS SHIFT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 14),
                  if (itemsSold.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text("No items were sold during this shift.", style: TextStyle(color: textSecondary, fontSize: 13)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: itemsSold.length,
                      separatorBuilder: (context, index) => const Divider(color: cardBorder, height: 1),
                      itemBuilder: (context, index) {
                        final name = itemsSold.keys.elementAt(index);
                        final qty = itemsSold[name] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 13)),
                              Text("Qty: $qty", style: const TextStyle(fontWeight: FontWeight.bold, color: textSecondary, fontSize: 13)),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 28),
                  const Divider(color: cardBorder),
                  const SizedBox(height: 16),

                  // Section: Sold Out and Inventory restocked
                  StreamBuilder<List<Product>>(
                    stream: productVM.getProducts(),
                    builder: (context, productSnapshot) {
                      final products = productSnapshot.data ?? [];
                      final soldOutItems = products.where((p) => p.stock == 0).toList();
                      final restockedItems = products.where((p) => p.stock > 10).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("INVENTORY STATUS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sold Out Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Sold Out Items (Stock: 0)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                                    const SizedBox(height: 8),
                                    if (soldOutItems.isEmpty)
                                      const Text("None", style: TextStyle(color: textSecondary, fontSize: 13))
                                    else
                                      ...soldOutItems.map((p) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                            child: Text("• ${p.name}", style: const TextStyle(fontSize: 13, color: textPrimary)),
                                          )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Active / In Stock Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Restocked / In Stock", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                                    const SizedBox(height: 8),
                                    if (restockedItems.isEmpty)
                                      const Text("None", style: TextStyle(color: textSecondary, fontSize: 13))
                                    else
                                      ...restockedItems.take(5).map((p) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                            child: Text("• ${p.name} (${p.stock} in stock)", style: const TextStyle(fontSize: 13, color: textPrimary)),
                                          )),
                                    if (restockedItems.length > 5)
                                      const Text("...and others", style: TextStyle(color: textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),
                  const Divider(color: cardBorder),
                  const SizedBox(height: 16),

                  // Section: Refund requests log
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: salesVM.getSalesForDateRange(shift.startTime, endTime).then((salesList) async {
                      final List<Map<String, dynamic>> refunds = [];
                      for (var sale in salesList) {
                        final list = await salesVM.getRefundRequestsForSale(sale.id).first;
                        refunds.addAll(list);
                      }
                      return refunds;
                    }),
                    builder: (context, refundSnapshot) {
                      final refunds = refundSnapshot.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("REFUND REQUESTS FILED DURING SHIFT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.5)),
                          const SizedBox(height: 14),
                          if (refunds.isEmpty)
                            const Text("No refund requests filed during this shift.", style: TextStyle(color: textSecondary, fontSize: 13))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: refunds.length,
                              separatorBuilder: (context, index) => const Divider(color: cardBorder, height: 1),
                              itemBuilder: (context, index) {
                                final req = refunds[index];
                                final status = req['status'] as String;
                                final receipt = req['receiptNo'] as String;
                                final total = (req['total'] ?? 0.0).toDouble();
                                final bank = req['bankAccountNumber'] as String?;
                                final name = req['customerFullName'] as String?;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Receipt: $receipt", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                                          Text("RM ${total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            bank != null ? "Bank: $bank ($name)" : "Method: Cash",
                                            style: const TextStyle(fontSize: 12, color: textSecondary),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: status == 'approved' ? Colors.green.shade50 : Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: status == 'approved' ? Colors.green.shade700 : Colors.orange.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Close Closing Report", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _auditHeaderRow() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: textSecondary);
    return Row(
      children: const [
        Expanded(flex: 3, child: Text("PAYMENT TYPE", style: headerStyle)),
        Expanded(flex: 2, child: Text("EXPECTED", style: headerStyle, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text("DECLARED", style: headerStyle, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text("VARIANCE", style: headerStyle, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _auditDetailRow({
    required IconData icon,
    required String name,
    required Color iconColor,
    required double expected,
    required double declared,
    required double variance,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 8),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text("RM ${expected.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text("RM ${declared.toStringAsFixed(2)}", style: const TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text(
              variance == 0 ? "RM 0.00" : "${variance > 0 ? '+' : ''}RM ${variance.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: variance == 0 ? Colors.green : (variance > 0 ? Colors.blue : Colors.red),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditTotalRow({
    required double expectedTotal,
    required double declaredTotal,
    required double netVariance,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text("Total Audit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
          ),
          Expanded(
            flex: 2,
            child: Text("RM ${expectedTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text("RM ${declaredTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text(
              netVariance == 0 ? "RM 0.00" : "${netVariance > 0 ? '+' : ''}RM ${netVariance.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: netVariance == 0 ? Colors.green : (netVariance > 0 ? Colors.blue : Colors.red),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: StreamBuilder<List<Shift>>(
          stream: shiftVM.getAllShifts(),
          builder: (context, shiftSnapshot) {
            if (shiftSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allShifts = shiftSnapshot.data ?? [];
            List<Shift> shifts = widget.role.toLowerCase() == 'cashier'
                ? allShifts.where((s) => s.userId == currentUserId).toList()
                : allShifts;

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              shifts = shifts.where((s) {
                final cashier = s.userName.toLowerCase();
                final dateStr = formatDate(s.startTime);
                final statusStr = s.endTime != null ? 'closed' : 'ongoing';
                return cashier.contains(query) ||
                    dateStr.contains(query) ||
                    statusStr.contains(query);
              }).toList();
            }

            if (_sortOption == 'Date: Newest') {
              shifts.sort((a, b) => b.startTime.compareTo(a.startTime));
            } else if (_sortOption == 'Date: Oldest') {
              shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
            }

            return StreamBuilder<List<Sale>>(
              stream: salesVM.getSales(),
              builder: (context, salesSnapshot) {
                final sales = salesSnapshot.data ?? [];

                return Column(
                  children: [
                    // Header Area
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cash Closing Reports',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Inspect shift closing totals, expected collections, inventory logs and refunds.',
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 240,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: TextField(
                                  textAlignVertical: TextAlignVertical.center,
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  decoration: const InputDecoration(
                                    hintText: "Search cashier, date...",
                                    hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                                    prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
                                    prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 38),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _sortOption,
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary),
                                    items: ['Date: Newest', 'Date: Oldest'].map((e) {
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
                        ],
                      ),
                    ),

                    // Filters & Table Area
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


                              if (shifts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(child: Text("No shift closing reports found.", style: TextStyle(color: textSecondary))),
                                )
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double tableWidth = constraints.maxWidth > 800 ? constraints.maxWidth : 800;
                                    const headerStyle = TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13);
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: tableWidth,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Table Header
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              child: Row(
                                                children: const [
                                                  Expanded(flex: 1, child: Text('#', style: headerStyle)),
                                                  Expanded(flex: 3, child: Text('CASHIER', style: headerStyle)),
                                                  Expanded(flex: 2, child: Text('DATE', style: headerStyle, textAlign: TextAlign.center)),
                                                  Expanded(flex: 3, child: Text('CLOCK-OUT TIME', style: headerStyle, textAlign: TextAlign.center)),
                                                  Expanded(flex: 2, child: Text('TOTAL SALES', style: headerStyle, textAlign: TextAlign.center)),
                                                  Expanded(flex: 2, child: Text('ACTION', style: headerStyle, textAlign: TextAlign.center)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),

                                            // Table Rows
                                            ...shifts.asMap().entries.map((entry) {
                                              final index = entry.key;
                                              final shift = entry.value;
                                              final displayName = toTitleCase(shift.userName.isEmpty ? 'Unknown Cashier' : shift.userName);

                                              // Fetch transactions belonging to this shift duration
                                              final shiftSales = sales.where((sale) =>
                                                sale.cashierId == shift.userId &&
                                                sale.createdAt.isAfter(shift.startTime) &&
                                                sale.createdAt.isBefore(shift.endTime ?? DateTime.now())
                                              ).toList();

                                              final double shiftTotalSales = shiftSales.fold(0.0, (acc, s) => acc + s.total);

                                              return Container(
                                                margin: const EdgeInsets.symmetric(vertical: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: index % 2 == 0 ? const Color(0xFFF8FAFC) : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(30),
                                                ),
                                                child: Row(
                                                  children: [
                                                    // Index
                                                    Expanded(
                                                      flex: 1,
                                                      child: Text(
                                                        '${index + 1}',
                                                        style: const TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 14),
                                                      ),
                                                    ),
                                                    // Cashier Name
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        displayName,
                                                        style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                                                      ),
                                                    ),
                                                    // Date
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        formatDate(shift.startTime),
                                                        style: const TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                    // Clock-Out Time
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        shift.endTime != null ? formatDateTime(shift.endTime!) : 'Ongoing...',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          color: shift.endTime != null ? textSecondary : const Color(0xFF22C55E),
                                                          fontStyle: shift.endTime != null ? FontStyle.normal : FontStyle.italic,
                                                          fontSize: 13,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                    // Total Sales
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        "RM ${shiftTotalSales.toStringAsFixed(2)}",
                                                        style: const TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 14),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                    // Action Button
                                                    Expanded(
                                                      flex: 2,
                                                      child: Align(
                                                        alignment: Alignment.center,
                                                        child: IconButton(
                                                          icon: const Icon(Icons.visibility_outlined, size: 20, color: textSecondary),
                                                          onPressed: () => _showClosingReportDialog(shift, shiftSales),
                                                          tooltip: "Display Closing Report",
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
            );
          },
        ),
      ),
    );
  }
}
