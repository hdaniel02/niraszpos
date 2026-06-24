import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/sales.dart';
import '../models/insights_data.dart';

class AiInsightsViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<InsightsData> generateInsights() async {
    // ── 1. Fetch data ─────────────────────────────────────────────────────────
    final productsSnapshot = await _firestore.collection('products').get();
    final products = productsSnapshot.docs
        .map((doc) => Product.fromMap(doc.id, doc.data()))
        .toList();

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo  = now.subtract(const Duration(days: 7));
    final oneYearAgo    = now.subtract(const Duration(days: 365));

    final salesSnapshot = await _firestore
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneYearAgo))
        .get();

    final allSales = salesSnapshot.docs
        .map((doc) => Sale.fromMap(doc.id, doc.data()))
        .toList();
        
    final sales = allSales.where((s) => s.createdAt.isAfter(thirtyDaysAgo)).toList();
    final weeklySales = allSales.where((s) => s.createdAt.isAfter(sevenDaysAgo)).toList();

    // ── 2. Aggregate metrics ──────────────────────────────────────────────────
    double totalRevenue   = 0;
    double weekRevenue    = 0;
    int    totalTxns      = sales.length;
    Map<String, int>    unitsSold    = {};
    Map<String, double> revenuePerProduct = {};

    // For line charts: aggregate revenue per day over the last 30 days
    List<double> dailyRevenues = List.filled(30, 0.0);

    for (final sale in sales) {
      totalRevenue += sale.total;
      
      // Calculate daily revenue index (0 is 30 days ago, 29 is today)
      final difference = sale.createdAt.difference(thirtyDaysAgo).inDays;
      if (difference >= 0 && difference < 30) {
        dailyRevenues[difference] += sale.total;
      }

      if (sale.createdAt.isAfter(sevenDaysAgo)) weekRevenue += sale.total;
      for (final item in sale.items) {
        unitsSold[item.name]          = (unitsSold[item.name] ?? 0) + item.quantity;
        revenuePerProduct[item.name]  = (revenuePerProduct[item.name] ?? 0) + (item.price * item.quantity);
      }
    }

    final double avgOrderValue = totalTxns > 0 ? totalRevenue / totalTxns : 0;
    final double dailyAvgRevenue = totalRevenue / 30;

    // Calculate Weekly Top Products
    Map<String, int> unitsSoldWeekly = {};
    Map<String, double> revenueWeekly = {};
    for (final sale in weeklySales) {
      for (final item in sale.items) {
        unitsSoldWeekly[item.name] = (unitsSoldWeekly[item.name] ?? 0) + item.quantity;
        revenueWeekly[item.name] = (revenueWeekly[item.name] ?? 0) + (item.price * item.quantity);
      }
    }
    final sortedBySalesWeekly = [...unitsSoldWeekly.entries.toList()]..sort((a, b) => b.value.compareTo(a.value));
    final topProductsWeeklyList = sortedBySalesWeekly.take(5).map((e) => TopProduct(
      name: e.key, unitsSold: e.value, revenue: revenueWeekly[e.key] ?? 0,
    )).toList();

    // Calculate Yearly Top Products
    Map<String, int> unitsSoldYearly = {};
    Map<String, double> revenueYearly = {};
    for (final sale in allSales) {
      for (final item in sale.items) {
        unitsSoldYearly[item.name] = (unitsSoldYearly[item.name] ?? 0) + item.quantity;
        revenueYearly[item.name] = (revenueYearly[item.name] ?? 0) + (item.price * item.quantity);
      }
    }
    final sortedBySalesYearly = [...unitsSoldYearly.entries.toList()]..sort((a, b) => b.value.compareTo(a.value));
    final topProductsYearlyList = sortedBySalesYearly.take(5).map((e) => TopProduct(
      name: e.key, unitsSold: e.value, revenue: revenueYearly[e.key] ?? 0,
    )).toList();

    // Sort monthly products by units sold
    final sortedBySales = [...unitsSold.entries.toList()]
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── 3. Identify urgent restocks ───────────────────────────────────────────
    final List<RestockItem> urgentRestocks = [];
    for (final product in products) {
      final sold = unitsSold[product.name] ?? 0;
      if (sold == 0 || product.stock <= 0) continue;
      final dailySaleRate = sold / 30.0;
      final daysLeft = (product.stock / dailySaleRate).round();
      if (daysLeft <= 10) {
        urgentRestocks.add(RestockItem(
          name: product.name,
          stock: product.stock,
          daysLeft: daysLeft,
          dailyRate: dailySaleRate,
        ));
      }
    }
    urgentRestocks.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    // ── 4. Identify dead stock ────────────────────────────────────────────────
    final List<DeadStockItem> deadStock = [];
    for (final product in products) {
      final sold = unitsSold[product.name] ?? 0;
      if (sold <= 2 && product.stock > 0) {
        deadStock.add(DeadStockItem(
          name: product.name,
          stock: product.stock,
          sold: sold,
          tiedUpValue: product.stock * product.price,
        ));
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
    if (healthScore >= 85) { healthLabel = 'Excellent'; }
    else if (healthScore >= 65) { healthLabel = 'Good'; }
    else { healthLabel = 'Needs Attention'; }

    // Map top products
    final topProductsList = sortedBySales.take(5).map((e) => TopProduct(
      name: e.key,
      unitsSold: e.value,
      revenue: revenuePerProduct[e.key] ?? 0,
    )).toList();

    // The data object to return
    final insightsData = InsightsData(
      totalRevenue: totalRevenue,
      weekRevenue: weekRevenue,
      totalTransactions: totalTxns,
      avgOrderValue: avgOrderValue,
      dailyAvgRevenue: dailyAvgRevenue,
      healthScore: healthScore,
      healthLabel: healthLabel,
      topProducts: topProductsList,
      topProductsWeekly: topProductsWeeklyList,
      topProductsYearly: topProductsYearlyList,
      urgentRestocks: urgentRestocks,
      deadStock: deadStock,
      aiAnalysis: null,
      dailyRevenues: dailyRevenues,
    );

    // If there are no transactions, skip AI call
    if (totalTxns == 0) {
      return insightsData;
    }

    // ── 6. Generate Offline Algorithmic Report ────────────────
    
    // Calculate real growth trend by comparing the first 15 days to the last 15 days
    double firstHalfRevenue = 0;
    double secondHalfRevenue = 0;
    for (int i = 0; i < 15; i++) {
      firstHalfRevenue += dailyRevenues[i];
    }
    for (int i = 15; i < 30; i++) {
      secondHalfRevenue += dailyRevenues[i];
    }

    double growthRate = 0.05; // default 5%
    if (firstHalfRevenue > 0) {
      growthRate = (secondHalfRevenue - firstHalfRevenue) / firstHalfRevenue;
      // Clamp extreme values so the prediction doesn't go crazy (e.g., -30% to +50%)
      growthRate = growthRate.clamp(-0.30, 0.50); 
    }

    double predictedRevenue = totalRevenue * (1 + growthRate);
    double lowForecast = predictedRevenue * 0.95;
    double highForecast = predictedRevenue * 1.05;
    
    String trendDirection = growthRate >= 0 ? "an upward growth trend of ${(growthRate * 100).toStringAsFixed(1)}%" : "a downward trend of ${(growthRate.abs() * 100).toStringAsFixed(1)}%";

    // Calculate dynamic growth recommendations based on real data metrics
    String rec1 = avgOrderValue < 30 
        ? "**Bundle Top Sellers**: Your Average Order Value is relatively low. Create a bundle featuring your most popular item with an accessory to instantly increase transaction sizes."
        : "**VIP Customer Program**: Your Average Order Value is healthy. Implement a VIP tier for big spenders to encourage them to return more frequently.";
    
    String rec2 = growthRate < 0 
        ? "**Drive Weekend Traffic**: Sales momentum has slowed recently. Introduce a 'Double Points Weekend' or localized social media marketing to bring foot traffic back up."
        : "**Capitalize on Momentum**: You have upward sales momentum. Slightly increase your advertising spend now to capture even more market share while demand is high.";

    String rec3 = deadStock.isNotEmpty 
        ? "**Flash Sale on Dead Stock**: Use a 24-hour flash sale to liquidate your ${deadStock.length} dead stock items and reinvest that cash into high-demand inventory."
        : "**Introduce New Product Lines**: Your inventory is incredibly healthy with zero dead stock! Consider testing 1 or 2 new product lines to see if customers are interested.";

    List<Map<String, dynamic>> timelineData = [
      {
        'title': 'Performance Summary',
        'content': 'Overall health is stable. You achieved RM ${totalRevenue.toStringAsFixed(2)} in revenue over the last 30 days with an average order value of RM ${avgOrderValue.toStringAsFixed(2)}. The business health score sits at $healthScore/100, indicating a consistent performance but with room for inventory optimization.',
        'icon': 'chart',
      },
      {
        'title': 'Sales Forecast',
        'content': 'Based on comparing your recent 15-day sales to the previous 15 days, your business is currently experiencing $trendDirection. By mathematically projecting this real data forward, next month\'s predicted revenue is forecasted to be between RM ${lowForecast.toStringAsFixed(2)} and RM ${highForecast.toStringAsFixed(2)}.',
        'icon': 'trending_up',
      },
      {
        'title': 'Inventory Strategy',
        'content': 'Urgent Restocks: You have ${urgentRestocks.length} items at critically low levels. Prioritize restocking your top sellers immediately to avoid stockouts and lost revenue.\n\nDead Stock: You currently have ${deadStock.length} items tying up capital. Consider running a targeted promotion to clear this slow-moving inventory.',
        'icon': 'inventory_2',
      },
      {
        'title': 'Growth Recommendations',
        'content': '1. $rec1\n\n2. $rec2\n\n3. $rec3'.replaceAll('**', ''),
        'icon': 'lightbulb',
      }
    ];

    return InsightsData(
      totalRevenue: totalRevenue,
      weekRevenue: weekRevenue,
      totalTransactions: totalTxns,
      avgOrderValue: avgOrderValue,
      dailyAvgRevenue: dailyAvgRevenue,
      healthScore: healthScore,
      healthLabel: healthLabel,
      topProducts: topProductsList,
      topProductsWeekly: topProductsWeeklyList,
      topProductsYearly: topProductsYearlyList,
      urgentRestocks: urgentRestocks,
      deadStock: deadStock,
      aiAnalysis: null,
      aiTimeline: timelineData,
      dailyRevenues: dailyRevenues,
    );
  }
}
