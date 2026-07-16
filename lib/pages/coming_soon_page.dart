import 'package:flutter/material.dart';

class ComingSoonPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const ComingSoonPage({
    super.key,
    required this.title,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3F51B5),
        foregroundColor: Colors.white,
        title: Text(title),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: const Color(0xFF3F51B5)),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
            const SizedBox(height: 8),
            Text("Fitur ini sedang dalam pengembangan",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}