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
      return '# 📊 Business Insights Report\n'
          '*Generated automatically from your last 30 days of sales data*\n\n'
          '## 🏆 Executive Summary\n\n'
          '| Metric | Value |\n'
          '|---|---|\n'
          '| 💰 Total Revenue (30d) | **RM 0.00** |\n'
          '| 💪 Business Health | **🔴 Needs Attention (60/100)** |\n\n'
          '> ⚠️ **No sales recorded in the last 30 days.** Start making sales to see insights here!';
    }

    // ── 6. Try generating with Gemini 3.5 Flash ──────────────────────────────
    final prompt = '''
You are a professional AI Business Analytics Consultant for a Malaysian POS retail store.
Analyze the following store performance data from the last 30 days and provide deep, professional, and actionable business insights.
All financial values are in RM (Malaysian Ringgit).

--- Raw Data (30-day summary) ---
- Total Revenue: RM ${totalRevenue.toStringAsFixed(2)}
- This Week's Revenue: RM ${weekRevenue.toStringAsFixed(2)}
- Total Transactions: $totalTxns
- Average Order Value: RM ${avgOrderValue.toStringAsFixed(2)}
- Daily Average Revenue: RM ${dailyAvgRevenue.toStringAsFixed(2)}
- Calculated Business Health Score: $healthScore/100 ($healthLabel)

--- Top Performing Products (Units Sold & Revenue) ---
${sortedBySales.take(5).map((e) => '- ${e.key}: ${e.value} units sold, RM ${revenuePerProduct[e.key]?.toStringAsFixed(2) ?? '0.00'} revenue').join('\n')}

--- Urgent Inventory Restocks Needed ---
${urgentRestocks.isEmpty ? 'All fast-moving products have sufficient stock. No urgent restocks needed.' : urgentRestocks.map((item) => '- ${item['name']}: ${item['stock']} units left (selling at ${(item['dailyRate'] as double).toStringAsFixed(1)} units/day, runs out in ${item['daysLeft']} days)').join('\n')}

--- Slow-Moving / Dead Stock ---
${deadStock.isEmpty ? 'No dead stock detected.' : deadStock.map((item) => '- ${item['name']}: ${item['stock']} units in stock (${item['sold'] ?? 0} sales in 30 days, RM ${((item['stock'] as int) * (item['price'] as double)).toStringAsFixed(2)} tied up)').join('\n')}

--- Guidelines for your response ---
Please generate a beautiful, professional business analysis report in Markdown.
The report MUST contain:
1. A summary section with a styled Markdown table of the key metrics.
2. A performance analysis section commenting on sales trends (e.g. comparing weekly revenue to total revenue, average order value health, etc.).
3. Inventory strategy section detailing which items need restocking and how many to order, plus tips for dead stock (like discount offers, bundling, etc.).
4. Clear, numbered business growth suggestions/recommendations tailored specifically to the data.

Use emojis, bold text, lists, and tables to make the report look polished and executive. Address the business owner directly. Keep your tone encouraging, strategic, and concise. Do not mention that these numbers were computed beforehand; speak as if you are analyzing the store's databases directly.
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

    buf.writeln('# 📊 Business Insights Report *(Generated Offline)*');
    buf.writeln('*Calculated from your last 30 days of sales data*');
    buf.writeln();

    buf.writeln('## 🏆 Executive Summary');
    buf.writeln();
    buf.writeln('| Metric | Value |');
    buf.writeln('|--------|-------|');
    buf.writeln('| 💰 Total Revenue (30d) | **RM ${totalRevenue.toStringAsFixed(2)}** |');
    buf.writeln('| 📅 This Week Revenue   | **RM ${weekRevenue.toStringAsFixed(2)}** |');
    buf.writeln('| 🛒 Total Transactions  | **$totalTxns** |');
    buf.writeln('| 🧾 Avg Order Value     | **RM ${avgOrderValue.toStringAsFixed(2)}** |');
    buf.writeln('| 📆 Daily Avg Revenue   | **RM ${dailyAvgRevenue.toStringAsFixed(2)}** |');
    buf.writeln('| 💪 Business Health     | **$healthEmoji $healthLabel ($healthScore/100)** |');
    buf.writeln();

    if (sortedBySales.isNotEmpty) {
      buf.writeln('## 🥇 Top Performing Products');
      buf.writeln();
      buf.writeln('| Rank | Product | Units Sold | Revenue |');
      buf.writeln('|------|---------|-----------|---------|');
      int rank = 1;
      for (final entry in sortedBySales.take(5)) {
        final rev = revenuePerProduct[entry.key]?.toStringAsFixed(2) ?? '0.00';
        final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '  ';
        buf.writeln('| $medal $rank | ${entry.key} | ${entry.value} | RM $rev |');
        rank++;
      }
      buf.writeln();
    }

    buf.writeln('## 🔴 Urgent Restocks');
    buf.writeln();
    if (urgentRestocks.isEmpty) {
      buf.writeln('✅ All fast-moving products have sufficient stock. No urgent restocks needed!');
    } else {
      buf.writeln('These items are selling fast and will run out soon — **restock immediately:**');
      buf.writeln();
      for (final item in urgentRestocks) {
        final days = item['daysLeft'] as int;
        final urgency = days <= 3 ? '🚨 CRITICAL' : days <= 7 ? '⚠️ Urgent' : '⏰ Soon';
        buf.writeln('- **${item['name']}** — $urgency');
        buf.writeln('  - Current stock: **${item['stock']} units**');
        buf.writeln('  - Selling at: **${(item['dailyRate'] as double).toStringAsFixed(1)} units/day**');
        buf.writeln('  - Estimated run-out: **$days day${days == 1 ? '' : 's'}**');
      }
    }
    buf.writeln();

    buf.writeln('## 💀 Dead Stock Alert');
    buf.writeln();
    if (deadStock.isEmpty) {
      buf.writeln('✅ Great news — all products have recorded at least some sales. No dead stock detected!');
    } else {
      buf.writeln('The following products have little or no sales. Consider taking action:');
      buf.writeln();
      for (final item in deadStock) {
        final sold = item['sold'] ?? 0;
        final stockValue = ((item['stock'] as int) * (item['price'] as double)).toStringAsFixed(2);
        buf.writeln('- **${item['name']}** — ${item['stock']} units in stock (${sold == 0 ? "0 sales" : "$sold sales"}, RM $stockValue tied up)');
        if (sold == 0) {
          buf.writeln('  - 💡 *Suggestion: Try bundling with ${sortedBySales.isNotEmpty ? sortedBySales.first.key : "top sellers"}, or apply a limited-time discount.*');
        } else {
          buf.writeln('  - 💡 *Suggestion: Promote this item or apply a small discount to boost movement.*');
        }
      }
    }
    buf.writeln();

    buf.writeln('## 💡 Recommendations');
    buf.writeln();

    final List<String> recs = [];
    if (avgOrderValue < 15) {
      recs.add('📦 **Upsell & Bundle**: Your average order value is RM ${avgOrderValue.toStringAsFixed(2)}. Try creating combo deals to push it above RM 20.');
    }
    if (weekRevenue > (totalRevenue * 0.4)) {
      recs.add('📈 **Strong Week**: This week\'s revenue is ${((weekRevenue / totalRevenue) * 100).toStringAsFixed(0)}% of your monthly total. Keep this momentum going!');
    }
    if (urgentRestocks.isNotEmpty) {
      recs.add('🚚 **Prioritize Restocking**: You have ${urgentRestocks.length} item(s) at risk of running out. Place orders today to avoid lost sales.');
    }
    if (deadStock.length > 2) {
      recs.add('🏷️ **Clear Dead Stock**: ${deadStock.length} items have very low movement. Run a weekend promo or bundle them with your top sellers.');
    }
    if (sortedBySales.isNotEmpty) {
      recs.add('⭐ **Double Down on Winners**: **${sortedBySales.first.key}** is your best seller with ${sortedBySales.first.value} units sold. Make sure it\'s always in stock and prominently displayed.');
    }
    if (totalTxns < 10) {
      recs.add('📣 **Drive More Traffic**: Only $totalTxns transactions in 30 days. Consider running a promotion or loyalty program to bring in more customers.');
    }

    if (recs.isEmpty) {
      recs.add('🎉 Your business is performing well! Keep monitoring stock levels and maintain your current sales pace.');
    }

    for (final rec in recs) {
      buf.writeln(rec);
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln('*This report is generated automatically from your sales and inventory data. Data reflects the last 30 days.*');

    return buf.toString();
  }
}

