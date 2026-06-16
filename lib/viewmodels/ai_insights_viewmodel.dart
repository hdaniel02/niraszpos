import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/sales.dart';

class AiInsightsViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> generateInsights(String apiKey) async {
    try {
      // 1. Fetch Current Inventory
      final productsSnapshot = await _firestore.collection('products').get();
      final products = productsSnapshot.docs.map((doc) => Product.fromMap(doc.id, doc.data())).toList();

      // 2. Fetch Recent Sales (Last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final salesSnapshot = await _firestore
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      final sales = salesSnapshot.docs.map((doc) => Sale.fromMap(doc.id, doc.data())).toList();

      // 3. Aggregate Data for the AI
      Map<String, int> unitsSoldPerProduct = {};
      double totalRevenue = 0.0;

      for (var sale in sales) {
        totalRevenue += sale.total;
        for (var item in sale.items) {
          unitsSoldPerProduct[item.name] = (unitsSoldPerProduct[item.name] ?? 0) + item.quantity;
        }
      }

      // 4. Build the context prompt
      StringBuffer prompt = StringBuffer();
      prompt.writeln("You are an elite retail business consultant and data analyst. You are analyzing the data from a modern Point of Sale (POS) system.");
      prompt.writeln("I will provide you with the current inventory and the sales data from the last 30 days.");
      prompt.writeln("Your task is to analyze this data and provide actionable business insights.");
      prompt.writeln("\n## Key Metrics:");
      prompt.writeln("- Total Revenue (Last 30 Days): RM ${totalRevenue.toStringAsFixed(2)}");
      prompt.writeln("- Total Transactions: ${sales.length}");
      
      prompt.writeln("\n## Inventory & Performance Data:");
      for (var product in products) {
        int sold = unitsSoldPerProduct[product.name] ?? 0;
        prompt.writeln("- ${product.name}: Stock=${product.stock}, Price=RM ${product.price}, Units Sold (Last 30 Days)=$sold");
      }

      prompt.writeln("\n## Required Output Format:");
      prompt.writeln("Please provide a beautifully formatted Markdown report with the following sections:");
      prompt.writeln("1. **Executive Summary**: A 2-sentence summary of the business's health.");
      prompt.writeln("2. **Urgent Restocks**: A list of items that are selling fast but have low stock. Predict when they might run out.");
      prompt.writeln("3. **Dead Stock Alert**: Items taking up space with zero or very low sales. Suggest a strategy to clear them (e.g., bundling, discounts).");
      prompt.writeln("4. **Future Forecast**: A brief prediction of what items will likely sell well next month based on the data, and general advice to hit KPIs.");
      prompt.writeln("\nKeep the tone professional, encouraging, and highly actionable.");

      // 5. Call Gemini via pure HTTP
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');
      final body = jsonEncode({
        "contents": [{
          "parts": [{"text": prompt.toString()}]
        }],
        "generationConfig": {
          "temperature": 0.2
        }
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode != 200) {
        return "⚠️ **API Error (${response.statusCode}):**\n\n```json\n${response.body}\n```";
      }

      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      return text;

    } catch (e) {
      return "⚠️ **System Error:**\n\n$e";
    }
  }
}
