import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class TransactionHistoryScreen extends StatefulWidget {
 const TransactionHistoryScreen({super.key});
 @override
 State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}
class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
 final _auth = FirebaseAuth.instance;
 final _firestore = FirebaseFirestore.instance;
 String currentUserId = '';
 @override
 void initState() {
 super.initState();
 final user = _auth.currentUser;
 if (user != null) {
 currentUserId = user.uid;
 } else {
 currentUserId = 'anonymous';
 }
 }
 @override
 Widget build(BuildContext context) {
 return Scaffold(
 appBar: AppBar(title: const Text("Transaction History")),
 body: currentUserId.isEmpty || currentUserId == 'anonymous'
 ? const Center(child: Text("Please log in to view transactions."))
 : StreamBuilder<QuerySnapshot>(
 stream: _firestore
 .collection('users')
 .doc(currentUserId)
 .collection('transactions')
 .orderBy('date', descending: true)
 .snapshots(),
 builder: (context, snapshot) {
 if (!snapshot.hasData) {
 return const Center(child: CircularProgressIndicator());
 }
 if (snapshot.hasError) {
 return Center(child: Text('Error: ${snapshot.error}'));
 }
 final userTransactions = snapshot.data!.docs;
 if (userTransactions.isEmpty) {
 return const Center(
 child: Text(
 "No transactions found.",
 style: TextStyle(fontSize: 16, color: Colors.grey),
 ),
 );
 }
 return ListView.builder(
 padding: const EdgeInsets.all(10.0),
 itemCount: userTransactions.length,
 itemBuilder: (context, index) {
 final doc = userTransactions[index];
 final data = doc.data() as Map<String, dynamic>;
 final title = data['title'] ?? 'N/A';
 final price = (data['price'] ?? 0).toString();
 final type = data['saleType'] ?? 'General';
 final timestamp = data['date'] as Timestamp?;
 final timeString = timestamp != null
 ? 'Date: ${timestamp.toDate().toString().split(' ')[0]}'
 : 'N/A';
 final isIncome = type == 'Sold';
 final sign = isIncome ? '+' : '-';
 final primaryColor = Theme.of(context).primaryColor;
 final icon = isIncome ? Icons.account_balance_wallet : Icons.money_off;
 return Card(
 elevation: 2,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 margin: const EdgeInsets.symmetric(vertical: 8),
 child: ListTile(
 leading: CircleAvatar(
 backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
 child: Icon(icon, color: isIncome ? Colors.green.shade700 : Colors.red.shade700),
 ),
 title: Text(
 title,
 style: const TextStyle(fontWeight: FontWeight.bold)
 ),
 subtitle: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('Type: $type', style: TextStyle(fontWeight: FontWeight.w500, color: primaryColor)),
 Text(timeString, style: const TextStyle(color: Colors.grey, fontSize: 12)),
 ],
 ),
 trailing: Column(
 crossAxisAlignment: CrossAxisAlignment.end,
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Text(
 '$sign\$ $price',
 style: TextStyle(
 fontWeight: FontWeight.bold,
 color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
 fontSize: 18,
 ),
 ),
 ],
 ),
 ),
 );
 },
 );
 },
 ),
 );
 }
}