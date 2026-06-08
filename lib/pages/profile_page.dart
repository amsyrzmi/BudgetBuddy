import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'categories_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _green = Color(0xFF1D9E75);
  static const _dark = Color(0xFF111827);
  static const _grey = Color(0xFF6B7280);
  static const _bg = Color(0xFFF9FAFB);

  // ── Firestore refs ─────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _categoriesCollection() =>
      FirebaseFirestore.instance.collection('categories');

  CollectionReference<Map<String, dynamic>> _expensesCollection() =>
      FirebaseFirestore.instance.collection('expenses');

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime get _startOfMonth {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  DateTime get _endOfMonth {
    final n = DateTime.now();
    return DateTime(n.year, n.month + 1, 1);
  }

  String _formatMoney(double v) => 'RM ${v.toStringAsFixed(2)}';

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ── Edit budget bottom sheet ───────────────────────────────────────────────

  void _editBudget(BuildContext context, String uid, double current) {
    final ctrl = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(2) : '',
    );
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Monthly Budget',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Set a limit to track your monthly spending.',
                  style: TextStyle(fontSize: 13, color: _grey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Budget Amount',
                    prefixText: 'RM ',
                    hintText: 'e.g. 1500.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _green, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter an amount';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheet(() => saving = true);
                          final value = double.tryParse(ctrl.text.trim()) ?? 0;
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({'monthlyBudget': value});
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Budget',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit display name ──────────────────────────────────────────────────────

  void _editName(BuildContext context, String uid, String current) {
    final ctrl = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Edit Display Name',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _green, width: 2),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheet(() => saving = true);
                          final newName = ctrl.text.trim();
                          await Future.wait([
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({'name': newName}),
                            FirebaseAuth.instance.currentUser
                                    ?.updateDisplayName(newName) ??
                                Future.value(),
                          ]);
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Name',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete all data confirmation ───────────────────────────────────────────

  void _confirmDeleteData(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete All Data'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your expenses and categories. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAllData(context, uid);
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllData(BuildContext context, String uid) async {
    final expSnap = await _expensesCollection()
        .where('userId', isEqualTo: uid)
        .get();
    final catSnap = await _categoriesCollection()
        .where('userId', isEqualTo: uid)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final d in expSnap.docs) batch.delete(d.reference);
    for (final d in catSnap.docs) batch.delete(d.reference);
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in')));
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: _dark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef(user.uid).snapshots(),
        builder: (context, userSnap) {
          final data = userSnap.data?.data() ?? {};
          final name = (data['name'] ?? user.displayName ?? 'User')
              .toString()
              .trim();
          final email = (data['email'] ?? user.email ?? '').toString();
          final budget = (data['monthlyBudget'] as num?)?.toDouble() ?? 0.0;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _expensesCollection()
                .where('userId', isEqualTo: user.uid)
                .where(
                  'date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfMonth),
                )
                .where('date', isLessThan: Timestamp.fromDate(_endOfMonth))
                .snapshots(),
            builder: (context, expSnap) {
              double totalSpent = 0;
              for (final doc in expSnap.data?.docs ?? []) {
                totalSpent += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
              }
              final txCount = expSnap.data?.docs.length ?? 0;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _categoriesCollection()
                    .where('userId', isEqualTo: user.uid)
                    .snapshots(),
                builder: (context, catSnap) {
                  final catCount = catSnap.data?.docs.length ?? 0;

                  final remaining = budget - totalSpent;
                  final budgetPct = budget > 0
                      ? (totalSpent / budget).clamp(0.0, 1.0)
                      : 0.0;
                  final isOver = budget > 0 && totalSpent > budget;
                  final isNear = budget > 0 && !isOver && budgetPct >= 0.85;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Avatar + name card ───────────────────────
                        _buildProfileHeader(
                          context,
                          user.uid,
                          name,
                          email,
                          user.emailVerified,
                        ),

                        const SizedBox(height: 20),

                        // ── Budget overview card ─────────────────────
                        _buildBudgetCard(
                          context: context,
                          uid: user.uid,
                          budget: budget,
                          totalSpent: totalSpent,
                          remaining: remaining,
                          budgetPct: budgetPct,
                          isOver: isOver,
                          isNear: isNear,
                        ),

                        const SizedBox(height: 20),

                        // ── Quick stats row ──────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _quickStat(
                                icon: Icons.receipt_long_outlined,
                                label: 'Transactions',
                                value: '$txCount',
                                color: const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _quickStat(
                                icon: Icons.category_outlined,
                                label: 'Categories',
                                value: '$catCount',
                                color: const Color(0xFF8B5CF6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _quickStat(
                                icon: Icons.savings_outlined,
                                label: 'Saved',
                                value: budget > 0 && !isOver
                                    ? _formatMoney(remaining)
                                    : '—',
                                color: _green,
                                small: true,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Account section ──────────────────────────
                        _sectionLabel('Account'),
                        const SizedBox(height: 10),
                        _menuTile(
                          icon: Icons.person_outline,
                          title: 'Edit Name',
                          subtitle: name,
                          onTap: () => _editName(context, user.uid, name),
                        ),
                        _menuTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Monthly Budget',
                          subtitle: budget > 0
                              ? _formatMoney(budget)
                              : 'Not set — tap to configure',
                          onTap: () => _editBudget(context, user.uid, budget),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 12,
                                color: _green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        _menuTile(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          subtitle: email,
                          enabled: false,
                          trailing: user.emailVerified
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : Container(
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
                                    'Unverified',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),

                        const SizedBox(height: 20),

                        // ── App section ──────────────────────────────
                        _sectionLabel('App'),
                        const SizedBox(height: 10),
                        _menuTile(
                          icon: Icons.category_outlined,
                          title: 'Manage Categories',
                          subtitle: '$catCount active',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CategoriesPage(),
                            ),
                          ),
                        ),
                        _menuTile(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Budget alerts & reminders',
                          onTap: () {},
                        ),

                        const SizedBox(height: 20),

                        // ── Danger zone ──────────────────────────────
                        _sectionLabel('Danger Zone'),
                        const SizedBox(height: 10),
                        _menuTile(
                          icon: Icons.delete_outline,
                          title: 'Delete All Data',
                          subtitle:
                              'Permanently remove all expenses & categories',
                          iconColor: Colors.red,
                          titleColor: Colors.red,
                          onTap: () => _confirmDeleteData(context, user.uid),
                        ),

                        const SizedBox(height: 28),

                        // ── Logout ───────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _logout(context),
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.red,
                              size: 18,
                            ),
                            label: const Text(
                              'Logout',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.red.shade200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildProfileHeader(
    BuildContext context,
    String uid,
    String name,
    String email,
    bool verified,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _green,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _editName(context, uid, name),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: _grey),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      verified ? Icons.verified_user : Icons.gpp_maybe_outlined,
                      size: 13,
                      color: verified ? _green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      verified ? 'Verified account' : 'Email not verified',
                      style: TextStyle(
                        fontSize: 11,
                        color: verified ? _green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard({
    required BuildContext context,
    required String uid,
    required double budget,
    required double totalSpent,
    required double remaining,
    required double budgetPct,
    required bool isOver,
    required bool isNear,
  }) {
    final Color progressColor = isOver
        ? Colors.red
        : isNear
        ? Colors.orange
        : _green;
    final Color cardBorder = isOver
        ? Colors.red.shade200
        : isNear
        ? Colors.orange.shade200
        : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOver
                        ? Icons.warning_amber
                        : isNear
                        ? Icons.warning_amber_outlined
                        : Icons.account_balance_wallet_outlined,
                    color: progressColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOver
                        ? 'Budget Exceeded!'
                        : isNear
                        ? 'Near Budget Limit'
                        : 'Monthly Budget',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _editBudget(context, uid, budget),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: _green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (budget == 0) ...[
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 36,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No budget set',
                    style: TextStyle(color: _grey, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _editBudget(context, uid, 0),
                    child: const Text(
                      'Tap to set a monthly budget',
                      style: TextStyle(
                        color: _green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMoney(totalSpent),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isOver ? Colors.red : _dark,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/ ${_formatMoney(budget)}',
                    style: const TextStyle(fontSize: 14, color: _grey),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: budgetPct,
                minHeight: 10,
                backgroundColor: Colors.grey.shade100,
                color: progressColor,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(budgetPct * 100).toStringAsFixed(0)}% used',
                  style: TextStyle(fontSize: 12, color: progressColor),
                ),
                Text(
                  isOver
                      ? '+${_formatMoney(totalSpent - budget)} over'
                      : '${_formatMoney(remaining)} left',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOver ? Colors.red : _green,
                  ),
                ),
              ],
            ),

            if (isOver) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You\'ve exceeded your monthly budget by ${_formatMoney(totalSpent - budget)}.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isNear) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Only ${_formatMoney(remaining)} remaining. Slow down your spending!',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _quickStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool small = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: small ? 12 : 15,
              color: _dark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: _grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _grey,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        enabled: enabled,
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? _green).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor ?? _green),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: titleColor ?? _dark,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: _grey),
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing:
            trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, size: 18, color: _grey)
                : null),
      ),
    );
  }
}
