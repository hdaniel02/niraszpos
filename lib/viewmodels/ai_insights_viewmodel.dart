import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/sales.dart';

class AiInsightsViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hardcoded API key for seamless direct execution
  static const String _apiKey = 'AQ.Ab8RN6LDWl0PNIIqjGU6lYbmyYwDaf6lgPKCQP-icE-f8lYSjg';
  static const String _model = 'gemini-3.5-flash';

  /// Generates smart business insights using Gemini AI from Firestore data.
  /// Falls back to local report generation if offline or API error occurs.
  Future<String> generateInsights() async {
    // ── 1. Fetch data ─────────────────────────────────────────────────────────
    final productsSnapshot = await _firestore.collection('products').get();
    final products = productsSnapshot.docs
        .map((doc) => Product.fromMap(doc.id, doc.data()))
        .toList();

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final sevenDaysAgo  = DateTime.now().subtract(const Duration(days: 7));

    final salesSnapshot = await _firestore
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    final sales = salesSnapshot.docs
        .map((doc) => Sale.fromMap(doc.id, doc.data()))
        .toList();

    // ── 2. Aggregate metrics ──────────────────────────────────────────────────
    double totalRevenue   = 0;
    double weekRevenue    = 0;
    int    totalTxns      = sales.length;
    Map<String, int>    unitsSold    = {};
    Map<String, double> revenuePerProduct = {};
    Map<String, String> productIdByName   = {};

    for (final product in products) {
      productIdByName[product.name] = product.id;
    }

    for (final sale in sales) {
      totalRevenue += sale.total;
      if (sale.createdAt.isAfter(sevenDaysAgo)) weekRevenue += sale.total;
      for (final item in sale.items) {
        unitsSold[item.name]          = (unitsSold[item.name] ?? 0) + item.quantity;
        revenuePerProduct[item.name]  = (revenuePerProduct[item.name] ?? 0) + (item.price * item.quantity);
      }
    }

    final double avgOrderValue = totalTxns > 0 ? totalRevenue / totalTxns : 0;
    final double dailyAvgRevenue = totalRevenue / 30;

    // Sort products by units sold
    final sortedBySales = [...unitsSold.entries.toList()]
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── 3. Identify urgent restocks ───────────────────────────────────────────
    final List<Map<String, dynamic>> urgentRestocks = [];
    for (final product in products) {
      final sold = unitsSold[product.name] ?? 0;
      if (sold == 0 || product.stock <= 0) continue;
      final dailySaleRate = sold / 30.0;
      final daysLeft = (product.stock / dailySaleRate).round();
      if (daysLeft <= 10) {
        urgentRestocks.add({
          'name': product.name,
          'stock': product.stock,
          'sold': sold,
          'daysLeft': daysLeft,
          'dailyRate': dailySaleRate,
        });
      }
    }
    urgentRestocks.sort((a, b) => (a['daysLeft'] as int).compareTo(b['daysLeft'] as int));

    // ── 4. Identify dead stock ────────────────────────────────────────────────
    final List<Map<String, dynamic>> deadStock = [];
    for (final product in products) {
      final sold = unitsSold[product.name] ?? 0;
      if (sold == 0 && product.stock > 0) {
        deadStock.add({'name': product.name, 'stock': product.stock, 'price': product.price});
      } else if (sold <= 2 && product.stock > 5) {
        deadStock.add({'name': product.name, 'stock': product.stock, 'price': product.price, 'sold': sold});
      }
    }

    // ── 5. Business health score (0-100) ─────────────────────────────────────
    int healthScore = 60;
    if (totalRevenue > 0) healthScore += 10;
    if (urgentRestocks.isEmpty) healthScore += 10;
    if (deadStock.isEmpty) healthScore += 10;
    if (avgOrderValue > 20) healthScore += 5;
    if (totalTxns > 20) healthScore += 5;
    healthScore = healthScore.clamp(0, 100);

    String healthLabel;
    String healthEmoji;
    if (healthScore >= 85) { healthLabel = 'Excellent'; healthEmoji = '🟢'; }
    else if (healthScore >= 65) { healthLabel = 'Good'; healthEmoji = '🟡'; }
    else { healthLabel = 'Needs Attention'; healthEmoji = '🔴'; }

    // If there are no transactions, we return immediately with a helpful placeholder
    if (totalTxns == 0) {
      return '# 📊 Shop Sales Report\n'
          '*Generated automatically from your last 30 days of sales data*\n\n'
          '## 🏆 Sales Summary\n\n'
          '| Metric / Ringkasan | Value / Nilai |\n'
          '|---|---|\n'
          '| 💰 Total Sales (30 Days) | **RM 0.00** |\n'
          '| 💪 Shop Performance | **🔴 Needs Attention (60/100)** |\n\n'
          '> ⚠️ **No sales recorded in the last 30 days.** Once you start making sales at the register, your AI assistant will analyze them and give you tips here!';
    }

    // ── 6. Try generating with Gemini 3.5 Flash ──────────────────────────────
    final prompt = '''
You are a warm, encouraging, and experienced retail store consultant helper in Malaysia.
Your job is to analyze the following sales and inventory numbers from the last 30 days and write a simple, easy-to-read shop summary report for a local store owner who is 50+ years old. 

All monetary values are in RM (Malaysian Ringgit).

--- Shop Data (30-day summary) ---
- Total Sales (Hasil Jualan): RM ${totalRevenue.toStringAsFixed(2)}
- Sales This Week: RM ${weekRevenue.toStringAsFixed(2)}
- Total Customers Served (Transactions): $totalTxns
- Average spent per customer (AOV): RM ${avgOrderValue.toStringAsFixed(2)}
- Average sales per day: RM ${dailyAvgRevenue.toStringAsFixed(2)}
- Shop Performance Score: $healthScore/100 ($healthLabel)

--- Best Selling Items (Top Performers) ---
${sortedBySales.take(5).map((e) => '- ${e.key}: ${e.value} units sold, RM ${revenuePerProduct[e.key]?.toStringAsFixed(2) ?? '0.00'} total sales').join('\n')}

--- Stock Running Out Soon (Urgent Restocks) ---
${urgentRestocks.isEmpty ? 'All items have plenty of stock.' : urgentRestocks.map((item) => '- ${item['name']}: only ${item['stock']} units left! (Selling around ${(item['dailyRate'] as double).toStringAsFixed(1)} units/day, will run out in ${item['daysLeft']} days)').join('\n')}

--- Slow Selling Items (Dead Stock) ---
${deadStock.isEmpty ? 'All items are selling well.' : deadStock.map((item) => '- ${item['name']}: ${item['stock']} units sitting on shelves (${item['sold'] ?? 0} sold in 30 days, RM ${((item['stock'] as int) * (item['price'] as double)).toStringAsFixed(2)} tied up)').join('\n')}

--- Guidelines for your response (Crucial for Readability) ---
- Tone: Extremely friendly, respectful, clear, and encouraging. Use simple English (with occasional simple Malay business terms in brackets if helpful, e.g. "Hasil Jualan" or "Stok").
- Language: NEVER use technical startup jargon like "conversion rate", "margin optimization", "revenue growth velocity", "churn rate", "AOV", "dead stock", "data latency", etc. 
- Instead, use simple words:
  * "Total Sales" instead of "Revenue"
  * "Average Spent per Customer" instead of "Average Order Value / AOV"
  * "Shop Performance" instead of "Business Health"
  * "Items Running Out Soon" instead of "Urgent Restocks"
  * "Slow Selling Items" instead of "Dead Stock"
  * "Tips to Grow Sales" instead of "Recommendations"
- Layout: Use very clean formatting.
  * Start with a simple 2-column table summarizing the key metrics with clear descriptions.
  * For metrics, explain what they mean in brackets (e.g. explain that "Average spent per customer" means how much money a single customer typically spends during one visit).
  * Use large section headers (like `## 🏆 Sales Summary`, `## 🥇 Best Selling Items`, `## ⚠️ Stock Alerts`, `## 💡 Easy Steps to Increase Sales`).
  * Give highly practical, step-by-step, numbered tips that a 50-year-old shop owner can start doing today (e.g., "Offer item X as a buy-1-free-1 combo with item Y", "Put item Z near the counter because it runs out fast").
  * Use emojis at the start of lists to make it visually friendly and easy to scan.
''';

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
      print('Gemini API Error: Status ${response.statusCode}, Body: ${response.body}');
    } catch (e) {
      print('Gemini API Exception: $e');
    }

    // ── 7. Fallback to Local Report if Gemini fails ───────────────────────────
    return _generateLocalReport(
      totalRevenue: totalRevenue,
      weekRevenue: weekRevenue,
      totalTxns: totalTxns,
      avgOrderValue: avgOrderValue,
      dailyAvgRevenue: dailyAvgRevenue,
      healthScore: healthScore,
      healthLabel: healthLabel,
      healthEmoji: healthEmoji,
      sortedBySales: sortedBySales,
      revenuePerProduct: revenuePerProduct,
      urgentRestocks: urgentRestocks,
      deadStock: deadStock,
    );
  }

  String _generateLocalReport({
    required double totalRevenue,
    required double weekRevenue,
    required int totalTxns,
    required double avgOrderValue,
    required double dailyAvgRevenue,
    required int healthScore,
    required String healthLabel,
    required String healthEmoji,
    required List<MapEntry<String, int>> sortedBySales,
    required Map<String, double> revenuePerProduct,
    required List<Map<String, dynamic>> urgentRestocks,
    required List<Map<String, dynamic>> deadStock,
  }) {
    final buf = StringBuffer();

    buf.writeln('# 📊 Shop Sales Report *(Offline)*');
    buf.writeln('*Calculated automatically from your last 30 days of sales data*');
    buf.writeln();

    buf.writeln('## 🏆 Sales Summary');
    buf.writeln();
    buf.writeln('| Sales Metric (Maklumat Jualan) | Value / Nilai |');
    buf.writeln('|--------|-------|');
    buf.writeln('| 💰 Total Sales (30 Days) | **RM ${totalRevenue.toStringAsFixed(2)}** |');
    buf.writeln('| 📅 Sales This Week | **RM ${weekRevenue.toStringAsFixed(2)}** |');
    buf.writeln('| 🛒 Customers Served | **$totalTxns** |');
    buf.writeln('| 🧾 Avg. Spent per Customer | **RM ${avgOrderValue.toStringAsFixed(2)}** |');
    buf.writeln('| 📆 Average Sales per Day | **RM ${dailyAvgRevenue.toStringAsFixed(2)}** |');
    buf.writeln('| 💪 Shop Performance | **$healthEmoji $healthLabel ($healthScore/100)** |');
    buf.writeln();

    if (sortedBySales.isNotEmpty) {
      buf.writeln('## 🥇 Best Selling Items');
      buf.writeln('These are your top 5 popular products:');
      buf.writeln();
      buf.writeln('| Rank | Product Name | Units Sold | Total Sales |');
      buf.writeln('|------|---------|-----------|---------|');
      int rank = 1;
      for (final entry in sortedBySales.take(5)) {
        final rev = revenuePerProduct[entry.key]?.toStringAsFixed(2) ?? '0.00';
        final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '  ';
        buf.writeln('| $medal $rank | ${entry.key} | ${entry.value} units | RM $rev |');
        rank++;
      }
      buf.writeln();
    }

    buf.writeln('## ⚠️ Stock Running Out Soon');
    buf.writeln();
    if (urgentRestocks.isEmpty) {
      buf.writeln('✅ Excellent! All fast-moving products have enough stock.');
    } else {
      buf.writeln('These items are selling fast and will run out of stock soon — **please order more:**');
      buf.writeln();
      for (final item in urgentRestocks) {
        final days = item['daysLeft'] as int;
        final urgency = days <= 3 ? '🚨 CRITICAL (Kurang 3 hari!)' : days <= 7 ? '⚠️ Urgent' : '⏰ Soon';
        buf.writeln('- **${item['name']}** — $urgency');
        buf.writeln('  - Left in stock: **${item['stock']} units**');
        buf.writeln('  - Selling speed: **${(item['dailyRate'] as double).toStringAsFixed(1)} units per day**');
        buf.writeln('  - Will run out in: **$days day${days == 1 ? '' : 's'}**');
      }
    }
    buf.writeln();

    buf.writeln('## 🐢 Slow Selling Items');
    buf.writeln();
    if (deadStock.isEmpty) {
      buf.writeln('✅ Great news — all your products are selling well!');
    } else {
      buf.writeln('These products have very low or no sales lately. You can try discounts or combos to clear them:');
      buf.writeln();
      for (final item in deadStock) {
        final sold = item['sold'] ?? 0;
        final stockValue = ((item['stock'] as int) * (item['price'] as double)).toStringAsFixed(2);
        buf.writeln('- **${item['name']}** — ${item['stock']} units sitting on shelves (${sold == 0 ? "0 sales" : "$sold sales"}, RM $stockValue tied up)');
        if (sold == 0) {
          buf.writeln('  - 💡 *Tip: Try bundling this with ${sortedBySales.isNotEmpty ? sortedBySales.first.key : "your best sellers"} as a package deal.*');
        } else {
          buf.writeln('  - 💡 *Tip: Put this near the front of the shop or offer a small discount to clear stock.*');
        }
      }
    }
    buf.writeln();

    buf.writeln('## 💡 Tips to Increase Sales');
    buf.writeln();

    final List<String> recs = [];
    if (avgOrderValue < 15) {
      recs.add('📦 **Create Combo Deals**: Customers spend around RM ${avgOrderValue.toStringAsFixed(2)} per visit. Create packaged combo deals to encourage them to spend more than RM 20.');
    }
    if (weekRevenue > (totalRevenue * 0.4)) {
      recs.add('📈 **Sales Momentum**: Sales this week are very strong! Make sure your shop is fully stocked and staffed to keep up the great work.');
    }
    if (urgentRestocks.isNotEmpty) {
      recs.add('🚚 **Restock Today**: You have ${urgentRestocks.length} popular item(s) running out. Order more today so you don\'t lose sales.');
    }
    if (deadStock.length > 2) {
      recs.add('🏷️ **Run a Promo**: You have a few items sitting on shelves. Run a weekend promotion or a discount to turn them back into cash.');
    }
    if (sortedBySales.isNotEmpty) {
      recs.add('⭐ **Focus on Best Sellers**: **${sortedBySales.first.key}** is your absolute favorite with ${sortedBySales.first.value} items sold. Always make sure this item is prominently displayed near the entrance.');
    }
    if (totalTxns < 10) {
      recs.add('📣 **Attract Customers**: You had only $totalTxns transactions this month. Consider offering a small local discount or posting on social media to invite more people in.');
    }

    if (recs.isEmpty) {
      recs.add('🎉 Your store is running smoothly! Keep an eye on stock levels and maintain your daily sales pace.');
    }

    for (int i = 0; i < recs.length; i++) {
      buf.writeln('${i + 1}. ${recs[i]}');
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln('*This analysis is automatically generated from your sales entries.*');

    return buf.toString();
  }
}

