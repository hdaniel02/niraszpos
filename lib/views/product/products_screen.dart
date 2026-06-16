import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product.dart';
import '../../viewmodels/product_viewmodel.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  static String? initialSearchQuery;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductViewModel productVM = ProductViewModel();

  String searchQuery = '';
  String selectedCategory = 'All';
  final TextEditingController searchController = TextEditingController();
  bool isSelectMode = false;
  final Set<String> selectedProductIds = {};

  @override
  void initState() {
    super.initState();
    _checkInitialSearchQuery();
  }

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkInitialSearchQuery();
  }

  void _checkInitialSearchQuery() {
    if (ProductsScreen.initialSearchQuery != null) {
      final query = ProductsScreen.initialSearchQuery!;
      ProductsScreen.initialSearchQuery = null;
      searchController.text = query;
      searchQuery = query;
      selectedCategory = 'All';
    }
  }

  static const Color primaryGreen = Color(0xFF059669);
  static const Color lightGreen = Color(0xFFDCFCE7);
  static const Color softBackground = Color(0xFFF8FAFC);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  Color getStockColor(int stock) {
    if (stock <= 5) return Colors.red;
    if (stock <= 15) return Colors.orange;
    return Colors.green;
  }

  Widget _buildProductImage(String imageUrl, {double? width, double? height, double borderRadius = 18}) {
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: lightGreen,
        alignment: Alignment.center,
        child: const Icon(Icons.inventory_2_rounded, color: primaryGreen, size: 30),
      );
    }

    Widget imageWidget;
    if (imageUrl.startsWith('data:image/') || imageUrl.contains('base64,')) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: width,
          height: height,
        );
      } catch (e) {
        imageWidget = Container(
          color: lightGreen,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_rounded, color: Colors.red, size: 30),
        );
      }
    } else {
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => Container(
          color: lightGreen,
          alignment: Alignment.center,
          child: const Icon(Icons.inventory_2_rounded, color: primaryGreen, size: 30),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageWidget,
    );
  }

  void _showProductDialog(BuildContext context, {Product? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController =
        TextEditingController(text: product != null ? product.price.toString() : '');
    final stockController =
        TextEditingController(text: product != null ? product.stock.toString() : '');
    final categoryController =
        TextEditingController(text: product?.category ?? '');
    final barcodeController =
        TextEditingController(text: product?.barcode ?? '');

    final isEdit = product != null;
    File? selectedImage;
    String? existingImageUrl = product?.imageUrl;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 300,
              maxHeight: 300,
              imageQuality: 70,
            );
            if (pickedFile != null) {
              setDialogState(() {
                selectedImage = File(pickedFile.path);
              });
            }
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9, 
              constraints: const BoxConstraints(maxWidth: 900),
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: lightGreen,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                            color: primaryGreen,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? "Update Product Details" : "Create New Product",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Fill in the required information to manage this item in your inventory.",
                                style: TextStyle(fontSize: 14, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Main Content Row (Image on left, Form on right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Image Upload
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Product Image"),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: isSaving ? null : pickImage,
                                child: Container(
                                  width: double.infinity,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: cardBorder,
                                      width: 2,
                                    ),
                                  ),
                                  child: selectedImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(18),
                                          child: Image.file(
                                            selectedImage!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 240,
                                          ),
                                        )
                                      : (existingImageUrl != null && existingImageUrl.isNotEmpty)
                                          ? (existingImageUrl.startsWith('data:image/') || existingImageUrl.contains('base64,'))
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(18),
                                                  child: Image.memory(
                                                    base64Decode(existingImageUrl.split(',').last),
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: 240,
                                                  ),
                                                )
                                              : ClipRRect(
                                                  borderRadius: BorderRadius.circular(18),
                                                  child: Image.network(
                                                    existingImageUrl,
                                                    fit: BoxFit.cover,
                                                    width: double.infinity,
                                                    height: 240,
                                                    errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                                                  ),
                                                )
                                          : _buildImagePlaceholder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        
                        // Right: Form Fields
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Product Name"),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: nameController,
                                hint: "e.g. Premium Coffee Beans",
                                icon: Icons.inventory_2_outlined,
                              ),
                              const SizedBox(height: 20),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Price (RM)"),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: priceController,
                                          hint: "0.00",
                                          icon: Icons.attach_money_rounded,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Stock Quantity"),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: stockController,
                                          hint: "0",
                                          icon: Icons.numbers_rounded,
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Category"),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: categoryController,
                                          hint: "e.g. Beverages",
                                          icon: Icons.category_outlined,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel("Barcode (Optional)"),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: barcodeController,
                                          hint: "Scan or enter",
                                          icon: Icons.qr_code_rounded,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 36),
                    const Divider(color: cardBorder, height: 1),
                    const SizedBox(height: 24),
                    
                    // Footer Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textSecondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: const BorderSide(color: cardBorder, width: 1.5),
                            ),
                            child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              final name = nameController.text.trim();
                              final price = double.tryParse(priceController.text.trim());
                              final stock = int.tryParse(stockController.text.trim());
                              final category = categoryController.text.trim();
                              final barcode = barcodeController.text.trim();

                              if (name.isEmpty || price == null || stock == null || category.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please fill all required fields correctly"), behavior: SnackBarBehavior.floating),
                                );
                                return;
                              }

                              setDialogState(() { isSaving = true; });

                              try {
                                String imageUrl = existingImageUrl ?? '';
                                if (selectedImage != null) {
                                  try {
                                    imageUrl = await productVM.uploadProductImage(selectedImage!);
                                  } catch (e) {
                                    debugPrint("Storage upload failed, falling back to Base64: $e");
                                    final bytes = await selectedImage!.readAsBytes();
                                    imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                                  }
                                }

                                final newProduct = Product(
                                  id: product?.id ?? '',
                                  name: name,
                                  price: price,
                                  stock: stock,
                                  category: category,
                                  barcode: barcode,
                                  imageUrl: imageUrl,
                                );

                                if (isEdit) {
                                  await productVM.updateProduct(newProduct);
                                } else {
                                  await productVM.addProduct(newProduct);
                                }

                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isEdit ? "Product updated successfully" : "Product added successfully"), behavior: SnackBarBehavior.floating),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e"), behavior: SnackBarBehavior.floating),
                                );
                              } finally {
                                setDialogState(() { isSaving = false; });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(isEdit ? Icons.save_rounded : Icons.check_circle_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(isEdit ? "Save Changes" : "Create Product", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLowStockDialog(BuildContext context, List<Product> lowStockProducts) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Low Stock Warning",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          content: lowStockProducts.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade600, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      "All caught up!",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "No low stock items found.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                    const SizedBox(height: 16),
                  ],
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: lowStockProducts.length,
                          separatorBuilder: (context, index) => const Divider(color: cardBorder, height: 1),
                          itemBuilder: (context, index) {
                            final product = lowStockProducts[index];
                            final isOutOfStock = product.stock == 0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildProductImage(product.imageUrl, width: 40, height: 40),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                              subtitle: Text(
                                isOutOfStock ? "Out of Stock" : "Only ${product.stock} left",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isOutOfStock ? Colors.red.shade700 : Colors.amber.shade800,
                                ),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondary),
                              onTap: () {
                                Navigator.pop(dialogContext);
                                setState(() {
                                  searchController.text = product.name;
                                  searchQuery = product.name;
                                  selectedCategory = 'All';
                                });
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    _showProductDialog(context, product: product);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: OutlinedButton.styleFrom(
                foregroundColor: textSecondary,
                side: const BorderSide(color: cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_photo_alternate_rounded,
            size: 36,
            color: primaryGreen,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Upload Image",
          style: TextStyle(
            fontSize: 15,
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "PNG, JPG up to 5MB",
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
          ),
        ),
      ],
    );
  }


  void _showBatchDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Delete Products",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: textSecondary, height: 1.5),
                  children: [
                    const TextSpan(text: "Are you sure you want to permanently delete the\n"),
                    TextSpan(
                      text: "${selectedProductIds.length} selected products",
                      style: const TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    const TextSpan(text: "? This action cannot be undone."),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: cardBorder, width: 1.5),
                        ),
                        child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Deleting selected products..."),
                              duration: Duration(days: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                          try {
                            for (final id in selectedProductIds) {
                              await productVM.deleteProduct(id);
                            }
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Selected products deleted successfully"),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }

                            setState(() {
                              isSelectMode = false;
                              selectedProductIds.clear();
                            });
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Delete failed: $e"),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showDeleteDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Delete Product",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: textSecondary, height: 1.5),
                  children: [
                    const TextSpan(text: "Are you sure you want to permanently delete\n"),
                    TextSpan(
                      text: product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
                    ),
                    const TextSpan(text: "? This action cannot be undone."),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: cardBorder, width: 1.5),
                        ),
                        child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await productVM.deleteProduct(product.id);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Product deleted successfully"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Delete failed: $e"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
    );
  }

  Widget buildProductCard(BuildContext context, Product product) {
    final stockColor = getStockColor(product.stock);
    final isSelected = selectedProductIds.contains(product.id);

    return GestureDetector(
      onTap: isSelectMode
          ? () {
              setState(() {
                if (isSelected) {
                  selectedProductIds.remove(product.id);
                } else {
                  selectedProductIds.add(product.id);
                }
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? lightGreen.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? primaryGreen : cardBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isSelectMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      selectedProductIds.add(product.id);
                    } else {
                      selectedProductIds.remove(product.id);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: _buildProductImage(product.imageUrl, width: 56, height: 56, borderRadius: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Category: ${product.category}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                  if (product.barcode.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.qr_code_rounded,
                          size: 14,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.barcode,
                          style: const TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    "RM ${product.price.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    product.stock == 0 ? "SOLD OUT" : "Stock: ${product.stock}",
                    style: TextStyle(
                      color: stockColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!isSelectMode) ...[
                  const SizedBox(height: 10),
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showProductDialog(context, product: product);
                      } else if (value == 'delete') {
                        _showDeleteDialog(context, product);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text("Edit Details"),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 10),
                            Text("Delete Product", style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Icon(Icons.edit_rounded, color: primaryGreen, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBackground,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_box_rounded),
        label: const Text("Add Product"),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Product>>(
          stream: productVM.getProducts(),
          builder: (context, snapshot) {

            final products = snapshot.data ?? [];
            final lowStock = products.where((p) => p.stock <= 5).length;
            
            final categories = ['All', ...products.map((p) => p.category).toSet().toList()..sort()];
            final filteredProducts = products.where((p) {
              final matchesCategory = selectedCategory == 'All' || p.category == selectedCategory;
              final matchesSearch = p.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
                                    p.barcode.contains(searchQuery);
              return matchesCategory && matchesSearch;
            }).toList();


            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: cardBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: lightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Products",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Create, update, and manage store inventory items.",
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final summaryItems = [
                              {
                                "title": "Total Products",
                                "value": products.length.toString(),
                                "icon": Icons.inventory_2_rounded,
                              },
                              {
                                "title": "Low Stock",
                                "value": lowStock.toString(),
                                "icon": Icons.warning_amber_rounded,
                              },
                              {
                                "title": "Categories",
                                "value": products
                                    .map((p) => p.category)
                                    .toSet()
                                    .length
                                    .toString(),
                                "icon": Icons.category_rounded,
                              },
                            ];

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: summaryItems.length,
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 320,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 100, // Compact and fixed height
                              ),
                              itemBuilder: (context, index) {
                                final item = summaryItems[index];
                                final isLowStockCard = item["title"] == "Low Stock";
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
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
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: isLowStockCard
                                          ? () {
                                              final lowStockProducts = products
                                                  .where((p) => p.stock <= 5)
                                                  .toList();
                                              _showLowStockDialog(
                                                  context, lowStockProducts);
                                            }
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                color: lightGreen,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Icon(
                                                item["icon"] as IconData,
                                                color: primaryGreen,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    item["title"] as String,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: textSecondary,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    item["value"] as String,
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w700,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          "Inventory Items",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "View and manage available products for sales and stock tracking.",
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // --- Search and Filter UI ---
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: searchController,
                                onChanged: (value) {
                                  setState(() {
                                    searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: "Search products by name or barcode...",
                                  prefixIcon: const Icon(Icons.search_rounded, color: textSecondary),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, color: textSecondary),
                                          onPressed: () {
                                            searchController.clear();
                                            setState(() {
                                              searchQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: cardBorder)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primaryGreen, width: 2)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Category Chips & Selection Actions Row
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: categories.length,
                                  itemBuilder: (context, index) {
                                    final cat = categories[index];
                                    final isSelected = cat == selectedCategory;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: ChoiceChip(
                                        label: Text(cat),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              selectedCategory = cat;
                                            });
                                          }
                                        },
                                        selectedColor: primaryGreen,
                                        labelStyle: TextStyle(
                                          color: isSelected ? Colors.white : textSecondary,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                        backgroundColor: Colors.white,
                                        side: BorderSide(color: isSelected ? primaryGreen : cardBorder),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (isSelectMode) ...[
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    isSelectMode = false;
                                    selectedProductIds.clear();
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                                label: const Text("Cancel"),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: textSecondary,
                                  side: const BorderSide(color: cardBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                  fixedSize: const Size.fromHeight(40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: selectedProductIds.isEmpty
                                    ? null
                                    : () => _showBatchDeleteDialog(context),
                                icon: const Icon(Icons.delete_rounded, size: 18),
                                label: Text("Delete (${selectedProductIds.length})"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.red.withOpacity(0.4),
                                  disabledForegroundColor: Colors.white.withOpacity(0.6),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                  fixedSize: const Size.fromHeight(40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    isSelectMode = true;
                                    selectedProductIds.clear();
                                  });
                                },
                                icon: const Icon(Icons.checklist_rounded, size: 18),
                                label: const Text("Select Multiple"),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: textSecondary,
                                  side: const BorderSide(color: cardBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                  fixedSize: const Size.fromHeight(40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        // --- End Search and Filter UI ---
                        if (snapshot.connectionState == ConnectionState.waiting)
                          Container(
                            height: 220,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder),
                            ),
                            child: const CircularProgressIndicator(),
                          )
                        else if (snapshot.hasError)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Text(
                              "Error loading products: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        else if (filteredProducts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: cardBorder),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 52,
                                  color: textSecondary,
                                ),
                                SizedBox(height: 14),
                                Text(
                                  "No products found",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  "Tap the Add Product button to create your first inventory item.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              return buildProductCard(context, filteredProducts[index]);
                            },
                          ),
                      ],
                    ),
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