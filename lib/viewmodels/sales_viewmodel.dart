import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/sales.dart';

class SalesViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _salesCollection =>
      _firestore.collection('sales');

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      _firestore.collection('products');

  Future<void> checkoutSale({
    required String cashierId,
    required String cashierEmail,
    required List<SaleItem> items,
    required double total,
    required List<Product> productsToUpdate,
  }) async {
    if (items.isEmpty) {
      throw Exception('Cart is empty.');
    }

    final saleRef = _salesCollection.doc();

    await _firestore.runTransaction((transaction) async {
      for (final updatedProduct in productsToUpdate) {
        final productRef = _productsCollection.doc(updatedProduct.id);
        final productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) {
          throw Exception('Product not found: ${updatedProduct.name}');
        }

        transaction.update(productRef, {
          'name': updatedProduct.name,
          'price': updatedProduct.price,
          'stock': updatedProduct.stock,
          'category': updatedProduct.category,
        });
      }

      final sale = Sale(
        id: saleRef.id,
        cashierId: cashierId,
        cashierEmail: cashierEmail,
        items: items,
        total: total,
        createdAt: DateTime.now(),
      );

      transaction.set(saleRef, sale.toMap());
    });
  }

  Stream<List<Sale>> getSales() {
    return _salesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Sale.fromMap(doc.id, doc.data());
      }).toList();
    });
  }
}