import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getReportsSummary();
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: AppColors.hint, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      const Text('Sales & Revenue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        _statCard('Total Orders', '${_data!['totalOrders']}', Icons.receipt_long_outlined, AppColors.primary),
                        const SizedBox(width: 10),
                        _statCard('Completed', '${_data!['completedOrders']}', Icons.check_circle_outline, Colors.greenAccent),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _statCard('Revenue (LKR)', '${(_data!['totalRevenue'] as num).toStringAsFixed(0)}', Icons.payments_outlined, Colors.greenAccent),
                        const SizedBox(width: 10),
                        _statCard('Commission (LKR)', '${(_data!['totalCommission'] as num).toStringAsFixed(0)}', Icons.account_balance_wallet_outlined, AppColors.primary),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _statCard('Disputed', '${_data!['disputedOrders']}', Icons.gavel_outlined, Colors.orangeAccent),
                        const SizedBox(width: 10),
                        _statCard('Active Listings', '${_data!['activeListings']} / ${_data!['totalListings']}', Icons.storefront_outlined, AppColors.primary),
                      ]),
                      const SizedBox(height: 24),
                      const Text('User Growth', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(children: [
                        _statCard('Total Users', '${_data!['totalUsers']}', Icons.people_outline, AppColors.primary),
                        const SizedBox(width: 10),
                        _statCard('Verified', '${_data!['verifiedUsers']}', Icons.verified_user_outlined, Colors.greenAccent),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        _statCard('New (7 days)', '${_data!['newSignups7d']}', Icons.trending_up, AppColors.primary),
                        const SizedBox(width: 10),
                        _statCard('New (30 days)', '${_data!['newSignups30d']}', Icons.calendar_month_outlined, AppColors.primary),
                      ]),
                      const SizedBox(height: 24),
                      const Text('Top Sellers', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if ((_data!['topSellers'] as List).isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: Text('No completed sales yet', style: TextStyle(color: AppColors.hint))),
                        )
                      else
                        ...List.generate((_data!['topSellers'] as List).length, (i) {
                          final s = _data!['topSellers'][i];
                          return Card(
                            color: AppColors.surface,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.15), child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                              title: Text(s['sellerEmail']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                              subtitle: Text('${s['salesCount']} sales', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                              trailing: Text('LKR ${(s['totalEarned'] as num).toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
