import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _user = FirebaseAuth.instance.currentUser;

  CollectionReference<Map<String, dynamic>> get _categoriesCollection =>
      FirebaseFirestore.instance.collection('categories');

  CollectionReference<Map<String, dynamic>> get _expensesCollection =>
      FirebaseFirestore.instance.collection('expenses');

  // Returns spending per category for the current month
  Future<Map<String, double>> _fetchMonthlySpendingByCategory() async {
    if (_user == null) return {};
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final snap = await _expensesCollection
        .where('userId', isEqualTo: _user!.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final Map<String, double> totals = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      final name = (data['categoryName'] ?? 'Unknown').toString();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      totals[name] = (totals[name] ?? 0) + amount;
    }
    return totals;
  }

  void _showAddCategoryDialog({
    String? existingId,
    String? existingName,
    double? existingBudget,
  }) {
    final nameController = TextEditingController(text: existingName ?? '');
    final budgetController = TextEditingController(
      text: existingBudget != null && existingBudget > 0
          ? existingBudget.toStringAsFixed(2)
          : '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(existingId == null ? 'Add Category' : 'Edit Category'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: budgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Monthly Budget (optional)',
                    prefixText: 'RM ',
                    hintText: 'e.g. 300.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Set a budget to track spending per category.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);

                      final name = nameController.text.trim();
                      final budgetText = budgetController.text.trim();
                      final budget = budgetText.isEmpty
                          ? 0.0
                          : double.tryParse(budgetText) ?? 0.0;

                      try {
                        if (existingId == null) {
                          await _categoriesCollection.add({
                            'userId': _user!.uid,
                            'name': name,
                            'budget': budget,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } else {
                          await _categoriesCollection.doc(existingId).update({
                            'name': name,
                            'budget': budget,
                          });
                        }
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(existingId == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(String categoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Category?'),
        content: const Text(
          'Expenses in this category will not be deleted, but will show as uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _categoriesCollection.doc(categoryId).delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showAddCategoryDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1D9E75),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<Map<String, double>>(
        future: _fetchMonthlySpendingByCategory(),
        builder: (context, spendingSnapshot) {
          final spendingByCategory = spendingSnapshot.data ?? {};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _categoriesCollection
                .where('userId', isEqualTo: _user!.uid)
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final categories = snapshot.data!.docs;

              if (categories.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No categories yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a category to start\norganising your expenses.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _showAddCategoryDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Category'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D9E75),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Summary counts
              int overBudgetCount = 0;
              int nearBudgetCount = 0;
              for (final doc in categories) {
                final data = doc.data();
                final catBudget = (data['budget'] as num?)?.toDouble() ?? 0.0;
                if (catBudget <= 0) continue;
                final spent = spendingByCategory[data['name']] ?? 0.0;
                final pct = spent / catBudget;
                if (pct >= 1.0) {
                  overBudgetCount++;
                } else if (pct >= 0.85) {
                  nearBudgetCount++;
                }
              }

              return Column(
                children: [
                  if (overBudgetCount > 0 || nearBudgetCount > 0)
                    _buildAlertSummaryBar(overBudgetCount, nearBudgetCount),

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = categories[index];
                        final data = doc.data();
                        final name = (data['name'] ?? 'Unnamed').toString();
                        final catBudget =
                            (data['budget'] as num?)?.toDouble() ?? 0.0;
                        final spent = spendingByCategory[name] ?? 0.0;

                        return _buildCategoryCard(
                          doc.id,
                          name,
                          catBudget,
                          spent,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAlertSummaryBar(int over, int near) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: over > 0 ? Colors.red.shade50 : Colors.orange.shade50,
      child: Row(
        children: [
          Icon(
            over > 0 ? Icons.error_outline : Icons.warning_amber,
            size: 18,
            color: over > 0 ? Colors.red.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                if (over > 0)
                  '$over ${over == 1 ? 'category' : 'categories'} over budget',
                if (near > 0)
                  '$near ${near == 1 ? 'category' : 'categories'} near limit',
              ].join(' • '),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: over > 0 ? Colors.red.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String id,
    String name,
    double budget,
    double spent,
  ) {
    final hasBudget = budget > 0;
    final progress = hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final isOver = hasBudget && spent > budget;
    final isNear = hasBudget && !isOver && progress >= 0.85;

    final Color statusColor = isOver
        ? Colors.red
        : isNear
        ? Colors.orange
        : const Color(0xFF1D9E75);

    final Color borderColor = isOver
        ? Colors.red.shade200
        : isNear
        ? Colors.orange.shade200
        : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.label_outline,
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (isOver)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                'OVER BUDGET',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            )
                          else if (isNear)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                'NEAR LIMIT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasBudget
                            ? 'RM ${spent.toStringAsFixed(2)} / RM ${budget.toStringAsFixed(2)}'
                            : spent > 0
                            ? 'RM ${spent.toStringAsFixed(2)} spent'
                            : 'No spending yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOver
                              ? Colors.red.shade600
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Color(0xFF6B7280),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddCategoryDialog(
                        existingId: id,
                        existingName: name,
                        existingBudget: budget,
                      );
                    } else if (value == 'delete') {
                      _deleteCategory(id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (hasBudget) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade100,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% used',
                    style: TextStyle(fontSize: 11, color: statusColor),
                  ),
                  Text(
                    isOver
                        ? '+RM ${(spent - budget).toStringAsFixed(2)} over'
                        : 'RM ${(budget - spent).toStringAsFixed(2)} left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOver
                          ? Colors.red.shade600
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
