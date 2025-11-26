import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  // Ensure that Flutter is ready to run
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the Firebase app
  await Firebase.initializeApp(); 
  runApp(const MyApp());
}