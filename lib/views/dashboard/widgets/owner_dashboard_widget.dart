import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../viewmodels/sales_viewmodel.dart';
import '../../../models/sales.dart';

class OwnerDashboardWidget extends StatefulWidget {
  final DateTime selectedDate;
  const OwnerDashboardWidget({super.key, required this.selectedDate});

  @override
  State<OwnerDashboardWidget> createState() => _OwnerDashboardWidgetState();
}

class _OwnerDashboardWidgetState extends State<OwnerDashboardWidget> {
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color cardBg = Colors.white;
  static const Color cardBorder = Color(0xFFF1F5F9);
  static const Color greenTrend = Color(0xFF22C55E);
  static const Color redTrend = Color(0xFFEF4444);
  static const Color chartGreen = Color(0xFF86EFAC);
  static const Color chartGrey = Color(0xFFF1F5F9);

  final SalesViewModel _salesVM = SalesViewModel();
  
  bool _isLoading = true;
  List<Sale> _recentSales = [];
  Map<String, String> _userNames = {};

  String _cashierFilter = 'Today'; // 'Today' or 'Monthly'
  String _topItemsFilter = 'Monthly'; // 'Today' or 'Monthly'
  String _searchTransaction = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(OwnerDashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
          _loadData();
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      // Fetch relative to selectedDate (8 months prior up to end of selected day)
      final start = DateTime(widget.selectedDate.year, widget.selectedDate.month - 8, 1);
      final end = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59);
      
      final results = await Future.wait([
        _salesVM.getSalesForDateRange(start, end),
        FirebaseFirestore.instance.collection('users').get(),
      ]);
      
      final sales = results[0] as List<Sale>;
      final usersQuery = results[1] as QuerySnapshot<Map<String, dynamic>>;
      
      final Map<String, String> userNames = {};
      for (var doc in usersQuery.docs) {
        final data = doc.data();
        final uid = doc.id;
        final name = data['name'] as String?;
        final email = data['email'] as String?;
        if (name != null && name.isNotEmpty) {
          userNames[uid] = name;
        } else if (email != null && email.isNotEmpty) {
          userNames[uid] = email.split('@')[0];
        }
      }

      if (!mounted) return;
      setState(() {
        _recentSales = sales;
        _userNames = userNames;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load dashboard data: $e')));
    }
  }

  // --- Data Helpers relative to selectedDate ---
  List<Sale> get _thisWeekSales {
    final startOfSelected = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    return _recentSales.where((s) => s.createdAt.isAfter(startOfSelected.subtract(const Duration(days: 7))) && s.createdAt.isBefore(startOfSelected.add(const Duration(days: 1)))).toList();
  }

  List<Sale> get _lastWeekSales {
    final startOfSelected = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    return _recentSales.where((s) => s.createdAt.isAfter(startOfSelected.subtract(const Duration(days: 14))) && s.createdAt.isBefore(startOfSelected.subtract(const Duration(days: 7)))).toList();
  }

  List<Sale> get _currentMonthSales {
    final endOfSelected = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59);
    return _recentSales.where((s) => s.createdAt.isAfter(DateTime(widget.selectedDate.year, widget.selectedDate.month, 1)) && s.createdAt.isBefore(endOfSelected)).toList();
  }

  List<Sale> get _todaySales {
    final startOfSelected = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final endOfSelected = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59);
    return _recentSales.where((s) => s.createdAt.isAfter(startOfSelected) && s.createdAt.isBefore(endOfSelected)).toList();
  }

  List<Sale> get _yesterdaySales {
    final startOfYesterday = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day).subtract(const Duration(days: 1));
    final endOfYesterday = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59).subtract(const Duration(days: 1));
    return _recentSales.where((s) => s.createdAt.isAfter(startOfYesterday) && s.createdAt.isBefore(endOfYesterday)).toList();
  }

  double _calculateGrowth(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopMetricsRow(),
          const SizedBox(height: 20),
          _buildMiddleRow(),
          const SizedBox(height: 20),
          _buildBottomRow(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTopMetricsRow() {
    // Revenue (Weekly)
    double revThisWeek = _thisWeekSales.fold(0, (sum, s) => sum + s.total);
    double revLastWeek = _lastWeekSales.fold(0, (sum, s) => sum + s.total);
    double revGrowth = _calculateGrowth(revThisWeek, revLastWeek);

    // Total Orders Per Day (Daily Sales Amount)
    double todaySalesAmount = _todaySales.fold(0.0, (sum, s) => sum + s.total);
    double yesterdaySalesAmount = _yesterdaySales.fold(0.0, (sum, s) => sum + s.total);
    double salesGrowth = _calculateGrowth(todaySalesAmount, yesterdaySalesAmount);

    // Total Customer Per Day (Daily Customer/Order Count)
    int todayCustomerCount = _todaySales.length;
    int yesterdayCustomerCount = _yesterdaySales.length;
    double customerGrowth = _calculateGrowth(todayCustomerCount.toDouble(), yesterdayCustomerCount.toDouble());

    // Items Sold (Weekly)
    int itemsThisWeek = _thisWeekSales.fold(0, (sum, s) => sum + s.items.fold(0, (isum, i) => isum + i.quantity));
    int itemsLastWeek = _lastWeekSales.fold(0, (sum, s) => sum + s.items.fold(0, (isum, i) => isum + i.quantity));
    double itemsGrowth = _calculateGrowth(itemsThisWeek.toDouble(), itemsLastWeek.toDouble());

    return Row(
      children: [
        Expanded(child: _buildMetricCard("Total Revenue", "RM ${revThisWeek.toStringAsFixed(2)}", revGrowth >= 0, "${revGrowth.abs().toStringAsFixed(1)}%", "From last week")),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard("Total Orders", "RM ${todaySalesAmount.toStringAsFixed(2)}", salesGrowth >= 0, "${salesGrowth.abs().toStringAsFixed(1)}%", "From yesterday")),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard("Total Customer", todayCustomerCount.toString(), customerGrowth >= 0, "${customerGrowth.abs().toStringAsFixed(1)}%", "From yesterday")),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard("Items Sold", itemsThisWeek.toString(), itemsGrowth >= 0, "${itemsGrowth.abs().toStringAsFixed(1)}%", "From last week")),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, bool isPositive, String percentage, String comparisonLabel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary)),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: isPositive ? greenTrend : redTrend, size: 14),
                      const SizedBox(width: 2),
                      Text(percentage, style: TextStyle(color: isPositive ? greenTrend : redTrend, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  Text(comparisonLabel, style: const TextStyle(color: textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleRow() {
    return SizedBox(
      height: 380,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: _buildMonthlySalesChart()),
          const SizedBox(width: 20),
          Expanded(flex: 1, child: _buildCashierPerformance()),
        ],
      ),
    );
  }

  Widget _buildMonthlySalesChart() {
    // Group sales by month
    Map<int, double> monthlySales = {};
    final refDate = widget.selectedDate;
    for (int i = 8; i >= 0; i--) {
      // Initialize last 9 months to 0
      int m = refDate.month - i;
      if (m <= 0) {
        m += 12;
      }
      monthlySales[m] = 0;
    }

    for (var s in _recentSales) {
      if (monthlySales.containsKey(s.createdAt.month)) {
        monthlySales[s.createdAt.month] = (monthlySales[s.createdAt.month] ?? 0) + s.total;
      }
    }

    double maxSales = monthlySales.values.isEmpty ? 1000 : monthlySales.values.reduce((a, b) => a > b ? a : b);
    if (maxSales == 0) maxSales = 1000;
    
    // Add 20% padding to max Y
    double maxY = maxSales * 1.2;
    
    const monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    double totalRevenueSelected = _currentMonthSales.fold(0, (sum, s) => sum + s.total);
    double revLastMonth = _recentSales.where((s) => s.createdAt.month == (refDate.month == 1 ? 12 : refDate.month - 1) && s.createdAt.year == (refDate.month == 1 ? refDate.year - 1 : refDate.year)).fold(0, (sum, s) => sum + s.total);
    double revGrowth = _calculateGrowth(totalRevenueSelected, revLastMonth);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Sales Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              Row(
                children: [
                  _buildLegendItem(chartGrey, "Target"),
                  const SizedBox(width: 12),
                  _buildLegendItem(chartGreen, "Revenue"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text("RM ${totalRevenueSelected.toStringAsFixed(2)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: revGrowth >= 0 ? greenTrend : redTrend, borderRadius: BorderRadius.circular(12)),
                    child: Text("${revGrowth >= 0 ? '+' : ''}${revGrowth.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  children: [
                    Text("This Month", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < monthlySales.length) {
                          int m = monthlySales.keys.elementAt(index);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(monthNames[m], style: const TextStyle(color: textSecondary, fontSize: 12)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('RM 0', style: TextStyle(color: textSecondary, fontSize: 12));
                        return Text('RM ${(value / 1000).toStringAsFixed(1)}k', style: const TextStyle(color: textSecondary, fontSize: 12));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(monthlySales.length, (index) {
                  int m = monthlySales.keys.elementAt(index);
                  double rev = monthlySales[m] ?? 0;
                  // Make a fake target that is slightly different from revenue for visual effect
                  double target = rev == 0 ? maxSales * 0.2 : rev * 0.85; 
                  return _makeGroupData(index, target, rev);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: y1, color: chartGrey, width: 14, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: y2, color: chartGreen, width: 14, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCashierPerformance() {
    List<Sale> filteredSales = _cashierFilter == 'Today' ? _todaySales : _currentMonthSales;
    
    // Aggregate by cashier using cashierId
    Map<String, double> cashierSales = {};
    Map<String, String> cashierNames = {}; // Mapping unique key to displayName
    
    for (var s in filteredSales) {
      final key = s.cashierId.isNotEmpty ? s.cashierId : (s.cashierEmail.isNotEmpty ? s.cashierEmail : 'unknown_cashier');
      cashierSales[key] = (cashierSales[key] ?? 0) + s.total;
      
      final cachedName = _userNames[s.cashierId];
      if (cachedName != null && cachedName.isNotEmpty) {
        cashierNames[key] = cachedName;
      } else if (s.cashierId.isNotEmpty && s.cashierId.length < 20) {
        cashierNames[key] = s.cashierId;
      } else if (s.cashierEmail.isNotEmpty) {
        cashierNames[key] = s.cashierEmail.split('@')[0];
      } else {
        cashierNames[key] = 'Cashier';
      }
    }

    var sortedCashiers = cashierSales.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    var topCashiers = sortedCashiers.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text("Cashier Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (val) => setState(() => _cashierFilter = val),
                color: Colors.white,
                surfaceTintColor: Colors.white,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'Today', child: Text('Today')),
                  PopupMenuItem(value: 'Monthly', child: Text('This Month')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Text(_cashierFilter, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (topCashiers.isEmpty)
            const Expanded(
              child: Center(
                child: Text("No sales recorded.", style: TextStyle(color: textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topCashiers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                final c = topCashiers[index];
                final name = (cashierNames[c.key] != null && cashierNames[c.key]!.isNotEmpty) 
                    ? cashierNames[c.key]! 
                    : 'Cashier';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: chartGreen.withValues(alpha: 0.2),
                      child: Text(initial, style: const TextStyle(color: chartGreen, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                          const SizedBox(height: 2),
                          const Text("Cashier", style: TextStyle(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text("RM ${c.value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 15)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomRow() {
    return SizedBox(
      height: 360,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: _buildTopItemsTable()),
          const SizedBox(width: 20),
          Expanded(flex: 1, child: _buildPaymentMethodsSummary()),
        ],
      ),
    );
  }

  Widget _buildTopItemsTable() {
    List<Sale> filteredSales = _topItemsFilter == 'Today' ? _todaySales : _currentMonthSales;
    
    // Filter by search query
    if (_searchTransaction.isNotEmpty) {
      filteredSales = filteredSales.where((s) => s.items.any((i) => i.name.toLowerCase().contains(_searchTransaction.toLowerCase()))).toList();
    }

    // Aggregate items
    Map<String, Map<String, dynamic>> itemStats = {};
    for (var s in filteredSales) {
      for (var i in s.items) {
        if (!itemStats.containsKey(i.productId)) {
          itemStats[i.productId] = {"name": i.name, "price": i.price, "qty": 0, "revenue": 0.0};
        }
        itemStats[i.productId]!["qty"] += i.quantity;
        itemStats[i.productId]!["revenue"] += (i.price * i.quantity);
      }
    }

    var sortedItems = itemStats.values.toList()..sort((a, b) => b["qty"].compareTo(a["qty"]));
    var topItems = sortedItems.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Top Items Sold", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
              PopupMenuButton<String>(
                onSelected: (val) => setState(() => _topItemsFilter = val),
                color: Colors.white,
                surfaceTintColor: Colors.white,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'Today', child: Text('Today')),
                  PopupMenuItem(value: 'Monthly', child: Text('This Month')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Text(_topItemsFilter, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text("${sortedItems.length} Products", style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                  child: TextField(
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (val) => setState(() => _searchTransaction = val),
                    decoration: const InputDecoration(
                      hintText: "Search Items",
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(Icons.search, size: 18, color: textSecondary),
                      prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 36),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topItems.isEmpty)
            const Expanded(
              child: Center(child: Text("No items sold yet.", style: TextStyle(color: textSecondary))),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.transparent),
                    dividerThickness: 0,
                    columnSpacing: 16,
                    horizontalMargin: 0,
                    columns: [
                      DataColumn(
                        label: Expanded(
                          child: Center(
                            child: Text("#", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Center(
                            child: Text("Product Name", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Center(
                            child: Text("Price", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      DataColumn(
                        numeric: true,
                        label: Expanded(
                          child: Center(
                            child: Text("Qty Sold", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Center(
                            child: Text("Total Revenue", style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                    rows: List.generate(topItems.length, (index) {
                      final item = topItems[index];
                      return DataRow(
                        cells: [
                          DataCell(Center(child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.w700, color: textSecondary)))),
                          DataCell(Center(child: Text(item["name"], style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary)))),
                          DataCell(Center(child: Text("RM ${item["price"].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w600, color: textSecondary)))),
                          DataCell(Center(child: Text(item["qty"].toString(), style: const TextStyle(fontWeight: FontWeight.w700, color: textPrimary)))),
                          DataCell(Center(child: Text("RM ${item["revenue"].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w600, color: greenTrend)))),
                        ],
                      );
                    }),
                  ),

                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSummary() {
    List<Sale> filteredSales = _topItemsFilter == 'Today' ? _todaySales : _currentMonthSales;
    
    double cash = 0, card = 0, qr = 0;
    for (var s in filteredSales) {
      if (s.paymentMethod.toLowerCase() == 'cash') {
        cash += s.total;
      } else if (s.paymentMethod.toLowerCase() == 'card') {
        card += s.total;
      } else if (s.paymentMethod.toLowerCase() == 'qr') {
        qr += s.total;
      } else {
        cash += s.total;
      }
    }

    double total = cash + card + qr;
    if (total == 0) total = 1; // Prevent division by zero

    int cashPct = ((cash / total) * 100).round();
    int cardPct = ((card / total) * 100).round();
    int qrPct = ((qr / total) * 100).round();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Payment Methods", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 6),
          Text(_topItemsFilter == 'Today' ? "Today's Breakdown" : "This Month's Breakdown", style: const TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          
          _buildPaymentRow(Icons.money_rounded, "Cash", "RM ${cash.toStringAsFixed(2)}", cashPct, const Color(0xFF22C55E)),
          const SizedBox(height: 20),
          _buildPaymentRow(Icons.credit_card_rounded, "Credit Card", "RM ${card.toStringAsFixed(2)}", cardPct, const Color(0xFF3B82F6)),
          const SizedBox(height: 20),
          _buildPaymentRow(Icons.qr_code_rounded, "QR Pay", "RM ${qr.toStringAsFixed(2)}", qrPct, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(IconData icon, String name, String amount, int pct, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(height: 6, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: pct / 100,
                    child: Container(height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 14)),
            Text("$pct%", style: const TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
