class Product {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String category;
  final String barcode;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    this.barcode = '',
    this.imageUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'stock': stock,
      'category': category,
      'barcode': barcode,
      'imageUrl': imageUrl,
    };
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      stock: (map['stock'] ?? 0) as int,
      category: map['category'] ?? '',
      barcode: map['barcode'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
    );
  }
}