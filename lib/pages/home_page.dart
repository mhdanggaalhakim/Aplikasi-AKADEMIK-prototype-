import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'data_mahasiswa_page.dart';
import 'data_dosen_page.dart';
import 'mata_kuliah_page.dart';
import 'user_page.dart';
import 'penjadwalan_page.dart';
import 'nilai_page.dart';
import 'krs_page.dart';
import 'khs_page.dart';
import 'persetujuan_krs_page.dart';
import 'daftar_mahasiswa_dosen_page.dart';
import 'profil_dosen_page.dart';
import 'profil_mahasiswa_page.dart';
import 'coming_soon_page.dart';

class HomePage extends StatefulWidget {
  final String userId;
  final String nama;
  final String nim;
  final String jurusan;
  final String alamat;
  final String usernameLogin;
  final String role; // 'admin' | 'dosen' | 'mahasiswa'

  const HomePage({
    super.key,
    required this.userId,
    required this.nama,
    required this.nim,
    required this.jurusan,
    required this.alamat,
    required this.usernameLogin,
    required this.role,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  int totalMhs = 0;
  int totalDosen = 0;
  int totalMk = 0;

  String dosenNip = '';
  String dosenBidang = '';
  bool isLoadingDosenProfil = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == 'admin') _getStats();
    if (widget.role == 'dosen') _getDosenProfil();
  }

  Future<void> _getDosenProfil() async {
    setState(() => isLoadingDosenProfil = true);
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          dosenNip = (d['nip'] ?? '').toString();
          dosenBidang = (d['bidangKeahlian'] ?? '').toString();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => isLoadingDosenProfil = false);
  }

  Future<void> _getStats() async {
    try {
      final mhsSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'mahasiswa')
          .where('isActive', isEqualTo: true)
          .get();
      final dosenSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'dosen')
          .where('isActive', isEqualTo: true)
          .get();
      final mkSnap = await _firestore.collection('mata_kuliah').get();

      if (mounted) {
        setState(() {
          totalMhs = mhsSnap.docs.length;
          totalDosen = dosenSnap.docs.length;
          totalMk = mkSnap.docs.length;
        });
      }
    } catch (_) {}
  }

  void logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Konfirmasi Logout", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Apakah Anda yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (r) => false,
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _roleLabel() {
    switch (widget.role) {
      case 'admin':
        return "Dashboard Admin";
      case 'dosen':
        return "Dashboard Dosen";
      default:
        return "Dashboard Mahasiswa";
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (widget.role == 'admin') {
      body = _buildAdmin();
    } else if (widget.role == 'dosen') {
      body = _buildDosen();
    } else {
      body = _buildMahasiswa();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9), // Latar belakang abu-abu sangat muda (elegan)
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5), // Warna biru keunguan
        foregroundColor: Colors.white,
        title: Text(_roleLabel(), style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done, size: 14, color: Colors.greenAccent),
                  SizedBox(width: 6),
                  Text("Firebase", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Logout",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }

  // ══════════════════════════════════════════════
  // BANNER PROFIL
  // ══════════════════════════════════════════════
  Widget _profileBanner({required String subtitle, IconData icon = Icons.shield}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              widget.nama.isNotEmpty ? widget.nama[0].toUpperCase() : "U",
              style: const TextStyle(
                  fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Halo, ${widget.nama} !",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          Icon(icon, color: Colors.white.withOpacity(0.4), size: 40),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // MENU GRID
  // ══════════════════════════════════════════════
  Widget _menuGrid(List<_MenuItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth >= 800 ? 4 : (constraints.maxWidth >= 500 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.05, // Membuat rasio kotak menu lebih proporsional
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _menuCard(items[i]),
        );
      },
    );
  }

  Widget _menuCard(_MenuItem item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.blueGrey.withOpacity(0.15),
      elevation: 4, // Efek shadow melayang
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: item.color.withOpacity(0.1),
        highlightColor: item.color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1), // Lingkaran transparan sesuai warna icon
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w600, 
                    color: Color(0xFF2C3E50)), // Warna teks keabu-abuan tua agar rapi
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goto(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      if (widget.role == 'admin') _getStats();
      if (widget.role == 'dosen') _getDosenProfil();
    });
  }

  // ══════════════════════════════════════════════
  // TAMPILAN ADMIN
  // ══════════════════════════════════════════════
  Widget _buildAdmin() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _profileBanner(subtitle: "Administrator", icon: Icons.admin_panel_settings),
              const SizedBox(height: 24),

              // Ringkasan Statistik
              Row(
                children: [
                  Expanded(child: _statCard(Icons.people, "$totalMhs", "Mahasiswa", const Color(0xFF673AB7))),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard(Icons.school, "$totalDosen", "Dosen", const Color(0xFF009688))),
                  const SizedBox(width: 16),
                  Expanded(child: _statCard(Icons.menu_book, "$totalMk", "Mata Kuliah", const Color(0xFFFF9800))),
                ],
              ),
              const SizedBox(height: 32),

              const Text(
                "Menu Manajemen",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
              ),
              const SizedBox(height: 16),

              _menuGrid([
                _MenuItem("Data Mahasiswa", Icons.people_outline, const Color(0xFF673AB7), () => _goto(DataMahasiswaPage(role: widget.role))),
                _MenuItem("Data Dosen", Icons.school_outlined, const Color(0xFF009688), () => _goto(DataDosenPage(role: widget.role))),
                _MenuItem("Data Mata Kuliah", Icons.menu_book_outlined, const Color(0xFFE65100), () => _goto(MataKuliahPage(role: widget.role))),
                _MenuItem("Penjadwalan Kuliah", Icons.calendar_month_outlined, const Color(0xFF5E35B1), () => _goto(PenjadwalanPage(role: 'admin'))),
                _MenuItem("Persetujuan KRS", Icons.fact_check_outlined, const Color(0xFFD32F2F), () => _goto(const PersetujuanKrsPage())),
                _MenuItem("Nilai", Icons.grade_outlined, const Color(0xFF2E7D32), () => _goto(NilaiPage(role: 'admin'))),
                _MenuItem("User", Icons.manage_accounts_outlined, const Color(0xFFE65100), () => _goto(const UserPage())),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAMPILAN DOSEN
  // ══════════════════════════════════════════════
  Widget _buildDosen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _goto(ProfilDosenPage(userId: widget.userId)),
                child: _profileBanner(subtitle: "Dosen • Ketuk untuk lihat profil", icon: Icons.workspace_premium),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 4,
                shadowColor: Colors.blueGrey.withOpacity(0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text("Informasi Akun",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                          ),
                          TextButton.icon(
                            onPressed: () => _goto(ProfilDosenPage(userId: widget.userId)),
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text("Edit Profil"),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF3949AB)),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Colors.black12),
                      if (isLoadingDosenProfil)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _infoRow(Icons.badge_outlined, "NIP", dosenNip),
                        _infoRow(Icons.person_outline, "Nama Lengkap", widget.nama),
                        _infoRow(Icons.school_outlined, "Bidang Keahlian", dosenBidang),
                        _infoRow(Icons.home_outlined, "Alamat", widget.alamat),
                        _infoRow(Icons.account_circle_outlined, "Username", widget.usernameLogin),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text("Menu Dosen",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              const SizedBox(height: 16),
              
              _menuGrid([
                _MenuItem("Profil Saya", Icons.person_outline, const Color(0xFF5E35B1), () => _goto(ProfilDosenPage(userId: widget.userId))),
                _MenuItem("Jadwal Mengajar", Icons.calendar_month_outlined, const Color(0xFF3F51B5), () => _goto(PenjadwalanPage(role: 'dosen', userId: widget.userId))),
                _MenuItem("Input Nilai", Icons.edit_note_outlined, const Color(0xFF2E7D32), () => _goto(NilaiPage(role: 'dosen', userId: widget.userId, userNama: widget.nama))),
                _MenuItem("Daftar Mahasiswa", Icons.people_outline, const Color(0xFF00897B), () => _goto(DaftarMahasiswaDosenPage(userId: widget.userId))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAMPILAN MAHASISWA
  // ══════════════════════════════════════════════
  Widget _buildMahasiswa() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _goto(ProfilMahasiswaPage(userId: widget.userId)),
                child: _profileBanner(subtitle: "Mahasiswa • Ketuk untuk lihat profil", icon: Icons.local_library),
              ),
              const SizedBox(height: 24),

              Card(
                elevation: 4,
                shadowColor: Colors.blueGrey.withOpacity(0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text("Informasi Akun",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                          ),
                          TextButton.icon(
                            onPressed: () => _goto(ProfilMahasiswaPage(userId: widget.userId)),
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text("Edit Profil"),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF3949AB)),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Colors.black12),
                      _infoRow(Icons.badge_outlined, "NIM", widget.nim),
                      _infoRow(Icons.person_outline, "Nama Lengkap", widget.nama),
                      _infoRow(Icons.school_outlined, "Jurusan", widget.jurusan),
                      _infoRow(Icons.home_outlined, "Alamat", widget.alamat),
                      _infoRow(Icons.account_circle_outlined, "Username", widget.usernameLogin),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text("Menu Akademik",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              const SizedBox(height: 16),

              _menuGrid([
                _MenuItem("Profil Saya", Icons.person_outline, const Color(0xFF00897B), () => _goto(ProfilMahasiswaPage(userId: widget.userId))),
                _MenuItem("Jadwal Kuliah", Icons.calendar_month_outlined, const Color(0xFF3F51B5), () => _goto(PenjadwalanPage(role: 'mahasiswa', userId: widget.userId))),
                _MenuItem("Nilai / Transkrip", Icons.grade_outlined, const Color(0xFF2E7D32), () => _goto(NilaiPage(role: 'mahasiswa', userId: widget.userId, userNama: widget.nama))),
                _MenuItem("KRS", Icons.assignment_outlined, const Color(0xFFE65100), () => _goto(KrsPage(userId: widget.userId, userNama: widget.nama))),
                _MenuItem("KHS", Icons.description_outlined, const Color(0xFF5E35B1), () => _goto(KhsPage(userId: widget.userId, userNama: widget.nama))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3949AB)),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const Text(" : ", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value.isNotEmpty ? value : "-",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _MenuItem(this.label, this.icon, this.color, this.onTap);
}