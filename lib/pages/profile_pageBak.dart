import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'categories_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  DocumentReference<Map<String, dynamic>> _userRef(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _categoriesCollection() {
    return FirebaseFirestore.instance.collection('categories');
  }

  CollectionReference<Map<String, dynamic>> _expensesCollection() {
    return FirebaseFirestore.instance.collection('expenses');
  }

  Future<double> _getMonthlySpent(String uid) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    final snap = await _expensesCollection()
        .where('userId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    double total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  void _editBudget(BuildContext context, String uid, double currentBudget) {
    final controller = TextEditingController(
      text: currentBudget.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Update Monthly Budget",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Monthly Budget (RM)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  final value = double.tryParse(controller.text) ?? 0;

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'monthlyBudget': value});

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text("Save"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("No user logged in")));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userRef(user.uid).snapshots(),
      builder: (context, userSnap) {
        final data = userSnap.data?.data() ?? {};

        final name = (data['name'] ?? user.displayName ?? 'User')
            .toString()
            .trim();

        final email = (data['email'] ?? user.email ?? '').toString();
        final budget = (data['monthlyBudget'] as num?)?.toDouble() ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "Profile",
              style: TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFFF3F4F6),
                      child: Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(email),
                  ],
                ),

                const SizedBox(height: 30),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _categoriesCollection()
                      .where('userId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, catSnap) {
                    final count = catSnap.data?.docs.length ?? 0;

                    return _infoCard(
                      "Active Categories",
                      "$count",
                      Icons.category,
                    );
                  },
                ),

                const SizedBox(height: 12),

                FutureBuilder<double>(
                  future: _getMonthlySpent(user.uid),
                  builder: (context, spentSnap) {
                    final spent = spentSnap.data ?? 0;
                    final remaining = budget - spent;
                    final usage = budget == 0
                        ? 0
                        : (spent / budget).clamp(0, 1);

                    Color statusColor;
                    String status;

                    if (usage < 0.6) {
                      status = "Good 👍";
                      statusColor = Colors.green;
                    } else if (usage < 0.9) {
                      status = "Warning ⚠";
                      statusColor = Colors.orange;
                    } else {
                      status = "Critical 🔴";
                      statusColor = Colors.red;
                    }

                    return Column(
                      children: [
                        _infoCard(
                          "Monthly Budget",
                          "RM ${budget.toStringAsFixed(2)}",
                          Icons.account_balance_wallet,
                          onTap: () => _editBudget(context, user.uid, budget),
                        ),
                        const SizedBox(height: 12),
                        _infoCard(
                          "Spent This Month",
                          "RM ${spent.toStringAsFixed(2)}",
                          Icons.trending_down,
                        ),
                        const SizedBox(height: 12),
                        _infoCard(
                          "Remaining",
                          "RM ${remaining.toStringAsFixed(2)}",
                          Icons.savings,
                        ),
                        const SizedBox(height: 12),
                        _infoCard("Budget Status", status, Icons.analytics),
                        if (spent > budget && budget > 0)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              "⚠ You have exceeded your monthly budget!",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 30),

                _settingsTile(
                  context,
                  Icons.category_outlined,
                  "Manage Categories",
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoriesPage()),
                    );
                  },
                ),

                _settingsTile(context, Icons.security, "Security & PIN", () {}),

                const SizedBox(height: 30),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () => _logout(context),
                    child: const Text(
                      "Logout",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCard(
    String title,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF1D9E75)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.white,
        leading: Icon(icon, color: const Color(0xFF1D9E75)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
