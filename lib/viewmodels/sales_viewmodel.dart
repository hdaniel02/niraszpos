import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/sales.dart';

class SalesViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Sale>> getSales() {
    return _firestore
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Sale.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> checkoutSale({
    required String cashierId,
    required String cashierEmail,
    required List<SaleItem> items,
    required double total,
    required List<Product> productsToUpdate,
  }) async {
    final batch = _firestore.batch();

    final saleRef = _firestore.collection('sales').doc();

    batch.set(saleRef, {
      'cashierId': cashierId,
      'cashierEmail': cashierEmail,
      'total': total,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final product in productsToUpdate) {
      final productRef = _firestore.collection('products').doc(product.id);
      batch.update(productRef, {
        'stock': product.stock,
      });
    }

    await batch.commit();
  }
}