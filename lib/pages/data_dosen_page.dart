import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataDosenPage extends StatefulWidget {
  final String role;
  const DataDosenPage({super.key, required this.role});

  @override
  State<DataDosenPage> createState() => _DataDosenPageState();
}

class _DataDosenPageState extends State<DataDosenPage> {
  final _firestore = FirebaseFirestore.instance;
  static const String _dosenEmailDomain = 'dosen.app';

  List<Map<String, dynamic>> listDosen = [];
  bool isLoading = true;
  bool isSaving  = false;
  String keyword = "";

  @override
  void initState() {
    super.initState();
    getDosen();
  }

  Future<void> getDosen() async {
    setState(() => isLoading = true);
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'dosen')
          .where('isActive', isEqualTo: true)
          .get();

      final docs = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      docs.sort((a, b) {
        final tsA = a['createdAt'];
        final tsB = b['createdAt'];
        if (tsA == null || tsB == null) return 0;
        return (tsA as Timestamp).compareTo(tsB as Timestamp);
      });

      setState(() => listDosen = docs);
    } catch (e) {
      _snack("Gagal mengambil data: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> get filtered {
    if (keyword.isEmpty) return listDosen;
    return listDosen.where((item) {
      return _s(item['nip']).toLowerCase().contains(keyword) ||
             _s(item['nama']).toLowerCase().contains(keyword) ||
             _s(item['bidangKeahlian']).toLowerCase().contains(keyword);
    }).toList();
  }

  String _s(dynamic v) => (v ?? '').toString();
  String _initial(dynamic name) {
    final s = (name ?? '').toString().trim();
    return s.isEmpty ? '?' : s[0].toUpperCase();
  }

  String _defaultPassword(String nip) {
    return nip.length < 6 ? nip.padLeft(6, '0') : nip;
  }

  Future<UserCredential> _createAuthAccountWithoutSignIn({
    required String email,
    required String password,
  }) async {
    final tempApp = await Firebase.initializeApp(
      name: 'tempApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final cred = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await tempAuth.signOut();
      return cred;
    } finally {
      await tempApp.delete();
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ));
  }

  // ══════════════════════════════════════════════
  // TAMBAH DOSEN (+ auto buat akun, NIP = username & password)
  // ══════════════════════════════════════════════
  void showAddDialog() {
    final cNip     = TextEditingController();
    final cNama    = TextEditingController();
    final cBidang  = TextEditingController();
    final cAlamat  = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.person_add, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text("Tambah Dosen",
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E))),
                    ]),
                    const Divider(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Akun login dosen otomatis dibuat. Username & password default = NIP.",
                        style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900),
                      ),
                    ),
                    _field(cNip, "NIP (jadi username & password)", Icons.badge),
                    _field(cNama, "Nama", Icons.person_outline),
                    _field(cBidang, "Bidang Keahlian", Icons.school),
                    _fieldMulti(cAlamat, "Alamat", Icons.home_outlined),
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
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() => isSaving = true);
                                  final ok = await tambahDosen(
                                    nip:    cNip.text.trim(),
                                    nama:   cNama.text.trim(),
                                    bidang: cBidang.text.trim(),
                                    alamat: cAlamat.text.trim(),
                                  );
                                  setDialogState(() => isSaving = false);
                                  if (ok && dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                },
                          icon: isSaving
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
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

  Future<bool> tambahDosen({
    required String nip,
    required String nama,
    required String bidang,
    required String alamat,
  }) async {
    if (nip.isEmpty || nama.isEmpty || bidang.isEmpty || alamat.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return false;
    }
    try {
      final nipCheck = await _firestore
          .collection('users')
          .where('nip', isEqualTo: nip)
          .limit(1)
          .get();
      if (nipCheck.docs.isNotEmpty) {
        _snack("NIP sudah terdaftar", Colors.red);
        return false;
      }

      final email    = "$nip@$_dosenEmailDomain";
      final password = _defaultPassword(nip);

      final cred = await _createAuthAccountWithoutSignIn(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(cred.user!.uid).set({
        'nip':            nip,
        'nama':           nama,
        'bidangKeahlian': bidang,
        'alamat':         alamat,
        'username':       nip,
        'email':          email,
        'role':           'dosen',
        'isActive':       true,
        'hasAccount':     true,
        'authUid':        cred.user!.uid,
        'createdAt':      FieldValue.serverTimestamp(),
        'updatedAt':      FieldValue.serverTimestamp(),
      });

      _snack("Dosen ditambahkan. Username: $nip | Password: $password",
          Colors.green);
      getDosen();
      return true;
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'email-already-in-use'
          ? 'NIP ini sudah pernah dipakai untuk membuat akun'
          : e.code == 'weak-password'
              ? 'Password (NIP) terlalu lemah'
              : 'Gagal membuat akun: ${e.message}';
      _snack(msg, Colors.red);
      return false;
    } catch (e) {
      _snack("Error: $e", Colors.red);
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // EDIT & HAPUS
  // ══════════════════════════════════════════════
  void showEditDialog(Map<String, dynamic> item) {
    final eNama   = TextEditingController(text: _s(item['nama']));
    final eBidang = TextEditingController(text: _s(item['bidangKeahlian']));
    final eAlamat = TextEditingController(text: _s(item['alamat']));

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.edit, color: Color(0xFF3F51B5)),
                    SizedBox(width: 8),
                    Text("Edit Data Dosen",
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E))),
                  ]),
                  const Divider(height: 20),
                  TextField(
                    readOnly: true,
                    controller: TextEditingController(text: _s(item['nip'])),
                    decoration: InputDecoration(
                      labelText: "NIP / Username (tidak bisa diubah)",
                      prefixIcon: const Icon(Icons.badge, color: Colors.grey),
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(eNama,   "Nama",            Icons.person_outline),
                  _field(eBidang, "Bidang Keahlian", Icons.school),
                  _fieldMulti(eAlamat, "Alamat",      Icons.home_outlined),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Batal"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F51B5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await update(
                            id:     item['id'].toString(),
                            nama:   eNama.text.trim(),
                            bidang: eBidang.text.trim(),
                            alamat: eAlamat.text.trim(),
                          );
                        },
                        icon: const Icon(Icons.save, size: 16),
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
    );
  }

  Future<void> update({
    required String id,
    required String nama,
    required String bidang,
    required String alamat,
  }) async {
    if (nama.isEmpty || bidang.isEmpty || alamat.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return;
    }
    try {
      await _firestore.collection('users').doc(id).update({
        'nama':           nama,
        'bidangKeahlian': bidang,
        'alamat':         alamat,
        'updatedAt':      FieldValue.serverTimestamp(),
      });
      _snack("Data berhasil diupdate", Colors.green);
      getDosen();
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
  }

  Future<void> hapus(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text("Konfirmasi Hapus"),
        ]),
        content: const Text("Yakin ingin menghapus data dosen ini?"),
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
    ) ?? false;

    if (!ok) return;
    try {
      await _firestore.collection('users').doc(id).update({
        'isActive':  false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack("Data berhasil dihapus", Colors.green);
      getDosen();
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide  = MediaQuery.of(context).size.width >= 800;
    final isAdmin = widget.role == 'admin';
    final data    = filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        title: const Text("Data Dosen"),
        elevation: 0,
        actions: [
          IconButton(onPressed: getDosen, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: showAddDialog,
              backgroundColor: const Color(0xFF3F51B5),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text("Tambah Dosen"),
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
                    _statChip(Icons.people, "${listDosen.length}", "Total"),
                    const SizedBox(width: 8),
                    _statChip(Icons.search, "${data.length}", "Ditampilkan"),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => keyword = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Cari nama, NIP, bidang keahlian...",
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
                    child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
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
                  const Text("Daftar Dosen",
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text("${data.length} dosen",
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                  const Expanded(flex: 2, child: _H("NIP")),
                  const Expanded(flex: 3, child: _H("Nama")),
                  const Expanded(flex: 3, child: _H("Bidang Keahlian")),
                  const Expanded(flex: 3, child: _H("Alamat")),
                  if (isAdmin) const SizedBox(width: 80, child: _H("Aksi")),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: data.asMap().entries.map((e) {
                    final i    = e.key;
                    final item = e.value;
                    final rowColor = i % 2 == 0 ? Colors.white : const Color(0xFFF5F6FF);
                    return Container(
                      color: rowColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Container(
                              width: 28, height: 28,
                              decoration: const BoxDecoration(
                                  color: Color(0xFFE8EAF6), shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text("${i + 1}",
                                  style: const TextStyle(
                                      color: Color(0xFF3F51B5),
                                      fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(_s(item['nip']),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Color(0xFF3F51B5),
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: const Color(0xFF3F51B5).withOpacity(0.12),
                                child: Text(_initial(item['nama']),
                                    style: const TextStyle(
                                        color: Color(0xFF3F51B5),
                                        fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(_s(item['nama']),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ]),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(_s(item['bidangKeahlian']),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(_s(item['alamat']),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          if (isAdmin)
                            SizedBox(
                              width: 80,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _aksiBtn(Icons.edit_outlined, Colors.orange,
                                      "Edit", () => showEditDialog(item)),
                                  const SizedBox(width: 4),
                                  _aksiBtn(Icons.delete_outline, Colors.red,
                                      "Hapus", () => hapus(item['id'].toString())),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF3F51B5),
                      child: Text(_initial(item['nama']),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_s(item['nama']),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    if (isAdmin) ...[
                      _aksiBtn(Icons.edit_outlined, Colors.orange, "Edit",
                          () => showEditDialog(item)),
                      _aksiBtn(Icons.delete_outline, Colors.red, "Hapus",
                          () => hapus(item['id'].toString())),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _cardRow(Icons.badge, "NIP", _s(item['nip'])),
                _cardRow(Icons.school, "Bidang", _s(item['bidangKeahlian'])),
                _cardRow(Icons.home_outlined, "Alamat", _s(item['alamat'])),
              ],
            ),
          ),
        );
      },
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
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const Text(": ", style: TextStyle(color: Colors.grey, fontSize: 12)),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 13))),
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
            keyword.isEmpty ? "Belum ada data dosen" : "Data tidak ditemukan",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF3F51B5)),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      ),
    );
  }

  Widget _fieldMulti(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF3F51B5)),
          alignLabelWithHint: true,
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10))),
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
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 13));
  }
}