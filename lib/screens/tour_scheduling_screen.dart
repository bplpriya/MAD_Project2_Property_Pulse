import 'package:flutter/material.dart';

// --- MOCK SERVICE FUNCTION (Replaces Firebase Cloud Function Call) ---
// This function simulates the server-side logic that connects to the Google Calendar API
// to check the seller's availability and prevent double-booking (Challenge 4).
Future<String> scheduleTourRequest(String propertyId, DateTime selectedTime) async {
  // Simulate network latency for API call
  await Future.delayed(const Duration(seconds: 2));

  // Mock Conflict Detection Logic
  // Conflict if the time is between 10:00 AM and 11:00 AM on the current date + 2 days
  final mockConflictDate = DateTime.now().add(const Duration(days: 2));
  final isConflictTime = selectedTime.hour == 10 && selectedTime.minute == 0;
  final isConflictDay = selectedTime.year == mockConflictDate.year &&
      selectedTime.month == mockConflictDate.month &&
      selectedTime.day == mockConflictDate.day;

  if (isConflictDay && isConflictTime) {
    return 'conflict'; // Conflict detected by Cloud Function
  }
  
  // Successful Booking
  return 'success';
}

// --- TOUR SCHEDULING SCREEN ---
class TourSchedulingScreen extends StatefulWidget {
  final String propertyId;
  final String propertyTitle;

  const TourSchedulingScreen({
    super.key,
    required this.propertyId,
    required this.propertyTitle,
  });

  @override
  State<TourSchedulingScreen> createState() => _TourSchedulingScreenState();
}

class _TourSchedulingScreenState extends State<TourSchedulingScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _selectedTime;
  bool _isBooking = false;

  // Mock availability slots for demonstration
  final List<TimeOfDay> availableSlots = [
    const TimeOfDay(hour: 9, minute: 0),
    const TimeOfDay(hour: 10, minute: 0), // Mock Conflict Slot
    const TimeOfDay(hour: 11, minute: 0),
    const TimeOfDay(hour: 13, minute: 0),
    const TimeOfDay(hour: 14, minute: 0),
    const TimeOfDay(hour: 16, minute: 0),
  ];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset time selection on new date
      });
    }
  }

  void _handleTimeSelection(TimeOfDay time) {
    setState(() {
      _selectedTime = time;
    });
  }

  void _handleBooking() async {
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an available time slot.')),
      );
      return;
    }

    setState(() {
      _isBooking = true;
    });

    final bookingDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      // --- CRITICAL CALL: Simulate Cloud Function for Conflict Detection ---
      final result = await scheduleTourRequest(widget.propertyId, bookingDateTime);

      if (result == 'success') {
        _showSuccessDialog();
      } else if (result == 'conflict') {
        _showConflictDialog();
      } else {
        _showError('Scheduling failed due to a server error.');
      }
    } catch (e) {
      _showError('Network error: Could not complete scheduling.');
    } finally {
      setState(() {
        _isBooking = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tour Confirmed!'),
        content: Text('Your tour for ${widget.propertyTitle} has been successfully booked for $_selectedDate at ${_selectedTime!.format(context)}. Check your notifications for a reminder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), // Go back to home/listings
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConflictDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conflict Detected'),
        content: const Text('The seller is already booked for the selected time. Please select another slot.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Select Another Time'),
          ),
        ],
      ),
    );
  }
  
  void _showError(String message) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Virtual Tour'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Tour for:',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.propertyTitle,
              style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
            const Divider(height: 30),

            // --- Date Picker ---
            Text('1. Select Date', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            InkWell(
              onTap: _isBooking ? null : () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.primaryColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Date: ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const Icon(Icons.edit_calendar, color: Colors.teal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // --- Time Slot Picker ---
            Text('2. Select Time Slot (All times are local)', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: availableSlots.map((time) {
                final isSelected = _selectedTime == time;
                final isConflictMock = _selectedDate.day == DateTime.now().add(const Duration(days: 2)).day && time.hour == 10;
                
                return ChoiceChip(
                  label: Text(time.format(context)),
                  selected: isSelected,
                  selectedColor: theme.primaryColor,
                  disabledColor: isConflictMock ? Colors.red.shade100 : Colors.grey.shade200,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  avatar: isConflictMock ? const Icon(Icons.cancel, color: Colors.red, size: 18) : null,
                  onSelected: isConflictMock || _isBooking ? null : (selected) {
                    if (selected) {
                      _handleTimeSelection(time);
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