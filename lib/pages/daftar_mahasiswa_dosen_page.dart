import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DaftarMahasiswaDosenPage extends StatefulWidget {
  final String userId; // authUid dosen yang sedang login
  const DaftarMahasiswaDosenPage({super.key, required this.userId});

  @override
  State<DaftarMahasiswaDosenPage> createState() => _DaftarMahasiswaDosenPageState();
}

class _DaftarMahasiswaDosenPageState extends State<DaftarMahasiswaDosenPage> {
  final _firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  String keyword = "";

  // Struktur: [{ mkId, mkNama, mahasiswa: [{id, nim, nama, jurusan}, ...] }, ...]
  List<Map<String, dynamic>> listPerMk = [];
  int totalMahasiswaUnik = 0;

  @override
  void initState() {
    super.initState();
    getData();
  }

  String _s(dynamic v) => (v ?? '').toString();

  String _initial(dynamic name) {
    final s = (name ?? '').toString().trim();
    return s.isEmpty ? '?' : s[0].toUpperCase();
  }

  Future<void> getData() async {
    setState(() => isLoading = true);
    try {
      // 1. Ambil semua mata kuliah yang diampu dosen ini (dari jadwal)
      final jadwalSnap = await _firestore
          .collection('jadwal')
          .where('dosenId', isEqualTo: widget.userId)
          .get();

      final Map<String, String> mkMap = {}; // mkId -> namaMk
      for (var doc in jadwalSnap.docs) {
        final d = doc.data();
        final mkId = _s(d['mataKuliahId']);
        if (mkId.isNotEmpty) {
          mkMap[mkId] = _s(d['mataKuliahNama']);
        }
      }

      if (mkMap.isEmpty) {
        setState(() {
          listPerMk = [];
          totalMahasiswaUnik = 0;
        });
        setState(() => isLoading = false);
        return;
      }

      // 2. Ambil KRS berstatus 'disetujui' untuk tiap mata kuliah tsb
      final Map<String, List<Map<String, dynamic>>> mhsPerMk = {};
      for (var mkId in mkMap.keys) {
        final krsSnap = await _firestore
            .collection('krs')
            .where('mataKuliahId', isEqualTo: mkId)
            .where('status', isEqualTo: 'disetujui')
            .get();

        mhsPerMk[mkId] = krsSnap.docs.map((doc) {
          final d = doc.data();
          return {
            'mahasiswaId':   _s(d['mahasiswaId']),
            'mahasiswaNama': _s(d['mahasiswaNama']),
          };
        }).toList();
      }

      // 3. Kumpulkan semua mahasiswaId unik, lalu ambil detail (NIM, Jurusan)
      final Set<String> mhsIdsUnik = {};
      for (var list in mhsPerMk.values) {
        for (var m in list) {
          if (_s(m['mahasiswaId']).isNotEmpty) mhsIdsUnik.add(_s(m['mahasiswaId']));
        }
      }

      final Map<String, Map<String, dynamic>> detailMhs = {};
      final idsList = mhsIdsUnik.toList();
      // Firestore whereIn maksimal 10 item per query, jadi dipecah per 10
      for (var i = 0; i < idsList.length; i += 10) {
        final chunk = idsList.sublist(i, i + 10 > idsList.length ? idsList.length : i + 10);
        if (chunk.isEmpty) continue;
        final usersSnap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (var doc in usersSnap.docs) {
          detailMhs[doc.id] = doc.data();
        }
      }

      // 4. Susun struktur final per mata kuliah, urut nama mahasiswa
      final hasil = mkMap.entries.map((e) {
        final mkId   = e.key;
        final mkNama = e.value;
        final mhsList = (mhsPerMk[mkId] ?? []).map((m) {
          final detail = detailMhs[_s(m['mahasiswaId'])] ?? {};
          return {
            'id':      _s(m['mahasiswaId']),
            'nama':    _s(detail['nama']).isNotEmpty ? _s(detail['nama']) : _s(m['mahasiswaNama']),
            'nim':     _s(detail['nim']),
            'jurusan': _s(detail['jurusan']),
          };
        }).toList();
        mhsList.sort((a, b) => _s(a['nama']).compareTo(_s(b['nama'])));
        return {
          'mkId':   mkId,
          'mkNama': mkNama.isEmpty ? "(Tanpa nama mata kuliah)" : mkNama,
          'mahasiswa': mhsList,
        };
      }).toList();

      hasil.sort((a, b) => _s(a['mkNama']).compareTo(_s(b['mkNama'])));

      setState(() {
        listPerMk = hasil;
        totalMahasiswaUnik = mhsIdsUnik.length;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Gagal mengambil data: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  // Hasil filter pencarian: tetap dikelompokkan per mata kuliah,
  // tapi hanya menampilkan mahasiswa yang cocok keyword.
  List<Map<String, dynamic>> get _filtered {
    if (keyword.isEmpty) return listPerMk;
    return listPerMk.map((mk) {
      final mhsList = (mk['mahasiswa'] as List<Map<String, dynamic>>).where((m) {
        return _s(m['nama']).toLowerCase().contains(keyword) ||
               _s(m['nim']).toLowerCase().contains(keyword) ||
               _s(m['jurusan']).toLowerCase().contains(keyword);
      }).toList();
      return {
        'mkId':   mk['mkId'],
        'mkNama': mk['mkNama'],
        'mahasiswa': mhsList,
      };
    }).where((mk) => (mk['mahasiswa'] as List).isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _filtered;
    final adaMataKuliah = listPerMk.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        title: const Text("Daftar Mahasiswa"),
        elevation: 0,
        actions: [
          IconButton(onPressed: getData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF3F51B5),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    _statChip(Icons.menu_book, "${listPerMk.length}", "Mata Kuliah"),
                    const SizedBox(width: 8),
                    _statChip(Icons.people, "$totalMahasiswaUnik", "Mahasiswa"),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => keyword = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Cari nama, NIM, atau jurusan mahasiswa...",
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
                : !adaMataKuliah
                    ? _buildEmpty(
                        "Kamu belum ditugaskan mengajar mata kuliah apapun.\nCek menu Jadwal Mengajar / hubungi admin.")
                    : data.isEmpty
                        ? _buildEmpty(keyword.isEmpty
                            ? "Belum ada mahasiswa dengan KRS disetujui\nuntuk mata kuliah yang kamu ampu."
                            : "Tidak ada mahasiswa yang cocok dengan pencarian.")
                        : _buildList(data),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> data) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final mk = data[i];
        final mhsList = mk['mahasiswa'] as List<Map<String, dynamic>>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(_s(mk['mkNama']),
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text("${mhsList.length} mahasiswa",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: mhsList.asMap().entries.map((e) {
                    final idx = e.key;
                    final m   = e.value;
                    return Container(
                      color: idx % 2 == 0 ? Colors.white : const Color(0xFFF5F6FF),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF3F51B5).withOpacity(0.12),
                          child: Text(_initial(m['nama']),
                              style: const TextStyle(
                                  color: Color(0xFF3F51B5), fontWeight: FontWeight.bold)),
                        ),
                        title: Text(_s(m['nama']).isEmpty ? "-" : _s(m['nama']),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                            "${_s(m['nim']).isEmpty ? '-' : _s(m['nim'])}"
                            "${_s(m['jurusan']).isEmpty ? '' : ' • ${_s(m['jurusan'])}'}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 70, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
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
          Text("$val $label", style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}