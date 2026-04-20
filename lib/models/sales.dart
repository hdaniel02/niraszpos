import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;

  SaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
    );
  }
}

class Sale {
  final String id;
  final String cashierId;
  final String cashierEmail;
  final List<SaleItem> items;
  final double total;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.cashierId,
    required this.cashierEmail,
    required this.items,
    required this.total,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'cashierId': cashierId,
      'cashierEmail': cashierEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Sale.fromMap(String id, Map<String, dynamic> map) {
    return Sale(
      id: id,
      cashierId: map['cashierId'] ?? '',
      cashierEmail: map['cashierEmail'] ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      total: (map['total'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}