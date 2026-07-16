import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class KrsPage extends StatefulWidget {
  final String userId;
  final String userNama;
  const KrsPage({super.key, required this.userId, required this.userNama});

  @override
  State<KrsPage> createState() => _KrsPageState();
}

class _KrsPageState extends State<KrsPage> {
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> listKrs        = [];
  List<Map<String, dynamic>> listMataKuliah = [];
  bool isLoading = true;
  bool isSaving  = false;
  bool isPrinting = false;
  final Set<String> selectedMkIds = {};

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
      final krsSnap = await _firestore
          .collection('krs')
          .where('mahasiswaId', isEqualTo: widget.userId)
          .get();
      final krs = krsSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      krs.sort((a, b) {
        final tsA = a['createdAt'];
        final tsB = b['createdAt'];
        if (tsA == null || tsB == null) return 0;
        return (tsB as Timestamp).compareTo(tsA as Timestamp);
      });

      final mkSnap = await _firestore.collection('mata_kuliah').get();
      final mk = mkSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      mk.sort((a, b) => _s(a['kodeMk']).compareTo(_s(b['kodeMk'])));

      setState(() {
        listKrs        = krs;
        listMataKuliah = mk;
      });
    } catch (e) {
      _snack("Gagal mengambil data: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  // Mata kuliah yg sudah pending/disetujui gak boleh diajukan lagi
  Set<String> get _mkTerpakai {
    return listKrs
        .where((k) => _s(k['status']) != 'ditolak')
        .map((k) => _s(k['mataKuliahId']))
        .toSet();
  }

  List<Map<String, dynamic>> get _mkTersedia {
    final terpakai = _mkTerpakai;
    return listMataKuliah.where((mk) => !terpakai.contains(mk['id'].toString())).toList();
  }

  List<Map<String, dynamic>> get _krsDisetujui {
    return listKrs.where((k) => _s(k['status']) == 'disetujui').toList();
  }

  int get totalSksDisetujui {
    return _krsDisetujui.fold(0, (sum, k) => sum + _n(k['sks']).toInt());
  }

  int get totalSksDipilih {
    return listMataKuliah
        .where((mk) => selectedMkIds.contains(mk['id'].toString()))
        .fold(0, (sum, mk) => sum + _n(mk['sks']).toInt());
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> ajukanKrs() async {
    if (selectedMkIds.isEmpty) {
      _snack("Pilih minimal 1 mata kuliah dulu", Colors.orange);
      return;
    }
    setState(() => isSaving = true);
    try {
      final batch = _firestore.batch();
      for (var mkId in selectedMkIds) {
        final mk = listMataKuliah.firstWhere((m) => m['id'] == mkId);
        final docRef = _firestore.collection('krs').doc();
        batch.set(docRef, {
          'mahasiswaId':    widget.userId,
          'mahasiswaNama':  widget.userNama,
          'mataKuliahId':   mkId,
          'mataKuliahNama': _s(mk['namaMk']),
          'kodeMk':         _s(mk['kodeMk']),
          'sks':            _n(mk['sks']),
          'semester':       _n(mk['semester']),
          'status':         'pending',
          'createdAt':      FieldValue.serverTimestamp(),
          'updatedAt':      FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      _snack("${selectedMkIds.length} mata kuliah berhasil diajukan", Colors.green);
      setState(() => selectedMkIds.clear());
      getData();
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
    setState(() => isSaving = false);
  }

  Future<void> batalkan(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Batalkan Pengajuan"),
        content: const Text("Yakin ingin membatalkan pengajuan mata kuliah ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Tidak")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Batalkan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!ok) return;
    try {
      await _firestore.collection('krs').doc(id).delete();
      _snack("Pengajuan dibatalkan", Colors.green);
      getData();
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
  }

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
      default:          return "Menunggu Persetujuan";
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'disetujui': return Icons.check_circle;
      case 'ditolak':   return Icons.cancel;
      default:          return Icons.hourglass_top;
    }
  }

  // ══════════════════════════════════════════════
  // CETAK KRS (PDF) — hanya mata kuliah berstatus disetujui
  // ══════════════════════════════════════════════
  Future<void> cetakKrs() async {
    final approved = _krsDisetujui;
    if (approved.isEmpty) {
      _snack("Belum ada mata kuliah yang disetujui untuk dicetak", Colors.orange);
      return;
    }

    setState(() => isPrinting = true);
    try {
      final pdf = pw.Document();
      final totalSks = approved.fold<int>(0, (sum, k) => sum + _n(k['sks']).toInt());
      final tanggalCetak =
          "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("KARTU RENCANA STUDI (KRS)",
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text("Dicetak pada: $tanggalCetak",
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 16),
              pw.Text("Nama Mahasiswa : ${widget.userNama}"),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ["No", "Kode MK", "Mata Kuliah", "SKS", "Semester"],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                data: approved.asMap().entries.map((e) {
                  final i = e.key + 1;
                  final k = e.value;
                  return [
                    "$i",
                    _s(k['kodeMk']),
                    _s(k['mataKuliahNama']),
                    "${_n(k['sks'])}",
                    "${_n(k['semester'])}",
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Total SKS Disetujui: $totalSks",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: "KRS_${widget.userNama}",
      );
    } catch (e) {
      _snack("Gagal mencetak KRS: $e", Colors.red);
    }
    setState(() => isPrinting = false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3F51B5),
          foregroundColor: Colors.white,
          title: const Text("KRS"),
          elevation: 0,
          actions: [IconButton(onPressed: getData, icon: const Icon(Icons.refresh))],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Ajukan Mata Kuliah"),
              Tab(text: "Status KRS Saya"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
            : TabBarView(
                children: [_buildAjukan(), _buildStatus()],
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 1: AJUKAN MATA KULIAH
  // ══════════════════════════════════════════════
  Widget _buildAjukan() {
    final tersedia = _mkTersedia;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF3F51B5),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              _statChip(Icons.check_circle_outline, "$totalSksDisetujui SKS", "Disetujui"),
              const SizedBox(width: 8),
              _statChip(Icons.checklist, "$totalSksDipilih SKS", "Dipilih"),
            ],
          ),
        ),
        Expanded(
          child: tersedia.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text("Tidak ada mata kuliah tersisa untuk diajukan",
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                  itemCount: tersedia.length,
                  itemBuilder: (_, i) {
                    final mk = tersedia[i];
                    final id = mk['id'].toString();
                    final selected = selectedMkIds.contains(id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: selected ? 3 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: selected ? const Color(0xFF3F51B5) : Colors.transparent, width: 1.5),
                      ),
                      child: CheckboxListTile(
                        value: selected,
                        activeColor: const Color(0xFF3F51B5),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            selectedMkIds.add(id);
                          } else {
                            selectedMkIds.remove(id);
                          }
                        }),
                        title: Text(_s(mk['namaMk']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                            "${_s(mk['kodeMk'])} • ${_n(mk['sks'])} SKS • Semester ${_n(mk['semester'])}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ),
                    );
                  },
                ),
        ),
        if (tersedia.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : ajukanKrs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isSaving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(isSaving
                    ? "Mengajukan..."
                    : "Ajukan ${selectedMkIds.length} Mata Kuliah"),
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // TAB 2: STATUS KRS
  // ══════════════════════════════════════════════
  Widget _buildStatus() {
    if (listKrs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text("Belum ada pengajuan KRS", style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          ],
        ),
      );
    }
    return Column(
      children: [
        // ── Tombol Cetak KRS ─────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: isPrinting ? null : cetakKrs,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3F51B5),
                side: const BorderSide(color: Color(0xFF3F51B5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: isPrinting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.print, size: 18),
              label: Text(isPrinting ? "Menyiapkan PDF..." : "Cetak KRS (${_krsDisetujui.length} MK Disetujui)"),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listKrs.length,
            itemBuilder: (_, i) {
              final item   = listKrs[i];
              final status = _s(item['status']);
              final color  = _statusColor(status);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(_statusIcon(status), color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_s(item['mataKuliahNama']),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 3),
                            Text("${_s(item['kodeMk'])} • ${_n(item['sks'])} SKS",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_statusLabel(status),
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      if (status == 'pending')
                        IconButton(
                          onPressed: () => batalkan(item['id'].toString()),
                          icon: const Icon(Icons.close, color: Colors.red, size: 20),
                          tooltip: "Batalkan",
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String val, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text("$val ($label)",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}