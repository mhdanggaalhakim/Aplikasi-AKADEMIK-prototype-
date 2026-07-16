import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MataKuliahPage extends StatefulWidget {
  final String role;
  const MataKuliahPage({super.key, required this.role});

  @override
  State<MataKuliahPage> createState() => _MataKuliahPageState();
}

class _MataKuliahPageState extends State<MataKuliahPage> {
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> listMk = [];
  bool isLoading = true;
  bool isSaving = false;
  String keyword = "";

  @override
  void initState() {
    super.initState();
    getMataKuliah();
  }

  Future<void> getMataKuliah() async {
    setState(() => isLoading = true);
    try {
      final snap = await _firestore.collection('mata_kuliah').get();
      final docs = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      docs.sort((a, b) => _s(a['kodeMk']).compareTo(_s(b['kodeMk'])));
      setState(() => listMk = docs);
    } catch (e) {
      _snack("Gagal mengambil data: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> get filtered {
    if (keyword.isEmpty) return listMk;
    return listMk.where((item) {
      return _s(item['kodeMk']).toLowerCase().contains(keyword) ||
          _s(item['namaMk']).toLowerCase().contains(keyword);
    }).toList();
  }

  String _s(dynamic v) => (v ?? '').toString();

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

  // ══════════════════════════════════════════════
  // TAMBAH / EDIT (dialog sama, beda mode)
  // ══════════════════════════════════════════════
  void showFormDialog({Map<String, dynamic>? item}) {
    final isEdit = item != null;
    final cKode = TextEditingController(text: isEdit ? _s(item['kodeMk']) : '');
    final cNama = TextEditingController(text: isEdit ? _s(item['namaMk']) : '');
    final cSks = TextEditingController(text: isEdit ? _s(item['sks']) : '');
    final cSemester = TextEditingController(
      text: isEdit ? _s(item['semester']) : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
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
                          color: const Color(0xFF3F51B5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEdit ? "Edit Mata Kuliah" : "Tambah Mata Kuliah",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _field(
                      cKode,
                      "Kode Mata Kuliah",
                      Icons.qr_code,
                      readOnly: isEdit,
                    ),
                    _field(cNama, "Nama Mata Kuliah", Icons.menu_book),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            cSks,
                            "SKS",
                            Icons.numbers,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            cSemester,
                            "Semester",
                            Icons.event_note,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
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
                            backgroundColor: const Color(0xFF3F51B5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() => isSaving = true);
                                  final ok = isEdit
                                      ? await update(
                                          id: item['id'].toString(),
                                          nama: cNama.text.trim(),
                                          sks: cSks.text.trim(),
                                          semester: cSemester.text.trim(),
                                        )
                                      : await tambah(
                                          kode: cKode.text.trim(),
                                          nama: cNama.text.trim(),
                                          sks: cSks.text.trim(),
                                          semester: cSemester.text.trim(),
                                        );
                                  setDialogState(() => isSaving = false);
                                  if (ok && dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
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

  Future<bool> tambah({
    required String kode,
    required String nama,
    required String sks,
    required String semester,
  }) async {
    if (kode.isEmpty || nama.isEmpty || sks.isEmpty || semester.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return false;
    }
    final sksInt = int.tryParse(sks);
    final semesterInt = int.tryParse(semester);
    if (sksInt == null || semesterInt == null) {
      _snack("SKS & Semester harus berupa angka", Colors.orange);
      return false;
    }
    try {
      final check = await _firestore
          .collection('mata_kuliah')
          .where('kodeMk', isEqualTo: kode)
          .limit(1)
          .get();
      if (check.docs.isNotEmpty) {
        _snack("Kode mata kuliah sudah dipakai", Colors.red);
        return false;
      }

      await _firestore.collection('mata_kuliah').add({
        'kodeMk': kode,
        'namaMk': nama,
        'sks': sksInt,
        'semester': semesterInt,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _snack("Mata kuliah berhasil ditambahkan", Colors.green);
      getMataKuliah();
      return true;
    } catch (e) {
      _snack("Error: $e", Colors.red);
      return false;
    }
  }

  Future<bool> update({
    required String id,
    required String nama,
    required String sks,
    required String semester,
  }) async {
    if (nama.isEmpty || sks.isEmpty || semester.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return false;
    }
    final sksInt = int.tryParse(sks);
    final semesterInt = int.tryParse(semester);
    if (sksInt == null || semesterInt == null) {
      _snack("SKS & Semester harus berupa angka", Colors.orange);
      return false;
    }
    try {
      await _firestore.collection('mata_kuliah').doc(id).update({
        'namaMk': nama,
        'sks': sksInt,
        'semester': semesterInt,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack("Mata kuliah berhasil diupdate", Colors.green);
      getMataKuliah();
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
            content: const Text(
              "Yakin ingin menghapus mata kuliah ini? Data jadwal/KRS/nilai "
              "yang terkait mata kuliah ini tidak akan otomatis terhapus.",
            ),
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
      await _firestore.collection('mata_kuliah').doc(id).delete();
      _snack("Mata kuliah berhasil dihapus", Colors.green);
      getMataKuliah();
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final isAdmin = widget.role == 'admin';
    final data = filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        title: const Text("Data Mata Kuliah"),
        elevation: 0,
        actions: [
          IconButton(onPressed: getMataKuliah, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => showFormDialog(),
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor:
                  Colors.white, // <-- Tambahan untuk warna teks dan ikon putih
              icon: const Icon(Icons.add),
              label: const Text("Tambah MK"),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: const Color(0xFF3F51B5),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    _statChip(Icons.menu_book, "${listMk.length}", "Total"),
                    const SizedBox(width: 8),
                    _statChip(Icons.search, "${data.length}", "Ditampilkan"),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => keyword = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Cari kode atau nama mata kuliah...",
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
                ? _buildTable(data, isAdmin)
                : _buildCardList(data, isAdmin),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> data, bool isAdmin) {
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              color: const Color(0xFF1A237E),
              child: Row(
                children: [
                  const Icon(Icons.table_chart, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    "Daftar Mata Kuliah",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${data.length} mata kuliah",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFE8EAF6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  const SizedBox(width: 40, child: _H("No")),
                  const SizedBox(width: 16),
                  const Expanded(flex: 2, child: _H("Kode")),
                  const Expanded(flex: 4, child: _H("Nama Mata Kuliah")),
                  const Expanded(flex: 1, child: _H("SKS")),
                  const Expanded(flex: 2, child: _H("Semester")),
                  if (isAdmin) const SizedBox(width: 80, child: _H("Aksi")),
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
                          Expanded(
                            flex: 2,
                            child: Text(
                              _s(item['kodeMk']),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF3F51B5),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              _s(item['namaMk']),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              _s(item['sks']),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _semesterBadge(_s(item['semester'])),
                            ),
                          ),
                          if (isAdmin)
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

  Widget _buildCardList(List<Map<String, dynamic>> data, bool isAdmin) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final item = data[i];
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F51B5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _s(item['kodeMk']),
                        style: const TextStyle(
                          color: Color(0xFF3F51B5),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _s(item['namaMk']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isAdmin) ...[
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
                _cardRow(Icons.numbers, "SKS", _s(item['sks'])),
                _cardRow(Icons.event_note, "Semester", _s(item['semester'])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _semesterBadge(String semester) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3F51B5).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3F51B5).withOpacity(0.3)),
      ),
      child: Text(
        "Semester $semester",
        style: const TextStyle(
          color: Color(0xFF3F51B5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
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

  Widget _cardRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF3F51B5)),
          const SizedBox(width: 6),
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const Text(": ", style: TextStyle(color: Colors.grey, fontSize: 12)),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
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
            keyword.isEmpty
                ? "Belum ada data mata kuliah"
                : "Data tidak ditemukan",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF3F51B5)),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade100 : null,
        ),
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
