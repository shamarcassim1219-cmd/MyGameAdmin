import re, sys

# ---------- api_service.dart ----------
p = 'lib/services/api_service.dart'
s = open(p, encoding='utf-8').read()

old_api = """  static Future<List<dynamic>> getTopups() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/topups'), headers: await _headers());
    final data = await _handle(res);
    return data['topups'];
  }

  static Future<void> decideTopup(int id, bool approve, {double? adjustedAmount}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/topups/$id/decide'),
      headers: await _headers(),
      body: jsonEncode({'approve': approve, if (adjustedAmount != null) 'adjustedAmount': adjustedAmount}),
    );
    await _handle(res);
  }

  static Future<List<dynamic>> getWithdrawals() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/withdrawals'), headers: await _headers());
    final data = await _handle(res);
    return data['withdrawals'];
  }

  static Future<void> decideWithdrawal(int id, bool approve) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/withdrawals/$id/decide'),
      headers: await _headers(),
      body: jsonEncode({'approve': approve}),
    );
    await _handle(res);
  }"""

new_api = """  static Future<List<dynamic>> getTopups() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/topups'), headers: await _headers());
    final data = await _handle(res);
    return data['topups'];
  }

  static Future<List<dynamic>> searchTopups(String orderId) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/topups/search?id=$orderId'), headers: await _headers());
    final data = await _handle(res);
    return data['topups'];
  }

  static Future<void> decideTopup(int id, bool approve, {double? adjustedAmount, String? reason}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/topups/$id/decide'),
      headers: await _headers(),
      body: jsonEncode({
        'approve': approve,
        if (adjustedAmount != null) 'adjustedAmount': adjustedAmount,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    );
    await _handle(res);
  }

  static Future<List<dynamic>> getWithdrawals() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/withdrawals'), headers: await _headers());
    final data = await _handle(res);
    return data['withdrawals'];
  }

  static Future<List<dynamic>> searchWithdrawals(String orderId) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/withdrawals/search?id=$orderId'), headers: await _headers());
    final data = await _handle(res);
    return data['withdrawals'];
  }

  static Future<void> decideWithdrawal(int id, bool approve, {String? reason}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/withdrawals/$id/decide'),
      headers: await _headers(),
      body: jsonEncode({
        'approve': approve,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    );
    await _handle(res);
  }"""

if 'searchTopups(' in s:
    print('api_service: already patched')
elif s.count(old_api) == 1:
    open(p, 'w', encoding='utf-8').write(s.replace(old_api, new_api))
    print('api_service: patched')
else:
    sys.exit('api_service: anchor not found (check for manual edits)')

# ---------- wallet_requests_screen.dart ----------
p = 'lib/screens/wallet_requests_screen.dart'
s = open(p, encoding='utf-8').read()

if '_searchCtrl' in s:
    sys.exit('wallet_requests_screen: already patched')

# 1) state fields: add search controller + search-mode lists
old_state = """  List<dynamic> _topups = [];
  List<dynamic> _withdrawals = [];
  bool _loading = true;
  String? _error;"""
new_state = """  List<dynamic> _topups = [];
  List<dynamic> _withdrawals = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  bool _searching = false;"""
if s.count(old_state) != 1:
    sys.exit('wallet_requests_screen: state anchor not found')
s = s.replace(old_state, new_state)

# 2) dispose the controller too
old_dispose = """  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }"""
new_dispose = """  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }"""
if s.count(old_dispose) != 1:
    sys.exit('wallet_requests_screen: dispose anchor not found')
s = s.replace(old_dispose, new_dispose)

# 3) add _search / _clearSearch methods right after _load()
old_load_end = """    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }"""
new_load_end = """    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      _clearSearch();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _searching = true;
    });
    try {
      if (_tabController.index == 0) {
        final r = await ApiService.searchTopups(q);
        setState(() {
          _topups = r;
          _loading = false;
        });
      } else {
        final r = await ApiService.searchWithdrawals(q);
        setState(() {
          _withdrawals = r;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _searching = false);
    _load();
  }"""
if s.count(old_load_end) != 1:
    sys.exit('wallet_requests_screen: _load end anchor not found')
s = s.replace(old_load_end, new_load_end)

# 4) _decideTopup: add an editable amount field + optional reason on reject.
#    Split into two dialogs: approve (with editable amount) and reject (with reason).
old_decide_topup = """  Future<void> _decideTopup(Map t) async {
    final id = t['id'];
    final amount = _get(t, ['amount']);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Approve Top-up?', style: TextStyle(color: Colors.white)),
        content: Text('LKR $amount will be added to the user\\'s wallet.', style: const TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideTopup(id is int ? id : int.parse(id.toString()), true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up approved')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _rejectTopup(Map t) async {
    final id = t['id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reject Top-up?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideTopup(id is int ? id : int.parse(id.toString()), false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }"""

new_decide_topup = """  Future<void> _decideTopup(Map t) async {
    final id = t['id'];
    final amountCtrl = TextEditingController(text: _get(t, ['amount']));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Approve Top-up?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amount credited to the user\\'s wallet (edit if needed):', style: TextStyle(color: AppColors.hint, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Amount (LKR)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true) return;
    final adjusted = double.tryParse(amountCtrl.text.trim());
    try {
      await ApiService.decideTopup(id is int ? id : int.parse(id.toString()), true, adjustedAmount: adjusted);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up approved')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _rejectTopup(Map t) async {
    final id = t['id'];
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reject Top-up?', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Reason (shown to the user)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideTopup(id is int ? id : int.parse(id.toString()), false, reason: reasonCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }"""

if s.count(old_decide_topup) != 1:
    sys.exit('wallet_requests_screen: _decideTopup/_rejectTopup anchor not found')
s = s.replace(old_decide_topup, new_decide_topup)

# 5) _decideWithdrawal: add a reason field when rejecting
old_decide_withdrawal = """  Future<void> _decideWithdrawal(Map w, bool approve) async {
    final id = w['id'];
    final amount = _get(w, ['amount']);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(approve ? 'Approve Withdrawal?' : 'Reject Withdrawal?', style: const TextStyle(color: Colors.white)),
        content: Text(
          approve
              ? 'Confirm LKR $amount has been sent to the user\\'s bank account.'
              : 'The amount will be refunded to the user\\'s wallet.',
          style: const TextStyle(color: AppColors.hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideWithdrawal(id is int ? id : int.parse(id.toString()), approve);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Withdrawal confirmed' : 'Withdrawal rejected & refunded')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }"""

new_decide_withdrawal = """  Future<void> _decideWithdrawal(Map w, bool approve) async {
    final id = w['id'];
    final amount = _get(w, ['amount']);
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(approve ? 'Approve Withdrawal?' : 'Reject Withdrawal?', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                  ? 'Confirm LKR $amount has been sent to the user\\'s bank account.'
                  : 'The amount will be refunded to the user\\'s wallet.',
              style: const TextStyle(color: AppColors.hint),
            ),
            if (!approve) ...[
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Reason (shown to the user)'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideWithdrawal(
        id is int ? id : int.parse(id.toString()),
        approve,
        reason: approve ? null : reasonCtrl.text.trim(),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Withdrawal confirmed' : 'Withdrawal rejected & refunded')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }"""

if s.count(old_decide_withdrawal) != 1:
    sys.exit('wallet_requests_screen: _decideWithdrawal anchor not found')
s = s.replace(old_decide_withdrawal, new_decide_withdrawal)

# 6) add the search bar UI just under the AppBar, above the TabBarView
old_body = """      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: TabBarView(
                    controller: _tabController,
                    children: ["""

new_body = """      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Search by order ID',
                      isDense: true,
                      suffixIcon: _searching
                          ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearSearch)
                          : null,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search, child: const Text('Search')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: TabBarView(
                          controller: _tabController,
                          children: ["""
if s.count(old_body) != 1:
    sys.exit('wallet_requests_screen: body anchor not found')
s = s.replace(old_body, new_body)

# 7) close the extra Column/Expanded wrappers added above (they replace the old closing)
old_body_close = """                    ],
                  ),
                ),
    );
  }
}"""
new_body_close = """                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}"""
if s.count(old_body_close) != 1:
    sys.exit('wallet_requests_screen: body-close anchor not found')
s = s.replace(old_body_close, new_body_close)

open(p, 'w', encoding='utf-8').write(s)
print('wallet_requests_screen: patched')
