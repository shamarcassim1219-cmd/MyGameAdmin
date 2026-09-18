import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<Map<String, String>> _tabs = [
    {'label': 'All', 'status': 'all'},
    {'label': 'Escrow', 'status': 'escrow_held'},
    {'label': 'Disputed', 'status': 'disputed'},
    {'label': 'Completed', 'status': 'completed'},
    {'label': 'Refunded', 'status': 'refunded'},
  ];
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
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
      final list = await ApiService.getOrders(status: _tabs[_tabController.index]['status']!);
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.greenAccent;
      case 'disputed':
        return Colors.orangeAccent;
      case 'refunded':
        return Colors.redAccent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.hint,
          tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _orders.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No orders here', style: TextStyle(color: AppColors.hint)))])
                      : ListView.builder(
                          itemCount: _orders.length,
                          itemBuilder: (context, i) {
                            final o = _orders[i];
                            final status = o['status']?.toString() ?? '';
                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(o['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Order #${o['id']} · LKR ${o['price']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text('Buyer: ${o['buyer_email']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                    Text('Seller: ${o['seller_email']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
