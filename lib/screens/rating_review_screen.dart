import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingReviewScreen extends StatefulWidget {
  final String propertyId; // This is the required parameter causing the error
  
  const RatingReviewScreen({super.key, required this.propertyId});

  @override
  State<RatingReviewScreen> createState() => _RatingReviewScreenState();
}

class _RatingReviewScreenState extends State<RatingReviewScreen> {
  double rating = 0;
  final TextEditingController reviewController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Logic to add the review to the sub-collection of the specific listing
      await FirebaseFirestore.instance
          .collection('listings') 
          .doc(widget.propertyId) // Uses the ID passed from the previous screen
          .collection('reviews')
          .add({
        'userId': user.uid,
        'userEmail': user.email ?? 'Anonymous',
        'rating': rating,
        'review': reviewController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Review submitted!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rate & Review")),
      body: SingleChildScrollView( // Added scroll view to prevent overflow on keyboard popup
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "How was your experience?",
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 30),
            
            // Star Selection Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  onPressed: () => setState(() => rating = index + 1.0),
                );
              }),
            ),
            const SizedBox(height: 30),
            
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(
                labelText: "Write a review (Optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit Review", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}