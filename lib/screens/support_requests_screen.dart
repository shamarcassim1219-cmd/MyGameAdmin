import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class SupportRequestsScreen extends StatefulWidget {
  const SupportRequestsScreen({super.key});

  @override
  State<SupportRequestsScreen> createState() => _SupportRequestsScreenState();
}

class _SupportRequestsScreenState extends State<SupportRequestsScreen> {
  List<dynamic> _requests = [];
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
      final list = await ApiService.getSupportRequests();
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Support Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _requests.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No open support requests', style: TextStyle(color: AppColors.hint)))])
                      : ListView.builder(
                          itemCount: _requests.length,
                          itemBuilder: (context, i) {
                            final r = _requests[i];
                            final escalated = r['escalated'] == true;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: escalated ? Colors.orangeAccent.withOpacity(0.15) : AppColors.primary.withOpacity(0.15),
                                child: Icon(escalated ? Icons.priority_high : Icons.support_agent_outlined,
                                    color: escalated ? Colors.orangeAccent : AppColors.primary, size: 18),
                              ),
                              title: Text(r['subject']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                '${r['userEmail'] ?? ''}\n${r['message'] ?? ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.hint, fontSize: 12),
                              ),
                              isThreeLine: true,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SupportChatScreen(request: r)),
                                );
                                _load();
                              },
                            );
                          },
                        ),
                ),
    );
  }
}

class SupportChatScreen extends StatefulWidget {
  final Map request;
  const SupportChatScreen({super.key, required this.request});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  List<dynamic> _messages = [];
  Map<String, dynamic>? _original;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  int get _requestId => widget.request['id'] is int ? widget.request['id'] : int.parse(widget.request['id'].toString());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getSupportMessages(_requestId);
      setState(() {
        _original = data['original'];
        _messages = data['messages'] ?? [];
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiService.replySupportRequest(_requestId, text);
      _msgCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Close this request?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.closeSupportRequest(_requestId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Widget _bubble(Map m) {
    final isAdmin = m['isAdmin'] == true;
    final imageUrl = m['imageUrl']?.toString();
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isAdmin ? AppColors.primary.withOpacity(0.85) : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl, height: 140, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            if (m['content'] != null && m['content'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(m['content'].toString(), style: const TextStyle(color: Colors.white, fontSize: 14)),
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
        title: Text(widget.request['subject']?.toString() ?? 'Support Chat', style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: 'Close request', onPressed: _closeRequest),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : Column(
                  children: [
                    if (_original != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: AppColors.surface,
                        child: Text(
                          _original!['message']?.toString() ?? '',
                          style: const TextStyle(color: AppColors.hint, fontSize: 13),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _bubble(_messages[i]),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _msgCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(hintText: 'Type a reply...'),
                                minLines: 1,
                                maxLines: 4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _sending
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                                : IconButton(icon: const Icon(Icons.send, color: AppColors.primary), onPressed: _send),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
