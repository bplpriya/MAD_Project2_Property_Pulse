// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'transaction_history_screen.dart'; 
import '../services/auth_service.dart'; // Ensure this is imported

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  // REMOVED: int tokens = 0;
  String name = 'Loading...';
  String role = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Fetch user data from the 'users' collection
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        // REMOVED: tokens = data?['tokens'] ?? 1000; 
        name = data?['name'] ?? user.email ?? 'User';
        role = data?['role'] ?? 'Unknown';
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      
      if (mounted) {
        // Clears navigation stack and redirects to the login screen via AuthWrapper
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),
            const SizedBox(height: 15),
            Text(
              name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.email ?? 'N/A',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Chip(
              label: Text(role, style: const TextStyle(color: Colors.white)),
              backgroundColor: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 30),

            // REMOVED: Token Display Card
            // Card(
            //   elevation: 4,
            //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            //   child: Padding(
            //     padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         Icon(Icons.monetization_on, color: Colors.amber.shade700, size: 30),
            //         const SizedBox(width: 10),
            //         Text(
            //           'Tokens: $tokens', 
            //           style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            //       ],
            //     ),
            //   ),
            // ),
            // const SizedBox(height: 30),
            
            // Transaction History Button (Links to the next screen)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const TransactionHistoryScreen())
                  );
                },
                icon: const Icon(Icons.history),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text("View Transaction History", style: TextStyle(fontSize: 16)),
                ),
                style: ElevatedButton.styleFrom(
                  // Fixed deprecation: using withAlpha(230) for 90% opacity
                  backgroundColor: Theme.of(context).primaryColor.withAlpha(230), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 20),
            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text("Sign Out", style: TextStyle(fontSize: 18)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}