import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class RentalsInstallmentsScreen extends StatefulWidget {
  const RentalsInstallmentsScreen({super.key});

  @override
  State<RentalsInstallmentsScreen> createState() => _RentalsInstallmentsScreenState();
}

class _RentalsInstallmentsScreenState extends State<RentalsInstallmentsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<dynamic> _rentals = [];
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rentals = await ApiService.getRentals();
      final plans = await ApiService.getInstallmentPlans();
      setState(() {
        _rentals = rentals;
        _plans = plans;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Widget _rentalTile(Map r) {
    final expired = r['isExpired'] == true;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(r['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (expired ? Colors.redAccent : Colors.greenAccent).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(expired ? 'Expired' : 'Active', style: TextStyle(color: expired ? Colors.redAccent : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Order #${r['orderId']} · ${r['quantity']} ${r['unit']}(s) · LKR ${r['totalPrice']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Buyer: ${r['buyerEmail']}  ·  Seller: ${r['sellerEmail']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Ends: ${r['rentalEnd']?.toString().split('T').first ?? ''}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _planTile(Map p) {
    final payments = (p['payments'] as List?) ?? [];
    final paidCount = payments.where((x) => x['status'] == 'paid').length;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Order #${p['orderId']} · LKR ${p['totalAmount']} · $paidCount/${p['installmentCount']} paid', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
            const SizedBox(height: 4),
            Text('Buyer: ${p['buyerEmail']}  ·  Seller: ${p['sellerEmail']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: payments.map<Widget>((pay) {
                Color c;
                switch (pay['status']) {
                  case 'paid':
                    c = Colors.greenAccent;
                    break;
                  case 'overdue':
                    c = Colors.redAccent;
                    break;
                  default:
                    c = AppColors.hint;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text('#${pay['installmentNumber']} · ${pay['status']}', style: TextStyle(color: c, fontSize: 11)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Rentals & Installments'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.hint,
          tabs: [
            Tab(text: 'Rentals (${_rentals.length})'),
            Tab(text: 'Installments (${_plans.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _rentals.isEmpty
                          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No rentals', style: TextStyle(color: AppColors.hint)))])
                          : ListView.builder(itemCount: _rentals.length, itemBuilder: (c, i) => _rentalTile(_rentals[i])),
                      _plans.isEmpty
                          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No installment plans', style: TextStyle(color: AppColors.hint)))])
                          : ListView.builder(itemCount: _plans.length, itemBuilder: (c, i) => _planTile(_plans[i])),
                    ],
                  ),
                ),
    );
  }
}
