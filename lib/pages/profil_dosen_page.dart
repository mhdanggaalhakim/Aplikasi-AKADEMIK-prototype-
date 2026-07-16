import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilDosenPage extends StatefulWidget {
  final String userId; // authUid dosen yang sedang login
  const ProfilDosenPage({super.key, required this.userId});

  @override
  State<ProfilDosenPage> createState() => _ProfilDosenPageState();
}

class _ProfilDosenPageState extends State<ProfilDosenPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth      = FirebaseAuth.instance;

  Map<String, dynamic>? data;
  bool isLoading = true;
  bool isSaving  = false;

  @override
  void initState() {
    super.initState();
    getProfil();
  }

  String _s(dynamic v) => (v ?? '').toString();
  String _initial(dynamic name) {
    final s = (name ?? '').toString().trim();
    return s.isEmpty ? '?' : s[0].toUpperCase();
  }

  Future<void> getProfil() async {
    setState(() => isLoading = true);
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (doc.exists) {
        setState(() => data = doc.data());
      } else {
        _snack("Data profil tidak ditemukan", Colors.red);
      }
    } catch (e) {
      _snack("Gagal mengambil profil: $e", Colors.red);
    }
    setState(() => isLoading = false);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ══════════════════════════════════════════════
  // EDIT PROFIL (Nama, Bidang Keahlian, Alamat)
  // NIP, Username, Email tidak bisa diubah sendiri (terikat login)
  // ══════════════════════════════════════════════
  void showEditDialog() {
    if (data == null) return;
    final cNama   = TextEditingController(text: _s(data!['nama']));
    final cBidang = TextEditingController(text: _s(data!['bidangKeahlian']));
    final cAlamat = TextEditingController(text: _s(data!['alamat']));

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
                      Icon(Icons.edit, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text("Edit Profil",
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    ]),
                    const Divider(height: 20),
                    _field(cNama, "Nama", Icons.person_outline),
                    _field(cBidang, "Bidang Keahlian", Icons.school),
                    _fieldMulti(cAlamat, "Alamat", Icons.home_outlined),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                          child: const Text("Batal"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3F51B5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  setDialogState(() => isSaving = true);
                                  final ok = await updateProfil(
                                    nama:   cNama.text.trim(),
                                    bidang: cBidang.text.trim(),
                                    alamat: cAlamat.text.trim(),
                                  );
                                  setDialogState(() => isSaving = false);
                                  if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
                                },
                          icon: isSaving
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

  Future<bool> updateProfil({
    required String nama,
    required String bidang,
    required String alamat,
  }) async {
    if (nama.isEmpty || bidang.isEmpty || alamat.isEmpty) {
      _snack("Semua field wajib diisi", Colors.orange);
      return false;
    }
    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'nama':           nama,
        'bidangKeahlian': bidang,
        'alamat':         alamat,
        'updatedAt':      FieldValue.serverTimestamp(),
      });
      _snack("Profil berhasil diupdate", Colors.green);
      getProfil();
      return true;
    } catch (e) {
      _snack("Error: $e", Colors.red);
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // GANTI PASSWORD
  // ══════════════════════════════════════════════
  void showGantiPasswordDialog() {
    final cLama    = TextEditingController();
    final cBaru    = TextEditingController();
    final cKonfirm = TextEditingController();
    bool showLama = false, showBaru = false, showKonfirm = false;
    bool isChanging = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.lock_reset, color: Color(0xFF3F51B5)),
                      SizedBox(width: 8),
                      Text("Ganti Password",
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    ]),
                    const Divider(height: 20),
                    _fieldPassword(cLama, "Password Lama", showLama,
                        () => setDialogState(() => showLama = !showLama)),
                    _fieldPassword(cBaru, "Password Baru (min. 8 karakter)", showBaru,
                        () => setDialogState(() => showBaru = !showBaru)),
                    _fieldPassword(cKonfirm, "Konfirmasi Password Baru", showKonfirm,
                        () => setDialogState(() => showKonfirm = !showKonfirm)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isChanging ? null : () => Navigator.pop(dialogContext),
                          child: const Text("Batal"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3F51B5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isChanging
                              ? null
                              : () async {
                                  final lama    = cLama.text;
                                  final baru    = cBaru.text;
                                  final konfirm = cKonfirm.text;

                                  if (lama.isEmpty || baru.isEmpty || konfirm.isEmpty) {
                                    _snack("Semua field wajib diisi", Colors.orange);
                                    return;
                                  }
                                  if (baru.length < 8) {
                                    _snack("Password baru minimal 8 karakter", Colors.orange);
                                    return;
                                  }
                                  if (baru != konfirm) {
                                    _snack("Konfirmasi password tidak sama", Colors.orange);
                                    return;
                                  }

                                  setDialogState(() => isChanging = true);
                                  final ok = await gantiPassword(lama, baru);
                                  setDialogState(() => isChanging = false);
                                  if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
                                },
                          icon: isChanging
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check, size: 16),
                          label: const Text("Ganti"),
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

  Future<bool> gantiPassword(String lama, String baru) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        _snack("Sesi login tidak valid, silakan login ulang", Colors.red);
        return false;
      }
      final cred = EmailAuthProvider.credential(email: user.email!, password: lama);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(baru);
      _snack("Password berhasil diubah", Colors.green);
      return true;
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password'      => 'Password lama salah',
        'invalid-credential'  => 'Password lama salah',
        'weak-password'       => 'Password baru terlalu lemah',
        'requires-recent-login' => 'Sesi kadaluarsa, silakan login ulang lalu coba lagi',
        _ => 'Gagal mengganti password: ${e.message}',
      };
      _snack(msg, Colors.red);
      return false;
    } catch (e) {
      _snack("Error: $e", Colors.red);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        title: const Text("Profil Dosen"),
        elevation: 0,
        actions: [
          IconButton(onPressed: getProfil, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3F51B5)))
          : data == null
              ? Center(
                  child: Text("Data profil tidak ditemukan",
                      style: TextStyle(color: Colors.grey.shade500)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildBanner(),
                          const SizedBox(height: 16),
                          _buildDataDiriCard(),
                          const SizedBox(height: 16),
                          _buildAksiCard(),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildBanner() {
    final active = data!['isActive'] == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _initial(data!['nama']),
              style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_s(data!['nama']).isEmpty ? "-" : _s(data!['nama']),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text("NIP: ${_s(data!['nip']).isEmpty ? '-' : _s(data!['nip'])}",
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (active ? Colors.greenAccent : Colors.redAccent).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(active ? Icons.check_circle : Icons.cancel,
                          size: 12, color: active ? Colors.greenAccent : Colors.redAccent),
                      const SizedBox(width: 4),
                      Text(active ? "Akun Aktif" : "Akun Nonaktif",
                          style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.school, color: Colors.white38, size: 36),
        ],
      ),
    );
  }

  Widget _buildDataDiriCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text("Data Diri",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                ),
                TextButton.icon(
                  onPressed: showEditDialog,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Edit"),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF3F51B5)),
                ),
              ],
            ),
            const Divider(height: 20),
            _infoRow(Icons.badge, "NIP", _s(data!['nip'])),
            _infoRow(Icons.person_outline, "Nama", _s(data!['nama'])),
            _infoRow(Icons.school, "Bidang Keahlian", _s(data!['bidangKeahlian'])),
            _infoRow(Icons.home_outlined, "Alamat", _s(data!['alamat'])),
            _infoRow(Icons.account_circle, "Username", _s(data!['username'])),
            _infoRow(Icons.email_outlined, "Email", _s(data!['email'])),
          ],
        ),
      ),
    );
  }

  Widget _buildAksiCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Keamanan Akun",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            const Divider(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: showGantiPasswordDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3F51B5),
                  side: const BorderSide(color: Color(0xFF3F51B5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.lock_reset, size: 18),
                label: const Text("Ganti Password"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3F51B5)),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const Text(": ", style: TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
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
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      ),
    );
  }

  Widget _fieldPassword(
      TextEditingController c, String label, bool show, VoidCallback toggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: !show,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF3F51B5)),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          suffixIcon: IconButton(
            icon: Icon(show ? Icons.visibility_off : Icons.visibility),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }
}