import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final int refundedQuantity;

  SaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.refundedQuantity = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'refundedQuantity': refundedQuantity,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      refundedQuantity: map['refundedQuantity'] ?? 0,
    );
  }
}

class Sale {
  final String id;
  final String receiptNo;
  final String cashierId;
  final String cashierEmail;
  final String paymentMethod;
  final List<SaleItem> items;
  final double total;
  final double amountReceived;
  final double change;
  final DateTime createdAt;
  final String? refundStatus; // 'full', 'partial', or null
  final double refundedAmount;

  Sale({
    required this.id,
    required this.receiptNo,
    required this.cashierId,
    required this.cashierEmail,
    required this.paymentMethod,
    required this.items,
    required this.total,
    this.amountReceived = 0.0,
    this.change = 0.0,
    required this.createdAt,
    this.refundStatus,
    this.refundedAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'receiptNo': receiptNo,
      'cashierId': cashierId,
      'cashierEmail': cashierEmail,
      'paymentMethod': paymentMethod,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'amountReceived': amountReceived,
      'change': change,
      'createdAt': Timestamp.fromDate(createdAt),
      'refundStatus': refundStatus,
      'refundedAmount': refundedAmount,
    };
  }

  factory Sale.fromMap(String id, Map<String, dynamic> map) {
    return Sale(
      id: id,
      receiptNo: map['receiptNo'] ?? '',
      cashierId: map['cashierId'] ?? '',
      cashierEmail: map['cashierEmail'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      total: (map['total'] ?? 0).toDouble(),
      amountReceived: (map['amountReceived'] ?? map['total'] ?? 0).toDouble(),
      change: (map['change'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      refundStatus: map['refundStatus'],
      refundedAmount: (map['refundedAmount'] ?? 0).toDouble(),
    );
  }
}