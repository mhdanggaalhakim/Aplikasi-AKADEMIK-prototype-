import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NilaiPage extends StatefulWidget {
  final String role; // admin | dosen | mahasiswa
  final String? userId; // authUid dosen/mahasiswa yang sedang login
  final String? userNama;
  const NilaiPage({super.key, required this.role, this.userId, this.userNama});

  @override
  State<NilaiPage> createState() => _NilaiPageState();
}

class _NilaiPageState extends State<NilaiPage> {
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> listNilai = [];
  List<Map<String, dynamic>> listMahasiswa = [];
  List<Map<String, dynamic>> listMataKuliah =
      []; // untuk dosen: cuma mk yg diampu

  bool isLoading = true;
  bool isSaving = false;
  String keyword = "";

  bool get isAdmin => widget.role == 'admin';
  bool get isDosen => widget.role == 'dosen';
  bool get isMahasiswa => widget.role == 'mahasiswa';
  bool get canInput => isAdmin || isDosen;

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
      // Dosen hanya boleh melihat & input nilai utk mata kuliah yg dia ampu
      // (dicek dari jadwal mengajarnya), dihitung DULU sebelum ambil nilai.
      Set<String> allowedMkIds = {};

      if (canInput) {
        final mhsSnap = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'mahasiswa')
            .where('isActive', isEqualTo: true)
            .get();
        listMahasiswa = mhsSnap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        if (isAdmin) {
          final mkSnap = await _firestore.collection('mata_kuliah').get();
          listMataKuliah = mkSnap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        } else if (isDosen && widget.userId != null) {
          final jadwalSnap = await _firestore
              .collection('jadwal')
              .where('dosenId', isEqualTo: widget.userId)
              .get();
          final mkMap = <String, Map<String, dynamic>>{};
          for (var doc in jadwalSnap.docs) {
            final d = doc.data();
            final id = _s(d['mataKuliahId']);
            if (id.isNotEmpty) {
              allowedMkIds.add(id);
              mkMap[id] = {
                'id': id,
                'kodeMk': '',
                'namaMk': _s(d['mataKuliahNama']),
              };
            }
          }
          listMataKuliah = mkMap.values.toList();
        }
      }

      Query<Map<String, dynamic>> q = _firestore.collection('nilai');
      if (isMahasiswa && widget.userId != null) {
        q = q.where('mahasiswaId', isEqualTo: widget.userId);
      }
      final nilaiSnap = await q.get();
      var nilai = nilaiSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Filter di sisi client: dosen hanya lihat nilai mata kuliah yg dia ampu
      if (isDosen) {
        nilai = nilai
            .where((n) => allowedMkIds.contains(_s(n['mataKuliahId'])))
            .toList();
      }

      nilai.sort(
        (a, b) => _s(a['mahasiswaNama']).compareTo(_s(b['mahasiswaNama'])),
      );
      setState(() => listNilai = nilai);
    } catch (e) {
      _snack("Gagal mengambil data: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> get filtered {
    if (keyword.isEmpty) return listNilai;
    return listNilai.where((n) {
      return _s(n['mahasiswaNama']).toLowerCase().contains(keyword) ||
          _s(n['mataKuliahNama']).toLowerCase().contains(keyword);
    }).toList();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Bobot: Tugas 30% + UTS 30% + UAS 40%
  double _hitungAkhir(num tugas, num uts, num uas) {
    return (tugas * 0.3) + (uts * 0.3) + (uas * 0.4);
  }

  String _hitungGrade(double akhir) {
    if (akhir >= 85) return "A";
    if (akhir >= 75) return "B";
    if (akhir >= 65) return "C";
    if (akhir >= 50) return "D";
    return "E";
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case "A":
        return const Color(0xFF2E7D32);
      case "B":
        return const Color(0xFF558B2F);
      case "C":
        return const Color(0xFFEF6C00);
      case "D":
        return const Color(0xFFD84315);
      default:
        return const Color(0xFFC62828);
    }
  }

  // ══════════════════════════════════════════════
  // TAMBAH / EDIT NILAI
  // ══════════════════════════════════════════════
  void showFormDialog({Map<String, dynamic>? item}) {
    final isEdit = item != null;
    String? selectedMhsId = isEdit ? _s(item['mahasiswaId']) : null;
    String? selectedMkId = isEdit ? _s(item['mataKuliahId']) : null;
    final cTugas = TextEditingController(text: isEdit ? _s(item['tugas']) : '');
    final cUts = TextEditingController(text: isEdit ? _s(item['uts']) : '');
    final cUas = TextEditingController(text: isEdit ? _s(item['uas']) : '');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isEdit ? Icons.edit : Icons.add_box,
                          color: const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEdit ? "Edit Nilai" : "Input Nilai",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    DropdownButtonFormField<String>(
                      initialValue: selectedMhsId,
                      decoration: _dec("Mahasiswa", Icons.person),
                      items: listMahasiswa.map((m) {
                        return DropdownMenuItem(
                          value: m['id'].toString(),
                          child: Text(
                            "${_s(m['nim'])} - ${_s(m['nama'])}",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: isEdit
                          ? null
                          : (v) => setDialogState(() => selectedMhsId = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedMkId,
                      decoration: _dec("Mata Kuliah", Icons.menu_book),
                      items: listMataKuliah.map((mk) {
                        final label = _s(mk['kodeMk']).isNotEmpty
                            ? "${_s(mk['kodeMk'])} - ${_s(mk['namaMk'])}"
                            : _s(mk['namaMk']);
                        return DropdownMenuItem(
                          value: mk['id'].toString(),
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: isEdit
                          ? null
                          : (v) => setDialogState(() => selectedMkId = v),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _fieldNum(cTugas, "Tugas", Icons.assignment),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _fieldNum(cUts, "UTS", Icons.edit_document),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _fieldNum(cUas, "UAS", Icons.school)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Bobot: Tugas 30% + UTS 30% + UAS 40%. Nilai 0-100.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(dialogContext),
                          child: const Text("Batal"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (selectedMhsId == null ||
                                      selectedMkId == null) {
                                    _snack(
                                      "Mahasiswa & mata kuliah wajib dipilih",
                                      Colors.orange,
                                    );
                                    return;
                                  }
                                  setDialogState(() => isSaving = true);
                                  final mhs = listMahasiswa.firstWhere(
                                    (m) => m['id'] == selectedMhsId,
                                    orElse: () => {
                                      'nama': _s(item?['mahasiswaNama']),
                                    },
                                  );
                                  final mk = listMataKuliah.firstWhere(
                                    (m) => m['id'] == selectedMkId,
                                    orElse: () => {
                                      'namaMk': _s(item?['mataKuliahNama']),
                                    },
                                  );
                                  final ok = isEdit
                                      ? await update(
                                          id: item['id'].toString(),
                                          tugas: cTugas.text.trim(),
                                          uts: cUts.text.trim(),
                                          uas: cUas.text.trim(),
                                        )
                                      : await tambah(
                                          mhsId: selectedMhsId!,
                                          mhsNama: _s(mhs['nama']),
                                          mkId: selectedMkId!,
                                          mkNama: _s(mk['namaMk']),
                                          tugas: cTugas.text.trim(),
                                          uts: cUts.text.trim(),
                                          uas: cUas.text.trim(),
                                        );
                                  setDialogState(() => isSaving = false);
                                  if (ok && dialogContext.mounted)
                                    Navigator.pop(dialogContext);
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save, size: 16),
                          label: const Text("Simpan"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _validScore(String v) {
    final n = num.tryParse(v);
    return n != null && n >= 0 && n <= 100;
  }

  Future<bool> tambah({
    required String mhsId,
    required String mhsNama,
    required String mkId,
    required String mkNama,
    required String tugas,
    required String uts,
    required String uas,
  }) async {
    if (!_validScore(tugas) || !_validScore(uts) || !_validScore(uas)) {
      _snack("Nilai harus berupa angka 0-100", Colors.orange);
      return false;
    }
    try {
      final check = await _firestore
          .collection('nilai')
          .where('mahasiswaId', isEqualTo: mhsId)
          .where('mataKuliahId', isEqualTo: mkId)
          .limit(1)
          .get();
      if (check.docs.isNotEmpty) {
        _snack(
          "Nilai mahasiswa ini untuk mata kuliah tsb sudah ada, silakan edit",
          Colors.red,
        );
        return false;
      }

      final t = num.parse(tugas), u = num.parse(uts), a = num.parse(uas);
      final akhir = _hitungAkhir(t, u, a);
      final grade = _hitungGrade(akhir);

      await _firestore.collection('nilai').add({
        'mahasiswaId': mhsId,
        'mahasiswaNama': mhsNama,
        'mataKuliahId': mkId,
        'mataKuliahNama': mkNama,
        'dosenId': isDosen ? widget.userId : null,
        'tugas': t,
        'uts': u,
        'uas': a,
        'nilaiAkhir': akhir,
        'grade': grade,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack("Nilai berhasil disimpan", Colors.green);
      getData();
      return true;
    } catch (e) {
      _snack("Error: $e", Colors.red);
      return false;
    }
  }

  Future<bool> update({
    required String id,
    required String tugas,
    required String uts,
    required String uas,
  }) async {
    if (!_validScore(tugas) || !_validScore(uts) || !_validScore(uas)) {
      _snack("Nilai harus berupa angka 0-100", Colors.orange);
      return false;
    }
    try {
      final t = num.parse(tugas), u = num.parse(uts), a = num.parse(uas);
      final akhir = _hitungAkhir(t, u, a);
      final grade = _hitungGrade(akhir);

      await _firestore.collection('nilai').doc(id).update({
        'tugas': t,
        'uts': u,
        'uas': a,
        'nilaiAkhir': akhir,
        'grade': grade,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack("Nilai berhasil diupdate", Colors.green);
      getData();
      return true;
    } catch (e) {
      _snack("Error: $e", Colors.red);
      return false;
    }
  }

  Future<void> hapus(String id) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text("Konfirmasi Hapus"),
              ],
            ),
            content: const Text("Yakin ingin menghapus nilai ini?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Tidak"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Ya", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    try {
      await _firestore.collection('nilai').doc(id).delete();
      _snack("Nilai berhasil dihapus", Colors.green);
      getData();
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final data = filtered;
    final title = isMahasiswa ? "Nilai / Transkrip" : "Nilai";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        title: Text(title),
        elevation: 0,
        actions: [
          IconButton(onPressed: getData, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: canInput
          ? FloatingActionButton.extended(
              onPressed: (listMahasiswa.isEmpty || listMataKuliah.isEmpty)
                  ? () => _snack(
                      isDosen
                          ? "Kamu belum ditugaskan mengajar mata kuliah apapun (cek Penjadwalan)"
                          : "Tambahkan Data Mahasiswa & Mata Kuliah dulu",
                      Colors.orange,
                    )
                  : () => showFormDialog(),
              backgroundColor: const Color(0xFF2E7D32),
              icon: const Icon(Icons.add),
              label: const Text("Input Nilai"),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: const Color(0xFF3F51B5),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                if (isMahasiswa) _ipkChip(data),
                if (!isMahasiswa)
                  Row(
                    children: [
                      _statChip(Icons.grade, "${listNilai.length}", "Total"),
                      const SizedBox(width: 8),
                      _statChip(Icons.search, "${data.length}", "Ditampilkan"),
                    ],
                  ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => keyword = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: isMahasiswa
                        ? "Cari mata kuliah..."
                        : "Cari mahasiswa, mata kuliah...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3F51B5)),
                  )
                : data.isEmpty
                ? _buildEmpty()
                : isWide
                ? _buildTable(data)
                : _buildCardList(data),
          ),
        ],
      ),
    );
  }

  Widget _ipkChip(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _statChip(Icons.grade, "-", "IPK");
    }
    final avg =
        data.map((n) => _n(n['nilaiAkhir'])).reduce((a, b) => a + b) /
        data.length;
    return Row(
      children: [
        _statChip(Icons.menu_book, "${data.length}", "Mata Kuliah"),
        const SizedBox(width: 8),
        _statChip(Icons.grade, avg.toStringAsFixed(1), "Rata-rata"),
      ],
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> data) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFE8EAF6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  const SizedBox(width: 40, child: _H("No")),
                  const SizedBox(width: 16),
                  if (!isMahasiswa)
                    const Expanded(flex: 3, child: _H("Mahasiswa")),
                  Expanded(flex: 3, child: const _H("Mata Kuliah")),
                  const Expanded(flex: 1, child: _H("Tugas")),
                  const Expanded(flex: 1, child: _H("UTS")),
                  const Expanded(flex: 1, child: _H("UAS")),
                  const Expanded(flex: 1, child: _H("Akhir")),
                  const SizedBox(width: 60, child: _H("Grade")),
                  if (canInput) const SizedBox(width: 80, child: _H("Aksi")),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: data.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    final grade = _s(item['grade']);
                    final rowColor = i % 2 == 0
                        ? Colors.white
                        : const Color(0xFFF5F6FF);
                    return Container(
                      color: rowColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8EAF6),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${i + 1}",
                                style: const TextStyle(
                                  color: Color(0xFF3F51B5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (!isMahasiswa)
                            Expanded(
                              flex: 3,
                              child: Text(
                                _s(item['mahasiswaNama']),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              _s(item['mataKuliahNama']),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _n(item['tugas']).toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _n(item['uts']).toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _n(item['uas']).toString(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _n(item['nilaiAkhir']).toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: 60, child: _gradeBadge(grade)),
                          if (canInput)
                            SizedBox(
                              width: 80,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _aksiBtn(
                                    Icons.edit_outlined,
                                    Colors.orange,
                                    "Edit",
                                    () => showFormDialog(item: item),
                                  ),
                                  const SizedBox(width: 4),
                                  _aksiBtn(
                                    Icons.delete_outline,
                                    Colors.red,
                                    "Hapus",
                                    () => hapus(item['id'].toString()),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(List<Map<String, dynamic>> data) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final item = data[i];
        final grade = _s(item['grade']);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMahasiswa)
                            Text(
                              _s(item['mahasiswaNama']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          Text(
                            _s(item['mataKuliahNama']),
                            style: TextStyle(
                              fontSize: isMahasiswa ? 15 : 12,
                              fontWeight: isMahasiswa
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isMahasiswa
                                  ? Colors.black
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _gradeBadge(grade),
                    if (canInput) ...[
                      _aksiBtn(
                        Icons.edit_outlined,
                        Colors.orange,
                        "Edit",
                        () => showFormDialog(item: item),
                      ),
                      _aksiBtn(
                        Icons.delete_outline,
                        Colors.red,
                        "Hapus",
                        () => hapus(item['id'].toString()),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _scoreBox("Tugas", _n(item['tugas'])),
                    const SizedBox(width: 8),
                    _scoreBox("UTS", _n(item['uts'])),
                    const SizedBox(width: 8),
                    _scoreBox("UAS", _n(item['uas'])),
                    const SizedBox(width: 8),
                    _scoreBox("Akhir", _n(item['nilaiAkhir']), highlight: true),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scoreBox(String label, num value, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFF3F51B5).withOpacity(0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value is double ? value.toStringAsFixed(1) : value.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: highlight ? const Color(0xFF3F51B5) : Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradeBadge(String grade) {
    if (grade.isEmpty) return const SizedBox.shrink();
    final color = _gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        grade,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            "$val $label",
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _aksiBtn(IconData icon, Color color, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grade_outlined, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            isMahasiswa ? "Belum ada nilai" : "Belum ada data nilai",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    );
  }

  Widget _fieldNum(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _dec(label, icon),
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A237E),
        fontSize: 13,
      ),
    );
  }
}
