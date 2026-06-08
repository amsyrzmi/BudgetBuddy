import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  DateTime _selectedMonth = DateTime.now();
  late TabController _tabController;

  static const _green = Color(0xFF1D9E75);
  static const _dark = Color(0xFF111827);
  static const _grey = Color(0xFF6B7280);

  // Palette for category bars / legend dots
  static const _palette = [
    Color(0xFF1D9E75),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatMonth(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _shortMonth(DateTime d) {
    const m = [
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
    return m[d.month - 1];
  }

  DateTime get _startOfMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month, 1);

  DateTime get _endOfMonth =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);

  int get _daysInMonth => _endOfMonth.difference(_startOfMonth).inDays;

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _selectedMonth.year == n.year && _selectedMonth.month == n.month;
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
        1,
      );
    });
  }

  Color _paletteColor(int index) => _palette[index % _palette.length];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        title: const Text(
          'Analytics',
          style: TextStyle(
            color: _dark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _green,
          unselectedLabelColor: _grey,
          indicatorColor: _green,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Breakdown'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnap) {
          final monthlyBudget =
              (userSnap.data?.data()?['monthlyBudget'] as num?)?.toDouble() ??
              0.0;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('expenses')
                .where('userId', isEqualTo: user.uid)
                .where(
                  'date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfMonth),
                )
                .where('date', isLessThan: Timestamp.fromDate(_endOfMonth))
                .orderBy('date', descending: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              // ── Aggregate data ───────────────────────────────────────────
              double total = 0;
              final Map<String, double> categoryTotals = {};
              final Map<String, double> paymentTotals = {};
              final Map<int, double> dailyTotals = {}; // day-of-month → amount
              final Map<int, double> weeklyTotals = {}; // week index → amount

              for (final doc in docs) {
                final d = doc.data();
                final amount = (d['amount'] as num?)?.toDouble() ?? 0;
                final cat = (d['categoryName'] ?? 'Unknown').toString();
                final pay = (d['paymentMethod'] ?? 'Unknown').toString();
                final ts = d['date'] as Timestamp?;
                final date = ts?.toDate();

                total += amount;
                categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
                paymentTotals[pay] = (paymentTotals[pay] ?? 0) + amount;

                if (date != null) {
                  final day = date.day;
                  dailyTotals[day] = (dailyTotals[day] ?? 0) + amount;
                  // Week 0-4
                  final week = ((day - 1) / 7).floor();
                  weeklyTotals[week] = (weeklyTotals[week] ?? 0) + amount;
                }
              }

              final isOver = monthlyBudget > 0 && total > monthlyBudget;
              final isNear =
                  monthlyBudget > 0 &&
                  !isOver &&
                  (total / monthlyBudget) >= 0.85;

              final sortedCats = categoryTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final sortedPays = paymentTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              // ── Average daily spend ──────────────────────────────────────
              final today = _isCurrentMonth ? DateTime.now().day : _daysInMonth;
              final avgDaily = today > 0 ? total / today : 0.0;

              // ── Projected end-of-month ───────────────────────────────────
              final projected = _isCurrentMonth && today > 0
                  ? (total / today) * _daysInMonth
                  : total;

              // ── Largest single expense ───────────────────────────────────
              double maxExpense = 0;
              String maxNote = '';
              for (final doc in docs) {
                final d = doc.data();
                final amt = (d['amount'] as num?)?.toDouble() ?? 0;
                if (amt > maxExpense) {
                  maxExpense = amt;
                  maxNote = (d['note'] ?? 'Untitled').toString();
                }
              }

              return Column(
                children: [
                  // ── Month navigation ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _navBtn(Icons.chevron_left, () => _changeMonth(-1)),
                        Text(
                          _formatMonth(_selectedMonth),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        _navBtn(Icons.chevron_right, () => _changeMonth(1)),
                      ],
                    ),
                  ),

                  // ── Budget alert banners ─────────────────────────────────
                  if (isOver) ...[
                    _budgetBanner(
                      icon: Icons.error_outline,
                      color: Colors.red,
                      title: 'Monthly Budget Exceeded!',
                      subtitle:
                          'Over by RM ${(total - monthlyBudget).toStringAsFixed(2)} '
                          '(Budget: RM ${monthlyBudget.toStringAsFixed(2)})',
                    ),
                  ] else if (isNear) ...[
                    _budgetBanner(
                      icon: Icons.warning_amber,
                      color: Colors.orange,
                      title:
                          'Approaching Limit — ${(total / monthlyBudget * 100).toStringAsFixed(0)}% used',
                      subtitle:
                          'RM ${(monthlyBudget - total).toStringAsFixed(2)} remaining this month',
                    ),
                  ],

                  // ── Tab views ────────────────────────────────────────────
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Tab 1: Overview ──────────────────────────────
                        _buildOverviewTab(
                          docs: docs,
                          total: total,
                          monthlyBudget: monthlyBudget,
                          isOver: isOver,
                          isNear: isNear,
                          avgDaily: avgDaily,
                          projected: projected,
                          maxExpense: maxExpense,
                          maxNote: maxNote,
                          sortedCats: sortedCats,
                        ),

                        // ── Tab 2: Breakdown ─────────────────────────────
                        _buildBreakdownTab(
                          total: total,
                          sortedCats: sortedCats,
                          sortedPays: sortedPays,
                          docs: docs,
                        ),

                        // ── Tab 3: Trends ────────────────────────────────
                        _buildTrendsTab(
                          dailyTotals: dailyTotals,
                          weeklyTotals: weeklyTotals,
                          total: total,
                          monthlyBudget: monthlyBudget,
                          docs: docs,
                        ),
                      ],
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

  // ── Tab 1: Overview ────────────────────────────────────────────────────────

  Widget _buildOverviewTab({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required double total,
    required double monthlyBudget,
    required bool isOver,
    required bool isNear,
    required double avgDaily,
    required double projected,
    required double maxExpense,
    required String maxNote,
    required List<MapEntry<String, double>> sortedCats,
  }) {
    final budgetProgress = monthlyBudget > 0
        ? (total / monthlyBudget).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero spending card ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isOver ? const Color(0xFF7F1D1D) : _dark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isOver)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                          size: 16,
                        ),
                      ),
                    Text(
                      isOver ? 'Over Budget!' : 'Total Spending',
                      style: TextStyle(
                        color: isOver ? Colors.orange.shade200 : Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'RM ${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isOver ? Colors.red.shade300 : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${docs.length} transaction${docs.length == 1 ? '' : 's'} this month',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (monthlyBudget > 0) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Budget  RM ${monthlyBudget.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        isOver
                            ? '+RM ${(total - monthlyBudget).toStringAsFixed(2)} over'
                            : 'RM ${(monthlyBudget - total).toStringAsFixed(2)} left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOver
                              ? Colors.red.shade300
                              : Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: budgetProgress,
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      color: isOver
                          ? Colors.red.shade400
                          : isNear
                          ? Colors.orange
                          : _green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(budgetProgress * 100).toStringAsFixed(0)}% of budget used',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Stat grid ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.today_outlined,
                  label: 'Avg / Day',
                  value: 'RM ${avgDaily.toStringAsFixed(2)}',
                  color: _green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.trending_up,
                  label: _isCurrentMonth ? 'Projected' : 'Final',
                  value: 'RM ${projected.toStringAsFixed(2)}',
                  color: projected > monthlyBudget && monthlyBudget > 0
                      ? Colors.red
                      : const Color(0xFF3B82F6),
                  subtitle: monthlyBudget > 0 && projected > monthlyBudget
                      ? '⚠ Over budget'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transactions',
                  value: docs.length.toString(),
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.arrow_upward,
                  label: 'Largest Expense',
                  value: 'RM ${maxExpense.toStringAsFixed(2)}',
                  subtitle: maxNote.isNotEmpty ? maxNote : null,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),

          if (docs.isEmpty) ...[
            const SizedBox(height: 40),
            _emptyState(),
          ] else ...[
            const SizedBox(height: 24),

            // ── Top categories preview ───────────────────────────────
            _sectionHeader(
              'Top Categories',
              onTap: () {
                _tabController.animateTo(1);
              },
            ),
            const SizedBox(height: 12),
            ...sortedCats.take(4).toList().asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              final pct = total > 0 ? entry.value / total : 0.0;
              return _miniCategoryRow(
                entry.key,
                entry.value,
                pct,
                _paletteColor(i),
              );
            }),

            const SizedBox(height: 24),

            // ── Recent transactions ──────────────────────────────────
            _sectionHeader('Recent Transactions'),
            const SizedBox(height: 12),
            ...docs.reversed.take(5).map((doc) {
              final d = doc.data();
              final amt = (d['amount'] as num?)?.toDouble() ?? 0;
              final note = (d['note'] ?? 'Untitled').toString();
              final cat = (d['categoryName'] ?? 'Unknown').toString();
              final ts = d['date'] as Timestamp?;
              final date = ts?.toDate();
              return _transactionRow(note, cat, amt, date);
            }),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Breakdown ───────────────────────────────────────────────────────

  Widget _buildBreakdownTab({
    required double total,
    required List<MapEntry<String, double>> sortedCats,
    required List<MapEntry<String, double>> sortedPays,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) {
    if (docs.isEmpty) {
      return Center(child: _emptyState());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Donut-style pie chart (custom painter) ─────────────────
          if (sortedCats.isNotEmpty) ...[
            _sectionHeader('Spending by Category'),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                height: 200,
                width: 200,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: sortedCats
                        .asMap()
                        .entries
                        .map(
                          (e) => _DonutSegment(
                            value: e.value.value,
                            color: _paletteColor(e.key),
                          ),
                        )
                        .toList(),
                    total: total,
                    centerLabel: 'RM ${total.toStringAsFixed(0)}',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: sortedCats.asMap().entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _paletteColor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      e.value.key,
                      style: const TextStyle(fontSize: 12, color: _grey),
                    ),
                  ],
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── Category bar list ──────────────────────────────────
            _sectionHeader('Category Details'),
            const SizedBox(height: 14),
            ...sortedCats.asMap().entries.map((e) {
              final pct = total > 0
                  ? (e.value.value / total).clamp(0.0, 1.0)
                  : 0.0;
              return _detailedCategoryBar(
                e.value.key,
                e.value.value,
                pct,
                _paletteColor(e.key),
                total,
              );
            }),
          ],

          const SizedBox(height: 24),

          // ── Payment method breakdown ───────────────────────────────
          _sectionHeader('By Payment Method'),
          const SizedBox(height: 14),
          ...sortedPays.asMap().entries.map((e) {
            final pct = total > 0
                ? (e.value.value / total).clamp(0.0, 1.0)
                : 0.0;
            return _detailedCategoryBar(
              e.value.key,
              e.value.value,
              pct,
              _paletteColor(e.key + 3),
              total,
            );
          }),
        ],
      ),
    );
  }

  // ── Tab 3: Trends ──────────────────────────────────────────────────────────

  Widget _buildTrendsTab({
    required Map<int, double> dailyTotals,
    required Map<int, double> weeklyTotals,
    required double total,
    required double monthlyBudget,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) {
    if (docs.isEmpty) {
      return Center(child: _emptyState());
    }

    final days = _daysInMonth;
    final maxDaily = dailyTotals.values.fold(0.0, (a, b) => b > a ? b : a);

    // Build weekly summary
    final weekLabels = ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4', 'Wk 5'];
    final weekAmounts = List.generate(5, (i) => weeklyTotals[i] ?? 0.0);
    final maxWeekly = weekAmounts.fold(0.0, (a, b) => b > a ? b : a);

    // Daily budget line
    final dailyBudget = monthlyBudget > 0 ? monthlyBudget / days : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Daily spending bar chart ────────────────────────────────
          _sectionHeader('Daily Spending'),
          const SizedBox(height: 4),
          if (dailyBudget > 0)
            Row(
              children: [
                Container(width: 12, height: 2, color: Colors.orange.shade400),
                const SizedBox(width: 6),
                Text(
                  'Daily budget line  RM ${dailyBudget.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
                ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: CustomPaint(
              size: const Size(double.infinity, 130),
              painter: _BarChartPainter(
                days: days,
                dailyTotals: dailyTotals,
                maxValue: maxDaily == 0 ? 1 : maxDaily,
                barColor: _green,
                dailyBudget: dailyBudget,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Day labels (every 7)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [1, 8, 15, 22, days]
                .map(
                  (d) => Text(
                    '$d',
                    style: const TextStyle(fontSize: 10, color: _grey),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 28),

          // ── Weekly bars ────────────────────────────────────────────
          _sectionHeader('Weekly Summary'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) {
              final amt = weekAmounts[i];
              final frac = maxWeekly > 0
                  ? (amt / maxWeekly).clamp(0.0, 1.0)
                  : 0.0;
              const maxH = 90.0;
              final isMax = amt == maxWeekly && amt > 0;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (amt > 0)
                    Text(
                      'RM ${amt.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMax ? _green : _grey,
                        fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 44,
                    height: frac * maxH,
                    decoration: BoxDecoration(
                      color: isMax ? _green : _green.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weekLabels[i],
                    style: const TextStyle(fontSize: 11, color: _grey),
                  ),
                ],
              );
            }),
          ),

          const SizedBox(height: 28),

          // ── Spending pace card ──────────────────────────────────────
          if (monthlyBudget > 0 && _isCurrentMonth) ...[
            _sectionHeader('Spending Pace'),
            const SizedBox(height: 12),
            _buildPaceCard(total, monthlyBudget, dailyBudget),
          ],

          const SizedBox(height: 28),

          // ── Day-by-day list (top 5 spending days) ──────────────────
          _sectionHeader('Highest Spending Days'),
          const SizedBox(height: 12),
          ...(dailyTotals.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(5)
              .map((e) {
                final date = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month,
                  e.key,
                );
                return _dayRow(date, e.value, maxDaily);
              }),
        ],
      ),
    );
  }

  // ── Pace card ─────────────────────────────────────────────────────────────

  Widget _buildPaceCard(
    double total,
    double monthlyBudget,
    double dailyBudget,
  ) {
    final today = DateTime.now().day;
    final daysLeft = _daysInMonth - today;
    final remaining = monthlyBudget - total;
    final dailyAllowance = daysLeft > 0 ? remaining / daysLeft : 0.0;
    final isOnTrack = remaining >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOnTrack ? Colors.grey.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isOnTrack ? Icons.check_circle_outline : Icons.warning_amber,
                color: isOnTrack ? _green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isOnTrack ? 'On Track' : 'Over Budget',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isOnTrack ? _green : Colors.red,
                ),
              ),
              const Spacer(),
              Text(
                '$daysLeft days left',
                style: const TextStyle(fontSize: 12, color: _grey),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _paceStatItem(
                  'Remaining Budget',
                  'RM ${remaining.toStringAsFixed(2)}',
                  isOnTrack ? _green : Colors.red,
                ),
              ),
              Expanded(
                child: _paceStatItem(
                  'Daily Allowance',
                  isOnTrack && daysLeft > 0
                      ? 'RM ${dailyAllowance.toStringAsFixed(2)}'
                      : '—',
                  const Color(0xFF3B82F6),
                ),
              ),
              Expanded(
                child: _paceStatItem(
                  'Avg Spent/Day',
                  'RM ${(today > 0 ? total / today : 0).toStringAsFixed(2)}',
                  const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Small widgets ──────────────────────────────────────────────────────────

  Widget _paceStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: _grey),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'See all',
              style: TextStyle(fontSize: 12, color: _green),
            ),
          ),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.white,
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF111827)),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: _grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: _grey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniCategoryRow(String name, double amount, double pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Text(
            'RM ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _dark,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11, color: _grey),
          ),
        ],
      ),
    );
  }

  Widget _detailedCategoryBar(
    String label,
    double amount,
    double progress,
    Color color,
    double totalAmount,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                'RM ${amount.toStringAsFixed(2)} (${(progress * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionRow(
    String note,
    String cat,
    double amount,
    DateTime? date,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date == null
                      ? cat
                      : '$cat · ${date.day} ${_shortMonth(date)}',
                  style: const TextStyle(fontSize: 11, color: _grey),
                ),
              ],
            ),
          ),
          Text(
            '-RM ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(DateTime date, double amount, double maxAmount) {
    final pct = maxAmount > 0 ? (amount / maxAmount).clamp(0.0, 1.0) : 0.0;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[date.weekday - 1];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: _dark,
                  ),
                ),
                Text(
                  '${date.day} ${_shortMonth(date)}',
                  style: const TextStyle(fontSize: 10, color: _grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.grey.shade100,
                color: _green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'RM ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'No expenses this month',
            style: TextStyle(color: _grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Custom Painters ──────────────────────────────────────────────────────────

class _DonutSegment {
  final double value;
  final Color color;
  const _DonutSegment({required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;
  final String centerLabel;

  const _DonutPainter({
    required this.segments,
    required this.total,
    required this.centerLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2;
    const strokeW = 36.0;
    const gapAngle = 0.04; // radians gap between segments

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    double startAngle = -1.5708; // -π/2 (top)

    for (final seg in segments) {
      if (total == 0) break;
      final sweep = (seg.value / total) * 6.2832 - gapAngle; // 2π
      if (sweep <= 0) continue;

      paint.color = seg.color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius - strokeW / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep + gapAngle;
    }

    // Center text
    final tp = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF111827),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.segments.length != segments.length;
}

class _BarChartPainter extends CustomPainter {
  final int days;
  final Map<int, double> dailyTotals;
  final double maxValue;
  final Color barColor;
  final double dailyBudget;

  const _BarChartPainter({
    required this.days,
    required this.dailyTotals,
    required this.maxValue,
    required this.barColor,
    required this.dailyBudget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barW = (size.width / days) * 0.65;
    final gap = (size.width / days) * 0.35;
    final maxH = size.height - 10;

    final barPaint = Paint()..color = barColor.withOpacity(0.8);
    final overPaint = Paint()..color = Colors.red.shade400;
    final linePaint = Paint()
      ..color = Colors.orange.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int d = 1; d <= days; d++) {
      final amt = dailyTotals[d] ?? 0;
      final h = (amt / maxValue) * maxH;
      final x = (d - 1) * (barW + gap) + gap / 2;
      final top = size.height - h;

      final isOver = dailyBudget > 0 && amt > dailyBudget;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top, barW, h),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );

      canvas.drawRRect(rect, isOver ? overPaint : barPaint);
    }

    // Daily budget line
    if (dailyBudget > 0 && maxValue > 0) {
      final y = size.height - (dailyBudget / maxValue) * maxH;
      if (y >= 0 && y <= size.height) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.dailyTotals != dailyTotals || old.maxValue != maxValue;
}
