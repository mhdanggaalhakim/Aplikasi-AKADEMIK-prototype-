import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth      = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final cUsername = TextEditingController();
  final cPassword = TextEditingController();

  bool isLoading    = false;
  bool showPassword = false;

  @override
  void dispose() {
    cUsername.dispose();
    cPassword.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final username = cUsername.text.trim();
    final password = cPassword.text;

    if (username.isEmpty || password.isEmpty) {
      _snack("Username dan password wajib diisi", Colors.orange);
      return;
    }

    setState(() => isLoading = true);
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _snack("Username tidak ditemukan", Colors.red);
        setState(() => isLoading = false);
        return;
      }

      final userDoc  = query.docs.first;
      final userData = userDoc.data();
      final email    = userData['email'] as String;

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      _snack("Login berhasil", Colors.green);
      cUsername.clear();
      cPassword.clear();

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            userId:        userDoc.id,
            nama:          userData['nama']     ?? '',
            nim:           userData['nim']      ?? '',
            jurusan:       userData['jurusan']  ?? '',
            alamat:        userData['alamat']   ?? '',
            usernameLogin: userData['username'] ?? '',
            role:          userData['role']     ?? 'mahasiswa',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'wrong-password' || e.code == 'invalid-credential'
          ? 'Password salah'
          : 'Login gagal: ${e.message}';
      _snack(msg, Colors.red);
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/gedung-upu.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 0 : 24,
                vertical: 32,
              ),
              child: isWide ? _buildWide() : _buildMobile(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWide() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Row(
          children: [
            Expanded(child: _buildBranding()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _buildCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobile() {
    return Column(
      children: [
        const Icon(Icons.school, size: 64, color: Colors.white),
        const SizedBox(height: 8),
        const Text(
          "Aplikasi Akademik",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 24),
        _buildCard(),
      ],
    );
  }

  Widget _buildBranding() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.school, size: 60, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Aplikasi\nAkademik",
            style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold,
              color: Colors.white, height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Kelola data akademik dengan mudah.",
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done, size: 14, color: Colors.greenAccent),
                SizedBox(width: 6),
                Text("Powered by Firebase",
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Card(
      elevation: 12,
      color: Colors.white.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Masuk",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                    color: Colors.black)), // GANTI WARNA JADI HITAM
            const SizedBox(height: 4),
            const Text("Silakan login untuk melanjutkan",
                style: TextStyle(color: Colors.black54, fontSize: 13)), // GANTI WARNA JADI ABU LEBIH TUA/HITAM
            const SizedBox(height: 20),
            TextField(
              controller: cUsername,
              decoration: const InputDecoration(
                labelText: "Username",
                prefixIcon: Icon(Icons.person_outline, color: Colors.black), // GANTI WARNA JADI HITAM
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: cPassword,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock_outline, color: Colors.black), // GANTI WARNA JADI HITAM
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.black), // GANTI WARNA JADI HITAM
                  onPressed: () => setState(() => showPassword = !showPassword),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700], // GANTI WARNA JADI BIRU (MEDIUM)
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("MASUK",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}