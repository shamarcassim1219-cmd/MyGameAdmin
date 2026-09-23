import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

// ======================= helpers =======================

String _two(int n) => n.toString().padLeft(2, '0');

String _fmtDt(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

String _fmt(dynamic ms) {
  final v = int.tryParse('${ms ?? ''}');
  if (v == null || v == 0) return '-';
  return _fmtDt(DateTime.fromMillisecondsSinceEpoch(v));
}

String _money(dynamic v) {
  final n = double.tryParse('${v ?? 0}') ?? 0;
  return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
}

String _phaseLabel(String p) {
  switch (p) {
    case 'upcoming':
      return 'Upcoming';
    case 'registration':
      return 'Registration open';
    case 'closed':
      return 'Registration closed';
    case 'live':
      return 'LIVE';
    case 'ended':
      return 'Ended';
    case 'finished':
      return 'Finished';
    case 'cancelled':
      return 'Cancelled';
    default:
      return p;
  }
}

Color _phaseColor(String p) {
  switch (p) {
    case 'registration':
      return Colors.green;
    case 'live':
      return Colors.red;
    case 'upcoming':
      return Colors.blue;
    case 'closed':
      return Colors.orange;
    case 'ended':
      return Colors.purple;
    default:
      return Colors.grey;
  }
}

Widget _chip(String text, Color c) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

Widget _thumb(String? url, {double size = 48, bool round = false, IconData icon = Icons.emoji_events}) {
  final radius = BorderRadius.circular(round ? size / 2 : 10);
  final ph = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.25), borderRadius: radius),
    child: Icon(icon, size: size * 0.5, color: Colors.grey),
  );
  if (url == null || url.isEmpty) return ph;
  return ClipRRect(
    borderRadius: radius,
    child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph),
  );
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
  final now = DateTime.now();
  final d = await showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(2024),
    lastDate: now.add(const Duration(days: 730)),
  );
  if (d == null) return null;
  if (!context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

Future<String?> _pickAndUpload() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
  if (file == null) return null;
  return await ApiService.uploadImage(file);
}

String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

// ======================= LIST =======================

class TournamentsAdminScreen extends StatefulWidget {
  const TournamentsAdminScreen({super.key});

  @override
  State<TournamentsAdminScreen> createState() => _TournamentsAdminScreenState();
}

class _TournamentsAdminScreenState extends State<TournamentsAdminScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await ApiService.getTournamentsAdmin();
      _items = (d['tournaments'] as List?) ?? [];
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(const TournamentFormScreen()),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No tournaments yet. Tap + to create one.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final t = _items[i] as Map;
                      final phase = '${t['phase']}';
                      final entry = t['isFree'] == true ? 'FREE' : 'LKR ${_money(t['entryFee'])}';
                      return Card(
                        child: ListTile(
                          leading: _thumb(t['imageUrl']?.toString(), size: 52),
                          title: Text('${t['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${t['game']} | ${t['mode']} | $entry\n'
                            'Prize LKR ${_money(t['prizePool'])} | Teams ${t['teamsCount']}/${t['maxTeams']}\n'
                            'Starts ${_fmt(t['startAt'])}',
                          ),
                          isThreeLine: true,
                          trailing: _chip(_phaseLabel(phase), _phaseColor(phase)),
                          onTap: () => _open(TournamentDetailAdminScreen(id: int.parse('${t['id']}'))),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ======================= CREATE / EDIT =======================

class TournamentFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const TournamentFormScreen({super.key, this.existing});

  @override
  State<TournamentFormScreen> createState() => _TournamentFormScreenState();
}

class _TournamentFormScreenState extends State<TournamentFormScreen> {
  final _title = TextEditingController();
  final _game = TextEditingController(text: 'Free Fire');
  final _teamSize = TextEditingController(text: '4');
  final _maxTeams = TextEditingController(text: '50');
  final _fee = TextEditingController(text: '0');
  final _prize = TextEditingController(text: '0');
  final _rules = TextEditingController();
  String _mode = 'squad';
  bool _free = true;
  String? _imageUrl;
  DateTime? _regOpen;
  DateTime? _regClose;
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = '${e['title'] ?? ''}';
      _game.text = '${e['game'] ?? 'Free Fire'}';
      _teamSize.text = '${e['teamSize'] ?? 4}';
      _maxTeams.text = '${e['maxTeams'] ?? 50}';
      _free = e['isFree'] == true;
      _fee.text = _money(e['entryFee']);
      _prize.text = _money(e['prizePool']);
      _rules.text = '${e['rules'] ?? ''}';
      _mode = '${e['mode'] ?? 'squad'}';
      _imageUrl = e['imageUrl']?.toString();
      DateTime? ms(dynamic v) {
        final n = int.tryParse('${v ?? ''}');
        return n == null ? null : DateTime.fromMillisecondsSinceEpoch(n);
      }
      _regOpen = ms(e['regOpenAt']);
      _regClose = ms(e['regCloseAt']);
      _start = ms(e['startAt']);
      _end = ms(e['endAt']);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _game.dispose();
    _teamSize.dispose();
    _maxTeams.dispose();
    _fee.dispose();
    _prize.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickImage() async {
    setState(() => _uploading = true);
    try {
      final url = await _pickAndUpload();
      if (url != null) setState(() => _imageUrl = url);
    } catch (e) {
      _msg(_err(e));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return _msg('Title is required');
    if (_regClose == null || _start == null) return _msg('Registration close time and start time are required');
    final double fee = _free ? 0.0 : (double.tryParse(_fee.text.trim()) ?? 0.0);
    final double prize = double.tryParse(_prize.text.trim()) ?? 0.0;
    final body = <String, dynamic>{
      'title': title,
      'game': _game.text.trim(),
      'imageUrl': _imageUrl ?? '',
      'mode': _mode,
      'teamSize': int.tryParse(_teamSize.text.trim()) ?? 4,
      'maxTeams': int.tryParse(_maxTeams.text.trim()) ?? 50,
      'entryFee': fee,
      'prizePool': prize,
      'rules': _rules.text,
      'regOpenAt': _regOpen?.millisecondsSinceEpoch,
      'regCloseAt': _regClose!.millisecondsSinceEpoch,
      'startAt': _start!.millisecondsSinceEpoch,
      'endAt': _end?.millisecondsSinceEpoch,
    };
    if (!_free && fee <= 0) return _msg('Enter an entry fee, or switch to Free');
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await ApiService.createTournament(body);
      } else {
        await ApiService.updateTournament(int.parse('${widget.existing!['id']}'), body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _msg(_err(e));
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _dateTile(String label, DateTime? v, ValueChanged<DateTime?> onChanged, {bool optional = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(v == null ? 'Not set' : _fmtDt(v)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (optional && v != null) IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null)),
          const Icon(Icons.calendar_month),
        ],
      ),
      onTap: () async {
        final p = await _pickDateTime(context, v);
        if (p != null) onChanged(p);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit tournament' : 'New tournament')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _uploading ? null : _pickImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey.withValues(alpha: 0.2),
                child: _uploading
                    ? const Center(child: CircularProgressIndicator())
                    : (_imageUrl == null || _imageUrl!.isEmpty)
                        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_photo_alternate_outlined, size: 40), SizedBox(height: 6), Text('Tap to add tournament image')]))
                        : Image.network(_imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image))),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tournament title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _game, decoration: const InputDecoration(labelText: 'Game name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'solo', child: Text('Solo')),
              DropdownMenuItem(value: 'duo', child: Text('Duo')),
              DropdownMenuItem(value: 'squad', child: Text('Squad')),
            ],
            onChanged: (v) => setState(() {
              _mode = v ?? 'squad';
              if (!editing) _teamSize.text = _mode == 'solo' ? '1' : (_mode == 'duo' ? '2' : '4');
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _teamSize, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Team size', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _maxTeams, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max teams', border: OutlineInputBorder()))),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Free entry'),
            subtitle: const Text('Off = paid (the team leader pays once per team)'),
            value: _free,
            onChanged: (v) => setState(() => _free = v),
          ),
          if (!_free)
            TextField(controller: _fee, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Entry fee per team (LKR)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _prize, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prize pool (LKR)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _rules, maxLines: 6, decoration: const InputDecoration(labelText: 'Rules (one per line)', alignLabelWithHint: true, border: OutlineInputBorder())),
          const SizedBox(height: 8),
          _dateTile('Registration opens (optional)', _regOpen, (d) => setState(() => _regOpen = d), optional: true),
          _dateTile('Registration closes', _regClose, (d) => setState(() => _regClose = d)),
          _dateTile('Tournament starts', _start, (d) => setState(() => _start = d)),
          _dateTile('Tournament ends (optional)', _end, (d) => setState(() => _end = d), optional: true),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_saving ? 'Saving...' : (editing ? 'Save changes' : 'Create tournament'))),
          ),
        ],
      ),
    );
  }
}

// ======================= DETAIL =======================

class TournamentDetailAdminScreen extends StatefulWidget {
  final int id;
  const TournamentDetailAdminScreen({super.key, required this.id});

  @override
  State<TournamentDetailAdminScreen> createState() => _TournamentDetailAdminScreenState();
}

class _TournamentDetailAdminScreenState extends State<TournamentDetailAdminScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _roomInit = false;
  bool _uploading = false;
  final _roomId = TextEditingController();
  final _roomPass = TextEditingController();
  int? _selWinner;
  String? _winnerImg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _roomId.dispose();
    _roomPass.dispose();
    super.dispose();
  }

  void _msg(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Map get _t => (_data!['tournament'] as Map);
  List get _teams => (_data!['teams'] as List);
  List<int> get _matches => ((_data!['matches'] as List?) ?? []).map((e) => int.parse('$e')).toList();

  Future<void> _load() async {
    try {
      final d = await ApiService.getTournamentAdmin(widget.id);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        if (!_roomInit) {
          final t = d['tournament'] as Map;
          _roomId.text = '${t['roomId'] ?? ''}';
          _roomPass.text = '${t['roomPassword'] ?? ''}';
          _roomInit = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _msg(_err(e));
    }
  }

  Future<void> _act(Future<String?> Function() fn) async {
    try {
      final m = await fn();
      if (m != null) _msg(m);
      await _load();
    } catch (e) {
      _msg(_err(e));
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    return ok == true;
  }

  Future<String?> _askText(String title, {String hint = '', bool mustFill = true, int maxLines = 1}) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return null;
    final v = c.text.trim();
    if (mustFill && v.isEmpty) return null;
    return v;
  }

  // ---------- teams ----------

  Future<void> _suspend(Map tm) async {
    final reason = await _askText('Suspend "${tm['guildName']}"', hint: 'Reason (e.g. hack / cheating)');
    if (reason == null) return;
    await _act(() async {
      await ApiService.suspendTournamentTeam(widget.id, int.parse('${tm['teamId']}'), reason);
      return 'Team suspended';
    });
  }

  Future<void> _restore(Map tm) async {
    await _act(() async {
      await ApiService.unsuspendTournamentTeam(widget.id, int.parse('${tm['teamId']}'));
      return 'Team restored';
    });
  }

  Widget _summary() {
    final t = _t;
    final phase = '${t['phase']}';
    final entry = t['isFree'] == true ? 'FREE' : 'LKR ${_money(t['entryFee'])} per team';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _thumb(t['imageUrl']?.toString(), size: 56),
                const SizedBox(width: 12),
                Expanded(child: Text('${t['title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                _chip(_phaseLabel(phase), _phaseColor(phase)),
              ],
            ),
            const SizedBox(height: 10),
            Text('${t['game']} | ${t['mode']} | team size ${t['teamSize']}'),
            Text('Entry: $entry | Prize: LKR ${_money(t['prizePool'])}'),
            Text('Teams: ${t['teamsCount']}/${t['maxTeams']}'),
            Text('Registration: ${_fmt(t['regOpenAt'])} to ${_fmt(t['regCloseAt'])}'),
            Text('Starts: ${_fmt(t['startAt'])}   Ends: ${_fmt(t['endAt'])}'),
          ],
        ),
      ),
    );
  }

  Widget _teamCard(Map tm) {
    final status = '${tm['status']}';
    final members = (tm['members'] as List?) ?? [];
    final refunded = tm['refunded'] == true;
    final fee = double.tryParse('${tm['feePaid'] ?? 0}') ?? 0;
    Color sc = Colors.green;
    if (status == 'suspended') sc = Colors.red;
    if (status == 'dissolved') sc = Colors.grey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _thumb(tm['guildImageUrl']?.toString(), size: 44, round: true, icon: Icons.groups),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${tm['guildName']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        'Points: ${tm['totalPoints']}'
                        '${fee > 0 ? '  |  Paid LKR ${_money(fee)}${refunded ? ' (refunded)' : ''}' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _chip(status, sc),
              ],
            ),
            if (status == 'suspended' && '${tm['suspendReason'] ?? ''}'.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('Reason: ${tm['suspendReason']}', style: const TextStyle(color: Colors.red, fontSize: 12))),
            const Divider(),
            ...members.map((m) {
              final mm = m as Map;
              final gid = '${mm['gameId'] ?? ''}';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(mm['role'] == 'leader' ? Icons.star : Icons.person, size: 20),
                title: Text('${mm['displayName']} (${mm['email']})', style: const TextStyle(fontSize: 13)),
                subtitle: Text('Game ID: ${gid.isEmpty ? '-' : gid}  |  Name: ${mm['gameName'] ?? '-'}  |  ${mm['status']}'),
                trailing: gid.isEmpty ? null : const Icon(Icons.copy, size: 16),
                onTap: gid.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: gid));
                        _msg('Game ID copied');
                      },
              );
            }),
            if (status == 'active')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _suspend(tm),
                  icon: const Icon(Icons.block, color: Colors.red),
                  label: const Text('Suspend', style: TextStyle(color: Colors.red)),
                ),
              ),
            if (status == 'suspended')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: () => _restore(tm), icon: const Icon(Icons.undo), label: const Text('Restore')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _teamsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _summary(),
        const SizedBox(height: 4),
        if (_teams.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No teams registered yet'))),
        ..._teams.map((t) => _teamCard(t as Map)),
      ],
    );
  }

  // ---------- points ----------

  List<Map> _ranked() {
    final list = _teams.where((t) => (t as Map)['status'] == 'active').map((t) => t as Map).toList();
    list.sort((a, b) => (int.tryParse('${b['totalPoints']}') ?? 0).compareTo(int.tryParse('${a['totalPoints']}') ?? 0));
    return list;
  }

  Future<void> _openMatch(int matchNo) async {
    final active = _ranked();
    if (active.isEmpty) return _msg('No active teams');
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _MatchPointsScreen(
          tournamentId: widget.id,
          matchNo: matchNo,
          teams: active,
          exists: _matches.contains(matchNo),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Widget _pointsTab() {
    final ranked = _ranked();
    final matches = _matches;
    final nextMatch = matches.isEmpty ? 1 : matches.reduce((a, b) => a > b ? a : b) + 1;
    int? lastPts;
    int lastRank = 0;
    final rows = <Widget>[];
    for (var i = 0; i < ranked.length; i++) {
      final pts = int.tryParse('${ranked[i]['totalPoints']}') ?? 0;
      if (pts != lastPts) {
        lastRank = i + 1;
        lastPts = pts;
      }
      rows.add(ListTile(
        dense: true,
        leading: CircleAvatar(radius: 14, child: Text('$lastRank', style: const TextStyle(fontSize: 12))),
        title: Text('${ranked[i]['guildName']}'),
        trailing: Text('$pts pts', style: const TextStyle(fontWeight: FontWeight.w700)),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Enter points per match. Totals and the leaderboard update automatically for players.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...matches.map((m) => ActionChip(avatar: const Icon(Icons.edit, size: 16), label: Text('Match $m'), onPressed: () => _openMatch(m))),
            ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text('Add match $nextMatch'), onPressed: () => _openMatch(nextMatch)),
          ],
        ),
        const Divider(height: 28),
        const Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No active teams')),
        ...rows,
      ],
    );
  }

  // ---------- manage ----------

  Future<void> _saveRoom({bool quiet = false}) async {
    final id = _roomId.text.trim();
    final pw = _roomPass.text.trim();
    if (id.isEmpty || pw.isEmpty) {
      throw Exception('Enter Room ID and password');
    }
    await ApiService.saveTournamentRoom(widget.id, id, pw);
    if (!quiet) _msg('Room details saved');
  }

  Future<void> _sendRoom() async {
    if (!await _confirm('Send to leaders?', 'Room ID and password will be sent as a notification to every team leader.')) return;
    await _act(() async {
      await _saveRoom(quiet: true);
      return await ApiService.sendTournamentRoom(widget.id);
    });
  }

  Future<void> _remind() async {
    final text = await _askText('Send reminder', hint: 'Leave empty for the default message', mustFill: false, maxLines: 2);
    if (text == null) return;
    await _act(() => ApiService.remindTournament(widget.id, message: text));
  }

  Future<void> _cancelTournament() async {
    if (!await _confirm('Cancel tournament?', 'Leaders of active teams get their entry fee refunded. Suspended teams are not refunded. This cannot be undone.')) return;
    await _act(() async {
      final r = await ApiService.cancelTournament(widget.id);
      return '${r['message'] ?? 'Cancelled'}';
    });
  }

  Future<void> _toggleVisibility() async {
    final currentlyHidden = _t['hiddenFromCustomers'] == true;
    final title = currentlyHidden ? 'Show this tournament in the customer app again?' : 'Remove this tournament from the customer app?';
    final body = currentlyHidden ? 'Customers will be able to see it again.' : 'Customers will no longer see this post. Nothing else changes - no refunds, no cancellation.';
    if (!await _confirm(title, body)) return;
    await _act(() async {
      final r = await ApiService.toggleTournamentVisibility(widget.id);
      return '${r['message'] ?? 'Updated'}';
    });
  }

  Future<void> _deleteTournament() async {
    if (!await _confirm('Delete tournament?', 'This removes the tournament permanently.')) return;
    try {
      await ApiService.deleteTournament(widget.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _msg(_err(e));
    }
  }

  Widget _manageTab() {
    final state = '${_t['state']}';
    final active = state == 'active';
    final sentAt = _t['roomSentAt'];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Room details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        TextField(controller: _roomId, decoration: const InputDecoration(labelText: 'Room ID', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _roomPass, decoration: const InputDecoration(labelText: 'Room password', border: OutlineInputBorder())),
        const SizedBox(height: 6),
        Text(sentAt == null ? 'Not sent to leaders yet' : 'Sent to leaders: ${_fmt(sentAt)}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: active
                    ? () => _act(() async {
                          await _saveRoom(quiet: true);
                          return 'Room details saved';
                        })
                    : null,
                child: const Text('Save'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: active ? _sendRoom : null, child: const Text('Send to leaders'))),
          ],
        ),
        const Divider(height: 32),
        const Text('Reminders', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Players also get automatic reminders 24 hours, 1 hour and 10 minutes before the start.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: active ? _remind : null, icon: const Icon(Icons.notifications_active_outlined), label: const Text('Send reminder to all players')),
        const Divider(height: 32),
        const Text('Danger zone', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.red)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: active ? _cancelTournament : null,
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          label: const Text('Cancel tournament (refund leaders)', style: TextStyle(color: Colors.red)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _toggleVisibility,
          icon: Icon(_t['hiddenFromCustomers'] == true ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          label: Text(_t['hiddenFromCustomers'] == true ? 'Show in customer app' : 'Remove from customer app'),
        ),
        if (_teams.isEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _deleteTournament,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Delete tournament', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }

  // ---------- winner ----------

  Future<void> _pickWinnerImage({required bool saveNow}) async {
    setState(() => _uploading = true);
    try {
      final url = await _pickAndUpload();
      if (url != null) {
        if (saveNow) {
          await ApiService.setTournamentWinnerImage(widget.id, url);
          _msg('Winner image updated');
          await _load();
        } else {
          setState(() => _winnerImg = url);
        }
      }
    } catch (e) {
      _msg(_err(e));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _declareWinner() async {
    final teamId = _selWinner;
    if (teamId == null) return;
    final tm = _teams.map((t) => t as Map).firstWhere((t) => int.tryParse('${t['teamId']}') == teamId);
    final accepted = ((tm['members'] as List?) ?? []).where((m) => (m as Map)['status'] == 'accepted').length;
    final prize = _money(_t['prizePool']);
    final ok = await _confirm(
      'Declare winner?',
      '"${tm['guildName']}" wins.\nLKR $prize will be shared equally between $accepted accepted member(s) and added to their wallets. This can only be done once.',
    );
    if (!ok) return;
    await _act(() => ApiService.setTournamentWinner(widget.id, teamId, _winnerImg));
  }

  Widget _winnerTab() {
    final winnerId = _t['winnerTeamId'];
    if (winnerId != null) {
      final tm = _teams.map((t) => t as Map).where((t) => int.tryParse('${t['teamId']}') == int.tryParse('$winnerId')).toList();
      final name = tm.isEmpty ? 'Team #$winnerId' : '${tm.first['guildName']}';
      final img = _t['winnerImageUrl']?.toString();
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                  const SizedBox(height: 8),
                  Text('Winner: $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Prize was paid to the team members.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  if (img != null && img.isNotEmpty)
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(img, height: 180, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pickWinnerImage(saveNow: true),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_uploading ? 'Uploading...' : (img == null || img.isEmpty ? 'Add winner image' : 'Change winner image')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final state = '${_t['state']}';
    if (state == 'cancelled') return const Center(child: Text('Tournament is cancelled'));
    final ranked = _ranked();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Pick the winning team (top points are listed first). The prize pool is shared equally between all accepted members and added to their wallets. This happens once.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        if (ranked.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No active teams')),
        ...ranked.asMap().entries.map((e) {
          final tm = e.value;
          final id = int.tryParse('${tm['teamId']}');
          final sel = _selWinner == id;
          return Card(
            color: sel ? Colors.green.withValues(alpha: 0.15) : null,
            child: ListTile(
              leading: _thumb(tm['guildImageUrl']?.toString(), size: 40, round: true, icon: Icons.groups),
              title: Text('${tm['guildName']}'),
              subtitle: Text('${tm['totalPoints']} pts${e.key == 0 ? '  |  top team' : ''}'),
              trailing: sel ? const Icon(Icons.check_circle, color: Colors.green) : null,
              onTap: () => setState(() => _selWinner = id),
            ),
          );
        }),
        const SizedBox(height: 10),
        if (_winnerImg != null && _winnerImg!.isNotEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_winnerImg!, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
        OutlinedButton.icon(
          onPressed: _uploading ? null : () => _pickWinnerImage(saveNow: false),
          icon: const Icon(Icons.image_outlined),
          label: Text(_uploading ? 'Uploading...' : (_winnerImg == null ? 'Add winner image (shown on tournament page)' : 'Change winner image')),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _selWinner == null ? null : _declareWinner,
          icon: const Icon(Icons.emoji_events),
          label: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Declare winner and pay prize')),
        ),
      ],
    );
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return Scaffold(appBar: AppBar(title: const Text('Tournament')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_data == null) {
      return Scaffold(appBar: AppBar(title: const Text('Tournament')), body: const Center(child: Text('Could not load tournament')));
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_t['title']}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => TournamentFormScreen(existing: Map<String, dynamic>.from(_t))),
                );
                if (changed == true) _load();
              },
            ),
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Teams (${_teams.length})'),
              const Tab(text: 'Points'),
              const Tab(text: 'Manage'),
              const Tab(text: 'Winner'),
            ],
          ),
        ),
        body: TabBarView(children: [_teamsTab(), _pointsTab(), _manageTab(), _winnerTab()]),
      ),
    );
  }
}

// ======================= MATCH POINTS ENTRY =======================

class _MatchPointsScreen extends StatefulWidget {
  final int tournamentId;
  final int matchNo;
  final List<Map> teams;
  final bool exists;
  const _MatchPointsScreen({required this.tournamentId, required this.matchNo, required this.teams, required this.exists});

  @override
  State<_MatchPointsScreen> createState() => _MatchPointsScreenState();
}

class _MatchPointsScreenState extends State<_MatchPointsScreen> {
  final Map<int, TextEditingController> _c = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final t in widget.teams) {
      final id = int.parse('${t['teamId']}');
      final m = (t['matches'] as Map?) ?? {};
      final v = m['${widget.matchNo}'];
      _c[id] = TextEditingController(text: v == null ? '' : '$v');
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    final entries = <Map<String, dynamic>>[];
    for (final e in _c.entries) {
      final txt = e.value.text.trim();
      if (txt.isEmpty) continue;
      final p = int.tryParse(txt);
      if (p == null) return _msg('Points must be whole numbers');
      entries.add({'teamId': e.key, 'points': p});
    }
    if (entries.isEmpty) return _msg('Enter points for at least one team');
    setState(() => _saving = true);
    try {
      await ApiService.saveTournamentPoints(widget.tournamentId, widget.matchNo, entries);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _msg(_err(e));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete match ${widget.matchNo}?'),
        content: const Text('All points entered for this match will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteTournamentMatch(widget.tournamentId, widget.matchNo);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _msg(_err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Match ${widget.matchNo} points'),
        actions: [if (widget.exists) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.teams.length,
              itemBuilder: (_, i) {
                final t = widget.teams[i];
                final id = int.parse('${t['teamId']}');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      _thumb(t['guildImageUrl']?.toString(), size: 40, round: true, icon: Icons.groups),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${t['guildName']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _c[id],
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(hintText: 'pts', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _saving ? null : _save, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_saving ? 'Saving...' : 'Save points'))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
