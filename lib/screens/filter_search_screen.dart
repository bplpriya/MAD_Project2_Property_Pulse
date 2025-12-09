// lib/screens/filter_search_screen.dart

import 'package:flutter/material.dart';

class FilterSearchScreen extends StatefulWidget {
  // Callback function to return the filters back to the listings screen
  final Function(String type, int minPrice, int maxPrice) onApplyFilters;
  
  // Optional: Initial filter values to pre-populate the form
  final String initialType;
  final int initialMinPrice;
  final int initialMaxPrice;

  const FilterSearchScreen({
    super.key,
    required this.onApplyFilters,
    this.initialType = 'All',
    this.initialMinPrice = 0,
    this.initialMaxPrice = 999999999, // A large number representing no max
  });

  @override
  State<FilterSearchScreen> createState() => _FilterSearchState();
}

class _FilterSearchState extends State<FilterSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  String? _selectedType;

  final List<String> _propertyTypes = [
    'All',
    'Apartment', 
    'House', 
    'Condo', 
    'Land', 
    'Commercial'
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _minPriceController.text = widget.initialMinPrice.toString();
    
    // FIX APPLIED: Removed conditional check to always display the max price value.
    _maxPriceController.text = widget.initialMaxPrice.toString();
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    if (_formKey.currentState!.validate()) {
      final minPrice = int.tryParse(_minPriceController.text) ?? 0;
      final maxPrice = _maxPriceController.text.isEmpty
          ? 999999999
          : int.tryParse(_maxPriceController.text) ?? 999999999; 

      if (minPrice > maxPrice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum price cannot be greater than maximum price.')),
        );
        return;
      }

      // Using ?? 'All' for null safety on _selectedType
      widget.onApplyFilters(_selectedType ?? 'All', minPrice, maxPrice);
      
      Navigator.pop(context);
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedType = 'All';
      _minPriceController.clear();
      _maxPriceController.clear();
    });
    widget.onApplyFilters('All', 0, 999999999);
    Navigator.pop(context);
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      prefixIcon: const Icon(Icons.attach_money),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Listings'),
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. Property Type Filter ---
              Text(
                'Filter by Property Type',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Property Type',
                  border: OutlineInputBorder(), // Removed redundant const
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedType,
                items: _propertyTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a type' : null,
              ),
              const SizedBox(height: 30),

              // --- 2. Price Range Filters ---
              Text(
                'Filter by Price Range',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _minPriceController,
                decoration: _inputDecoration('Minimum Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Must be a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _maxPriceController,
                decoration: _inputDecoration('Maximum Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Must be a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              // --- Apply Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.filter_alt),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('Apply Filters', style: TextStyle(fontSize: 18)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}