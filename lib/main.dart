import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const ExpenseTrackerApp());
}

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

class Category {
  int id;
  String name;
  String icon;
  Color color;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class Expense {
  int id;
  String desc;
  String categoryName;
  double amount;
  DateTime date;

  Expense({
    required this.id,
    required this.desc,
    required this.categoryName,
    required this.amount,
    required this.date,
  });
}

// ─────────────────────────────────────────────
// APP STATE
// ─────────────────────────────────────────────

class AppState extends ChangeNotifier {
  List<Category> categories = [
    Category(id: 1, name: 'Food & Dining', icon: '🍜', color: const Color(0xFFE24B4A)),
    Category(id: 2, name: 'Transport', icon: '🚌', color: const Color(0xFF378ADD)),
    Category(id: 3, name: 'Groceries', icon: '🛒', color: const Color(0xFF639922)),
    Category(id: 4, name: 'Health', icon: '💊', color: const Color(0xFFD85A30)),
    Category(id: 5, name: 'Utilities', icon: '💡', color: const Color(0xFFBA7517)),
    Category(id: 6, name: 'Entertainment', icon: '🎬', color: const Color(0xFF7F77DD)),
    Category(id: 7, name: 'Shopping', icon: '👕', color: const Color(0xFFD4537E)),
  ];

  List<Expense> expenses = [
    Expense(id: 1, desc: 'Jollibee', categoryName: 'Food & Dining', amount: 185, date: DateTime(2026, 3, 18)),
    Expense(id: 2, desc: 'Commute (jeep)', categoryName: 'Transport', amount: 56, date: DateTime(2026, 3, 18)),
    Expense(id: 3, desc: 'SM Grocery run', categoryName: 'Groceries', amount: 1240, date: DateTime(2026, 3, 17)),
    Expense(id: 4, desc: 'Mercury Drug', categoryName: 'Health', amount: 320, date: DateTime(2026, 3, 17)),
    Expense(id: 5, desc: "Bo's Coffee", categoryName: 'Food & Dining', amount: 210, date: DateTime(2026, 3, 16)),
    Expense(id: 6, desc: 'Globe Load', categoryName: 'Utilities', amount: 99, date: DateTime(2026, 3, 15)),
    Expense(id: 7, desc: 'Netflix subscription', categoryName: 'Entertainment', amount: 459, date: DateTime(2026, 3, 14)),
    Expense(id: 8, desc: 'Grab ride', categoryName: 'Transport', amount: 135, date: DateTime(2026, 3, 14)),
    Expense(id: 9, desc: 'Shopee haul', categoryName: 'Shopping', amount: 890, date: DateTime(2026, 3, 13)),
    Expense(id: 10, desc: 'Mang Inasal', categoryName: 'Food & Dining', amount: 175, date: DateTime(2026, 3, 12)),
  ];

  int _nextExpenseId = 11;
  int _nextCatId = 8;

  Category? getCategoryByName(String name) {
    try {
      return categories.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  void addExpense(Expense e) {
    e.id = _nextExpenseId++;
    expenses.insert(0, e);
    notifyListeners();
  }

  void updateExpense(Expense updated) {
    final idx = expenses.indexWhere((e) => e.id == updated.id);
    if (idx != -1) expenses[idx] = updated;
    notifyListeners();
  }

  void deleteExpense(int id) {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addCategory(Category c) {
    c.id = _nextCatId++;
    categories.add(c);
    notifyListeners();
  }

  void updateCategory(Category updated) {
    final idx = categories.indexWhere((c) => c.id == updated.id);
    if (idx != -1) categories[idx] = updated;
    notifyListeners();
  }

  void deleteCategory(int id) {
    categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  double get monthTotal {
    final now = DateTime(2026, 3);
    return expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0, (s, e) => s + e.amount);
  }

  double get todayTotal {
    final today = DateTime(2026, 3, 18);
    return expenses
        .where((e) => e.date.year == today.year && e.date.month == today.month && e.date.day == today.day)
        .fold(0, (s, e) => s + e.amount);
  }

  double get weekTotal {
    final weekStart = DateTime(2026, 3, 16);
    final weekEnd = DateTime(2026, 3, 22);
    return expenses
        .where((e) => !e.date.isBefore(weekStart) && !e.date.isAfter(weekEnd))
        .fold(0, (s, e) => s + e.amount);
  }

  double get avgPerDay {
    final now = DateTime(2026, 3);
    final days = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .map((e) => e.date.day)
        .toSet()
        .length;
    return days == 0 ? 0 : monthTotal / days;
  }

  List<double> get weeklyAmounts {
    final days = List.generate(7, (i) => DateTime(2026, 3, 16 + i));
    return days.map((d) {
      return expenses
          .where((e) => e.date.year == d.year && e.date.month == d.month && e.date.day == d.day)
          .fold(0.0, (s, e) => s + e.amount);
    }).toList();
  }
}

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────

const kBg = Color(0xFF0E0D1A);
const kSurface = Color(0xFF18162E);
const kSurface2 = Color(0xFF1E1A42);
const kBorder = Color(0xFF2A2640);
const kPurple = Color(0xFF534AB7);
const kPurpleLight = Color(0xFF7F77DD);
const kPurplePale = Color(0xFFAFA9EC);
const kPurpleDark = Color(0xFF3C3489);
const kPurpleDarker = Color(0xFF26215C);
const kText = Color(0xFFEEEDFE);
const kTextMuted = Color(0xFF534AB7);
const kTextDim = Color(0xFF3C3489);

// ─────────────────────────────────────────────
// MAIN APP
// ─────────────────────────────────────────────

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) => MaterialApp(
        title: 'Expense Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg,
          colorScheme: const ColorScheme.dark(
            primary: kPurple,
            surface: kSurface,
          ),
          fontFamily: 'SF Pro Display',
          useMaterial3: true,
        ),
        home: const MainShell(),
      ),
    );
  }
}

final _appState = AppState();

// ─────────────────────────────────────────────
// MAIN SHELL (tab navigation)
// ─────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const ExpensesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: kBg,
      body: screens[_tab],
      floatingActionButton: _tab != 2
          ? FloatingActionButton(
              backgroundColor: kPurple,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              onPressed: () => _openAddExpense(context),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kBorder, width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', active: _tab == 0, onTap: () => setState(() => _tab = 0)),
                _TabItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Expenses', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
                _TabItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings', active: _tab == 2, onTap: () => setState(() => _tab = 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExpenseFormSheet(),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon, size: 22, color: active ? kPurpleLight : kTextDim),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: active ? kPurpleLight : kTextDim)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        final recent = [..._appState.expenses]
          ..sort((a, b) => b.date.compareTo(a.date));
        final recentFew = recent.take(4).toList();

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wednesday, Mar 18', style: TextStyle(fontSize: 12, color: kTextMuted)),
                      const SizedBox(height: 2),
                      const Text('Good morning 👋', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: kText)),
                    ],
                  ),
                ),
                // Hero spending card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    decoration: BoxDecoration(color: kSurface2, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder, width: 0.5)),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total this month', style: TextStyle(fontSize: 11, color: kTextMuted)),
                        const SizedBox(height: 4),
                        Text(_fmt(_appState.monthTotal), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: kText, letterSpacing: -1)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _MiniStat(label: 'Today', value: _fmt(_appState.todayTotal)),
                            const SizedBox(width: 8),
                            _MiniStat(label: 'This week', value: _fmt(_appState.weekTotal)),
                            const SizedBox(width: 8),
                            _MiniStat(label: 'Avg/day', value: _fmt(_appState.avgPerDay)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Weekly bar chart
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder, width: 0.5)),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('This week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kText)),
                            Text('Mar 16 – 22', style: TextStyle(fontSize: 10, color: kTextMuted)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        WeeklyBarChart(amounts: _appState.weeklyAmounts, todayIndex: 2),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Recent expenses
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent expenses', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText)),
                      Text('See all', style: TextStyle(fontSize: 11, color: kPurpleLight)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder, width: 0.5)),
                    child: Column(
                      children: recentFew.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        return _ExpenseListTile(expense: e, showBorder: i < recentFew.length - 1);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(color: kPurpleDarker, borderRadius: BorderRadius.circular(9)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: kPurpleLight)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WEEKLY BAR CHART
// ─────────────────────────────────────────────

class WeeklyBarChart extends StatelessWidget {
  final List<double> amounts;
  final int todayIndex;

  const WeeklyBarChart({super.key, required this.amounts, required this.todayIndex});

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = amounts.reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final val = amounts[i];
              final frac = maxVal == 0 ? 0.0 : val / maxVal;
              final barH = 8.0 + frac * 60;
              final isToday = i == todayIndex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (val > 0)
                        Text(_fmtShort(val), style: const TextStyle(fontSize: 8, color: kPurpleLight)),
                      const SizedBox(height: 3),
                      Container(
                        height: barH,
                        decoration: BoxDecoration(
                          color: isToday ? kPurpleLight : kPurpleDarker,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(7, (i) {
            final isToday = i == todayIndex;
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, color: isToday ? kPurplePale : kTextDim, fontWeight: isToday ? FontWeight.w500 : FontWeight.normal),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _fmtShort(double v) {
    if (v >= 1000) return '₱${(v / 1000).toStringAsFixed(1)}k';
    return '₱${v.toInt()}';
  }
}

// ─────────────────────────────────────────────
// EXPENSES SCREEN
// ─────────────────────────────────────────────

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _filter = 'This month';
  final _filters = ['Today', 'This week', 'This month'];

  List<Expense> get _filtered {
    final today = DateTime(2026, 3, 18);
    switch (_filter) {
      case 'Today':
        return _appState.expenses.where((e) => e.date.year == today.year && e.date.month == today.month && e.date.day == today.day).toList();
      case 'This week':
        final ws = DateTime(2026, 3, 16);
        final we = DateTime(2026, 3, 22);
        return _appState.expenses.where((e) => !e.date.isBefore(ws) && !e.date.isAfter(we)).toList();
      default:
        return _appState.expenses.where((e) => e.date.year == today.year && e.date.month == today.month).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, _) {
        final list = _filtered;
        final total = list.fold(0.0, (s, e) => s + e.amount);

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Text('Expenses', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: kText)),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder, width: 0.5)),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 16, color: kTextDim),
                      const SizedBox(width: 8),
                      Text('Search expenses...', style: TextStyle(fontSize: 13, color: kTextDim)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: _filters.map((f) {
                    final active = f == _filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: active ? kPurple : kSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: active ? kPurple : kBorder, width: 0.5),
                          ),
                          child: Text(f, style: TextStyle(fontSize: 12, color: active ? Colors.white : kPurpleLight)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              // Count + total
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${list.length} expenses', style: TextStyle(fontSize: 11, color: kTextDim)),
                    Text(_fmt(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kText)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Table
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder, width: 0.5)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        children: [
                          // Header row
                          Container(
                            color: const Color(0xFF141228),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            child: Row(
                              children: [
                                const Expanded(flex: 3, child: Text('Description', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted))),
                                Expanded(flex: 3, child: Text('Category', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted))),
                                Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted))),
                                Expanded(flex: 2, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted))),
                              ],
                            ),
                          ),
                          // Rows
                          Expanded(
                            child: list.isEmpty
                                ? Center(child: Text('No expenses', style: TextStyle(color: kTextDim, fontSize: 13)))
                                : ListView.builder(
                                    itemCount: list.length,
                                    itemBuilder: (ctx, i) {
                                      final e = list[i];
                                      return _ExpenseTableRow(
                                        expense: e,
                                        showBorder: i < list.length - 1,
                                        onEdit: () => _editExpense(ctx, e),
                                        onDelete: () => _deleteExpense(ctx, e),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  void _editExpense(BuildContext context, Expense e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseFormSheet(existing: e),
    );
  }

  void _deleteExpense(BuildContext context, Expense e) {
    showDialog(
      context: context,
      builder: (_) => _DeleteDialog(
        title: 'Delete expense?',
        body: '"${e.desc}" will be removed.',
        onConfirm: () => _appState.deleteExpense(e.id),
      ),
    );
  }
}

class _ExpenseTableRow extends StatelessWidget {
  final Expense expense;
  final bool showBorder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseTableRow({required this.expense, required this.showBorder, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cat = _appState.getCategoryByName(expense.categoryName);
    final color = cat?.color ?? const Color(0xFF888780);
    final icon = cat?.icon ?? '🏷️';
    final shortCat = expense.categoryName.split(' ').first;

    return Container(
      decoration: BoxDecoration(border: showBorder ? const Border(bottom: BorderSide(color: kBorder, width: 0.5)) : null),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Expanded(child: Text(expense.desc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kText), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 3),
                    Text(shortCat, style: TextStyle(fontSize: 10, color: color)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(_fmt(expense.amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kText)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(onTap: onEdit, child: const Padding(padding: EdgeInsets.all(4), child: Text('✏️', style: TextStyle(fontSize: 13)))),
                GestureDetector(onTap: onDelete, child: const Padding(padding: EdgeInsets.all(4), child: Text('🗑', style: TextStyle(fontSize: 13)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseListTile extends StatelessWidget {
  final Expense expense;
  final bool showBorder;

  const _ExpenseListTile({required this.expense, required this.showBorder});

  @override
  Widget build(BuildContext context) {
    final cat = _appState.getCategoryByName(expense.categoryName);
    final color = cat?.color ?? const Color(0xFF888780);
    final icon = cat?.icon ?? '🏷️';
    final today = DateTime(2026, 3, 18);
    final yesterday = DateTime(2026, 3, 17);
    String dateLabel;
    if (expense.date == today || (expense.date.year == today.year && expense.date.month == today.month && expense.date.day == today.day)) {
      dateLabel = 'Today';
    } else if (expense.date.year == yesterday.year && expense.date.month == yesterday.month && expense.date.day == yesterday.day) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = '${expense.date.month}/${expense.date.day}';
    }

    return Container(
      decoration: BoxDecoration(border: showBorder ? const Border(bottom: BorderSide(color: kBorder, width: 0.5)) : null),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.desc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kText), overflow: TextOverflow.ellipsis),
                Text(expense.categoryName, style: TextStyle(fontSize: 10, color: kTextMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt(expense.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kText)),
              Text(dateLabel, style: TextStyle(fontSize: 10, color: kTextDim)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD / EDIT EXPENSE SHEET
// ─────────────────────────────────────────────

class ExpenseFormSheet extends StatefulWidget {
  final Expense? existing;
  const ExpenseFormSheet({super.key, this.existing});

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late String _selectedCat;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _descCtrl = TextEditingController(text: e?.desc ?? '');
    _selectedCat = e?.categoryName ?? (_appState.categories.isNotEmpty ? _appState.categories.first.name : '');
    _selectedDate = e?.date ?? DateTime(2026, 3, 18);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    final desc = _descCtrl.text.trim().isEmpty ? 'Expense' : _descCtrl.text.trim();
    if (widget.existing != null) {
      _appState.updateExpense(Expense(id: widget.existing!.id, desc: desc, categoryName: _selectedCat, amount: amt, date: _selectedDate));
    } else {
      _appState.addExpense(Expense(id: 0, desc: desc, categoryName: _selectedCat, amount: amt, date: _selectedDate));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: kSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(top: BorderSide(color: kBorder, width: 0.5))),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text(widget.existing != null ? 'Edit expense' : 'Add expense', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(flex: 3, child: _field('Amount (₱)', _amountCtrl, isNumber: true)),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _dateField()),
              ],
            ),
            const SizedBox(height: 10),
            _field('Description', _descCtrl),
            const SizedBox(height: 10),
            _catField(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _save,
                child: const Text('Save expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: kPurpleLight, padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: kPurpleLight)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
          style: const TextStyle(color: kText, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: kBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder, width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder, width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPurple, width: 1)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date', style: TextStyle(fontSize: 11, color: kPurpleLight)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2027),
              builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: kPurple, surface: kSurface)), child: child!));
            if (d != null) setState(() => _selectedDate = d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder, width: 0.5)),
            child: Text('${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}', style: const TextStyle(fontSize: 13, color: kText)),
          ),
        ),
      ],
    );
  }

  Widget _catField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: TextStyle(fontSize: 11, color: kPurpleLight)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder, width: 0.5)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCat,
              isExpanded: true,
              dropdownColor: kSurface,
              style: const TextStyle(color: kText, fontSize: 13),
              items: _appState.categories.map((c) => DropdownMenuItem(value: c.name, child: Text('${c.icon}  ${c.name}'))).toList(),
              onChanged: (v) { if (v != null) setState(() => _selectedCat = v); },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: Text('Settings', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: kText)),
            ),
            _SettingsGroup(label: 'Appearance', items: [
              _SettingsRow(label: 'Dark mode', trailing: Switch(value: true, activeColor: kPurple, onChanged: (_) {})),
              _SettingsRow(label: 'Currency', trailing: Text('PHP (₱)', style: TextStyle(fontSize: 12, color: kTextDim))),
            ]),
            const SizedBox(height: 4),
            _SettingsGroup(label: 'Categories', items: [
              _SettingsTapRow(
                label: 'Manage categories',
                trailing: const Icon(Icons.chevron_right, color: kTextDim, size: 18),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
              ),
            ]),
            const SizedBox(height: 4),
            _SettingsGroup(label: 'Data', items: [
              _SettingsTapRow(label: 'Export data', trailing: Text('CSV / JSON ›', style: TextStyle(fontSize: 12, color: kTextDim)), onTap: () {}),
              _SettingsTapRow(label: 'Import data', trailing: const Icon(Icons.chevron_right, color: kTextDim, size: 18), onTap: () {}),
            ]),
            const SizedBox(height: 4),
            _SettingsGroup(label: 'General', items: [
              _SettingsRow(label: 'Notifications', trailing: Switch(value: true, activeColor: kPurple, onChanged: (_) {})),
              _SettingsTapRow(label: 'About', trailing: Text('v1.0 ›', style: TextStyle(fontSize: 12, color: kTextDim)), onTap: () {}),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String label;
  final List<Widget> items;
  const _SettingsGroup({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
          child: Text(label.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: kPurpleLight)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder, width: 0.5)),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _SettingsRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: kText)),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsTapRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback onTap;
  const _SettingsTapRow({required this.label, required this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: kText)),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORIES SCREEN
// ─────────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kPurpleLight,
        title: const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: kText)),
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _appState,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder, width: 0.5)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.builder(
                      itemCount: _appState.categories.length,
                      itemBuilder: (ctx, i) {
                        final c = _appState.categories[i];
                        final count = _appState.expenses.where((e) => e.categoryName == c.name).length;
                        return Container(
                          decoration: BoxDecoration(border: i < _appState.categories.length - 1 ? const Border(bottom: BorderSide(color: kBorder, width: 0.5)) : null),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: c.color.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
                                alignment: Alignment.center,
                                child: Text(c.icon, style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText)),
                                    Text('$count expense${count != 1 ? 's' : ''}', style: TextStyle(fontSize: 10, color: kTextMuted)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => CategoryFormSheet(existing: c)),
                                child: const Padding(padding: EdgeInsets.all(6), child: Text('✏️', style: TextStyle(fontSize: 16))),
                              ),
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => _DeleteDialog(
                                    title: 'Delete category?',
                                    body: '"${c.name}" — existing expenses will become uncategorized.',
                                    onConfirm: () => _appState.deleteCategory(c.id),
                                  ),
                                ),
                                child: const Padding(padding: EdgeInsets.all(6), child: Text('🗑', style: TextStyle(fontSize: 16))),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: kPurpleLight, side: const BorderSide(color: kPurple, width: 0.5), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const CategoryFormSheet()),
                  child: const Text('+ Add new category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY FORM SHEET
// ─────────────────────────────────────────────

const _kIcons = ['🍜','🍔','🍕','🥤','☕','🛒','🚌','🚗','⛽','✈️','💊','🏥','🎬','🎮','📱','💡','🏠','👕','💈','📚','🐾','💰','🎁','🏋️'];
const _kColors = [Color(0xFF534AB7), Color(0xFFE24B4A), Color(0xFF378ADD), Color(0xFF639922), Color(0xFFD85A30), Color(0xFFBA7517), Color(0xFFD4537E), Color(0xFF1D9E75), Color(0xFF888780)];

class CategoryFormSheet extends StatefulWidget {
  final Category? existing;
  const CategoryFormSheet({super.key, this.existing});

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  late TextEditingController _nameCtrl;
  late String _selectedIcon;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _selectedIcon = c?.icon ?? _kIcons[0];
    _selectedColor = c?.color ?? _kColors[0];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (widget.existing != null) {
      _appState.updateCategory(Category(id: widget.existing!.id, name: name, icon: _selectedIcon, color: _selectedColor));
    } else {
      _appState.addCategory(Category(id: 0, name: name, icon: _selectedIcon, color: _selectedColor));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previewName = _nameCtrl.text.isEmpty ? 'Category name' : _nameCtrl.text;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: kSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), border: Border(top: BorderSide(color: kBorder, width: 0.5))),
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text(widget.existing != null ? 'Edit category' : 'New category', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText)),
              const SizedBox(height: 12),
              // Name input
              Text('Category name', style: TextStyle(fontSize: 11, color: kPurpleLight)),
              const SizedBox(height: 4),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: kText, fontSize: 13),
                decoration: InputDecoration(
                  filled: true, fillColor: kBg,
                  hintText: 'e.g. Entertainment',
                  hintStyle: TextStyle(color: kTextDim, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder, width: 0.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder, width: 0.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPurple, width: 1)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                ),
              ),
              const SizedBox(height: 12),
              // Icon picker
              Text('Choose icon', style: TextStyle(fontSize: 11, color: kPurpleLight)),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 6, crossAxisSpacing: 6),
                itemCount: _kIcons.length,
                itemBuilder: (_, i) {
                  final ic = _kIcons[i];
                  final sel = ic == _selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = ic),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? kPurpleDarker : kBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? kPurpleLight : kBorder, width: sel ? 1.5 : 0.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(ic, style: const TextStyle(fontSize: 16)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Color picker
              Text('Choose color', style: TextStyle(fontSize: 11, color: kPurpleLight)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _kColors.map((c) {
                  final sel = c == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2),
                        boxShadow: sel ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 0, spreadRadius: 2)] : []),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Preview
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF141228), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _selectedColor.withOpacity(0.2), borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: Text(_selectedIcon, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(previewName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText)),
                        Text('Preview', style: TextStyle(fontSize: 10, color: kTextMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _save,
                  child: const Text('Save category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: kPurpleLight, padding: const EdgeInsets.symmetric(vertical: 10)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DELETE DIALOG
// ─────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onConfirm;

  const _DeleteDialog({required this.title, required this.body, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kBorder, width: 0.5)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗑️', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kTextMuted)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: kPurpleLight, side: const BorderSide(color: kBorder, width: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF791F1F), foregroundColor: const Color(0xFFF09595), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () { Navigator.pop(context); onConfirm(); },
                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────

String _fmt(double v) => '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
