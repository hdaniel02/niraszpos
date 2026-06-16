import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/shift.dart';
import '../../viewmodels/shift_viewmodel.dart';


class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final ShiftViewModel shiftVM = ShiftViewModel();
  String _searchQuery = '';
  String _sortOption = 'Date: Newest';
  
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  String formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
  }

  void _showShiftDetailsDialog(Shift shift) {
    final displayName = toTitleCase(shift.userName.isEmpty ? 'Unknown User' : shift.userName);
    final totalSales = (shift.endingCash ?? 0) + (shift.endingCard ?? 0) + (shift.endingQR ?? 0);
    final netSales = totalSales > 0 ? (totalSales - shift.startingCash) : 0.0;

    String shiftStatusText = "Active";
    Color statusBgColor = const Color(0xFFDBEAFE);
    Color statusTextColor = const Color(0xFF1D4ED8);

    if (shift.endTime != null) {
      final duration = shift.endTime!.difference(shift.startTime);
      if (duration.inMinutes >= 480) {
        shiftStatusText = "Complete";
        statusBgColor = const Color(0xFFDCFCE7);
        statusTextColor = const Color(0xFF15803D);
      } else {
        shiftStatusText = "Incomplete";
        statusBgColor = const Color(0xFFFEE2E2);
        statusTextColor = const Color(0xFFB91C1C);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      shiftStatusText,
                      style: TextStyle(
                        color: statusTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                shift.userRole.toUpperCase(),
                style: const TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 16),
                  
                  // Section: Timeline
                  const Text("SHIFT TIMELINE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.login_rounded, color: Colors.green, size: 18),
                      const SizedBox(width: 10),
                      const Text("Clock In:", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textPrimary)),
                      const Spacer(),
                      Text(formatDateTime(shift.startTime), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 10),
                      const Text("Clock Out:", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textPrimary)),
                      const Spacer(),
                      Text(
                        shift.endTime != null ? formatDateTime(shift.endTime!) : 'Ongoing...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: shift.endTime != null ? textPrimary : const Color(0xFF22C55E),
                          fontStyle: shift.endTime != null ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  const Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 16),

                  // Section: Starting Float
                  const Text("STARTING FLOAT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right_rounded, color: Colors.blue, size: 18),
                      const SizedBox(width: 10),
                      const Text("Cash-In (Start Shift):", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textPrimary)),
                      const Spacer(),
                      Text("RM ${shift.startingCash.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textPrimary)),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 16),

                  // Section: Closing Declarations
                  const Text("CLOSING DECLARATIONS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.money_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      const Text("Cash Sales (Closing):", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textPrimary)),
                      const Spacer(),
                      Text(
                        shift.endingCash != null ? "RM ${shift.endingCash!.toStringAsFixed(2)}" : "-",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.credit_card_rounded, color: Color(0xFF3B82F6), size: 18),
                      const SizedBox(width: 10),
                      const Text("Card Sales (Closing):", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textPrimary)),
                      const Spacer(),
                      Text(
                        shift.endingCard != null ? "RM ${shift.endingCard!.toStringAsFixed(2)}" : "-",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.qr_code_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 10),
                      const Text("QR Sales (Closing):", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: textPrimary)),
                      const Spacer(),
                      Text(
                        shift.endingQR != null ? "RM ${shift.endingQR!.toStringAsFixed(2)}" : "-",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: cardBorder, height: 1),
                  const SizedBox(height: 16),

                  // Section: Summary Totals
                  const Text("SHIFT SUMMARY TOTALS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text("Total Sales (Revenue):", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary)),
                      const Spacer(),
                      Text("RM ${totalSales.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("Net Sales (Minus Float):", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textPrimary)),
                      const Spacer(),
                      Text(
                        "RM ${netSales.toStringAsFixed(2)}",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: netSales >= 0 ? const Color(0xFF10B981) : Colors.redAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: textSecondary,
                side: const BorderSide(color: cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _generatePdf(List<Shift> filteredShifts) async {
    final pdf = pw.Document();

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFE2E8F0))),
      ),
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('STAFF', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B), fontSize: 10))),
        pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('ROLE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B), fontSize: 10))),
        pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('STATUS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B), fontSize: 10))),
        pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('CLOCK IN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B), fontSize: 10))),
        pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('CLOCK OUT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B), fontSize: 10))),
        pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('CASH', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF16A34A), fontSize: 10))),
        pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('CARD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF2563EB), fontSize: 10))),
        pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Text('QR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF9333EA), fontSize: 10))),
      ],
    );

    final dataRows = filteredShifts.map((shift) {
      final displayName = shift.userName.isEmpty ? 'Unknown User' : shift.userName;
      
      String shiftStatusText = "Active";
      int pdfBgColorHex = 0xFFDBEAFE;
      int pdfTextColorHex = 0xFF1D4ED8;

      if (shift.endTime != null) {
        final duration = shift.endTime!.difference(shift.startTime);
        if (duration.inMinutes >= 480) {
          shiftStatusText = "Complete";
          pdfBgColorHex = 0xFFDCFCE7;
          pdfTextColorHex = 0xFF15803D;
        } else {
          shiftStatusText = "Incomplete";
          pdfBgColorHex = 0xFFFEE2E2;
          pdfTextColorHex = 0xFFB91C1C;
        }
      }

      return pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFF1F5F9)))),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 20,
                  height: 20,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(pdfBgColorHex),
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    displayName[0].toUpperCase(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromInt(pdfTextColorHex)),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(displayName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: const PdfColor.fromInt(0xFF0F172A))),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9), borderRadius: pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Text(shift.userRole.toUpperCase(), style: pw.TextStyle(color: const PdfColor.fromInt(0xFF64748B), fontWeight: pw.FontWeight.bold, fontSize: 8), softWrap: false),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(pdfBgColorHex),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Text(
                shiftStatusText,
                style: pw.TextStyle(color: PdfColor.fromInt(pdfTextColorHex), fontWeight: pw.FontWeight.bold, fontSize: 9),
                softWrap: false,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(formatDateTime(shift.startTime), style: const pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF0F172A))),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(
              shift.endTime != null ? formatDateTime(shift.endTime!) : 'Ongoing...', 
              style: pw.TextStyle(
                fontSize: 10, 
                color: shift.endTime != null ? const PdfColor.fromInt(0xFF0F172A) : const PdfColor.fromInt(0xFF64748B), 
                fontStyle: shift.endTime != null ? pw.FontStyle.normal : pw.FontStyle.italic,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(shift.endingCash != null ? "RM ${shift.endingCash!.toStringAsFixed(2)}" : "-", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: const PdfColor.fromInt(0xFF0F172A))),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(shift.endingCard != null ? "RM ${shift.endingCard!.toStringAsFixed(2)}" : "-", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: const PdfColor.fromInt(0xFF0F172A))),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Text(shift.endingQR != null ? "RM ${shift.endingQR!.toStringAsFixed(2)}" : "-", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: const PdfColor.fromInt(0xFF0F172A))),
          ),
        ],
      );
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, // Wide enough for all columns
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("NiraszPOS", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E3A8A))),
                    pw.SizedBox(height: 4),
                    pw.Text("Shift Tracking & Audit Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A))),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9), borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
                  child: pw.Text("Date: ${formatDateTime(DateTime.now())}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B))),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.ClipRRect(
              horizontalRadius: 12,
              verticalRadius: 12,
              child: pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.4), // Name
                  1: const pw.FlexColumnWidth(1.5), // Role
                  2: const pw.FlexColumnWidth(1.6), // Status
                  3: const pw.FlexColumnWidth(2.1), // Clock In
                  4: const pw.FlexColumnWidth(2.1), // Clock Out
                  5: const pw.FlexColumnWidth(1.6), // Cash
                  6: const pw.FlexColumnWidth(1.4), // Card
                  7: const pw.FlexColumnWidth(1.4), // QR
                },
                children: [
                  headerRow,
                  ...dataRows,
                ],
              ),
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Shift_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: StreamBuilder<List<Shift>>(
          stream: shiftVM.getAllShifts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          List<Shift> shifts = (snapshot.data ?? [])
              .where((s) => s.userRole.toLowerCase() == 'cashier')
              .toList();
          
          // Filtering
          if (_searchQuery.isNotEmpty) {
            shifts = shifts.where((s) => s.userName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          }

          // Sorting
          if (_sortOption == 'Date: Newest') {
            shifts.sort((a, b) => b.startTime.compareTo(a.startTime));
          } else if (_sortOption == 'Date: Oldest') {
            shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
          } else if (_sortOption == 'Name A-Z') {
            shifts.sort((a, b) => a.userName.compareTo(b.userName));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Cashier Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                        SizedBox(height: 4),
                        Text("Track cashier performance sales", style: TextStyle(fontSize: 13, color: textSecondary)),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: shifts.isEmpty ? null : () => _generatePdf(shifts),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: textSecondary),
                      label: const Text("Export PDF"),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: textPrimary,
                        side: const BorderSide(color: cardBorder),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                                  hintText: "Search cashier...",
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
                                items: ['Date: Newest', 'Date: Oldest', 'Name A-Z'].map((e) {
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
                      const SizedBox(height: 16),
                      if (shifts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text("No shifts match your search criteria.", style: TextStyle(color: textSecondary))),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double tableWidth = constraints.maxWidth > 1000 ? constraints.maxWidth : 1000;
                            const headerStyle = TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13);
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Header Row
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: const [
                                          Expanded(flex: 1, child: Text('#', style: headerStyle)),
                                          Expanded(flex: 3, child: Text('STAFF', style: headerStyle)),
                                          Expanded(flex: 2, child: Text('ROLE', style: headerStyle)),
                                          Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
                                          Expanded(flex: 3, child: Text('CLOCK IN', style: headerStyle)),
                                          Expanded(flex: 3, child: Text('CLOCK OUT', style: headerStyle)),
                                          Expanded(flex: 2, child: Text('SALES', style: headerStyle)),
                                          Expanded(flex: 2, child: Text('ACTION', style: headerStyle, textAlign: TextAlign.center)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Data Rows
                                    ...shifts.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final shift = entry.value;
                                      final displayName = toTitleCase(shift.userName.isEmpty ? 'Unknown User' : shift.userName);
                                      final totalSales = (shift.endingCash ?? 0) + (shift.endingCard ?? 0) + (shift.endingQR ?? 0);
                                      
                                      String shiftStatusText = "Active";
                                      Color statusBgColor = const Color(0xFFDBEAFE);
                                      Color statusTextColor = const Color(0xFF1D4ED8);

                                      if (shift.endTime != null) {
                                        final duration = shift.endTime!.difference(shift.startTime);
                                        if (duration.inMinutes >= 480) {
                                          shiftStatusText = "Complete";
                                          statusBgColor = const Color(0xFFDCFCE7);
                                          statusTextColor = const Color(0xFF15803D);
                                        } else {
                                          shiftStatusText = "Incomplete";
                                          statusBgColor = const Color(0xFFFEE2E2);
                                          statusTextColor = const Color(0xFFB91C1C);
                                        }
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
                                            // Index
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 14),
                                              ),
                                            ),
                                            // Staff Name
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                displayName,
                                                style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14),
                                              ),
                                            ),
                                            // Role
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    shift.userRole.toUpperCase(),
                                                    style: const TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 10),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Status
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: statusBgColor,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    shiftStatusText,
                                                    style: TextStyle(
                                                      color: statusTextColor,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Clock In
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                formatDateTime(shift.startTime),
                                                style: const TextStyle(fontWeight: FontWeight.w600, color: textSecondary, fontSize: 13),
                                              ),
                                            ),
                                            // Clock Out
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
                                              ),
                                            ),
                                            // Sales
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                "RM ${totalSales.toStringAsFixed(2)}",
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14),
                                              ),
                                            ),
                                            // Action
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: IconButton(
                                                  icon: const Icon(Icons.visibility_outlined, size: 20, color: textSecondary),
                                                  onPressed: () => _showShiftDetailsDialog(shift),
                                                  tooltip: "View Details",
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
              ],
            ),
          );
        },
      ),
    ),
  );
}
}
