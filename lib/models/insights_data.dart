/// Structured data model for AI Insights — used to power charts and cards.
class InsightsData {
  final double totalRevenue;
  final double weekRevenue;
  final int totalTransactions;
  final double avgOrderValue;
  final double dailyAvgRevenue;
  final int healthScore;
  final String healthLabel;

  /// Top products (Monthly default)
  final List<TopProduct> topProducts;
  
  /// Top products (Weekly)
  final List<TopProduct> topProductsWeekly;
  
  /// Top products (Yearly)
  final List<TopProduct> topProductsYearly;

  /// Products running low: {name, stock, daysLeft, dailyRate}
  final List<RestockItem> urgentRestocks;

  /// Slow-moving products: {name, stock, sold, tiedUpValue}
  final List<DeadStockItem> deadStock;

  /// AI-generated analysis text (Markdown) from Gemini, or null if offline
  final String? aiAnalysis;
  
  /// Structured timeline data
  final List<Map<String, dynamic>>? aiTimeline;

  /// Daily revenues over the last 30 days
  final List<double> dailyRevenues;

  InsightsData({
    required this.totalRevenue,
    required this.weekRevenue,
    required this.totalTransactions,
    required this.avgOrderValue,
    required this.dailyAvgRevenue,
    required this.healthScore,
    required this.healthLabel,
    required this.topProducts,
    required this.topProductsWeekly,
    required this.topProductsYearly,
    required this.urgentRestocks,
    required this.deadStock,
    required this.dailyRevenues,
    this.aiAnalysis,
    this.aiTimeline,
  });
}

class TopProduct {
  final String name;
  final int unitsSold;
  final double revenue;

  TopProduct({required this.name, required this.unitsSold, required this.revenue});
}

class RestockItem {
  final String name;
  final int stock;
  final int daysLeft;
  final double dailyRate;

  RestockItem({required this.name, required this.stock, required this.daysLeft, required this.dailyRate});
}

class DeadStockItem {
  final String name;
  final int stock;
  final int sold;
  final double tiedUpValue;

  DeadStockItem({required this.name, required this.stock, required this.sold, required this.tiedUpValue});
}
