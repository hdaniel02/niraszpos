import 'package:flutter/material.dart';
import '../../models/product.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {

  List<Product> products = [
    Product(id: "1", name: "Coffee", price: 5.0, stock: 20, category: "Beverages"),
    Product(id: "2", name: "Bread", price: 3.0, stock: 30, category: "Bakery"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Products"),
      ),
      body: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) {

          final product = products[index];

          return ListTile(
            title: Text(product.name),
            subtitle: Text("Stock: ${product.stock}"),
            trailing: Text("RM ${product.price}"),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
       onPressed: () async {

  final newProduct = await Navigator.pushNamed(context, "/add-product");

  if (newProduct != null) {
    setState(() {
      products.add(newProduct as Product);
    });
  }

},
        child: const Icon(Icons.add),
      ),
    );
  }
}