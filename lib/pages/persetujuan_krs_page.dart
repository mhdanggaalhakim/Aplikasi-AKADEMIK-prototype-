import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PersetujuanKrsPage extends StatefulWidget {
  const PersetujuanKrsPage({super.key});

  @override
  State<PersetujuanKrsPage> createState() => _PersetujuanKrsPageState();
}

class _PersetujuanKrsPageState extends State<PersetujuanKrsPage> {
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> listKrs = [];
  bool isLoading = true;
  String keyword = "";
  String filterStatus = "pending"; // semua | pending | disetujui | ditolak
  final Set<String> processingIds = {};

  @override
  void initState() {
    super.initState();
    getData();
  }

  String _s(dynamic v) => (v ?? '').toString();
  num _n(dynamic v) => v is num ? v : (num.tryParse(_s(v)) ?? 0);

  Future<void> getData() async {
    setState(() => isLoading = true);
    try {
      final snap = await _firestore.collection('krs').get();
      final data = snap.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();

      data.sort((a, b) {
        final tsA = a['createdAt'];
        final tsB = b['createdAt'];
        if (tsA == null || tsB == null) return 0;
        return (tsB as Timestamp).compareTo(tsA as Timestamp);
      });

      setState(() => listKrs = data);
    } catch (e) {
      _snack("Gagal mengambil data: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> get filtered {
    var data = listKrs;
    if (filterStatus != "semua") {
      data = data.where((k) => _s(k['status']) == filterStatus).toList();
    }
    if (keyword.isNotEmpty) {
      data = data.where((k) {
        return _s(k['mahasiswaNama']).toLowerCase().contains(keyword) ||
               _s(k['mataKuliahNama']).toLowerCase().contains(keyword);
      }).toList();
    }
    return data;
  }

  int get countPending   => listKrs.where((k) => _s(k['status']) == 'pending').length;
  int get countDisetujui => listKrs.where((k) => _s(k['status']) == 'disetujui').length;
  int get countDitolak   => listKrs.where((k) => _s(k['status']) == 'ditolak').length;

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _updateStatus(String id, String status) async {
    setState(() => processingIds.add(id));
    try {
      await _firestore.collection('krs').doc(id).update({
        'status':    status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack(status == 'disetujui' ? "KRS disetujui" : "KRS ditolak", Colors.green);
      getData();
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
    setState(() => processingIds.remove(id));
  }

  Future<void> setujui(String id) => _updateStatus(id, 'disetujui');
  Future<void> tolak(String id)   => _updateStatus(id, 'ditolak');

  Color _statusColor(String status) {
    switch (status) {
      case 'disetujui': return const Color(0xFF2E7D32);
      case 'ditolak':   return const Color(0xFFC62828);
      default:          return const Color(0xFFEF6C00);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'disetujui': return "Disetujui";
      case 'ditolak':   return "Ditolak";
      default:          return "Menunggu";
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        title: const Text("Persetujuan KRS"),
        elevation: 0,
        actions: [IconButton(onPressed: getData, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF3F51B5),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                Row(children: [
                  _statChip(Icons.hourglass_top, "$countPending", "Menunggu", const Color(0xFFFFCC80)),
                  const SizedBox(width: 8),
                  _statChip(Icons.check_circle, "$countDisetujui", "Disetujui", const Color(0xFFA5D6A7)),
                  const SizedBox(width: 8),
                  _statChip(Icons.cancel, "$countDitolak", "Ditolak", const Color(0xFFEF9A9A)),
                ]),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => keyword = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Cari nama mahasiswa, mata kuliah...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _filterChip("Menunggu", "pending"),
                    const SizedBox(width: 6),
                    _filterChip("Disetujui", "disetujui"),
                    const SizedBox(width: 6),
                    _filterChip("Ditolak", "ditolak"),
                    const SizedBox(width: 6),
                    _filterChip("Semua", "semua"),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
                : data.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: data.length,
                        itemBuilder: (_, i) => _krsCard(data[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _krsCard(Map<String, dynamic> item) {
    final status = _s(item['status']);
    final color  = _statusColor(status);
    final id     = item['id'].toString();
    final isProcessing = processingIds.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF3F51B5).withOpacity(0.12),
                  child: Text(
                    _s(item['mahasiswaNama']).isNotEmpty
                        ? _s(item['mahasiswaNama'])[0].toUpperCase()
                        : "?",
                    style: const TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_s(item['mahasiswaNama']),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(_s(item['mataKuliahNama']),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(_statusLabel(status),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("${_s(item['kodeMk'])} • ${_n(item['sks'])} SKS • Semester ${_n(item['semester'])}",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing ? null : () => tolak(id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text("Tolak"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing ? null : () => setujui(id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: isProcessing
                          ? const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 16),
                      label: const Text("Setujui"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = filterStatus == value;
    return InkWell(
      onTap: () => setState(() => filterStatus = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF3F51B5) : Colors.white)),
      ),
    );
  }

  Widget _statChip(IconData icon, String val, String label, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(height: 2),
            Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            filterStatus == 'pending' ? "Tidak ada pengajuan yang menunggu" : "Tidak ada data",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }
}