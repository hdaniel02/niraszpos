import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class ProductViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 GET PRODUCTS (FIXED HERE)
  Stream<List<Product>> getProducts() {
    return _firestore
        .collection('products')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromMap(
          doc.id,          // ✅ FIRST = id
          doc.data(),      // ✅ SECOND = map
        );
      }).toList();
    });
  }

  // 🔹 ADD PRODUCT
  Future<void> addProduct(Product product) async {
    await _firestore.collection('products').add(product.toMap());
  }

  // 🔹 UPDATE PRODUCT
  Future<void> updateProduct(Product product) async {
    await _firestore
        .collection('products')
        .doc(product.id)
        .update(product.toMap());
  }

  // 🔹 DELETE PRODUCT
  Future<void> deleteProduct(String productId) async {
    await _firestore
        .collection('products')
        .doc(productId)
        .delete();
  }
}