import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final _firestore = FirebaseFirestore.instance;
  static const String _mahasiswaEmailDomain = 'mahasiswa.app';
  static const String _dosenEmailDomain = 'dosen.app';

  List<Map<String, dynamic>> listUser = [];
  bool isLoading = true;
  bool isSaving = false;
  String keyword = "";
  String filterRole = "semua"; // semua | admin | dosen | mahasiswa

  @override
  void initState() {
    super.initState();
    getUsers();
  }

  Future<void> getUsers() async {
    setState(() => isLoading = true);
    try {
      final snap = await _firestore.collection('users').get();
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

      setState(() => listUser = docs);
    } catch (e) {
      _snack("Gagal mengambil data: $e", Colors.redAccent);
    }
    setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> get filtered {
    var data = listUser;
    if (filterRole != "semua") {
      data = data.where((u) => _s(u['role']) == filterRole).toList();
    }
    if (keyword.isNotEmpty) {
      data = data.where((u) {
        return _s(u['nama']).toLowerCase().contains(keyword) ||
            _s(u['username']).toLowerCase().contains(keyword) ||
            _s(u['email']).toLowerCase().contains(keyword);
      }).toList();
    }
    return data;
  }

  String _s(dynamic v) => (v ?? '').toString();
  String _initial(dynamic name) {
    final s = (name ?? '').toString().trim();
    return s.isEmpty ? '?' : s[0].toUpperCase();
  }

  String _defaultPassword(String id) {
    return id.length < 6 ? id.padLeft(6, '0') : id;
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
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

  // ══════════════════════════════════════════════
  // TOGGLE AKTIF / NONAKTIF
  // ══════════════════════════════════════════════
  Future<void> toggleActive(Map<String, dynamic> item) async {
    final newStatus = !(item['isActive'] == true);
    try {
      await _firestore.collection('users').doc(item['id'].toString()).update({
        'isActive': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack(newStatus ? "Akun diaktifkan" : "Akun dinonaktifkan", Colors.green);
      getUsers();
    } catch (e) {
      _snack("Error: $e", Colors.redAccent);
    }
  }

  // ══════════════════════════════════════════════
  // PILIH MAU TAMBAH DOSEN ATAU MAHASISWA
  // ══════════════════════════════════════════════
  void showAddChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Tambah Akun Baru",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            const SizedBox(height: 16),
            _buildChoiceTile(
              icon: Icons.school,
              color: const Color(0xFF00897B),
              title: "Tambah Dosen",
              subtitle: "Username & password default = NIP",
              onTap: () {
                Navigator.pop(context);
                showAddDosenDialog();
              },
            ),
            const SizedBox(height: 12),
            _buildChoiceTile(
              icon: Icons.person,
              color: const Color(0xFF3F51B5),
              title: "Tambah Mahasiswa",
              subtitle: "Username & password default = NIM",
              onTap: () {
                Navigator.pop(context);
                showAddMahasiswaDialog();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: Border.all(color: color.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // DIALOG TAMBAH DOSEN & MAHASISWA
  // ══════════════════════════════════════════════
  void showAddDosenDialog() {
    final cNip = TextEditingController();
    final cNama = TextEditingController();
    final cBidang = TextEditingController();
    final cAlamat = TextEditingController();
    _showAddDialog(
      title: "Tambah Dosen",
      icon: Icons.person_add,
      color: const Color(0xFF00897B),
      hint: "Username & password default otomatis menggunakan NIP.",
      fields: [
        _field(cNip, "NIP", Icons.badge),
        _field(cNama, "Nama Lengkap", Icons.person_outline),
        _field(cBidang, "Bidang Keahlian", Icons.school),
        _fieldMulti(cAlamat, "Alamat Lengkap", Icons.home_outlined),
      ],
      onSave: (setDialogState, ctx) async {
        setDialogState(() => isSaving = true);
        final ok = await tambahDosen(nip: cNip.text.trim(), nama: cNama.text.trim(), bidang: cBidang.text.trim(), alamat: cAlamat.text.trim());
        setDialogState(() => isSaving = false);
        if (ok && ctx.mounted) Navigator.pop(ctx);
      }
    );
  }

  void showAddMahasiswaDialog() {
    final cNim = TextEditingController();
    final cNama = TextEditingController();
    final cJurusan = TextEditingController();
    final cAlamat = TextEditingController();
    _showAddDialog(
      title: "Tambah Mahasiswa",
      icon: Icons.person_add_alt_1,
      color: const Color(0xFF3F51B5),
      hint: "Username & password default otomatis menggunakan NIM.",
      fields: [
        _field(cNim, "NIM", Icons.badge),
        _field(cNama, "Nama Lengkap", Icons.person_outline),
        _field(cJurusan, "Jurusan", Icons.school),
        _fieldMulti(cAlamat, "Alamat Lengkap", Icons.home_outlined),
      ],
      onSave: (setDialogState, ctx) async {
        setDialogState(() => isSaving = true);
        final ok = await tambahMahasiswa(nim: cNim.text.trim(), nama: cNama.text.trim(), jurusan: cJurusan.text.trim(), alamat: cAlamat.text.trim());
        setDialogState(() => isSaving = false);
        if (ok && ctx.mounted) Navigator.pop(ctx);
      }
    );
  }

  void _showAddDialog({required String title, required IconData icon, required Color color, required String hint, required List<Widget> fields, required Function(void Function(void Function()), BuildContext) onSave}) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                      const SizedBox(width: 16),
                      Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                    ]),
                    const SizedBox(height: 20),
                    _hint(hint, color),
                    const SizedBox(height: 16),
                    ...fields,
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
                          child: const Text("Batal", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: isSaving ? null : () => onSave(setDialogState, dialogContext),
                          icon: isSaving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check, size: 18),
                          label: Text(isSaving ? "Menyimpan..." : "Simpan", style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // ══════════════════════════════════════════════
  // LOGIKA FIRESTORE 
  // ══════════════════════════════════════════════
  Future<bool> tambahDosen({required String nip, required String nama, required String bidang, required String alamat}) async {
    if (nip.isEmpty || nama.isEmpty || bidang.isEmpty || alamat.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return false;
    }
    try {
      final check = await _firestore.collection('users').where('nip', isEqualTo: nip).limit(1).get();
      if (check.docs.isNotEmpty) {
        _snack("NIP sudah terdaftar", Colors.redAccent);
        return false;
      }
      final email = "$nip@$_dosenEmailDomain";
      final password = _defaultPassword(nip);
      final cred = await _createAuthAccountWithoutSignIn(email: email, password: password);
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'nip': nip, 'nama': nama, 'bidangKeahlian': bidang, 'alamat': alamat,
        'username': nip, 'email': email, 'role': 'dosen', 'isActive': true,
        'hasAccount': true, 'authUid': cred.user!.uid,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack("Dosen ditambahkan. Username: $nip | Password: $password", Colors.green);
      getUsers();
      return true;
    } on FirebaseAuthException catch (e) {
      _snack(_authErr(e), Colors.redAccent); return false;
    } catch (e) {
      _snack("Error: $e", Colors.redAccent); return false;
    }
  }

  Future<bool> tambahMahasiswa({required String nim, required String nama, required String jurusan, required String alamat}) async {
    if (nim.isEmpty || nama.isEmpty || jurusan.isEmpty || alamat.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return false;
    }
    try {
      final check = await _firestore.collection('users').where('nim', isEqualTo: nim).limit(1).get();
      if (check.docs.isNotEmpty) {
        _snack("NIM sudah terdaftar", Colors.redAccent);
        return false;
      }
      final email = "$nim@$_mahasiswaEmailDomain";
      final password = _defaultPassword(nim);
      final cred = await _createAuthAccountWithoutSignIn(email: email, password: password);
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'nim': nim, 'nama': nama, 'jurusan': jurusan, 'alamat': alamat,
        'username': nim, 'email': email, 'role': 'mahasiswa', 'isActive': true,
        'hasAccount': true, 'authUid': cred.user!.uid,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack("Mahasiswa ditambahkan. Username: $nim | Password: $password", Colors.green);
      getUsers();
      return true;
    } on FirebaseAuthException catch (e) {
      _snack(_authErr(e), Colors.redAccent); return false;
    } catch (e) {
      _snack("Error: $e", Colors.redAccent); return false;
    }
  }

  String _authErr(FirebaseAuthException e) {
    if (e.code == 'email-already-in-use') return 'ID ini sudah pernah dipakai untuk membuat akun';
    if (e.code == 'weak-password') return 'Password terlalu lemah';
    return 'Gagal membuat akun: ${e.message}';
  }

  // ══════════════════════════════════════════════
  // UI BUILDER UTAMA
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final data = filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Latar belakang abu-abu sangat lembut
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddChoice,
        backgroundColor: const Color(0xFF3F51B5),
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text("Tambah User", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
      body: Column(
        children: [
          // HEADER MODERN DENGAN GRADASI
          Container(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3F51B5), Color(0xFF283593)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Manajemen User", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        onPressed: getUsers,
                        tooltip: "Refresh Data",
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statChip(Icons.people_alt_rounded, "${listUser.length}", "Total Akun"),
                    const SizedBox(width: 12),
                    _statChip(Icons.filter_list_rounded, "${data.length}", "Ditampilkan"),
                  ],
                ),
                const SizedBox(height: 20),
                // SEARCH BAR FLOATING
                TextField(
                  onChanged: (v) => setState(() => keyword = v.toLowerCase()),
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Cari nama, username, email...",
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3F51B5)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip("Semua", "semua"),
                      const SizedBox(width: 8),
                      _filterChip("Admin", "admin"),
                      const SizedBox(width: 8),
                      _filterChip("Dosen", "dosen"),
                      const SizedBox(width: 8),
                      _filterChip("Mahasiswa", "mahasiswa"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
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

  Widget _filterChip(String label, String value) {
    final selected = filterRole == value;
    return InkWell(
      onTap: () => setState(() => filterRole = value),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? Colors.white : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                color: selected ? const Color(0xFF283593) : Colors.white)),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final config = switch (role) {
      'admin' => (const Color(0xFFD32F2F), Icons.admin_panel_settings, "Admin"),
      'dosen' => (const Color(0xFF00897B), Icons.school, "Dosen"),
      _ => (const Color(0xFF3F51B5), Icons.person, "Mahasiswa"),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.$1.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.$2, size: 14, color: config.$1),
          const SizedBox(width: 6),
          Text(config.$3, style: TextStyle(color: config.$1, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TABEL DESKTOP MODERN
  // ══════════════════════════════════════════════
  Widget _buildTable(List<Map<String, dynamic>> data) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFFAFBFF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: const Row(
                children: [
                  SizedBox(width: 40, child: _H("No")),
                  SizedBox(width: 20),
                  Expanded(flex: 3, child: _H("Nama Lengkap")),
                  Expanded(flex: 2, child: _H("Role")),
                  Expanded(flex: 2, child: _H("Username")),
                  Expanded(flex: 3, child: _H("Email")),
                  SizedBox(width: 90, child: _H("Status", align: TextAlign.center)),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: ListView.separated(
                itemCount: data.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, i) {
                  final item = data[i];
                  final active = item['isActive'] == true;
                  return Container(
                    color: Colors.white, // Menghilangkan background warna-warni yang mencolok
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text("${i + 1}",
                              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 3,
                          child: Row(children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF3F51B5).withOpacity(0.1),
                              child: Text(_initial(item['nama']),
                                  style: const TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(_s(item['nama']),
                                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
                            ),
                          ]),
                        ),
                        Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _roleBadge(_s(item['role'])))),
                        Expanded(
                          flex: 2,
                          child: Text(_s(item['username']),
                              overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(_s(item['email']),
                              overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ),
                        SizedBox(
                          width: 90,
                          child: Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: active,
                              activeColor: Colors.white,
                              activeTrackColor: Colors.green,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: Colors.grey.shade300,
                              onChanged: (_) => toggleActive(item),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // CARD LIST MOBILE MODERN
  // ══════════════════════════════════════════════
  Widget _buildCardList(List<Map<String, dynamic>> data) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final item = data[i];
        final active = item['isActive'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF3F51B5).withOpacity(0.1),
                      child: Text(_initial(item['nama']),
                          style: const TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_s(item['nama']),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
                          const SizedBox(height: 4),
                          _roleBadge(_s(item['role'])),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: active,
                        activeColor: Colors.white,
                        activeTrackColor: Colors.green,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.grey.shade300,
                        onChanged: (_) => toggleActive(item),
                      ),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                _cardRow(Icons.account_circle_outlined, "Username", _s(item['username'])),
                const SizedBox(height: 8),
                _cardRow(Icons.email_outlined, "Email", _s(item['email'])),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════
  // KOMPONEN PELENGKAP UI
  // ══════════════════════════════════════════════
  Widget _statChip(IconData icon, String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text("$val $label", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cardRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
        Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87))),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)]),
            child: Icon(Icons.inbox_rounded, size: 60, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 16),
          Text(
            keyword.isEmpty ? "Belum ada user" : "Data tidak ditemukan",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _hint(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5)),
        ),
      ),
    );
  }

  Widget _fieldMulti(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          alignLabelWithHint: true,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5)),
        ),
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _H(this.text, {this.align = TextAlign.left});
  @override
  Widget build(BuildContext context) {
    return Text(text,
        textAlign: align,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 13, letterSpacing: 0.5));
  }
}