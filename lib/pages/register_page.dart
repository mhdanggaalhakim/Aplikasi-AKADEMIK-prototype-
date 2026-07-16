import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final cNim = TextEditingController();
  final cNama = TextEditingController();
  final cJurusan = TextEditingController();
  final cAlamat = TextEditingController();

  final cUsername = TextEditingController();
  final cEmail = TextEditingController();
  final cPassword = TextEditingController();
  final cKonfirm = TextEditingController();

  int currentStep = 0;
  bool isLoading = false;
  bool showPass = false;
  bool showKonfirm = false;

  @override
  void dispose() {
    cNim.dispose(); cNama.dispose(); cJurusan.dispose(); cAlamat.dispose();
    cUsername.dispose(); cEmail.dispose();
    cPassword.dispose(); cKonfirm.dispose();
    super.dispose();
  }

  void nextStep() {
    if (cNim.text.trim().isEmpty) { _snack("NIM wajib diisi", Colors.orange); return; }
    if (cNama.text.trim().isEmpty) { _snack("Nama wajib diisi", Colors.orange); return; }
    if (cJurusan.text.trim().isEmpty) { _snack("Jurusan wajib diisi", Colors.orange); return; }
    if (cAlamat.text.trim().isEmpty) { _snack("Alamat wajib diisi", Colors.orange); return; }
    setState(() => currentStep = 1);
  }

  // Logika register persis sama
  Future<void> register() async {
    final username = cUsername.text.trim();
    final email = cEmail.text.trim();
    final password = cPassword.text;
    final konfirm = cKonfirm.text;

    if (username.isEmpty) { _snack("Username wajib diisi", Colors.orange); return; }
    if (email.isEmpty) { _snack("Email wajib diisi", Colors.orange); return; }
    if (password.length < 8) { _snack("Password minimal 8 karakter", Colors.orange); return; }
    if (password != konfirm) { _snack("Password tidak cocok", Colors.orange); return; }

    setState(() => isLoading = true);
    try {
      final usernameCheck = await _firestore.collection('users').where('username', isEqualTo: username).limit(1).get();
      if (usernameCheck.docs.isNotEmpty) { _snack("Username sudah digunakan", Colors.redAccent); setState(() => isLoading = false); return; }
      final nimCheck = await _firestore.collection('users').where('nim', isEqualTo: cNim.text.trim()).limit(1).get();
      if (nimCheck.docs.isNotEmpty) { _snack("NIM sudah terdaftar", Colors.redAccent); setState(() => isLoading = false); return; }

      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'nim': cNim.text.trim(), 'nama': cNama.text.trim(), 'jurusan': cJurusan.text.trim(), 'alamat': cAlamat.text.trim(),
        'username': username, 'email': email, 'role': 'mahasiswa', 'isActive': true,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
      await _auth.signOut();
      _snack("Registrasi berhasil! Silakan login", Colors.green);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? "Registrasi gagal", Colors.redAccent);
    } catch (e) {
      _snack("Error: $e", Colors.redAccent);
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [Color(0xFF3F51B5), Color(0xFF1A237E), Color(0xFF0D145A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.person_add_alt_1, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text("Daftar Akun Baru", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                    const SizedBox(height: 30),
                    _stepIndicator(),
                    const SizedBox(height: 30),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: currentStep == 1 ? const Offset(0.1, 0) : const Offset(-0.1, 0), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      child: currentStep == 0 ? _buildStep1() : _buildStep2(),
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

  Widget _stepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(1, currentStep >= 0, "Data Diri"),
        Container(width: 60, height: 2, color: currentStep >= 1 ? Colors.white : Colors.white.withOpacity(0.3), margin: const EdgeInsets.only(bottom: 20)),
        _stepDot(2, currentStep >= 1, "Keamanan"),
      ],
    );
  }

  Widget _stepDot(int num, bool active, String label) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.white.withOpacity(0.2),
            boxShadow: active ? [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 10)] : [],
          ),
          alignment: Alignment.center,
          child: Text("$num", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: active ? const Color(0xFF3F51B5) : Colors.white)),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(active ? 1.0 : 0.6))),
      ],
    );
  }

  Widget _buildStep1() {
    return _buildCardWrapper(
      key: const ValueKey('step1'),
      title: "Informasi Akademik",
      icon: Icons.assignment_ind,
      children: [
        _field(cNim, "Nomor Induk Mahasiswa", Icons.badge),
        _field(cNama, "Nama Lengkap", Icons.person_outline),
        _field(cJurusan, "Program Studi / Jurusan", Icons.school),
        _field(cAlamat, "Alamat Tempat Tinggal", Icons.home_outlined, maxLines: 2),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: nextStep,
            style: _btnStyle(),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text("Selanjutnya", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 20)],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Sudah punya akun? Masuk di sini", style: TextStyle(color: Color(0xFF3F51B5), fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return _buildCardWrapper(
      key: const ValueKey('step2'),
      title: "Buat Kredensial Login",
      icon: Icons.lock_person,
      children: [
        _field(cUsername, "Username", Icons.alternate_email),
        _field(cEmail, "Alamat Email", Icons.email_outlined),
        _fieldPassword(cPassword, "Password (min. 8 karakter)", showPass, () => setState(() => showPass = !showPass)),
        _fieldPassword(cKonfirm, "Ulangi Password", showKonfirm, () => setState(() => showKonfirm = !showKonfirm)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 52, width: 52,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF3F51B5)),
                onPressed: () => setState(() => currentStep = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : register,
                  style: _btnStyle(),
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Daftar Sekarang", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardWrapper({required Key key, required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFF3F51B5), size: 24),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
          ]),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  ButtonStyle _btnStyle() => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      );

  Widget _field(TextEditingController c, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF3F51B5)),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5)),
        ),
      ),
    );
  }

  Widget _fieldPassword(TextEditingController c, String label, bool show, VoidCallback toggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c, obscureText: !show,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF3F51B5)),
          suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade500), onPressed: toggle),
          filled: true, fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 1.5)),
        ),
      ),
    );
  }
}