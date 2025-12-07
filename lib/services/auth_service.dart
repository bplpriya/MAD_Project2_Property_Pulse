// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart'; // Import the new model

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // --- Sign Up Function ---
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      // 1. Create the user in Firebase Authentication
      final UserCredential userCredential = 
          await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
          );

      final user = userCredential.user;
      if (user != null) {
        // Convert enum role to string for Firestore storage
        final roleString = role == UserRole.Buyer ? 'Buyer' : 'Seller/Agent';
        
        // 2. Save the user details and role to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'role': roleString,
          // REMOVED: 'tokens': 20, // Initial tokens for new user
          'createdAt': Timestamp.now(),
        });
        
        return user;
      }
    } on FirebaseAuthException catch (e) {
      // Re-throw the exception so the UI can handle it
      throw e; 
    }
    return null;
  }

  // --- Login Function ---
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = 
          await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
          );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Re-throw the exception so the UI can handle it
      throw e;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Optional: Listen to auth state changes
  Stream<User?> get user => _auth.authStateChanges();
}