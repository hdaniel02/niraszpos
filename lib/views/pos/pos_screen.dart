import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  List<_CartItem> cart = [];
  String searchText = '';
  bool isCheckingOut = false;

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

    setState(() {
      isCheckingOut = true;
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
            ),
          )
          .toList();

      await salesVM.checkoutSale(
        cashierId: currentUser.uid,
        cashierEmail: currentUser.email ?? 'Unknown',
        items: saleItems,
        total: getTotal(),
        productsToUpdate: updatedProducts,
      );

      setState(() {
        cart.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Checkout successful"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Checkout failed: $e"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() {
      isCheckingOut = false;
    });
  }

  Widget buildProductCard(Product product) {
    final outOfStock = product.stock <= 0;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: outOfStock ? null : () => addToCart(product),
      child: Ink(
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
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 6),
            Text(
              product.category,
              style: const TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              "RM ${product.price.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: outOfStock
                    ? Colors.red.withOpacity(0.10)
                    : Colors.green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                outOfStock ? "Out of Stock" : "Stock: ${product.stock}",
                style: TextStyle(
                  color: outOfStock ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBackground,
      body: SafeArea(
        child: StreamBuilder<List<Product>>(
          stream: productVM.getProducts(),
          builder: (context, snapshot) {
            final allProducts = snapshot.data ?? [];
            final products = allProducts.where((product) {
              final query = searchText.toLowerCase();
              return product.name.toLowerCase().contains(query) ||
                  product.category.toLowerCase().contains(query);
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
                              TextField(
                                controller: searchController,
                                onChanged: (value) {
                                  setState(() {
                                    searchText = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: "Search products...",
                                  prefixIcon:
                                      const Icon(Icons.search_rounded),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide:
                                        const BorderSide(color: cardBorder),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide:
                                        const BorderSide(color: cardBorder),
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
                                                padding:
                                                    const EdgeInsets.all(32),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(22),
                                                  border: Border.all(
                                                      color: cardBorder),
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
                                                  childAspectRatio: 0.95,
                                                ),
                                                itemBuilder: (context, index) {
                                                  return buildProductCard(
                                                      products[index]);
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
                                        border:
                                            Border.all(color: cardBorder),
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