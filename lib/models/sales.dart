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

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: (map['quantity'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}

class Sale {
  final String id;
  final String cashierId;
  final String cashierEmail;
  final double total;
  final List<SaleItem> items;
  final DateTime? createdAt;

  Sale({
    required this.id,
    required this.cashierId,
    required this.cashierEmail,
    required this.total,
    required this.items,
    required this.createdAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map, String docId) {
    final rawItems = (map['items'] as List<dynamic>? ?? []);
    final timestamp = map['createdAt'];

    return Sale(
      id: docId,
      cashierId: map['cashierId'] ?? '',
      cashierEmail: map['cashierEmail'] ?? '',
      total: (map['total'] ?? 0).toDouble(),
      items: rawItems
          .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cashierId': cashierId,
      'cashierEmail': cashierEmail,
      'total': total,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': createdAt,
    };
  }
}