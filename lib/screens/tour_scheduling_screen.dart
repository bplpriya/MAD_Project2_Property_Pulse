import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

// --- MOCK SERVICE FUNCTION (Replaces Firebase Cloud Function Call) ---
// This function simulates the server-side logic that connects to the Google Calendar API
// to check the seller's availability and prevent double-booking (Challenge 4).
// Added buyerId and sellerId parameters
Future<String> scheduleTourRequest(String propertyId, DateTime selectedTime, String buyerId, String sellerId) async {
  // Simulate network latency for API call
  await Future.delayed(const Duration(seconds: 2));

  // 1. Mock Conflict Detection Logic
  // Conflict if the time is between 10:00 AM and 11:00 AM on the current date + 2 days
  final mockConflictDate = DateTime.now().add(const Duration(days: 2));
  final isConflictTime = selectedTime.hour == 10 && selectedTime.minute == 0;
  final isConflictDay = selectedTime.year == mockConflictDate.year &&
      selectedTime.month == mockConflictDate.month &&
      selectedTime.day == mockConflictDate.day;

  if (isConflictDay && isConflictTime) {
    return 'conflict'; // Conflict detected by Cloud Function
  }
  
  // 2. Mock Firestore Transaction Logging (To be replaced by Cloud Function logic)
  try {
    // Log the successful booking request in Firestore
    await FirebaseFirestore.instance.collection('tours').add({
      'propertyId': propertyId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'scheduledTime': selectedTime,
      'bookedAt': FieldValue.serverTimestamp(),
      'status': 'pending', // Initially pending until confirmed by seller/calendar
    });
    print('Tour booking successfully logged for: $propertyId at $selectedTime');
  } catch (e) {
    print('Error logging mock tour booking: $e');
  }

  // Successful Booking
  return 'success';
}

// --- TOUR SCHEDULING SCREEN ---
class TourSchedulingScreen extends StatefulWidget {
  final String propertyId;
  final String propertyTitle;
  final String sellerId; // NEW: Added required sellerId

  const TourSchedulingScreen({
    super.key,
    required this.propertyId,
    required this.propertyTitle,
    required this.sellerId, // NEW: Added required sellerId
  });

  @override
  State<TourSchedulingScreen> createState() => _TourSchedulingScreenState();
}

class _TourSchedulingScreenState extends State<TourSchedulingScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  final List<String> _availableTimes = ['9:00 AM', '10:00 AM', '11:00 AM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM'];
  bool _isBooking = false;
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Default selection to the first available time
    if (_availableTimes.isNotEmpty) {
      _selectedTime = _availableTimes.first;
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = _availableTimes.isNotEmpty ? _availableTimes.first : null;
    });
  }

  void _selectTimeSelection(String time) {
    setState(() {
      _selectedTime = time;
    });
  }

  DateTime _combineDateTime(DateTime date, String time) {
    // Parse time string (e.g., '3:00 PM') into hour/minute
    final parts = time.split(' ');
    final timeOfDay = time.split(':');
    
    // Safety check for parsing 
    if (timeOfDay.length < 2) return date; 

    int hour = int.parse(timeOfDay[0].replaceAll(RegExp(r'[^0-9]'), '')); // Extract hour part cleanly
    final minutePart = timeOfDay[1].substring(0, 2); // Get '00' or '30' part
    final minute = int.parse(minutePart);
    final period = parts.length > 1 ? parts[1].toUpperCase() : '';

    if (period == 'PM' && hour != 12) {
      hour += 12;
    }
    if (period == 'AM' && hour == 12) {
      hour = 0; // Midnight (12 AM)
    }
    
    // Ensure hour is within 0-23 range
    hour = hour % 24; 

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }


  Future<void> _handleBooking() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot.')),
      );
      return;
    }
    
    final buyerId = _currentUserId;
    if (buyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to schedule a tour.')),
      );
      return;
    }

    final tourDateTime = _combineDateTime(_selectedDate, _selectedTime!);
    
    if (tourDateTime.isBefore(DateTime.now().add(const Duration(hours: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot at least 1 hour in the future.')),
      );
      return;
    }

    setState(() {
      _isBooking = true;
    });

    try {
      final result = await scheduleTourRequest(
        widget.propertyId, 
        tourDateTime, 
        buyerId, // Current user is the buyer
        widget.sellerId, // Seller is passed from the property model
      );

      String message;
      if (result == 'conflict') {
        message = 'The seller is unavailable at this time. Please choose another slot.';
      } else {
        message = 'Tour successfully requested for ${widget.propertyTitle} on ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year} at $_selectedTime!';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result == 'success' ? Colors.green : Colors.red,
        ),
      );
      
      if (result == 'success') {
        // Optionally navigate back after successful booking
        Navigator.pop(context);
      }

    } catch (e) {
      print('Booking error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to schedule tour. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter dates to show the next 7 days, starting tomorrow
    final now = DateTime.now();
    final nextSevenDays = List.generate(7, (i) => now.add(Duration(days: i + 1)));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Schedule Virtual Tour"),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Property Title & Seller Info ---
            Text(
              widget.propertyTitle,
              style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
            const SizedBox(height: 5),
            Text(
              'Property ID: ${widget.propertyId}',
              style: theme.textTheme.bodyMedium!.copyWith(color: Colors.grey),
            ),
            Text(
              'Seller ID: ${widget.sellerId}',
              style: theme.textTheme.bodySmall!.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // --- Date Selection ---
            Text(
              'Select a Date',
              style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: nextSevenDays.length,
                itemBuilder: (context, index) {
                  final date = nextSevenDays[index];
                  final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: InkWell(
                      onTap: () => _selectDate(date),
                      child: Container(
                        width: 70,
                        decoration: BoxDecoration(
                          color: isSelected ? theme.primaryColor : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? theme.primaryColor : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              '${date.month}/${date.year % 100}', // e.g., 12/25
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white70 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 40),

            // --- Time Selection ---
            Text(
              'Select a Time (Available Slots)',
              style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: _availableTimes.map((time) {
                final isSelected = time == _selectedTime;
                return ChoiceChip(
                  label: Text(time),
                  selected: isSelected,
                  selectedColor: theme.primaryColor,
                  backgroundColor: Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _selectTimeSelection(time);
                    }
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 40),

            // --- Booking Button ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _handleBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 5,
                ),
                child: _isBooking
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Checking Availability...', style: TextStyle(fontSize: 18)),
                        ],
                      )
                    : const Text(
                        'Confirm Tour Booking',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}