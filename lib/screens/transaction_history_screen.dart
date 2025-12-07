// lib/screens/transaction_history_screen.dart

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
      // Handle case where user might be null, though AuthWrapper should prevent this
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
              // Stream all documents from the 'transactions' collection
              stream: _firestore.collection('transactions').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 1. Filter: Find transactions where the current user is either the buyer or the seller
                final allTransactions = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['buyerId'] == currentUserId || data['sellerId'] == currentUserId;
                }).toList();

                if (allTransactions.isEmpty) {
                  return const Center(child: Text("No transactions found for your account."));
                }

                // 2. Sort: Display the most recent transactions first (descending timestamp)
                allTransactions.sort((a, b) {
                  final aTime = (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final bTime = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  return bTime.compareTo(aTime);
                });

                // 3. Display the list of filtered and sorted transactions
                return ListView.builder(
                  itemCount: allTransactions.length,
                  itemBuilder: (context, index) {
                    final data = allTransactions[index].data() as Map<String, dynamic>;
                    
                    // Determine transaction type and color
                    final bool isPurchase = data['buyerId'] == currentUserId;
                    final String type = isPurchase ? 'Purchase' : 'Sale';
                    final Color typeColor = isPurchase ? Colors.green.shade700 : Colors.orange.shade700;
                    
                    // Changed from 'tokenChange' to 'price' (assuming transactions store the property price)
                    final int price = data['price'] ?? 0; 
                    final String status = data['status'] ?? 'Completed';
                    final String itemId = data['itemId'] ?? 'N/A';
                    
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                    final timeString = timestamp != null 
                        ? '${timestamp.month}/${timestamp.day}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}' 
                        : 'N/A';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: typeColor.withAlpha(50),
                          child: Icon(
                            isPurchase ? Icons.shopping_cart : Icons.sell,
                            color: typeColor,
                          ),
                        ),
                        title: Text(
                          '$type - Item: $itemId', 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: $status'),
                            Text(timeString, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Display the price/amount involved in the transaction
                            Text(
                              isPurchase ? '-\$$price' : '+\$$price', // Using '$' as a generic currency sign
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                // Color remains to indicate direction (spent/received)
                                color: isPurchase ? Colors.red.shade700 : Colors.green.shade700,
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