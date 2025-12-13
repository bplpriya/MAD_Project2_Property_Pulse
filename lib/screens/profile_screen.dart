// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'transaction_history_screen.dart'; 
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  String name = 'Loading...';
  String role = '';
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getToken();
  }

  Future<void> _getToken() async {
    String? t = await FirebaseMessaging.instance.getToken();
    setState(() => _token = t);
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          if (doc.exists) {
            name = doc.data()?['name'] ?? user.email ?? 'User';
            role = doc.data()?['role'] ?? 'Buyer';
          } else {
            // FIX: Use email as name if document doesn't exist yet
            name = user.email?.split('@')[0] ?? 'User';
            role = 'Buyer';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => name = 'Error Loading');
    }
  }

  void _showToken() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Your FCM Device Token"),
        content: SelectableText(_token ?? "Generating..."),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 20),
            Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(role, style: const TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 40),

            // FCM TEST BUTTON
            ListTile(
              leading: const Icon(Icons.notifications_active, color: Colors.orange),
              title: const Text("Get My Device Token"),
              subtitle: const Text("Use this to test notifications"),
              onTap: _showToken,
            ),
            
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Transaction History"),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
            ),
            
            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  await _authService.signOut();
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: const Text("Sign Out", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}