import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  final _user = FirebaseAuth.instance.currentUser;

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String _selectedPaymentMethod = 'Cash';

  // Budget awareness
  double _monthlyBudget = 0.0;
  double _currentMonthSpent = 0.0;
  bool _budgetDataLoaded = false;

  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'QR',
    'Bank Transfer',
    'E-Wallet',
  ];

  CollectionReference<Map<String, dynamic>> get _categoriesCollection =>
      FirebaseFirestore.instance.collection('categories');

  CollectionReference<Map<String, dynamic>> get _expensesCollection =>
      FirebaseFirestore.instance.collection('expenses');

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBudgetData() async {
    if (_user == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 1);

      final expensesSnap = await _expensesCollection
          .where('userId', isEqualTo: _user!.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      double spent = 0;
      for (final doc in expensesSnap.docs) {
        spent += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _monthlyBudget =
              (userDoc.data()?['monthlyBudget'] as num?)?.toDouble() ?? 0.0;
          _currentMonthSpent = spent;
          _budgetDataLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _budgetDataLoaded = true);
    }
  }

  double get _enteredAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  double get _projectedTotal => _currentMonthSpent + _enteredAmount;

  bool get _wouldExceedBudget =>
      _monthlyBudget > 0 && _projectedTotal > _monthlyBudget;

  bool get _isAlreadyOverBudget =>
      _monthlyBudget > 0 && _currentMonthSpent >= _monthlyBudget;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveExpense() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    // Show warning dialog if budget will be exceeded
    if (_wouldExceedBudget) {
      final confirmed = await _showBudgetExceededDialog();
      if (!confirmed) return;
    }

    setState(() => _isLoading = true);

    try {
      await _expensesCollection.add({
        'userId': _user!.uid,
        'amount': double.parse(_amountController.text.trim()),
        'note': _noteController.text.trim().isEmpty
            ? 'Untitled expense'
            : _noteController.text.trim(),
        'categoryId': _selectedCategoryId,
        'categoryName': _selectedCategoryName,
        'paymentMethod': _selectedPaymentMethod,
        'date': Timestamp.fromDate(_selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _wouldExceedBudget
                ? '⚠️ Expense added — you\'ve exceeded your budget!'
                : 'Expense added successfully',
          ),
          backgroundColor: _wouldExceedBudget
              ? Colors.orange
              : const Color(0xFF1D9E75),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save expense: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showBudgetExceededDialog() async {
    final overage = _projectedTotal - _monthlyBudget;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Text('Budget Exceeded'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adding this expense will put you RM ${overage.toStringAsFixed(2)} over your monthly budget.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                _budgetSummaryRow(
                  'Monthly Budget',
                  'RM ${_monthlyBudget.toStringAsFixed(2)}',
                  Colors.grey,
                ),
                _budgetSummaryRow(
                  'Already Spent',
                  'RM ${_currentMonthSpent.toStringAsFixed(2)}',
                  Colors.grey,
                ),
                _budgetSummaryRow(
                  'This Expense',
                  'RM ${_enteredAmount.toStringAsFixed(2)}',
                  Colors.orange,
                ),
                const Divider(),
                _budgetSummaryRow(
                  'Projected Total',
                  'RM ${_projectedTotal.toStringAsFixed(2)}',
                  Colors.red,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Add Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _budgetSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => "${date.day}/${date.month}/${date.year}";

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Expense',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _categoriesCollection
            .where('userId', isEqualTo: _user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load categories'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data!.docs;

          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No categories found.\nCreate categories first.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final validSelectedCategoryId =
              categories.any((doc) => doc.id == _selectedCategoryId)
              ? _selectedCategoryId
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Budget status banner
                  if (_budgetDataLoaded && _monthlyBudget > 0) ...[
                    _buildBudgetStatusBanner(),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'RM ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null) return 'Invalid number';
                      if (amount <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),

                  // Live budget impact preview
                  if (_budgetDataLoaded &&
                      _monthlyBudget > 0 &&
                      _enteredAmount > 0) ...[
                    const SizedBox(height: 8),
                    _buildBudgetImpactPreview(),
                  ],

                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: validSelectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: categories.map((doc) {
                      final data = doc.data();
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text((data['name'] ?? 'Unnamed').toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      final selectedCategory = categories.firstWhere(
                        (doc) => doc.id == value,
                      );
                      setState(() {
                        _selectedCategoryId = value;
                        _selectedCategoryName = selectedCategory
                            .data()['name']
                            ?.toString();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    decoration: InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _paymentMethods.map((method) {
                      return DropdownMenuItem<String>(
                        value: method,
                        child: Text(method),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Note',
                      hintText: 'Example: Lunch at canteen',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month),
                          const SizedBox(width: 12),
                          Text(
                            _formatDate(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _wouldExceedBudget
                          ? Colors.orange
                          : const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_wouldExceedBudget)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(Icons.warning_amber, size: 18),
                                ),
                              Text(
                                _wouldExceedBudget
                                    ? 'Save (Exceeds Budget)'
                                    : 'Save Expense',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetStatusBanner() {
    final remaining = _monthlyBudget - _currentMonthSpent;
    final isOver = _isAlreadyOverBudget;
    final pct = (_currentMonthSpent / _monthlyBudget).clamp(0.0, 1.0);
    final isNearLimit = pct >= 0.85 && !isOver;

    final bgColor = isOver
        ? Colors.red.shade50
        : isNearLimit
        ? Colors.orange.shade50
        : Colors.green.shade50;
    final borderColor = isOver
        ? Colors.red.shade200
        : isNearLimit
        ? Colors.orange.shade200
        : Colors.green.shade200;
    final textColor = isOver
        ? Colors.red.shade700
        : isNearLimit
        ? Colors.orange.shade700
        : Colors.green.shade700;
    final icon = isOver
        ? Icons.error_outline
        : isNearLimit
        ? Icons.warning_amber
        : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOver
                      ? 'Budget already exceeded by RM ${(-remaining).toStringAsFixed(2)}'
                      : isNearLimit
                      ? 'Only RM ${remaining.toStringAsFixed(2)} left this month'
                      : 'RM ${remaining.toStringAsFixed(2)} remaining this month',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.white,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetImpactPreview() {
    final projected = _projectedTotal;
    final exceeds = _wouldExceedBudget;
    final overage = projected - _monthlyBudget;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: exceeds ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: exceeds ? Colors.red.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            exceeds ? Icons.trending_up : Icons.info_outline,
            size: 16,
            color: exceeds ? Colors.red : Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exceeds
                  ? 'This will exceed your budget by RM ${overage.toStringAsFixed(2)}'
                  : 'Projected total: RM ${projected.toStringAsFixed(2)} / RM ${_monthlyBudget.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: exceeds ? Colors.red.shade700 : Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
