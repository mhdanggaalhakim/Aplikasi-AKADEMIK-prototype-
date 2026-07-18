import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class KhsPage extends StatefulWidget {
  final String userId;
  final String userNama;

  const KhsPage({super.key, required this.userId, required this.userNama});

  @override
  State<KhsPage> createState() => _KhsPageState();
}

class _KhsPageState extends State<KhsPage> {
  final _firestore = FirebaseFirestore.instance;

  String selectedSemester = "1"; // Default semester yang dilihat
  final List<String> semesters = ["1", "2", "3", "4", "5", "6", "7", "8"];

  bool isLoading = true;
  bool isPrinting = false;

  // Semua nilai mahasiswa (belum difilter semester)
  List<Map<String, dynamic>> _allNilai = [];

  @override
  void initState() {
    super.initState();
    _loadNilai();
  }

  String _s(dynamic v) => (v ?? '').toString();

  // Fungsi konversi Grade ke Bobot
  double getBobot(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return 4.0;
      case 'B':
        return 3.0;
      case 'C':
        return 2.0;
      case 'D':
        return 1.0;
      default:
        return 0.0;
    }
  }

  // ══════════════════════════════════════════════
  // AMBIL SEMUA NILAI MAHASISWA + BACKFILL SEMESTER & SKS
  // ══════════════════════════════════════════════
  Future<void> _loadNilai() async {
    setState(() => isLoading = true);
    try {
      final nilaiSnap = await _firestore
          .collection('nilai')
          .where('mahasiswaId', isEqualTo: widget.userId)
          .get();

      final docs = nilaiSnap.docs;
      final Map<String, Map<String, dynamic>> mkCache = {};
      final List<Map<String, dynamic>> hasil = [];

      for (var doc in docs) {
        final data = doc.data();
        data['id'] = doc.id;

        String semester = _s(data['semester']).trim();
        int sks = data['sks'] is num
            ? (data['sks'] as num).toInt()
            : (int.tryParse(_s(data['sks'])) ?? 0);

        // Jika semester kosong atau SKS 0 (data lama), ambil dari koleksi mata_kuliah
        if (semester.isEmpty || sks == 0) {
          final mkId = _s(data['mataKuliahId']);
          if (mkId.isNotEmpty) {
            if (!mkCache.containsKey(mkId)) {
              try {
                final mkDoc = await _firestore
                    .collection('mata_kuliah')
                    .doc(mkId)
                    .get();
                if (mkDoc.exists) {
                  mkCache[mkId] = {
                    'semester': _s(mkDoc.data()?['semester']).trim(),
                    'sks': mkDoc.data()?['sks'] is num
                        ? (mkDoc.data()?['sks'] as num).toInt()
                        : (int.tryParse(_s(mkDoc.data()?['sks'])) ?? 0),
                  };
                }
              } catch (_) {}
            }

            if (mkCache.containsKey(mkId)) {
              if (semester.isEmpty) semester = mkCache[mkId]!['semester'];
              if (sks == 0) sks = mkCache[mkId]!['sks'];
            }
          }
        }

        data['semesterResolved'] = semester.isEmpty ? '-' : semester;
        data['sksResolved'] = sks; // Simpan SKS yang sudah fix
        hasil.add(data);
      }

      if (mounted) {
        setState(() => _allNilai = hasil);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mengambil data KHS: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredNilai {
    return _allNilai
        .where((n) => _s(n['semesterResolved']) == selectedSemester)
        .toList();
  }

  // ══════════════════════════════════════════════
  // CETAK KHS (PDF)
  // ══════════════════════════════════════════════
  Future<void> cetakKhs(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    setState(() => isPrinting = true);
    try {
      double totalBobotSks = 0;
      int totalSks = 0;

      final rows = items.map((data) {
        final mkNama = _s(data['mataKuliahNama']).isEmpty
            ? "-"
            : _s(data['mataKuliahNama']);
        final sks = data['sksResolved'] ?? 0;
        final grade = _s(data['grade']).isEmpty ? "E" : _s(data['grade']);
        final bobot = getBobot(grade);

        totalSks += (sks as int);
        totalBobotSks += (bobot * sks);

        return {
          'nama': mkNama,
          'sks': sks,
          'grade': grade,
          'skor': bobot * sks,
        };
      }).toList();

      final ips = totalBobotSks / (totalSks == 0 ? 1 : totalSks);
      final tanggalCetak =
          "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "KARTU HASIL STUDI (KHS)",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                "Dicetak pada: $tanggalCetak",
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text("Nama Mahasiswa : ${widget.userNama}"),
              pw.Text("Semester       : $selectedSemester"),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ["No", "Mata Kuliah", "SKS", "Grade", "Skor"],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                data: rows.asMap().entries.map((e) {
                  final i = e.key + 1;
                  final r = e.value;
                  return [
                    "$i",
                    "${r['nama']}",
                    "${r['sks']}",
                    "${r['grade']}",
                    "${r['skor']}",
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Total SKS: $totalSks"),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "IPS (Indeks Prestasi Semester): ${ips.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: "KHS_${widget.userNama}_Semester$selectedSemester",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mencetak KHS: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => isPrinting = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredNilai;

    double totalBobotSks = 0;
    int totalSks = 0;

    // Perhitungan IPS untuk UI menggunakan SKS yang sudah di-resolve
    for (var data in items) {
      final sks = data['sksResolved'] ?? 0;
      final grade = _s(data['grade']).isEmpty ? "E" : _s(data['grade']);
      totalSks += (sks as int);
      totalBobotSks += (getBobot(grade) * sks);
    }
    final ips = totalBobotSks / (totalSks == 0 ? 1 : totalSks);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kartu Hasil Studi (KHS)"),
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _loadNilai, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          // Filter Semester
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text(
                  "Pilih Semester : ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedSemester,
                  items: semesters
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text("Semester $s"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() => selectedSemester = val!);
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _allNilai.isEmpty
                              ? "Belum ada nilai yang diinput untuk kamu.\nHubungi dosen/admin untuk input nilai."
                              : "Data KHS belum tersedia untuk semester ini.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // ── Tombol Cetak KHS ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: isPrinting
                                ? null
                                : () => cetakKhs(items),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3F51B5),
                              side: const BorderSide(color: Color(0xFF3F51B5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: isPrinting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.print, size: 18),
                            label: Text(
                              isPrinting
                                  ? "Menyiapkan PDF..."
                                  : "Cetak KHS Semester $selectedSemester",
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final data = items[index];
                            final mkNama = _s(data['mataKuliahNama']).isEmpty
                                ? "-"
                                : _s(data['mataKuliahNama']);
                            final sks = data['sksResolved'] ?? 0;
                            final grade = _s(data['grade']).isEmpty
                                ? "E"
                                : _s(data['grade']);
                            final bobot = getBobot(grade);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF3F51B5),
                                  child: Text(
                                    grade,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  mkNama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text("SKS: $sks | Bobot: $bobot"),
                                trailing: Text("Skor: ${bobot * sks}"),
                              ),
                            );
                          },
                        ),
                      ),

                      // Ringkasan IPS
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3F51B5),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Total SKS: $totalSks",
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const Text(
                                  "Semester Aktif",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "IPS: ${ips.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  "Indeks Prestasi Semester",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
