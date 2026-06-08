import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_expense_page.dart';
import 'categories_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  CollectionReference<Map<String, dynamic>> _expensesCollection() =>
      FirebaseFirestore.instance.collection('expenses');

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  DateTime _startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime _startOfNextMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 1);

  String _formatMoney(double value) => 'RM ${value.toStringAsFixed(2)}';

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  IconData _paymentMethodIcon(String method) {
    switch (method) {
      case 'Cash':
        return Icons.money;
      case 'Card':
        return Icons.credit_card;
      case 'QR':
        return Icons.qr_code;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'E-Wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt_long;
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    await _expensesCollection().doc(expenseId).delete();
  }

  void _openAddExpense(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExpensePage()),
    );
  }

  void _openCategories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoriesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in')));
    }

    final now = DateTime.now();
    final start = _startOfMonth(now);
    final next = _startOfNextMonth(now);

    final expenseQuery = _expensesCollection()
        .where('userId', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(next))
        .orderBy('date', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(text: 'BudgetBuddy'),
              TextSpan(
                text: '.',
                style: TextStyle(color: Color(0xFF1D9E75)),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none, size: 22),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef(user.uid).snapshots(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data() ?? {};
          final displayName = (user.displayName?.trim().isNotEmpty == true)
              ? user.displayName!.trim()
              : (userData['name'] ?? 'User').toString();

          final monthlyBudget =
              (userData['monthlyBudget'] as num?)?.toDouble() ?? 0.0;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: expenseQuery.snapshots(),
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.hasError) {
                return const Center(
                  child: Text('Failed to load dashboard data'),
                );
              }

              if (!expenseSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final expenses = expenseSnapshot.data!.docs;

              double totalSpent = 0.0;
              final Map<String, double> categoryTotals = {};

              for (final doc in expenses) {
                final data = doc.data();
                final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final categoryName = (data['categoryName'] ?? 'Uncategorized')
                    .toString();

                totalSpent += amount;
                categoryTotals[categoryName] =
                    (categoryTotals[categoryName] ?? 0.0) + amount;
              }

              final remainingBudget = monthlyBudget > 0
                  ? (monthlyBudget - totalSpent)
                  : 0.0;

              final budgetProgress = monthlyBudget > 0
                  ? (totalSpent / monthlyBudget).clamp(0.0, 1.0)
                  : 0.0;

              final isOverBudget =
                  monthlyBudget > 0 && totalSpent > monthlyBudget;
              final isNearBudget =
                  monthlyBudget > 0 && !isOverBudget && budgetProgress >= 0.85;

              final sortedCategories = categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final recentExpenses = expenses.take(5).toList();

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Hello, $displayName',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Here is your spending summary for ${_formatDate(start)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Budget Alert Banners ──
                  if (isOverBudget) ...[
                    _buildOverBudgetBanner(totalSpent, monthlyBudget, context),
                    const SizedBox(height: 16),
                  ] else if (isNearBudget) ...[
                    _buildNearBudgetBanner(
                      totalSpent,
                      monthlyBudget,
                      budgetProgress,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Summary Card ──
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isOverBudget
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This Month',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatMoney(totalSpent),
                          style: TextStyle(
                            color: isOverBudget
                                ? Colors.red.shade300
                                : Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _miniStat(
                              'Budget',
                              monthlyBudget > 0
                                  ? _formatMoney(monthlyBudget)
                                  : 'Not set',
                              Colors.greenAccent,
                            ),
                            const Spacer(),
                            _miniStat(
                              'Remaining',
                              monthlyBudget > 0
                                  ? _formatMoney(remainingBudget)
                                  : 'Set budget',
                              isOverBudget
                                  ? Colors.red.shade300
                                  : isNearBudget
                                  ? Colors.orangeAccent
                                  : Colors.lightGreenAccent,
                            ),
                            const Spacer(),
                            _miniStat(
                              'Expenses',
                              expenses.length.toString(),
                              Colors.white,
                            ),
                          ],
                        ),
                        if (monthlyBudget > 0) ...[
                          const SizedBox(height: 18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: budgetProgress,
                              minHeight: 10,
                              backgroundColor: Colors.white12,
                              color: isOverBudget
                                  ? Colors.red.shade400
                                  : isNearBudget
                                  ? Colors.orange
                                  : const Color(0xFF1D9E75),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(budgetProgress * 100).toStringAsFixed(0)}% of budget used',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if (isOverBudget)
                                Text(
                                  '+${_formatMoney(totalSpent - monthlyBudget)} over',
                                  style: TextStyle(
                                    color: Colors.red.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Action Cards ──
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          icon: Icons.add_circle_outline,
                          title: 'Add Expense',
                          subtitle: 'Log spending',
                          onTap: () => _openAddExpense(context),
                          urgent: isOverBudget,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionCard(
                          icon: Icons.category_outlined,
                          title: 'Categories',
                          subtitle: 'Manage groups',
                          onTap: () => _openCategories(context),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Category Breakdown ──
                  const Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (sortedCategories.isEmpty)
                    _emptyCard('No expenses yet this month.')
                  else
                    ...sortedCategories.take(5).map((entry) {
                      final percent = totalSpent > 0
                          ? (entry.value / totalSpent).clamp(0.0, 1.0)
                          : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  _formatMoney(entry.value),
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: percent,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                              backgroundColor: Colors.grey.shade100,
                              color: const Color(0xFF1D9E75),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // ── Recent Activity ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openAddExpense(context),
                        child: const Text('Add New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (recentExpenses.isEmpty)
                    _emptyCard('No recent transactions.')
                  else
                    ...recentExpenses.map((doc) {
                      final data = doc.data();
                      final title = (data['note'] ?? 'Untitled expense')
                          .toString();
                      final categoryName =
                          (data['categoryName'] ?? 'Uncategorized').toString();
                      final amount =
                          (data['amount'] as num?)?.toDouble() ?? 0.0;
                      final timestamp = data['date'] as Timestamp?;
                      final date = timestamp?.toDate();

                      return Dismissible(
                        key: ValueKey(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.only(right: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete expense?'),
                                  content: const Text(
                                    'This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) async {
                          await _deleteExpense(doc.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Expense deleted')),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _paymentMethodIcon(
                                  (data['paymentMethod'] ?? '').toString(),
                                ),
                                size: 20,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF111827),
                              ),
                            ),
                            subtitle: Text(
                              date == null
                                  ? categoryName
                                  : '$categoryName • ${data['paymentMethod'] ?? 'Unknown'} • ${_formatDate(date)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              '-${_formatMoney(amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$title in $categoryName'),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOverBudgetBanner(
    double spent,
    double budget,
    BuildContext context,
  ) {
    final overage = spent - budget;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber,
              color: Colors.red.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🚨 Monthly Budget Exceeded!',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'You\'ve overspent by ${_formatMoney(overage)} this month.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearBudgetBanner(double spent, double budget, double progress) {
    final remaining = budget - spent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber,
              color: Colors.orange.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Approaching Budget Limit',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Only ${_formatMoney(remaining)} left (${(progress * 100).toStringAsFixed(0)}% used).',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF6B7280))),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool urgent = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: urgent ? Colors.orange.shade300 : Colors.grey.shade200,
            width: urgent ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: urgent ? Colors.orange : const Color(0xFF1D9E75)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
