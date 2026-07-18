import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToInventory;
  final VoidCallback onNavigateToScanner;
  final VoidCallback onNavigateToSupplier;

  const DashboardScreen({
    super.key,
    required this.onNavigateToInventory,
    required this.onNavigateToScanner,
    required this.onNavigateToSupplier,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _totalProducts = 0;
  int _totalUnits = 0;
  int _expiredCount = 0;
  int _nearExpiryCount = 0;
  int _deficientCount = 0;
  List<Medicine> _urgentMedicines = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final inventory = await DatabaseHelper.instance.getInventory();

    int totalUnits = 0;
    int expired = 0;
    int nearExpiry = 0;
    List<Medicine> urgent = [];

    // Group quantities by barcode to check safety thresholds
    final Map<String, int> barcodeQuantities = {};
    final Map<String, int> barcodeMinQuantities = {};
    final Map<String, List<Medicine>> barcodeBatches = {};

    for (final med in inventory) {
      totalUnits += med.quantity;
      barcodeQuantities[med.barcode] = (barcodeQuantities[med.barcode] ?? 0) + med.quantity;
      barcodeMinQuantities[med.barcode] = med.minQuantity;
      barcodeBatches.putIfAbsent(med.barcode, () => []).add(med);

      // Expirations are evaluated at the batch level
      if (med.daysToExpiry <= 0) {
        expired++;
        urgent.add(med);
      } else if (med.daysToExpiry <= 90) {
        nearExpiry++;
        urgent.add(med);
      }
    }

    // Count deficiencies at the aggregated product level
    int deficient = 0;
    barcodeQuantities.forEach((barcode, totalQty) {
      final minQty = barcodeMinQuantities[barcode] ?? 0;
      if (totalQty < minQty) {
        deficient++;
        // Add the soonest-to-expire batch of this deficient barcode to the urgent list if not already there
        final batches = barcodeBatches[barcode]!;
        batches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
        if (batches.isNotEmpty) {
          final targetBatch = batches.first;
          if (!urgent.any((m) => m.id == targetBatch.id)) {
            urgent.add(targetBatch);
          }
        }
      }
    });

    // Sort urgent items: expired first, then near-expiry, then deficient
    urgent.sort((a, b) {
      if (a.daysToExpiry <= 0 && b.daysToExpiry > 0) return -1;
      if (b.daysToExpiry <= 0 && a.daysToExpiry > 0) return 1;
      if (a.daysToExpiry <= 90 && b.daysToExpiry > 90) return -1;
      if (b.daysToExpiry <= 90 && a.daysToExpiry > 90) return 1;
      return a.quantity.compareTo(b.quantity);
    });

    // Extract unique product count
    final uniqueProductsCount = barcodeQuantities.keys.length;

    setState(() {
      _totalProducts = uniqueProductsCount;
      _totalUnits = totalUnits;
      _expiredCount = expired;
      _nearExpiryCount = nearExpiry;
      _deficientCount = deficient;
      _urgentMedicines = urgent.take(5).toList(); // Show top 5 urgent items
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header greeting & Quick Actions
                    _buildHeader(theme),
                    const SizedBox(height: 20),

                    // Grid of 4 KPI Metrics
                    _buildKpiGrid(theme, isDark),
                    const SizedBox(height: 24),

                    // Visual Charts section
                    _buildAnalyticsSection(theme, isDark),
                    const SizedBox(height: 24),

                    // Action Required / Notifications
                    _buildActionRequiredSection(theme, isDark),
                    const SizedBox(height: 24),

                    // Quick navigation bento items
                    _buildQuickShortcuts(theme, isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pharmacy Dashboard',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Real-time inventory and expiry tracking',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          icon: const Icon(Icons.refresh),
          onPressed: _loadDashboardData,
          tooltip: 'Refresh Data',
        ),
      ],
    );
  }

  Widget _buildKpiGrid(ThemeData theme, bool isDark) {
    final cards = [
      _KpiData(
        title: 'Total Products',
        value: '$_totalProducts',
        subtitle: '$_totalUnits units in stock',
        icon: Icons.inventory_2_outlined,
        color: theme.colorScheme.primary,
        bgColor: theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.2 : 0.7),
      ),
      _KpiData(
        title: 'Expired Items',
        value: '$_expiredCount',
        subtitle: 'Requires disposal',
        icon: Icons.dangerous_outlined,
        color: const Color(0xFFEF4444),
        bgColor: const Color(0xFFEF4444).withOpacity(isDark ? 0.15 : 0.1),
      ),
      _KpiData(
        title: 'Near Expiry',
        value: '$_nearExpiryCount',
        subtitle: 'Expiring in 90 days',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFF97316).withOpacity(isDark ? 0.15 : 0.1),
      ),
      _KpiData(
        title: 'Deficient Stock',
        value: '$_deficientCount',
        subtitle: 'Below safety level',
        icon: Icons.trending_down,
        color: Colors.cyan,
        bgColor: Colors.cyan.withOpacity(isDark ? 0.15 : 0.1),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.18, // Taller cards to accommodate text dynamically
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: card.bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: card.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(card.icon, color: card.color, size: 22),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: card.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        card.value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      card.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsSection(ThemeData theme, bool isDark) {
    final double expiredRatio = _totalProducts > 0 ? _expiredCount / _totalProducts : 0.0;
    final double nearRatio = _totalProducts > 0 ? _nearExpiryCount / _totalProducts : 0.0;
    final double healthyRatio = _totalProducts > 0 
        ? (_totalProducts - _expiredCount - _nearExpiryCount) / _totalProducts 
        : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Health & Expiry Ratio',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Stacked Bar Representation
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  if (expiredRatio > 0)
                    Expanded(
                      flex: (expiredRatio * 100).round(),
                      child: Container(
                        color: const Color(0xFFEF4444),
                        child: const Center(
                          child: Text(
                            '',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  if (nearRatio > 0)
                    Expanded(
                      flex: (nearRatio * 100).round(),
                      child: Container(
                        color: const Color(0xFFF97316),
                        child: const Center(
                          child: Text(
                            '',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  if (healthyRatio > 0)
                    Expanded(
                      flex: (healthyRatio * 100).round(),
                      child: Container(
                        color: const Color(0xFF10B981),
                        child: const Center(
                          child: Text(
                            '',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend using Wrap instead of Row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              _buildLegendItem(
                'Healthy (${(healthyRatio * 100).toStringAsFixed(0)}%)',
                const Color(0xFF10B981),
                theme,
              ),
              _buildLegendItem(
                'Near Expiry (${(nearRatio * 100).toStringAsFixed(0)}%)',
                const Color(0xFFF97316),
                theme,
              ),
              _buildLegendItem(
                'Expired (${(expiredRatio * 100).toStringAsFixed(0)}%)',
                const Color(0xFFEF4444),
                theme,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActionRequiredSection(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Urgent Action Items',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_urgentMedicines.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Needs Attention',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_urgentMedicines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'All stock and expiries are perfectly healthy!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _urgentMedicines.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final med = _urgentMedicines[index];
                final bool isExpired = med.daysToExpiry <= 0;
                final bool isLowStock = med.isDeficient;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Expiry/Stock color code indicator
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: med.statusColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Generic: ${med.genericName} • Qty: ${med.quantity}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Specific alert pill
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isExpired)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'EXPIRED',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (med.daysToExpiry <= 90)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'EXP ${med.daysToExpiry}d',
                              style: const TextStyle(
                                color: Color(0xFFF97316),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isLowStock) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LOW STOCK (${med.quantity})',
                              style: const TextStyle(
                                color: Colors.cyan,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQuickShortcuts(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Operations',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onNavigateToScanner,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(isDark ? 0.15 : 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_scanner, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        'Launch Scanner',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: widget.onNavigateToSupplier,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.teal.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: Colors.teal, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        'Procurement Engine',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;

  _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
