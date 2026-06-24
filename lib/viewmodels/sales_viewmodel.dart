import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/sales.dart';

class SalesViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _salesCollection =>
      _firestore.collection('sales');

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      _firestore.collection('products');

  Future<Sale> checkoutSale({
    required String cashierId,
    required String cashierEmail,
    required String paymentMethod,
    required List<SaleItem> items,
    required double total,
    double amountReceived = 0.0,
    double change = 0.0,
    required List<Product> productsToUpdate,
  }) async {
    if (items.isEmpty) {
      throw Exception('Cart is empty.');
    }

    final saleRef = _salesCollection.doc();
    final now = DateTime.now();

    final receiptNo =
        'RCP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${saleRef.id.substring(0, 5).toUpperCase()}';

    final sale = Sale(
      id: saleRef.id,
      receiptNo: receiptNo,
      cashierId: cashierId,
      cashierEmail: cashierEmail,
      paymentMethod: paymentMethod,
      items: items,
      total: total,
      amountReceived: amountReceived,
      change: change,
      createdAt: now,
    );

    await _firestore.runTransaction((transaction) async {
      final List<DocumentReference<Map<String, dynamic>>> productRefs =
          productsToUpdate
              .map((product) => _productsCollection.doc(product.id))
              .toList();

      final List<DocumentSnapshot<Map<String, dynamic>>> productSnapshots = [];
      for (final productRef in productRefs) {
        final snapshot = await transaction.get(productRef);
        productSnapshots.add(snapshot);
      }

      for (int i = 0; i < productSnapshots.length; i++) {
        final snapshot = productSnapshots[i];
        final updatedProduct = productsToUpdate[i];

        if (!snapshot.exists) {
          throw Exception('Product not found: ${updatedProduct.name}');
        }

        final data = snapshot.data();
        final currentStock = (data?['stock'] ?? 0) as int;

        final soldItem = items.firstWhere(
          (item) => item.productId == updatedProduct.id,
          orElse: () => throw Exception(
            'Sale item not found for product: ${updatedProduct.name}',
          ),
        );

        if (currentStock < soldItem.quantity) {
          throw Exception('Insufficient stock for ${updatedProduct.name}');
        }
      }

      for (int i = 0; i < productRefs.length; i++) {
        final productRef = productRefs[i];
        final updatedProduct = productsToUpdate[i];

        transaction.update(productRef, {
          'name': updatedProduct.name,
          'price': updatedProduct.price,
          'stock': updatedProduct.stock,
          'category': updatedProduct.category,
        });
      }

      transaction.set(saleRef, sale.toMap());
    });

    return sale;
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

  Future<List<Sale>> getTodaySalesOnce() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snapshot = await _salesCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
        )
        .get();

    return snapshot.docs.map((doc) {
      return Sale.fromMap(doc.id, doc.data());
    }).toList();
  }

  Future<List<Sale>> getSalesForDateRange(DateTime start, DateTime end) async {
    final snapshot = await _salesCollection
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return snapshot.docs.map((doc) => Sale.fromMap(doc.id, doc.data())).toList();
  }

  Future<List<Sale>> getRecentSales({int months = 6}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months, 1);
    return getSalesForDateRange(start, now);
  }

  Future<void> submitRefundRequest({
    required Sale sale,
    required List<SaleItem> refundItems,
    required double refundAmount,
    String? bankAccountNumber,
    String? customerFullName,
    String? customerPhoneNumber,
  }) async {
    final refundRef = _firestore.collection('refund_requests').doc();
    await refundRef.set({
      'id': refundRef.id,
      'saleId': sale.id,
      'receiptNo': sale.receiptNo,
      'cashierId': sale.cashierId,
      'cashierEmail': sale.cashierEmail,
      'items': refundItems.map((item) => item.toMap()).toList(),
      'total': refundAmount,
      'status': 'pending',
      'bankAccountNumber': bankAccountNumber,
      'customerFullName': customerFullName,
      'customerPhoneNumber': customerPhoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getPendingRefundRequests() {
    return _firestore
        .collection('refund_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getRefundRequestsForSale(String saleId) {
    return _firestore
        .collection('refund_requests')
        .where('saleId', isEqualTo: saleId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> approveRefundRequest(String requestId) async {
    final requestRef = _firestore.collection('refund_requests').doc(requestId);
    final requestSnapshot = await requestRef.get();
    if (!requestSnapshot.exists) {
      throw Exception('Refund request not found.');
    }

    final data = requestSnapshot.data()!;
    final saleId = data['saleId'] as String;
    final itemsList = (data['items'] as List<dynamic>? ?? [])
        .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    final refundAmount = (data['total'] ?? 0.0).toDouble();

    await executeApprovedRefund(
      saleId: saleId,
      refundItems: itemsList,
      refundAmount: refundAmount,
    );

    await requestRef.update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRefundRequest(String requestId) async {
    await _firestore.collection('refund_requests').doc(requestId).update({
      'status': 'rejected',
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> processImmediateRefund({
    required Sale sale,
    required List<SaleItem> refundItems,
    required double refundAmount,
    String? bankAccountNumber,
    String? customerFullName,
    String? customerPhoneNumber,
  }) async {
    final tempRequestRef = _firestore.collection('refund_requests').doc();
    final now = DateTime.now();

    await tempRequestRef.set({
      'id': tempRequestRef.id,
      'saleId': sale.id,
      'receiptNo': sale.receiptNo,
      'cashierId': sale.cashierId,
      'cashierEmail': sale.cashierEmail,
      'items': refundItems.map((item) => item.toMap()).toList(),
      'total': refundAmount,
      'status': 'approved',
      'bankAccountNumber': bankAccountNumber,
      'customerFullName': customerFullName,
      'customerPhoneNumber': customerPhoneNumber,
      'createdAt': Timestamp.fromDate(now),
      'approvedAt': Timestamp.fromDate(now),
    });

    await executeApprovedRefund(
      saleId: sale.id,
      refundItems: refundItems,
      refundAmount: refundAmount,
    );
  }

  Future<void> executeApprovedRefund({
    required String saleId,
    required List<SaleItem> refundItems,
    required double refundAmount,
  }) async {
    await _firestore.runTransaction((transaction) async {
      final saleRef = _salesCollection.doc(saleId);
      final saleSnapshot = await transaction.get(saleRef);
      if (!saleSnapshot.exists) {
        throw Exception('Sale record not found.');
      }

      final saleData = saleSnapshot.data()!;
      final currentSale = Sale.fromMap(saleSnapshot.id, saleData);

      final List<SaleItem> updatedItems = [];
      for (final currentItem in currentSale.items) {
        final refundItem = refundItems.firstWhere(
          (item) => item.productId == currentItem.productId,
          orElse: () => SaleItem(
            productId: currentItem.productId,
            name: currentItem.name,
            price: currentItem.price,
            quantity: 0,
            refundedQuantity: 0,
          ),
        );

        final newRefundedQuantity = currentItem.refundedQuantity + refundItem.quantity;
        if (newRefundedQuantity > currentItem.quantity) {
          throw Exception('Refund quantity exceeds original purchased quantity for ${currentItem.name}');
        }

        updatedItems.add(SaleItem(
          productId: currentItem.productId,
          name: currentItem.name,
          price: currentItem.price,
          quantity: currentItem.quantity,
          refundedQuantity: newRefundedQuantity,
        ));
      }

      bool allFullyRefunded = true;
      bool anyRefunded = false;
      for (final item in updatedItems) {
        if (item.refundedQuantity < item.quantity) {
          allFullyRefunded = false;
        }
        if (item.refundedQuantity > 0) {
          anyRefunded = true;
        }
      }

      String? newStatus;
      if (allFullyRefunded) {
        newStatus = 'full';
      } else if (anyRefunded) {
        newStatus = 'partial';
      }

      final newTotalRefundedAmount = currentSale.refundedAmount + refundAmount;

      // Phase 1: Reads
      final Map<String, DocumentSnapshot<Map<String, dynamic>>> productSnapshots = {};
      for (final refundItem in refundItems) {
        if (refundItem.quantity <= 0) continue;
        final productRef = _productsCollection.doc(refundItem.productId);
        productSnapshots[refundItem.productId] = await transaction.get(productRef);
      }

      // Phase 2: Writes
      for (final refundItem in refundItems) {
        if (refundItem.quantity <= 0) continue;
        final productSnapshot = productSnapshots[refundItem.productId];
        if (productSnapshot != null && productSnapshot.exists) {
          final productData = productSnapshot.data()!;
          final currentStock = (productData['stock'] ?? 0) as int;
          transaction.update(productSnapshot.reference, {
            'stock': currentStock + refundItem.quantity,
          });
        }
      }

      transaction.update(saleRef, {
        'items': updatedItems.map((item) => item.toMap()).toList(),
        'refundStatus': newStatus,
        'refundedAmount': newTotalRefundedAmount,
      });
    });
  }

  Stream<List<Map<String, dynamic>>> getAllRefundRequestsStream() {
    return _firestore
        .collection('refund_requests')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      list.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getCashierRefundRequestsStream(String cashierId) {
    return getAllRefundRequestsStream().map((list) {
      return list.where((req) => req['cashierId'] == cashierId).toList();
    });
  }
}