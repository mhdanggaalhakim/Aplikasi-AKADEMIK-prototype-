import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'presensi_dosen_page.dart'; // Menghubungkan ke halaman presensi dosen yang baru

class PenjadwalanPage extends StatefulWidget {
  final String role; // admin | dosen | mahasiswa
  final String? userId; // authUid, dipakai kalau role == dosen
  const PenjadwalanPage({super.key, required this.role, this.userId});

  @override
  State<PenjadwalanPage> createState() => _PenjadwalanPageState();
}

const List<String> _hariList = [
  "Senin",
  "Selasa",
  "Rabu",
  "Kamis",
  "Jumat",
  "Sabtu",
];

class _PenjadwalanPageState extends State<PenjadwalanPage> {
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> listJadwal = [];
  List<Map<String, dynamic>> listMataKuliah = [];
  List<Map<String, dynamic>> listDosen = [];

  bool isLoading = true;
  bool isSaving = false;
  String keyword = "";

  bool get isAdmin => widget.role == 'admin';
  bool get isDosen => widget.role == 'dosen';

  @override
  void initState() {
    super.initState();
    getData();
  }

  String _s(dynamic v) => (v ?? '').toString();

  Future<void> getData() async {
    setState(() => isLoading = true);
    try {
      final jadwalSnap = await _firestore.collection('jadwal').get();
      var jadwal = jadwalSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (isDosen && widget.userId != null) {
        jadwal = jadwal
            .where((j) => _s(j['dosenId']) == widget.userId)
            .toList();
      }

      jadwal.sort((a, b) {
        final hi = _hariList.indexOf(_s(a['hari']));
        final hj = _hariList.indexOf(_s(b['hari']));
        if (hi != hj) return hi.compareTo(hj);
        return _s(a['jamMulai']).compareTo(_s(b['jamMulai']));
      });

      if (isAdmin) {
        final mkSnap = await _firestore.collection('mata_kuliah').get();
        listMataKuliah = mkSnap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        final dosenSnap = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'dosen')
            .where('isActive', isEqualTo: true)
            .get();
        listDosen = dosenSnap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      }

      setState(() => listJadwal = jadwal);
    } catch (e) {
      _snack("Gagal mengambil data: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> get filtered {
    if (keyword.isEmpty) return listJadwal;
    return listJadwal.where((j) {
      return _s(j['mataKuliahNama']).toLowerCase().contains(keyword) ||
          _s(j['dosenNama']).toLowerCase().contains(keyword) ||
          _s(j['ruang']).toLowerCase().contains(keyword) ||
          _s(j['hari']).toLowerCase().contains(keyword);
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

  // ══════════════════════════════════════════════
  // LOGIKA WAKTU (STRICT TIME)
  // ══════════════════════════════════════════════
  int _hariToInt(String hari) {
    switch (hari.toLowerCase()) {
      case 'senin':
        return 1;
      case 'selasa':
        return 2;
      case 'rabu':
        return 3;
      case 'kamis':
        return 4;
      case 'jumat':
        return 5;
      case 'sabtu':
        return 6;
      case 'minggu':
        return 7;
      default:
        return 0;
    }
  }

  bool _isSesiAktif(String hari, String jamMulai, String jamSelesai) {
    final now = DateTime.now();

    // 1. Cek matching hari saat ini dengan jadwal
    if (now.weekday != _hariToInt(hari)) return false;

    try {
      // Menangani variasi pemisah waktu baik menggunakan titik (.) maupun titik dua (:)
      final startStr = jamMulai.replaceAll('.', ':');
      final endStr = jamSelesai.replaceAll('.', ':');

      final startParts = startStr.split(':');
      final endParts = endStr.split(':');

      final startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMin = int.parse(endParts[1]);

      final startTime = DateTime(
        now.year,
        now.month,
        now.day,
        startHour,
        startMin,
      );
      final endTime = DateTime(now.year, now.month, now.day, endHour, endMin);

      // Sesi aktif jika waktu sekarang berada di dalam rentang jam tersebut
      return (now.isAfter(startTime) || now.isAtSameMomentAs(startTime)) &&
          (now.isBefore(endTime) || now.isAtSameMomentAs(endTime));
    } catch (e) {
      return false;
    }
  }

  // Navigasi masuk ke PresensiDosenPage dengan menyertakan ID dan Nama MK
  void _mulaiSesi(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PresensiDosenPage(
          mataKuliahId: _s(item['mataKuliahId']),
          mataKuliahNama: _s(item['mataKuliahNama']),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAMBAH / EDIT JADWAL (Admin Only)
  // ══════════════════════════════════════════════
  void showFormDialog({Map<String, dynamic>? item}) {
    final isEdit = item != null;
    String? selectedMkId = isEdit ? _s(item['mataKuliahId']) : null;
    String? selectedDosenId = isEdit ? _s(item['dosenId']) : null;
    String selectedHari = isEdit ? _s(item['hari']) : _hariList.first;
    final cJamMulai = TextEditingController(
      text: isEdit ? _s(item['jamMulai']) : '',
    );
    final cJamSelesai = TextEditingController(
      text: isEdit ? _s(item['jamSelesai']) : '',
    );
    final cRuang = TextEditingController(text: isEdit ? _s(item['ruang']) : '');

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
                          color: const Color(0xFF3F51B5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEdit ? "Edit Jadwal" : "Tambah Jadwal",
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
                      initialValue: selectedMkId,
                      decoration: _dec("Mata Kuliah", Icons.menu_book),
                      items: listMataKuliah.map((mk) {
                        return DropdownMenuItem(
                          value: mk['id'].toString(),
                          child: Text(
                            "${_s(mk['kodeMk'])} - ${_s(mk['namaMk'])}",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedMkId = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedDosenId,
                      decoration: _dec("Dosen Pengampu", Icons.school),
                      items: listDosen.map((d) {
                        return DropdownMenuItem(
                          value: d['id'].toString(),
                          child: Text(
                            _s(d['nama']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedDosenId = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedHari,
                      decoration: _dec("Hari", Icons.calendar_today),
                      items: _hariList
                          .map(
                            (h) => DropdownMenuItem(value: h, child: Text(h)),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(
                        () => selectedHari = v ?? _hariList.first,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            cJamMulai,
                            "Jam Mulai (08:00)",
                            Icons.access_time,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            cJamSelesai,
                            "Jam Selesai (10:00)",
                            Icons.access_time_filled,
                          ),
                        ),
                      ],
                    ),
                    _field(cRuang, "Ruang", Icons.room),

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
                                  if (selectedMkId == null ||
                                      selectedDosenId == null) {
                                    _snack(
                                      "Mata kuliah & dosen wajib dipilih",
                                      Colors.orange,
                                    );
                                    return;
                                  }
                                  setDialogState(() => isSaving = true);
                                  final mk = listMataKuliah.firstWhere(
                                    (m) => m['id'] == selectedMkId,
                                  );
                                  final dosen = listDosen.firstWhere(
                                    (d) => d['id'] == selectedDosenId,
                                  );

                                  final ok = isEdit
                                      ? await update(
                                          id: item['id'].toString(),
                                          mkId: selectedMkId!,
                                          mkNama: _s(mk['namaMk']),
                                          dosenId: selectedDosenId!,
                                          dosenNama: _s(dosen['nama']),
                                          hari: selectedHari,
                                          jamMulai: cJamMulai.text.trim(),
                                          jamSelesai: cJamSelesai.text.trim(),
                                          ruang: cRuang.text.trim(),
                                        )
                                      : await tambah(
                                          mkId: selectedMkId!,
                                          mkNama: _s(mk['namaMk']),
                                          dosenId: selectedDosenId!,
                                          dosenNama: _s(dosen['nama']),
                                          hari: selectedHari,
                                          jamMulai: cJamMulai.text.trim(),
                                          jamSelesai: cJamSelesai.text.trim(),
                                          ruang: cRuang.text.trim(),
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

  Future<bool> tambah({
    required String mkId,
    required String mkNama,
    required String dosenId,
    required String dosenNama,
    required String hari,
    required String jamMulai,
    required String jamSelesai,
    required String ruang,
  }) async {
    if (jamMulai.isEmpty || jamSelesai.isEmpty || ruang.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return false;
    }
    try {
      await _firestore.collection('jadwal').add({
        'mataKuliahId': mkId,
        'mataKuliahNama': mkNama,
        'dosenId': dosenId,
        'dosenNama': dosenNama,
        'hari': hari,
        'jamMulai': jamMulai,
        'jamSelesai': jamSelesai,
        'ruang': ruang,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack("Jadwal berhasil ditambahkan", Colors.green);
      getData();
      return true;
    } catch (e) {
      _snack("Error: $e", Colors.red);
      return false;
    }
  }

  Future<bool> update({
    required String id,
    required String mkId,
    required String mkNama,
    required String dosenId,
    required String dosenNama,
    required String hari,
    required String jamMulai,
    required String jamSelesai,
    required String ruang,
  }) async {
    if (jamMulai.isEmpty || jamSelesai.isEmpty || ruang.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return false;
    }
    try {
      await _firestore.collection('jadwal').doc(id).update({
        'mataKuliahId': mkId,
        'mataKuliahNama': mkNama,
        'dosenId': dosenId,
        'dosenNama': dosenNama,
        'hari': hari,
        'jamMulai': jamMulai,
        'jamSelesai': jamSelesai,
        'ruang': ruang,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack("Jadwal berhasil diupdate", Colors.green);
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
            content: const Text("Yakin ingin menghapus jadwal ini?"),
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
      await _firestore.collection('jadwal').doc(id).delete();
      _snack("Jadwal berhasil dihapus", Colors.green);
      getData();
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = filtered;
    final title = isDosen
        ? "Jadwal Mengajar"
        : (isAdmin ? "Penjadwalan Kuliah" : "Jadwal Kuliah");

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
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: listMataKuliah.isEmpty || listDosen.isEmpty
                  ? () => _snack(
                      "Tambahkan Mata Kuliah & Dosen dulu sebelum membuat jadwal",
                      Colors.orange,
                    )
                  : () => showFormDialog(),
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white, // Teks dan Icon menjadi putih
              icon: const Icon(Icons.add),
              label: const Text("Tambah Jadwal"),
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
                    _statChip(
                      Icons.event_note,
                      "${listJadwal.length}",
                      "Total",
                    ),
                    const SizedBox(width: 8),
                    _statChip(Icons.search, "${data.length}", "Ditampilkan"),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => keyword = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Cari mata kuliah, dosen, ruang, hari...",
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
                : _buildList(data),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> data) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in data) {
      final hari = _s(item['hari']);
      grouped.putIfAbsent(hari, () => []).add(item);
    }
    final hariOrder = _hariList.where((h) => grouped.containsKey(h)).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: hariOrder.length,
      itemBuilder: (_, i) {
        final hari = hariOrder[i];
        final items = grouped[hari]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hari,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...items.map((item) => _jadwalCard(item)),
            ],
          ),
        );
      },
    );
  }

  Widget _jadwalCard(Map<String, dynamic> item) {
    final bool isAktif = _isSesiAktif(
      _s(item['hari']),
      _s(item['jamMulai']),
      _s(item['jamSelesai']),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F51B5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book, color: Color(0xFF3F51B5)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _s(item['mataKuliahNama']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 13,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${_s(item['jamMulai'])} - ${_s(item['jamSelesai'])}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.room,
                            size: 13,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _s(item['ruang']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.school,
                            size: 13,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _s(item['dosenNama']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  Row(
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
              ],
            ),
          ),

          // FOOTER DOSEN: AKTIF TOMBOL JIKA WAKTU DAN HARI SESUAI
          if (isDosen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAktif ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isAktif
                          ? "Sesi kuliah sedang berlangsung"
                          : "Sesi hanya bisa dibuka sesuai hari & jam jadwal",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isAktif
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontWeight: isAktif
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: isAktif ? () => _mulaiSesi(item) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAktif
                            ? const Color(0xFF3F51B5)
                            : Colors.grey.shade300,
                        foregroundColor: isAktif
                            ? Colors.white
                            : Colors.grey.shade500,
                        elevation: isAktif ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: Icon(
                        Icons.play_circle_fill,
                        size: 16,
                        color: isAktif ? Colors.white : Colors.grey.shade500,
                      ),
                      label: Text(
                        "Mulai Sesi",
                        style: TextStyle(
                          fontSize: 12,
                          color: isAktif ? Colors.white : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
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
          Icon(Icons.event_busy, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            isAdmin ? "Belum ada jadwal kuliah" : "Belum ada jadwal untuk kamu",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF3F51B5)),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: c, decoration: _dec(label, icon)),
    );
  }
}
