import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PresensiDosenPage extends StatefulWidget {
  final String mataKuliahId;
  final String mataKuliahNama;

  const PresensiDosenPage({
    super.key,
    required this.mataKuliahId,
    required this.mataKuliahNama,
  });

  @override
  State<PresensiDosenPage> createState() => _PresensiDosenPageState();
}

class _PresensiDosenPageState extends State<PresensiDosenPage> {
  final _firestore = FirebaseFirestore.instance;
  late String _todayStr;
  late String _hariStr;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _initDate();
  }

  void _initDate() {
    final now = DateTime.now();
    _todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _hariStr = _getHari(now.weekday);
  }

  String _getHari(int weekday) {
    switch (weekday) {
      case 1:
        return "Senin";
      case 2:
        return "Selasa";
      case 3:
        return "Rabu";
      case 4:
        return "Kamis";
      case 5:
        return "Jumat";
      case 6:
        return "Sabtu";
      case 7:
        return "Minggu";
      default:
        return "";
    }
  }

  // ══════════════════════════════════════════════
  // LOGIKA CETAK PDF
  // ══════════════════════════════════════════════
  Future<void> _cetakPdfReport() async {
    setState(() => _isPrinting = true);
    try {
      // 1. Ambil data presensi mahasiswa yang sudah diinput hari ini dari Firestore
      final snap = await _firestore
          .collection('presensi')
          .where('mataKuliahId', isEqualTo: widget.mataKuliahId)
          .where('tanggal', isEqualTo: _todayStr)
          .get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        _showSnack(
          "Belum ada mahasiswa yang diberi status absen hari ini.",
          Colors.orange,
        );
        setState(() => _isPrinting = false);
        return;
      }

      // 2. Inisialisasi dokumen PDF berkas
      final pdf = pw.Document();

      // Struktur tabel data PDF
      final List<List<String>> tableData = [
        ['No', 'Nama Mahasiswa', 'Status Kehadiran'],
      ];

      for (int i = 0; i < snap.docs.length; i++) {
        final data = snap.docs[i].data();
        tableData.add([
          (i + 1).toString(),
          data['mahasiswaNama'] ?? '-',
          data['status'] ?? '-',
        ]);
      }

      // 3. Desain Dokumen PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw
                    .CrossAxisAlignment
                    .start, // [PERBAIKAN ERROR TYPO DISINI]
                children: [
                  pw.Center(
                    child: pw.Text(
                      "LAPORAN PRESENSI MAHASISWA",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    "Mata Kuliah : ${widget.mataKuliahNama}",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    "Hari / Tanggal : $_hariStr, $_todayStr",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1.5, color: PdfColors.grey300),
                  pw.SizedBox(height: 16),

                  // Tabel Generator Otomatis (Menggunakan TableHelper sesuai versi terbaru)
                  pw.TableHelper.fromTextArray(
                    // [PERBAIKAN WARNING DEPRECATED TABLE]
                    headers: tableData[0],
                    data: tableData.sublist(1),
                    border: pw.TableBorder.all(
                      width: 0.5,
                      color: PdfColors.grey400,
                    ),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.indigo,
                    ),
                    cellAlignment: pw.Alignment.centerLeft,
                    cellAlignments: {
                      0: pw.Alignment.center,
                      2: pw.Alignment.center,
                    },
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // 4. Trigger printer bawaan OS / Browser Web Preview dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Presensi_${widget.mataKuliahNama}_$_todayStr.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack("Gagal mencetak PDF: $e", Colors.red);
    }
    if (mounted) {
      setState(() => _isPrinting = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Stream<QuerySnapshot> get _mahasiswaStream => _firestore
      .collection('krs')
      .where('mataKuliahId', isEqualTo: widget.mataKuliahId)
      .where('status', isEqualTo: 'disetujui')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          "Presensi: ${widget.mataKuliahNama}",
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        actions: [
          // TOMBOL CETAK PDF BARU
          _isPrinting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'Cetak Laporan PDF',
                  onPressed: _cetakPdfReport,
                ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  "$_hariStr, $_todayStr",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _mahasiswaStream,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(
              child: Text("Belum ada mahasiswa yang mengambil MK ini."),
            );

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _MahasiswaPresensiTile(
                mahasiswaId: data['mahasiswaId'].toString(),
                mahasiswaNama: data['mahasiswaNama'].toString(),
                mataKuliahId: widget.mataKuliahId,
                mataKuliahNama: widget.mataKuliahNama,
                todayStr: _todayStr,
              );
            },
          );
        },
      ),
    );
  }
}

class _MahasiswaPresensiTile extends StatelessWidget {
  final String mahasiswaId;
  final String mahasiswaNama;
  final String mataKuliahId;
  final String mataKuliahNama;
  final String todayStr;

  const _MahasiswaPresensiTile({
    required this.mahasiswaId,
    required this.mahasiswaNama,
    required this.mataKuliahId,
    required this.mataKuliahNama,
    required this.todayStr,
  });

  Future<void> _catatPresensi(BuildContext context, String status) async {
    final docId = "${mataKuliahId}_${mahasiswaId}_$todayStr";
    try {
      await FirebaseFirestore.instance.collection('presensi').doc(docId).set({
        'mahasiswaId': mahasiswaId,
        'mahasiswaNama': mahasiswaNama,
        'mataKuliahId': mataKuliahId,
        'mataKuliahNama': mataKuliahNama,
        'tanggal': todayStr,
        'waktuUpdate': FieldValue.serverTimestamp(),
        'status': status,
      }, SetOptions(merge: true));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hadir':
        return Colors.green;
      case 'Sakit':
        return Colors.blue;
      case 'Izin':
        return Colors.orange;
      case 'Alpa':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildButton(
    BuildContext context,
    String statusLabel,
    String currentStatus,
  ) {
    final isSelected = statusLabel == currentStatus;
    final color = _getStatusColor(statusLabel);

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.white,
        foregroundColor: isSelected ? Colors.white : color,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      onPressed: () => _catatPresensi(context, statusLabel),
      child: Text(
        statusLabel,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docId = "${mataKuliahId}_${mahasiswaId}_$todayStr";

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('presensi')
          .doc(docId)
          .snapshots(),
      builder: (context, snapshot) {
        String currentStatus = "";
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          currentStatus = data['status'] ?? "";
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              // [PERBAIKAN WARNING DEPRECATED OPACITY KE WITHVALUES]
              color: currentStatus.isNotEmpty
                  ? _getStatusColor(currentStatus).withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      // [PERBAIKAN WARNING DEPRECATED OPACITY KE WITHVALUES]
                      backgroundColor: const Color(
                        0xFF3F51B5,
                      ).withValues(alpha: 0.1),
                      child: Text(
                        mahasiswaNama.isNotEmpty
                            ? mahasiswaNama[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          color: Color(0xFF3F51B5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mahasiswaNama,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (currentStatus.isNotEmpty)
                      Icon(
                        Icons.check_circle,
                        color: _getStatusColor(currentStatus),
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildButton(context, "Hadir", currentStatus),
                    _buildButton(context, "Sakit", currentStatus),
                    _buildButton(context, "Izin", currentStatus),
                    _buildButton(context, "Alpa", currentStatus),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
