import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product.dart';
import '../../models/sales.dart';
import '../../viewmodels/product_viewmodel.dart';
import '../../viewmodels/sales_viewmodel.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ProductViewModel productVM = ProductViewModel();
  final SalesViewModel salesVM = SalesViewModel();

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  final TextEditingController searchController = TextEditingController();
  final FocusNode _pageFocusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();

  List<_CartItem> cart = [];
  String searchText = '';
  String selectedCategory = 'All';
  List<Product> _currentProducts = [];
  String _barcodeBuffer = '';
  bool isCheckingOut = false;
  String selectedPaymentMethod = 'Cash';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        _pageFocusNode.requestFocus();
      }
    });
  }

  void addToCart(Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This product is out of stock"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final index = cart.indexWhere((item) => item.product.id == product.id);

    setState(() {
      if (index >= 0) {
        if (cart[index].quantity < product.stock) {
          cart[index].quantity++;
        }
      } else {
        cart.add(_CartItem(product: product, quantity: 1));
      }
    });
  }

  void scanBarcode(String barcode) {
    if (barcode.trim().isEmpty) return;

    final product = _currentProducts.firstWhere(
      (p) => p.barcode == barcode.trim(),
      orElse: () => Product(id: '', name: '', price: 0, stock: 0, category: ''),
    );

    if (product.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found for barcode: ${barcode.trim()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } else {
      addToCart(product);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Don't capture when search field has focus
    if (_searchFocusNode.hasFocus) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (_barcodeBuffer.isNotEmpty) {
          scanBarcode(_barcodeBuffer);
          _barcodeBuffer = '';
        }
        return KeyEventResult.handled;
      }

      final char = event.character;
      if (char != null && char.isNotEmpty && char != '\n' && char != '\r') {
        _barcodeBuffer += char;
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void increaseQty(_CartItem item) {
    if (item.quantity < item.product.stock) {
      setState(() {
        item.quantity++;
      });
    }
  }

  void decreaseQty(_CartItem item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity--;
      } else {
        cart.remove(item);
      }
    });
  }

  double getTotal() {
    return cart.fold(
      0,
      (sum, item) => sum + (item.product.price * item.quantity),
    );
  }

  int getTotalItems() {
    return cart.fold(0, (sum, item) => sum + item.quantity);
  }

  String formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year  $hour:$minute';
  }

  Widget _receiptRow(
    String label,
    String value, {
    Color valueColor = textPrimary,
    bool bold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              color: valueColor,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> showPaymentMethodDialog() async {
    String tempMethod = selectedPaymentMethod;

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              Widget paymentTile({
                required String value,
                required IconData icon,
                required String label,
              }) {
                final isSelected = tempMethod == value;

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setDialogState(() {
                      tempMethod = value;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? primaryBlue : cardBorder,
                        width: isSelected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryBlue.withOpacity(0.10)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? primaryBlue : textSecondary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? primaryBlue : textSecondary,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: primaryBlue,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          color: primaryBlue,
                          size: 26,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Select Payment Method',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose how the customer will pay for this transaction.',
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    paymentTile(
                      value: 'Cash',
                      icon: Icons.payments_outlined,
                      label: 'Cash',
                    ),
                    paymentTile(
                      value: 'Card',
                      icon: Icons.credit_card_rounded,
                      label: 'Card',
                    ),
                    paymentTile(
                      value: 'QR',
                      icon: Icons.qr_code_2_rounded,
                      label: 'QR Payment',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textPrimary,
                                side: const BorderSide(color: cardBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, tempMethod),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
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
        );
      },
    );
  }

  Future<void> showReceiptDialog(Sale sale) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Checkout Successful',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The transaction has been completed and saved successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
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
                        _receiptRow('Receipt No', sale.receiptNo),
                        const SizedBox(height: 12),
                        _receiptRow('Payment', sale.paymentMethod),
                        const SizedBox(height: 12),
                        _receiptRow(
                          'Total',
                          'RM ${sale.total.toStringAsFixed(2)}',
                          valueColor: primaryBlue,
                          bold: true,
                        ),
                        if (sale.paymentMethod == 'Cash') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Cash Received',
                                      style: TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'RM ${sale.amountReceived.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(color: Colors.green.withOpacity(0.3), height: 1),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Change Due',
                                      style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      'RM ${sale.change.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        const SizedBox(height: 12),
                        _receiptRow('Cashier', sale.cashierEmail),
                        const SizedBox(height: 12),
                        _receiptRow(
                          'Date',
                          formatDateTime(sale.createdAt),
                        ),
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
                              foregroundColor: textPrimary,
                              side: const BorderSide(color: cardBorder, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Skip Print', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              showPrintReceiptPreview(sale);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 20),
                                SizedBox(width: 8),
                                Text('Print Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
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
  }

  Future<void> showPrintReceiptPreview(Sale sale) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 380, // Standard thermal width relative scale
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: const Center(
                    child: Text(
                      'Receipt Preview',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                  ),
                ),
                
                // Receipt Paper
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'NIRASZ POS',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '123 Retail Street, KL, Malaysia',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '---------------------------------------',
                            style: TextStyle(color: Colors.grey, letterSpacing: 1),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Receipt:', style: TextStyle(fontSize: 12)),
                              Text(sale.receiptNo, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Date:', style: TextStyle(fontSize: 12)),
                              Text(formatDateTime(sale.createdAt), style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Cashier:', style: TextStyle(fontSize: 12)),
                              Text(sale.cashierEmail.split('@')[0], style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '---------------------------------------',
                            style: TextStyle(color: Colors.grey, letterSpacing: 1),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                          const SizedBox(height: 16),
                          
                          // Items
                          ...sale.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text('${item.quantity} x ${item.name}', style: const TextStyle(fontSize: 13)),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'RM ${(item.price * item.quantity).toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          
                          const SizedBox(height: 8),
                          const Text(
                            '---------------------------------------',
                            style: TextStyle(color: Colors.grey, letterSpacing: 1),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                          const SizedBox(height: 12),
                          
                          // Totals
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('RM ${sale.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sale.paymentMethod == 'Cash' ? 'CASH' : sale.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 13)),
                              Text('RM ${sale.paymentMethod == 'Cash' ? sale.amountReceived.toStringAsFixed(2) : sale.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          if (sale.paymentMethod == 'Cash') ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('CHANGE', style: TextStyle(fontSize: 13)),
                                Text('RM ${sale.change.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          const Text(
                            '---------------------------------------',
                            style: TextStyle(color: Colors.grey, letterSpacing: 1),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'THANK YOU FOR YOUR PURCHASE!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please come again',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Footer buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: cardBorder),
                          ),
                          child: const Text('Close', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Hardware printing integration will go here
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Printing to hardware terminal..."),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Print Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, double>?> showCashPaymentDialog(double total) async {
    String inputAmount = '';
    double? amountReceived;

    // Quick amounts based on total
    List<double> quickAmounts = [total];
    quickAmounts.add(total.ceilToDouble()); // Next round number (e.g. 12.30 -> 13.00)
    if (total < 10) quickAmounts.add(10);
    if (total < 20) quickAmounts.add(20);
    if (total < 50) quickAmounts.add(50);
    if (total < 100) quickAmounts.add(100);
    // Ensure we don't have duplicates and sort
    quickAmounts = quickAmounts.toSet().toList()..sort();

    return await showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final change = (amountReceived ?? 0) - total;
            final isSufficient = (amountReceived ?? 0) >= total;

            void updateInput(String val) {
              setDialogState(() {
                if (val == '<') {
                  if (inputAmount.isNotEmpty) {
                    inputAmount = inputAmount.substring(0, inputAmount.length - 1);
                  }
                } else if (val == '.') {
                  if (!inputAmount.contains('.')) {
                    inputAmount += inputAmount.isEmpty ? '0.' : '.';
                  }
                } else {
                  // Prevent more than 2 decimal places
                  if (inputAmount.contains('.')) {
                    final parts = inputAmount.split('.');
                    if (parts.length > 1 && parts[1].length >= 2) return;
                  }
                  // Prevent leading zeros unless followed by decimal
                  if (inputAmount == '0' && val != '.') {
                    inputAmount = val;
                  } else {
                    inputAmount += val;
                  }
                }
                amountReceived = double.tryParse(inputAmount);
              });
            }

            void setQuickAmount(double amount) {
              setDialogState(() {
                amountReceived = amount;
                inputAmount = amount == amount.toInt() ? amount.toInt().toString() : amount.toStringAsFixed(2);
              });
            }

            Widget numButton(String label, {Color? color, Color? textColor}) {
              return Material(
                color: color ?? Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => updateInput(label),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: cardBorder),
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFFF8FAFC),
                    ),
                    alignment: Alignment.center,
                    child: label == '<'
                        ? Icon(Icons.backspace_outlined, color: textColor ?? textPrimary)
                        : Text(
                            label,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: textColor ?? textPrimary,
                            ),
                          ),
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cash Payment',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    const SizedBox(height: 24),

                    // Display Area
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: softBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        children: [
                          _receiptRow('Total Due', 'RM ${total.toStringAsFixed(2)}', bold: true, valueColor: primaryBlue),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text('Received', style: TextStyle(fontSize: 16, color: textSecondary)),
                                  const SizedBox(width: 10),
                                  if (inputAmount.isNotEmpty)
                                    InkWell(
                                      onTap: () => setDialogState(() { inputAmount = ''; amountReceived = null; }),
                                      borderRadius: BorderRadius.circular(4),
                                      child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                              Text(
                                inputAmount.isEmpty ? 'RM 0.00' : 'RM $inputAmount',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
                              ),
                            ],
                          ),
                          if (amountReceived != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Change', style: TextStyle(fontSize: 16, color: textSecondary)),
                                Text(
                                  'RM ${change > 0 ? change.toStringAsFixed(2) : '0.00'}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isSufficient ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Amounts
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: quickAmounts.map((amt) {
                          final isExact = amt == total;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton(
                              onPressed: () => setQuickAmount(amt),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryBlue,
                                side: const BorderSide(color: primaryBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                backgroundColor: isExact ? primaryBlue.withOpacity(0.05) : Colors.white,
                              ),
                              child: Text(
                                isExact ? 'Exact (RM ${amt.toStringAsFixed(2)})' : 'RM ${amt.toInt()}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Keypad
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        numButton('1'), numButton('2'), numButton('3'),
                        numButton('4'), numButton('5'), numButton('6'),
                        numButton('7'), numButton('8'), numButton('9'),
                        numButton('.'), numButton('0'), numButton('<'),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: cardBorder, width: 1.5),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSufficient
                                ? () => Navigator.pop(context, {'amountReceived': amountReceived!, 'change': change})
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text('Confirm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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

  Future<bool> showCardPaymentDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.credit_card, size: 64, color: primaryBlue),
                const SizedBox(height: 16),
                const Text('Waiting for card...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true), // Simulating success
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Simulate Success', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    ) ?? false;
  }

  Future<bool> showQRPaymentDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_2, size: 100, color: textPrimary),
                const SizedBox(height: 16),
                const Text('Scan QR to Pay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Awaiting customer payment...', textAlign: TextAlign.center, style: TextStyle(color: textSecondary)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true), // Simulating success
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Simulate Success', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    ) ?? false;
  }

  Future<void> handleCheckout() async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cart is empty"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No logged in user found"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final paymentMethod = await showPaymentMethodDialog();
    if (paymentMethod == null) return;

    double amountReceived = getTotal();
    double change = 0.0;

    if (paymentMethod == 'Cash') {
      final cashResult = await showCashPaymentDialog(getTotal());
      if (cashResult == null) return; // User cancelled cash payment
      amountReceived = cashResult['amountReceived']!;
      change = cashResult['change']!;
    } else if (paymentMethod == 'Card') {
      final success = await showCardPaymentDialog();
      if (!success) return; // User cancelled card payment
    } else if (paymentMethod == 'QR') {
      final success = await showQRPaymentDialog();
      if (!success) return; // User cancelled QR payment
    }

    setState(() {
      isCheckingOut = true;
      selectedPaymentMethod = paymentMethod;
    });

    try {
      final saleItems = cart
          .map(
            (item) => SaleItem(
              productId: item.product.id,
              name: item.product.name,
              price: item.product.price,
              quantity: item.quantity,
            ),
          )
          .toList();

      final updatedProducts = cart
          .map(
            (item) => Product(
              id: item.product.id,
              name: item.product.name,
              price: item.product.price,
              stock: item.product.stock - item.quantity,
              category: item.product.category,
              barcode: item.product.barcode,
            ),
          )
          .toList();

      final sale = await salesVM.checkoutSale(
        cashierId: currentUser.uid,
        cashierEmail: currentUser.email ?? 'Unknown',
        paymentMethod: paymentMethod,
        items: saleItems,
        total: getTotal(),
        amountReceived: amountReceived,
        change: change,
        productsToUpdate: updatedProducts,
      );

      setState(() {
        cart.clear();
      });

      if (!mounted) return;
      await showReceiptDialog(sale);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Checkout failed: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isCheckingOut = false;
        });
      }
    }
  }

  Widget _buildProductImage(String imageUrl, {double? width, double? height, double borderRadius = 16}) {
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFDBEAFE),
        alignment: Alignment.center,
        child: const Icon(Icons.inventory_2_rounded, color: primaryBlue, size: 48),
      );
    }

    Widget imageWidget;
    if (imageUrl.startsWith('data:image/') || imageUrl.contains('base64,')) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: width,
          height: height,
        );
      } catch (e) {
        imageWidget = Container(
          color: const Color(0xFFDBEAFE),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_rounded, color: Colors.red, size: 48),
        );
      }
    } else {
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFDBEAFE),
          alignment: Alignment.center,
          child: const Icon(Icons.inventory_2_rounded, color: primaryBlue, size: 48),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageWidget,
    );
  }

  Widget buildProductCard(Product product) {
    final outOfStock = product.stock <= 0;

    return GestureDetector(
      onTap: outOfStock ? null : () => addToCart(product),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: outOfStock ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(22),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: product.imageUrl.isNotEmpty
                      ? Colors.transparent
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildProductImage(
                  product.imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "RM ${product.price.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                  ),
                ),
                if (outOfStock)
                  const Text(
                    "Out of Stock",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCartItem(_CartItem item) {
    final subtotal = item.product.price * item.quantity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.product.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "RM ${item.product.price.toStringAsFixed(2)} each",
            style: const TextStyle(
              color: textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _qtyButton(
                icon: Icons.remove,
                onTap: () => decreaseQty(item),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  "${item.quantity}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              _qtyButton(
                icon: Icons.add,
                onTap: () => increaseQty(item),
              ),
              const Spacer(),
              Text(
                "RM ${subtotal.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        child: Icon(icon, size: 18, color: textPrimary),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    _pageFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pageFocusNode.requestFocus(),
      child: Focus(
        focusNode: _pageFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: softBackground,
          body: SafeArea(
        child: StreamBuilder<List<Product>>(
          stream: productVM.getProducts(),
          builder: (context, snapshot) {
            final allProducts = snapshot.data ?? [];
            _currentProducts = allProducts;
            final categories = ['All', ...allProducts.map((p) => p.category).toSet().toList()..sort()];
            final products = allProducts.where((product) {
              final query = searchText.toLowerCase();
              final matchesSearch = product.name.toLowerCase().contains(query) ||
                  product.category.toLowerCase().contains(query) ||
                  product.barcode.toLowerCase().contains(query);
              final matchesCategory = selectedCategory == 'All' || product.category == selectedCategory;
              return matchesSearch && matchesCategory;
            }).toList();

            return Column(
              children: [
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
                          Icons.point_of_sale_rounded,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Point of Sale",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Select products, manage cart, and complete checkout.",
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
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: searchController,
                                      focusNode: _searchFocusNode,
                                      onChanged: (value) {
                                        setState(() {
                                          searchText = value;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: "Search products...",
                                        prefixIcon: const Icon(Icons.search_rounded),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: const BorderSide(color: cardBorder),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: const BorderSide(color: cardBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: const BorderSide(
                                            color: primaryBlue,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFA7F3D0),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 20,
                                          color: Color(0xFF059669),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Scanner Ready",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: categories.length,
                                  itemBuilder: (context, index) {
                                    final cat = categories[index];
                                    final isSelected = cat == selectedCategory;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: ChoiceChip(
                                        label: Text(cat),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              selectedCategory = cat;
                                            });
                                          }
                                        },
                                        selectedColor: primaryBlue,
                                        labelStyle: TextStyle(
                                          color: isSelected ? Colors.white : textSecondary,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                        backgroundColor: Colors.white,
                                        side: BorderSide(color: isSelected ? primaryBlue : cardBorder),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 18),
                              Expanded(
                                child: snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : snapshot.hasError
                                        ? Center(
                                            child: Text(
                                              "Error loading products: ${snapshot.error}",
                                            ),
                                          )
                                        : products.isEmpty
                                            ? Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(32),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  border:
                                                      Border.all(color: cardBorder),
                                                ),
                                                child: const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.inventory_2_outlined,
                                                      size: 54,
                                                      color: textSecondary,
                                                    ),
                                                    SizedBox(height: 14),
                                                    Text(
                                                      "No products found",
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : GridView.builder(
                                                itemCount: products.length,
                                                gridDelegate:
                                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 3,
                                                  crossAxisSpacing: 16,
                                                  mainAxisSpacing: 16,
                                                  childAspectRatio: 0.75,
                                                ),
                                                itemBuilder: (context, index) {
                                                  return buildProductCard(
                                                    products[index],
                                                  );
                                                },
                                              ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 380,
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            left: BorderSide(color: cardBorder),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Cart",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${getTotalItems()} item(s) selected",
                              style: const TextStyle(color: textSecondary),
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: cart.isEmpty
                                  ? Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_cart_outlined,
                                            size: 52,
                                            color: textSecondary,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            "Your cart is empty",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            "Select a product to begin a sale.",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: cart.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        return buildCartItem(cart[index]);
                                      },
                                    ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        "Total",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        "RM ${getTotal().toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Text(
                                        "Payment",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        selectedPaymentMethod,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed:
                                          isCheckingOut ? null : handleCheckout,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryBlue,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: isCheckingOut
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              "Checkout",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    ),
    );
  }
}

class _CartItem {
  final Product product;
  int quantity;

  _CartItem({
    required this.product,
    required this.quantity,
  });
}