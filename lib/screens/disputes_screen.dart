import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});

  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  List<dynamic> _disputes = [];
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
      final list = await ApiService.getDisputes();
      setState(() {
        _disputes = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _resolve(Map d, String resolution) async {
    final label = resolution == 'refund_buyer' ? 'Refund Buyer' : 'Release to Seller';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('$label?', style: const TextStyle(color: Colors.white)),
        content: Text(
          resolution == 'refund_buyer'
              ? 'LKR ${d['price']} will be refunded to the buyer and the listing relisted.'
              : 'LKR ${d['price']} will be released to the seller and the order completed.',
          style: const TextStyle(color: AppColors.hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(label)),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.resolveDispute(d['id'] is int ? d['id'] : int.parse(d['id'].toString()), resolution);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispute resolved')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Disputes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _disputes.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No open disputes', style: TextStyle(color: AppColors.hint)))])
                      : ListView.builder(
                          itemCount: _disputes.length,
                          itemBuilder: (context, i) {
                            final d = _disputes[i];
                            final screenshots = (d['screenshots'] as List?) ?? [];
                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d['listingTitle']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('Order #${d['orderId']} · LKR ${d['price']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    Text('Buyer: ${d['buyerEmail']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                    Text('Seller: ${d['sellerEmail']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Text('Reason:', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                    Text(d['reason']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    if (screenshots.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 90,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: screenshots.length,
                                          itemBuilder: (c, si) => Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: GestureDetector(
                                              onTap: () => showDialog(
                                                context: context,
                                                builder: (_) => Dialog(backgroundColor: Colors.black, child: InteractiveViewer(child: Image.network(screenshots[si].toString()))),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(screenshots[si].toString(), width: 90, height: 90, fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(width: 90, height: 90, color: AppColors.fieldFill, child: const Icon(Icons.broken_image_outlined, color: AppColors.hint))),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _resolve(d, 'refund_buyer'),
                                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
                                            child: const Text('Refund Buyer', style: TextStyle(fontSize: 12)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _resolve(d, 'release_seller'),
                                            child: const Text('Release to Seller', style: TextStyle(fontSize: 12)),
                                          ),
                                        ),
                                      ],
                                    ),
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
