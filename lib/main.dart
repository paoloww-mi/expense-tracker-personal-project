import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _appState.load();
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

  Category({required this.id, required this.name, required this.icon, required this.color});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'icon': icon, 'color': color.value};

  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j['id'], name: j['name'], icon: j['icon'], color: Color(j['color']));
}

class Expense {
  int id;
  String desc;
  String categoryName;
  double amount;
  DateTime date;
  String remarks; // v1.1

  Expense({
    required this.id,
    required this.desc,
    required this.categoryName,
    required this.amount,
    required this.date,
    this.remarks = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'desc': desc,
    'categoryName': categoryName,
    'amount': amount,
    'date': date.toIso8601String(),
    'remarks': remarks,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'],
    desc: j['desc'],
    categoryName: j['categoryName'],
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date']),
    remarks: j['remarks'] ?? '',
  );
}

// ─────────────────────────────────────────────
// SORT & FILTER ENUMS
// ─────────────────────────────────────────────

enum SortField { recentlyModified, description, category, amount, date }

extension SortFieldLabel on SortField {
  String get label {
    switch (this) {
      case SortField.recentlyModified: return 'Recently modified';
      case SortField.description: return 'Description';
      case SortField.category: return 'Category';
      case SortField.amount: return 'Amount';
      case SortField.date: return 'Date';
    }
  }
  IconData get icon {
    switch (this) {
      case SortField.recentlyModified: return Icons.history;
      case SortField.description: return Icons.sort_by_alpha;
      case SortField.category: return Icons.label_outline;
      case SortField.amount: return Icons.attach_money;
      case SortField.date: return Icons.calendar_today_outlined;
    }
  }
}

// ─────────────────────────────────────────────
// APP STATE
// ─────────────────────────────────────────────

class AppState extends ChangeNotifier {
  bool isDarkMode = true;
  bool notificationsEnabled = true;

  List<Category> categories = [
    Category(id: 1, name: 'Food & Dining', icon: '🍜', color: const Color(0xFFE24B4A)),
    Category(id: 2, name: 'Transport', icon: '🚌', color: const Color(0xFF378ADD)),
    Category(id: 3, name: 'Groceries', icon: '🛒', color: const Color(0xFF639922)),
    Category(id: 4, name: 'Health', icon: '💊', color: const Color(0xFFD85A30)),
    Category(id: 5, name: 'Utilities', icon: '💡', color: const Color(0xFFBA7517)),
    Category(id: 6, name: 'Entertainment', icon: '🎬', color: const Color(0xFF7F77DD)),
    Category(id: 7, name: 'Shopping', icon: '👕', color: const Color(0xFFD4537E)),
  ];

  List<Expense> expenses = [];
  int _nextExpenseId = 1;
  int _nextCatId = 8;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool('darkMode') ?? true;
    notificationsEnabled = prefs.getBool('notifications') ?? true;

    final catJson = prefs.getString('categories');
    if (catJson != null) {
      final list = jsonDecode(catJson) as List;
      categories = list.map((e) => Category.fromJson(e)).toList();
      _nextCatId = categories.isEmpty
          ? 1
          : categories.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
    }

    final expJson = prefs.getString('expenses');
    if (expJson != null) {
      final list = jsonDecode(expJson) as List;
      expenses = list.map((e) => Expense.fromJson(e)).toList();
      _nextExpenseId = expenses.isEmpty
          ? 1
          : expenses.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

      // Restore persisted mod order
      final modJson = prefs.getString('modOrder');
      if (modJson != null) {
        final raw = jsonDecode(modJson) as Map<String, dynamic>;
        _modOrder.clear();
        raw.forEach((k, v) => _modOrder[int.parse(k)] = v as int);
        _nextModOrder = _modOrder.isEmpty ? 0 : _modOrder.values.reduce((a, b) => a > b ? a : b) + 1;
      } else {
        // First run after update — seed mod order from expense id (higher id = more recent)
        for (final e in expenses) {
          _modOrder[e.id] = e.id;
        }
        _nextModOrder = _modOrder.isEmpty ? 0 : _modOrder.values.reduce((a, b) => a > b ? a : b) + 1;
      }
    }
    // No seed data — fresh install starts empty
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDarkMode);
    await prefs.setBool('notifications', notificationsEnabled);
    await prefs.setString('categories', jsonEncode(categories.map((c) => c.toJson()).toList()));
    await prefs.setString('expenses', jsonEncode(expenses.map((e) => e.toJson()).toList()));
    // Persist mod order so "Recently modified" sort survives app restarts
    await prefs.setString('modOrder', jsonEncode(_modOrder.map((k, v) => MapEntry(k.toString(), v))));
  }

  Category? getCategoryByName(String name) {
    try { return categories.firstWhere((c) => c.name == name); } catch (_) { return null; }
  }

  double _sumWhere(bool Function(Expense) test) =>
      expenses.where(test).fold(0, (s, e) => s + e.amount);

  double get monthTotal {
    final now = DateTime.now();
    return _sumWhere((e) => e.date.year == now.year && e.date.month == now.month);
  }

  double get todayTotal {
    final now = DateTime.now();
    return _sumWhere((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day);
  }

  double get weekTotal {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return _sumWhere((e) =>
        !e.date.isBefore(weekStart) &&
        !e.date.isAfter(DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59)));
  }

  double get avgPerDay {
    final now = DateTime.now();
    final days = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .map((e) => e.date.day)
        .toSet()
        .length;
    return days == 0 ? 0 : monthTotal / days;
  }

  List<double> get weeklyAmounts {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return List.generate(7, (i) {
      final d = weekStart.add(Duration(days: i));
      return _sumWhere((e) =>
          e.date.year == d.year && e.date.month == d.month && e.date.day == d.day);
    });
  }

  int get todayIndex => DateTime.now().weekday - 1;

  void toggleDarkMode() { isDarkMode = !isDarkMode; _save(); notifyListeners(); }
  void toggleNotifications() { notificationsEnabled = !notificationsEnabled; _save(); notifyListeners(); }

  // Modification-order tracking for "Recently modified" sort
  int _nextModOrder = 0;
  final Map<int, int> _modOrder = {}; // expenseId -> mod order (higher = more recent)

  void addExpense(Expense e) {
    e.id = _nextExpenseId++;
    _modOrder[e.id] = _nextModOrder++;
    expenses.insert(0, e);
    _save();
    notifyListeners();
  }

  void updateExpense(Expense u) {
    final i = expenses.indexWhere((e) => e.id == u.id);
    if (i != -1) expenses[i] = u;
    _modOrder[u.id] = _nextModOrder++; // bump so it surfaces as recently modified
    _save();
    notifyListeners();
  }

  void deleteExpense(int id) { expenses.removeWhere((e) => e.id == id); _modOrder.remove(id); _save(); notifyListeners(); }

  int modOrderOf(int expenseId) => _modOrder[expenseId] ?? expenseId;

  /// Replaces all expenses with the imported list. Returns the count imported.
  Future<int> importExpenses(List<Expense> imported) async {
    expenses = imported;
    _modOrder.clear();
    _nextExpenseId = 1;
    _nextModOrder = 0;
    for (int i = 0; i < expenses.length; i++) {
      if (expenses[i].id >= _nextExpenseId) _nextExpenseId = expenses[i].id + 1;
      _modOrder[expenses[i].id] = i;
      _nextModOrder = i + 1;
    }
    await _save();
    notifyListeners();
    return expenses.length;
  }

  void addCategory(Category c) { c.id = _nextCatId++; categories.add(c); _save(); notifyListeners(); }
  void updateCategory(Category u) {
    final i = categories.indexWhere((c) => c.id == u.id);
    if (i != -1) categories[i] = u;
    _save();
    notifyListeners();
  }
  void deleteCategory(int id) { categories.removeWhere((c) => c.id == id); _save(); notifyListeners(); }
}

final _appState = AppState();

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────

ThemeData _buildTheme(bool dark) => dark
    ? ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0E0D1A), colorScheme: const ColorScheme.dark(primary: Color(0xFF534AB7), surface: Color(0xFF18162E)), useMaterial3: true)
    : ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: const Color(0xFFF7F5FF), colorScheme: const ColorScheme.light(primary: Color(0xFF534AB7), surface: Colors.white), useMaterial3: true);

Color kBg(bool d) => d ? const Color(0xFF0E0D1A) : const Color(0xFFF7F5FF);
Color kSurface(bool d) => d ? const Color(0xFF18162E) : Colors.white;
Color kSurface2(bool d) => d ? const Color(0xFF1E1A42) : const Color(0xFFEEEDFE);
Color kBorder(bool d) => d ? const Color(0xFF2A2640) : const Color(0xFFE0DEFF);
Color kPurpleLight(bool d) => d ? const Color(0xFF7F77DD) : const Color(0xFF534AB7);
Color kPurplePale(bool d) => d ? const Color(0xFFAFA9EC) : const Color(0xFF7F77DD);
Color kPurpleDarker(bool d) => d ? const Color(0xFF26215C) : const Color(0xFFEEEDFE);
Color kText(bool d) => d ? const Color(0xFFEEEDFE) : const Color(0xFF26215C);
Color kTextMuted(bool d) => d ? const Color(0xFF534AB7) : const Color(0xFF7F77DD);
Color kTextDim(bool d) => d ? const Color(0xFF3C3489) : const Color(0xFFAFA9EC);

// ─────────────────────────────────────────────
// MAIN APP
// ─────────────────────────────────────────────

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (_, __) => MaterialApp(
        title: 'GastosFlow',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(_appState.isDarkMode),
        home: const MainShell(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN SHELL
// ─────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  void _goToExpenses() => setState(() => _tab = 1);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (_, __) {
        final dark = _appState.isDarkMode;
        final screens = [
          HomeScreen(onSeeAll: _goToExpenses),
          const ExpensesScreen(),
          const SettingsScreen(),
        ];
        return Scaffold(
          backgroundColor: kBg(dark),
          body: screens[_tab],
          floatingActionButton: _tab != 2
              ? FloatingActionButton(
                  backgroundColor: const Color(0xFF534AB7),
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const ExpenseFormSheet(),
                  ),
                  child: const Icon(Icons.add, size: 28),
                )
              : null,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: kSurface(dark),
              border: Border(top: BorderSide(color: kBorder(dark), width: 0.5)),
            ),
            child: SafeArea(
              child: SizedBox(
                height: 56,
                child: Row(children: [
                  _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', active: _tab == 0, dark: dark, onTap: () => setState(() => _tab = 0)),
                  _TabItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Expenses', active: _tab == 1, dark: dark, onTap: () => setState(() => _tab = 1)),
                  _TabItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings', active: _tab == 2, dark: dark, onTap: () => setState(() => _tab = 2)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active, dark;
  final VoidCallback onTap;
  const _TabItem({required this.icon, required this.activeIcon, required this.label, required this.active, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(active ? activeIcon : icon, size: 22, color: active ? kPurpleLight(dark) : kTextDim(dark)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, color: active ? kPurpleLight(dark) : kTextDim(dark))),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  final VoidCallback onSeeAll;
  const HomeScreen({super.key, required this.onSeeAll});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  String _weekRangeLabel() {
    final now = DateTime.now();
    final ws = now.subtract(Duration(days: now.weekday - 1));
    final we = ws.add(const Duration(days: 6));
    return '${DateFormat('MMM d').format(ws)} – ${DateFormat('MMM d').format(we)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (_, __) {
        final dark = _appState.isDarkMode;
        final now = DateTime.now();
        final recent = [..._appState.expenses]..sort((a, b) => b.date.compareTo(a.date));
        final recentFew = recent.take(4).toList();

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(DateFormat('EEEE, MMM d').format(now), style: TextStyle(fontSize: 12, color: kTextMuted(dark))),
                  const SizedBox(height: 2),
                  Text('Good ${_greeting()} 👋', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: kText(dark))),
                ]),
              ),
              // Hero card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  decoration: BoxDecoration(color: kSurface2(dark), borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder(dark), width: 0.5)),
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total this month', style: TextStyle(fontSize: 11, color: kTextMuted(dark))),
                    const SizedBox(height: 4),
                    Text(_fmt(_appState.monthTotal), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: kText(dark), letterSpacing: -1)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _MiniStat(label: 'Today', value: _fmt(_appState.todayTotal), dark: dark),
                      const SizedBox(width: 8),
                      _MiniStat(label: 'This week', value: _fmt(_appState.weekTotal), dark: dark),
                      const SizedBox(width: 8),
                      _MiniStat(label: 'Avg/day', value: _fmt(_appState.avgPerDay), dark: dark),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              // Weekly bar chart
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  decoration: BoxDecoration(color: kSurface(dark), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder(dark), width: 0.5)),
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('This week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kText(dark))),
                      Text(_weekRangeLabel(), style: TextStyle(fontSize: 10, color: kTextMuted(dark))),
                    ]),
                    const SizedBox(height: 10),
                    WeeklyBarChart(amounts: _appState.weeklyAmounts, todayIndex: _appState.todayIndex, dark: dark),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              // Recent expenses
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Recent expenses', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText(dark))),
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text('See all', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  decoration: BoxDecoration(color: kSurface(dark), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder(dark), width: 0.5)),
                  child: recentFew.isEmpty
                      ? Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('No expenses yet. Tap + to add one!', style: TextStyle(color: kTextDim(dark), fontSize: 13))))
                      : Column(
                          children: recentFew.asMap().entries.map((entry) =>
                            _ExpenseListTile(expense: entry.value, showBorder: entry.key < recentFew.length - 1, dark: dark)
                          ).toList(),
                        ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final bool dark;
  const _MiniStat({required this.label, required this.value, required this.dark});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: kPurpleDarker(dark), borderRadius: BorderRadius.circular(9)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: kPurpleLight(dark))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText(dark))),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────
// WEEKLY BAR CHART
// ─────────────────────────────────────────────

class WeeklyBarChart extends StatelessWidget {
  final List<double> amounts;
  final int todayIndex;
  final bool dark;
  const WeeklyBarChart({super.key, required this.amounts, required this.todayIndex, required this.dark});

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxVal = amounts.isEmpty ? 1.0 : amounts.reduce((a, b) => a > b ? a : b);

    return Column(children: [
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
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (val > 0)
                    Text(_fmtShort(val), style: TextStyle(fontSize: 8, color: kPurpleLight(dark))),
                  const SizedBox(height: 3),
                  Container(
                    height: barH,
                    decoration: BoxDecoration(
                      color: isToday ? kPurpleLight(dark) : kPurpleDarker(dark),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: List.generate(7, (i) {
        final isToday = i == todayIndex;
        return Expanded(
          child: Text(labels[i], textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: isToday ? kPurplePale(dark) : kTextDim(dark), fontWeight: isToday ? FontWeight.w500 : FontWeight.normal)),
        );
      })),
    ]);
  }

  String _fmtShort(double v) => v >= 1000 ? '₱${(v / 1000).toStringAsFixed(1)}k' : '₱${v.toInt()}';
}

// ─────────────────────────────────────────────
// EXPENSE DETAIL SHEET  (v1.1 — tap a row to open)
// ─────────────────────────────────────────────

class ExpenseDetailSheet extends StatelessWidget {
  final Expense expense;
  const ExpenseDetailSheet({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final dark = _appState.isDarkMode;
    final cat = _appState.getCategoryByName(expense.categoryName);
    final color = cat?.color ?? const Color(0xFF888780);
    final icon = cat?.icon ?? '🏷️';

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    String dateLabel;
    if (expense.date.year == now.year && expense.date.month == now.month && expense.date.day == now.day) {
      dateLabel = 'Today, ${DateFormat('MMM d yyyy').format(expense.date)}';
    } else if (expense.date.year == yesterday.year && expense.date.month == yesterday.month && expense.date.day == yesterday.day) {
      dateLabel = 'Yesterday, ${DateFormat('MMM d yyyy').format(expense.date)}';
    } else {
      dateLabel = DateFormat('EEEE, MMM d yyyy').format(expense.date);
    }

    return Container(
      decoration: BoxDecoration(
        color: kSurface(dark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: kBorder(dark), width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder(dark), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),

        // Icon + amount hero
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(18)),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 30)),
        ),
        const SizedBox(height: 12),
        Text(_fmt(expense.amount), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: kText(dark), letterSpacing: -1)),
        const SizedBox(height: 4),
        Text(expense.desc, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kText(dark))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(expense.categoryName, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(height: 20),

        // Details card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(color: kBg(dark), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder(dark), width: 0.5)),
          child: Column(children: [
            _DetailRow(label: 'Date', value: dateLabel, dark: dark, showBorder: true),
            _DetailRow(label: 'Category', value: '${expense.categoryName}  $icon', dark: dark, showBorder: expense.remarks.isNotEmpty),
            if (expense.remarks.isNotEmpty)
              _DetailRow(label: 'Remarks', value: expense.remarks, dark: dark, showBorder: false),
          ]),
        ),
        const SizedBox(height: 20),

        // Edit + Delete buttons
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kPurpleLight(dark),
                side: BorderSide(color: kBorder(dark), width: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit', style: TextStyle(fontSize: 14)),
              onPressed: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ExpenseFormSheet(existing: expense),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF791F1F),
                foregroundColor: const Color(0xFFF09595),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => _DeleteDialog(
                    title: 'Delete expense?',
                    body: '"${expense.desc}" will be removed.',
                    onConfirm: () => _appState.deleteExpense(expense.id),
                  ),
                );
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool dark, showBorder;
  const _DetailRow({required this.label, required this.value, required this.dark, required this.showBorder});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(border: showBorder ? Border(bottom: BorderSide(color: kBorder(dark), width: 0.5)) : null),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: kTextMuted(dark)))),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: kText(dark), fontWeight: FontWeight.w500))),
    ]),
  );
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
  // Month navigation
  late int _selectedYear;
  late int _selectedMonth;

  // Sub-filter chips within the selected month
  String _subFilter = 'All'; // 'All' | 'Today' | 'This week'
  final _subFilters = ['All', 'Today', 'This week'];

  // Search
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // Sort
  SortField _sortField = SortField.recentlyModified;
  bool _sortAscending = false;

  // Advanced filters
  String? _filterCategory;
  DateTime? _filterDate;
  double? _filterAmountMin;
  double? _filterAmountMax;

  bool get _hasActiveFilters =>
      _filterCategory != null || _filterDate != null ||
      _filterAmountMin != null || _filterAmountMax != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedYear == now.year && _selectedMonth == now.month;
  }

  // Earliest month that has any expense
  DateTime get _earliestMonth {
    if (_appState.expenses.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month);
    }
    final earliest = _appState.expenses.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(earliest.year, earliest.month);
  }

  bool get _canGoBack {
    final em = _earliestMonth;
    if (_selectedYear > em.year) return true;
    if (_selectedYear == em.year && _selectedMonth > em.month) return true;
    return false;
  }

  bool get _canGoForward => !_isCurrentMonth;

  void _prevMonth() {
    if (!_canGoBack) return;
    setState(() {
      if (_selectedMonth == 1) { _selectedYear--; _selectedMonth = 12; }
      else { _selectedMonth--; }
      // Reset sub-filter when changing months (Today/This week only make sense on current month)
      if (!_isCurrentMonth) _subFilter = 'All';
    });
  }

  void _nextMonth() {
    if (!_canGoForward) return;
    setState(() {
      if (_selectedMonth == 12) { _selectedYear++; _selectedMonth = 1; }
      else { _selectedMonth++; }
    });
  }

  List<Expense> get _filtered {
    final now = DateTime.now();

    // 1. Scope to selected month
    List<Expense> list = _appState.expenses.where((e) =>
        e.date.year == _selectedYear && e.date.month == _selectedMonth).toList();

    // 2. Sub-filter within the month (only meaningful on current month)
    if (_subFilter == 'Today') {
      list = list.where((e) =>
          e.date.year == now.year && e.date.month == now.month && e.date.day == now.day).toList();
    } else if (_subFilter == 'This week') {
      final ws = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final we = ws.add(const Duration(days: 6));
      list = list.where((e) =>
          !e.date.isBefore(ws) && !e.date.isAfter(DateTime(we.year, we.month, we.day, 23, 59))).toList();
    }

    // 2. Search (desc + remarks only)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) =>
          e.desc.toLowerCase().contains(q) ||
          e.remarks.toLowerCase().contains(q)).toList();
    }

    // 3. Advanced filters
    if (_filterCategory != null) {
      list = list.where((e) => e.categoryName == _filterCategory).toList();
    }
    if (_filterDate != null) {
      final fd = _filterDate!;
      list = list.where((e) =>
          e.date.year == fd.year && e.date.month == fd.month && e.date.day == fd.day).toList();
    }
    if (_filterAmountMin != null) {
      list = list.where((e) => e.amount >= _filterAmountMin!).toList();
    }
    if (_filterAmountMax != null) {
      list = list.where((e) => e.amount <= _filterAmountMax!).toList();
    }

    // 4. Sort
    if (_sortField == SortField.recentlyModified) {
      // recentlyModified = modification order (most recently added/edited first)
      list.sort((a, b) => _appState.modOrderOf(b.id).compareTo(_appState.modOrderOf(a.id)));
    } else {
      list.sort((a, b) {
        int cmp;
        switch (_sortField) {
          case SortField.description:
            cmp = a.desc.toLowerCase().compareTo(b.desc.toLowerCase());
            break;
          case SortField.category:
            cmp = a.categoryName.toLowerCase().compareTo(b.categoryName.toLowerCase());
            break;
          case SortField.amount:
            cmp = a.amount.compareTo(b.amount);
            break;
          case SortField.date:
            cmp = a.date.compareTo(b.date);
            break;
          default:
            cmp = 0;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    return list;
  }

  void _openDetail(BuildContext context, Expense e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseDetailSheet(expense: e),
    );
  }

  void _openSortSheet(BuildContext context, bool dark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: kSurface(dark),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: kBorder(dark), width: 0.5)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder(dark), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text('Sort by', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText(dark))),
              const SizedBox(height: 12),
              ...SortField.values.map((field) {
                final isSelected = _sortField == field;
                return GestureDetector(
                  onTap: () {
                    if (_sortField == field && field != SortField.recentlyModified) {
                      setState(() => _sortAscending = !_sortAscending);
                      setSheetState(() {});
                    } else {
                      setState(() {
                        _sortField = field;
                        _sortAscending = field == SortField.description || field == SortField.category;
                      });
                      setSheetState(() {});
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: isSelected ? kPurpleDarker(dark) : kBg(dark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? kPurpleLight(dark) : kBorder(dark), width: isSelected ? 1 : 0.5),
                    ),
                    child: Row(children: [
                      Icon(field.icon, size: 16, color: isSelected ? kPurpleLight(dark) : kTextMuted(dark)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(field.label, style: TextStyle(fontSize: 13, color: isSelected ? kText(dark) : kTextMuted(dark), fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal))),
                      if (isSelected && field != SortField.recentlyModified)
                        Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: kPurpleLight(dark))
                      else if (isSelected && field == SortField.recentlyModified)
                        Icon(Icons.check, size: 14, color: kPurpleLight(dark)),
                    ]),
                  ),
                );
              }),
              if (_sortField != SortField.recentlyModified) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () { setState(() => _sortAscending = true); setSheetState(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _sortAscending ? const Color(0xFF534AB7) : kBg(dark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _sortAscending ? const Color(0xFF534AB7) : kBorder(dark), width: 0.5),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.arrow_upward, size: 13, color: _sortAscending ? Colors.white : kPurpleLight(dark)),
                        const SizedBox(width: 5),
                        Text(_sortField == SortField.description || _sortField == SortField.category ? 'A → Z' : 'Low → High',
                          style: TextStyle(fontSize: 12, color: _sortAscending ? Colors.white : kPurpleLight(dark))),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () { setState(() => _sortAscending = false); setSheetState(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !_sortAscending ? const Color(0xFF534AB7) : kBg(dark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: !_sortAscending ? const Color(0xFF534AB7) : kBorder(dark), width: 0.5),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.arrow_downward, size: 13, color: !_sortAscending ? Colors.white : kPurpleLight(dark)),
                        const SizedBox(width: 5),
                        Text(_sortField == SortField.description || _sortField == SortField.category ? 'Z → A' : 'High → Low',
                          style: TextStyle(fontSize: 12, color: !_sortAscending ? Colors.white : kPurpleLight(dark))),
                      ]),
                    ),
                  )),
                ]),
              ],
            ]),
          );
        },
      ),
    );
  }

  void _openFilterSheet(BuildContext context, bool dark) {
    String? tempCategory = _filterCategory;
    DateTime? tempDate = _filterDate;
    final minCtrl = TextEditingController(text: _filterAmountMin?.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(text: _filterAmountMax?.toStringAsFixed(0) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: kSurface(dark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: kBorder(dark), width: 0.5)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder(dark), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Filter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText(dark))),
                    if (tempCategory != null || tempDate != null || minCtrl.text.isNotEmpty || maxCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setSheetState(() { tempCategory = null; tempDate = null; minCtrl.clear(); maxCtrl.clear(); });
                        },
                        child: Text('Clear all', style: TextStyle(fontSize: 12, color: kPurpleLight(dark))),
                      ),
                  ]),
                  const SizedBox(height: 14),

                  // Category
                  Text('Category', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
                  const SizedBox(height: 8),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    GestureDetector(
                      onTap: () => setSheetState(() => tempCategory = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: tempCategory == null ? const Color(0xFF534AB7) : kBg(dark),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: tempCategory == null ? const Color(0xFF534AB7) : kBorder(dark), width: 0.5),
                        ),
                        child: Text('All', style: TextStyle(fontSize: 12, color: tempCategory == null ? Colors.white : kPurpleLight(dark))),
                      ),
                    ),
                    ..._appState.categories.map((cat) {
                      final sel = tempCategory == cat.name;
                      return GestureDetector(
                        onTap: () => setSheetState(() => tempCategory = sel ? null : cat.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? cat.color.withOpacity(0.2) : kBg(dark),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? cat.color : kBorder(dark), width: sel ? 1 : 0.5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(cat.icon, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 5),
                            Text(cat.name, style: TextStyle(fontSize: 12, color: sel ? cat.color : kTextMuted(dark))),
                          ]),
                        ),
                      );
                    }),
                  ]),
                  const SizedBox(height: 16),

                  // Specific date
                  Text('Specific date', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: tempDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(primary: const Color(0xFF534AB7), surface: kSurface(dark)),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setSheetState(() => tempDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: tempDate != null ? kPurpleDarker(dark) : kBg(dark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tempDate != null ? kPurpleLight(dark) : kBorder(dark), width: tempDate != null ? 1 : 0.5),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_outlined, size: 15, color: tempDate != null ? kPurpleLight(dark) : kTextDim(dark)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          tempDate != null ? DateFormat('EEEE, MMM d yyyy').format(tempDate!) : 'Pick a date...',
                          style: TextStyle(fontSize: 13, color: tempDate != null ? kText(dark) : kTextDim(dark)),
                        )),
                        if (tempDate != null)
                          GestureDetector(
                            onTap: () => setSheetState(() => tempDate = null),
                            child: Icon(Icons.close, size: 15, color: kTextMuted(dark)),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount range
                  Text('Amount range (₱)', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: kText(dark), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Min',
                        hintStyle: TextStyle(color: kTextDim(dark), fontSize: 12),
                        prefixText: '₱ ',
                        prefixStyle: TextStyle(color: kTextMuted(dark), fontSize: 13),
                        filled: true,
                        fillColor: kBg(dark),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF534AB7), width: 1)),
                      ),
                    )),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('–', style: TextStyle(color: kTextDim(dark), fontSize: 16)),
                    ),
                    Expanded(child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: kText(dark), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Max',
                        hintStyle: TextStyle(color: kTextDim(dark), fontSize: 12),
                        prefixText: '₱ ',
                        prefixStyle: TextStyle(color: kTextMuted(dark), fontSize: 13),
                        filled: true,
                        fillColor: kBg(dark),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF534AB7), width: 1)),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 20),

                  SizedBox(width: double.infinity, child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF534AB7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _filterCategory = tempCategory;
                        _filterDate = tempDate;
                        _filterAmountMin = minCtrl.text.isNotEmpty ? double.tryParse(minCtrl.text) : null;
                        _filterAmountMax = maxCtrl.text.isNotEmpty ? double.tryParse(maxCtrl.text) : null;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Apply filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  )),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (_, __) {
        final dark = _appState.isDarkMode;
        final list = _filtered;
        final total = list.fold(0.0, (s, e) => s + e.amount);

        // Sort indicator label
        String sortLabel = _sortField.label;
        if (_sortField != SortField.recentlyModified) {
          sortLabel += _sortAscending ? ' ↑' : ' ↓';
        }

        final monthLabel = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));

        return SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header row: title + month navigator
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 14, 6),
              child: Row(children: [
                Text('Expenses', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: kText(dark))),
                const Spacer(),
                // Month navigator
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: _canGoBack ? _prevMonth : null,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: _canGoBack ? kSurface2(dark) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_left, size: 18,
                        color: _canGoBack ? kPurpleLight(dark) : kTextDim(dark)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      // Tap the label to jump to current month quickly
                      if (!_isCurrentMonth) {
                        final now = DateTime.now();
                        setState(() {
                          _selectedYear = now.year;
                          _selectedMonth = now.month;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kSurface2(dark),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder(dark), width: 0.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(monthLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kText(dark))),
                        if (!_isCurrentMonth) ...[
                          const SizedBox(width: 5),
                          Container(
                            width: 5, height: 5,
                            decoration: const BoxDecoration(color: Color(0xFF534AB7), shape: BoxShape.circle),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _canGoForward ? _nextMonth : null,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: _canGoForward ? kSurface2(dark) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.chevron_right, size: 18,
                        color: _canGoForward ? kPurpleLight(dark) : kTextDim(dark)),
                    ),
                  ),
                ]),
              ]),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: kText(dark), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by description or remarks...',
                  hintStyle: TextStyle(color: kTextDim(dark), fontSize: 12),
                  prefixIcon: Icon(Icons.search, size: 18, color: kTextDim(dark)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, size: 16, color: kTextDim(dark)),
                          onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                        )
                      : null,
                  filled: true,
                  fillColor: kSurface(dark),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF534AB7), width: 1)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Sub-filter chips (Today / This week only active on current month) + Sort + Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                // Sub-filter chips
                ..._subFilters.map((f) {
                  final active = f == _subFilter;
                  // Disable Today/This week on past months
                  final enabled = f == 'All' || _isCurrentMonth;
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: enabled ? () => setState(() => _subFilter = f) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF534AB7) : kSurface(dark),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? const Color(0xFF534AB7) : kBorder(dark),
                            width: 0.5,
                          ),
                        ),
                        child: Text(f, style: TextStyle(
                          fontSize: 12,
                          color: active ? Colors.white : (enabled ? kPurpleLight(dark) : kTextDim(dark)),
                        )),
                      ),
                    ),
                  );
                }),

                // Divider
                Container(width: 0.5, height: 20, color: kBorder(dark), margin: const EdgeInsets.only(right: 7)),

                // Sort button
                GestureDetector(
                  onTap: () => _openSortSheet(context, dark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _sortField != SortField.recentlyModified ? kPurpleDarker(dark) : kSurface(dark),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _sortField != SortField.recentlyModified ? kPurpleLight(dark) : kBorder(dark),
                        width: _sortField != SortField.recentlyModified ? 1 : 0.5,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.sort, size: 13, color: kPurpleLight(dark)),
                      const SizedBox(width: 5),
                      Text(sortLabel, style: TextStyle(fontSize: 12, color: kPurpleLight(dark))),
                    ]),
                  ),
                ),
                const SizedBox(width: 7),

                // Filter button
                GestureDetector(
                  onTap: () => _openFilterSheet(context, dark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters ? kPurpleDarker(dark) : kSurface(dark),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _hasActiveFilters ? kPurpleLight(dark) : kBorder(dark),
                        width: _hasActiveFilters ? 1 : 0.5,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.tune, size: 13, color: kPurpleLight(dark)),
                      const SizedBox(width: 5),
                      Text('Filter', style: TextStyle(fontSize: 12, color: kPurpleLight(dark))),
                      if (_hasActiveFilters) ...[
                        const SizedBox(width: 5),
                        Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: Color(0xFF534AB7), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            '${(_filterCategory != null ? 1 : 0) + (_filterDate != null ? 1 : 0) + (_filterAmountMin != null || _filterAmountMax != null ? 1 : 0)}',
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${list.length} expense${list.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: kTextDim(dark))),
                Text(_fmt(total), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kText(dark))),
              ]),
            ),
            const SizedBox(height: 6),

            // Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: kSurface(dark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder(dark), width: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(children: [
                      // Table header
                      Container(
                        color: dark ? const Color(0xFF141228) : const Color(0xFFF0EEFF),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(children: [
                          Expanded(flex: 8, child: Text('Description', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted(dark)))),
                          Expanded(flex: 6, child: Text('Category', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted(dark)))),
                          Expanded(flex: 5, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted(dark)))),
                          Expanded(flex: 5, child: Text('Date', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted(dark)))),
                        ]),
                      ),
                      // Rows
                      Expanded(
                        child: list.isEmpty
                            ? Center(child: Text('No expenses found', style: TextStyle(color: kTextDim(dark), fontSize: 13)))
                            : ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (ctx, i) => _ExpenseTableRow(
                                  expense: list[i],
                                  showBorder: i < list.length - 1,
                                  dark: dark,
                                  onTap: () => _openDetail(ctx, list[i]),
                                ),
                              ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ]),
        );
      },
    );
  }
}

// v1.1 — tappable row, no actions column, date column instead
class _ExpenseTableRow extends StatelessWidget {
  final Expense expense;
  final bool showBorder, dark;
  final VoidCallback onTap;
  const _ExpenseTableRow({required this.expense, required this.showBorder, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = _appState.getCategoryByName(expense.categoryName);
    final color = cat?.color ?? const Color(0xFF888780);
    final icon = cat?.icon ?? '🏷️';
    final shortCat = expense.categoryName.split(' ').first;
    final dateStr = DateFormat('MMM d').format(expense.date);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: showBorder ? Border(bottom: BorderSide(color: kBorder(dark), width: 0.5)) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(children: [
          // Description (icon + name)
          Expanded(
            flex: 8,
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(expense.desc, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kText(dark)), overflow: TextOverflow.ellipsis),
                  if (expense.remarks.isNotEmpty)
                    Text(expense.remarks, style: TextStyle(fontSize: 9, color: kTextDim(dark)), overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
          // Category pill
          Expanded(
            flex: 6,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  Flexible(child: Text(shortCat, style: TextStyle(fontSize: 10, color: color), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ),
          // Amount
          Expanded(
            flex: 5,
            child: Text(_fmt(expense.amount), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kText(dark))),
          ),
          // Date (replaces Actions)
          Expanded(
            flex: 5,
            child: Text(dateStr, textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: kTextDim(dark))),
          ),
        ]),
      ),
    );
  }
}

// Home screen expense list tile — also tappable
class _ExpenseListTile extends StatelessWidget {
  final Expense expense;
  final bool showBorder, dark;
  const _ExpenseListTile({required this.expense, required this.showBorder, required this.dark});

  @override
  Widget build(BuildContext context) {
    final cat = _appState.getCategoryByName(expense.categoryName);
    final color = cat?.color ?? const Color(0xFF888780);
    final icon = cat?.icon ?? '🏷️';
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    String dateLabel;
    if (expense.date.year == now.year && expense.date.month == now.month && expense.date.day == now.day) {
      dateLabel = 'Today';
    } else if (expense.date.year == yesterday.year && expense.date.month == yesterday.month && expense.date.day == yesterday.day) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('MMM d').format(expense.date);
    }

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ExpenseDetailSheet(expense: expense),
      ),
      child: Container(
        decoration: BoxDecoration(border: showBorder ? Border(bottom: BorderSide(color: kBorder(dark), width: 0.5)) : null),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(9)), alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 15))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(expense.desc, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kText(dark)), overflow: TextOverflow.ellipsis),
            Text(expense.categoryName, style: TextStyle(fontSize: 10, color: kTextMuted(dark))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmt(expense.amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kText(dark))),
            Text(dateLabel, style: TextStyle(fontSize: 10, color: kTextDim(dark))),
          ]),
        ]),
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
  late TextEditingController _amountCtrl, _descCtrl, _remarksCtrl;
  late String _selectedCat;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _descCtrl = TextEditingController(text: e?.desc ?? '');
    _remarksCtrl = TextEditingController(text: e?.remarks ?? '');
    _selectedCat = e?.categoryName ?? (_appState.categories.isNotEmpty ? _appState.categories.first.name : '');
    _selectedDate = e?.date ?? DateTime.now();
  }

  @override
  void dispose() { _amountCtrl.dispose(); _descCtrl.dispose(); _remarksCtrl.dispose(); super.dispose(); }

  void _save() {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    final desc = _descCtrl.text.trim().isEmpty ? 'Expense' : _descCtrl.text.trim();
    final remarks = _remarksCtrl.text.trim();
    if (widget.existing != null) {
      _appState.updateExpense(Expense(id: widget.existing!.id, desc: desc, categoryName: _selectedCat, amount: amt, date: _selectedDate, remarks: remarks));
    } else {
      _appState.addExpense(Expense(id: 0, desc: desc, categoryName: _selectedCat, amount: amt, date: _selectedDate, remarks: remarks));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dark = _appState.isDarkMode;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface(dark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: kBorder(dark), width: 0.5)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder(dark), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text(widget.existing != null ? 'Edit expense' : 'Add expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText(dark))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(flex: 3, child: _buildField('Amount (₱)', _amountCtrl, dark: dark, isNumber: true)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _buildDateField(dark)),
          ]),
          const SizedBox(height: 10),
          _buildField('Description', _descCtrl, dark: dark),
          const SizedBox(height: 10),
          _buildCatField(dark),
          const SizedBox(height: 10),
          // Remarks field (v1.1)
          _buildField('Remarks (optional)', _remarksCtrl, dark: dark, hint: 'e.g. Chickenjoy + rice'),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF534AB7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _save,
            child: const Text('Save expense', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: TextButton(
            style: TextButton.styleFrom(foregroundColor: kPurpleLight(dark), padding: const EdgeInsets.symmetric(vertical: 10)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          )),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {required bool dark, bool isNumber = false, String? hint}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
        style: TextStyle(color: kText(dark), fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: kBg(dark),
          hintText: hint,
          hintStyle: TextStyle(color: kTextDim(dark), fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF534AB7), width: 1)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        ),
      ),
    ]);
  }

  Widget _buildDateField(bool dark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Date', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(
              data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF534AB7), surface: Color(0xFF18162E))),
              child: child!,
            ),
          );
          if (d != null) setState(() => _selectedDate = d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: kBg(dark), borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder(dark), width: 0.5)),
          child: Text(DateFormat('MMM d, yyyy').format(_selectedDate), style: TextStyle(fontSize: 13, color: kText(dark))),
        ),
      ),
    ]);
  }

  Widget _buildCatField(bool dark) {
    final validCat = _appState.categories.any((c) => c.name == _selectedCat)
        ? _selectedCat
        : (_appState.categories.isNotEmpty ? _appState.categories.first.name : '');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Category', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(color: kBg(dark), borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder(dark), width: 0.5)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: validCat,
            isExpanded: true,
            dropdownColor: kSurface(dark),
            style: TextStyle(color: kText(dark), fontSize: 13),
            items: _appState.categories.map((c) => DropdownMenuItem(value: c.name, child: Text('${c.icon}  ${c.name}'))).toList(),
            onChanged: (v) { if (v != null) setState(() => _selectedCat = v); },
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _exporting = false;
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (_, __) {
        final dark = _appState.isDarkMode;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Text('Settings', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: kText(dark))),
              ),
              _SettingsGroup(label: 'Appearance', dark: dark, items: [
                _SettingsToggleRow(label: 'Dark mode', value: _appState.isDarkMode, dark: dark, onChanged: (_) => _appState.toggleDarkMode()),
                _SettingsStaticRow(label: 'Currency', dark: dark, trailing: Text('PHP (₱)', style: TextStyle(fontSize: 12, color: kTextDim(dark)))),
              ]),
              const SizedBox(height: 4),
              _SettingsGroup(label: 'Categories', dark: dark, items: [
                _SettingsTapRow(
                  label: 'Manage categories', dark: dark,
                  trailing: Icon(Icons.chevron_right, color: kTextDim(dark), size: 18),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                ),
              ]),
              const SizedBox(height: 4),
              _SettingsGroup(label: 'Data', dark: dark, items: [
                _SettingsTapRow(
                  label: 'Export data',
                  dark: dark,
                  trailing: _exporting
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPurpleLight(dark)))
                      : Text('CSV ›', style: TextStyle(fontSize: 12, color: kTextDim(dark))),
                  onTap: _exporting ? () {} : () => _exportCsv(context, dark),
                ),
                _SettingsTapRow(
                  label: 'Import data',
                  dark: dark,
                  trailing: _importing
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPurpleLight(dark)))
                      : Icon(Icons.chevron_right, color: kTextDim(dark), size: 18),
                  onTap: _importing ? () {} : () => _showImportWarning(context, dark),
                ),
              ]),
              const SizedBox(height: 4),
              _SettingsGroup(label: 'General', dark: dark, items: [
                _SettingsToggleRow(label: 'Notifications', value: _appState.notificationsEnabled, dark: dark, onChanged: (_) => _appState.toggleNotifications()),
                _SettingsTapRow(label: 'About', dark: dark, trailing: Text('v1.1.1 ›', style: TextStyle(fontSize: 12, color: kTextDim(dark))), onTap: () => _showAboutDialog(context, dark)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  // ── EXPORT ──────────────────────────────────────────────

  Future<void> _exportCsv(BuildContext context, bool dark) async {
    setState(() => _exporting = true);
    try {
      // Build CSV content
      final csv = StringBuffer('id,date,description,category,amount,remarks\n');
      for (final e in _appState.expenses) {
        final date = DateFormat('yyyy-MM-dd').format(e.date);
        final desc = _csvEscape(e.desc);
        final cat = _csvEscape(e.categoryName);
        final remarks = _csvEscape(e.remarks);
        csv.writeln('${e.id},$date,$desc,$cat,${e.amount.toStringAsFixed(2)},$remarks');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'expenses_$timestamp.csv';
      final file = await _resolveExportFile(fileName);

      await file.writeAsString(csv.toString());

      if (context.mounted) {
        _showSnackbar(context, dark,
          icon: Icons.check_circle_outline,
          color: const Color(0xFF4CAF50),
          message: 'Saved: $fileName',
          detail: file.path,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackbar(context, dark,
          icon: Icons.error_outline,
          color: const Color(0xFFE24B4A),
          message: 'Export failed: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Returns a File in Documents/ExpenseTracker/ on internal storage.
  /// Creates the folder if it doesn't exist.
  /// Falls back to app documents dir if public storage is inaccessible.
  Future<File> _resolveExportFile(String fileName) async {
    // Request storage permission for Android ≤ 12 (API 32)
    // Android 13+ doesn't need WRITE_EXTERNAL_STORAGE for Documents
    final sdkInt = await _getAndroidSdkInt();
    if (sdkInt != null && sdkInt <= 32) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission denied. Please allow it in app settings.');
      }
    }

    // Try the user-visible public Documents folder first
    // /storage/emulated/0/Documents/ExpenseTracker/
    const publicDocs = '/storage/emulated/0/Documents';
    final publicDir = Directory('$publicDocs/ExpenseTracker');
    try {
      if (!await publicDir.exists()) await publicDir.create(recursive: true);
      return File('${publicDir.path}/$fileName');
    } catch (_) {
      // Fallback: use external app-specific dir (still visible via USB/file manager)
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final fallback = Directory('${extDir.path}/ExpenseTracker');
        if (!await fallback.exists()) await fallback.create(recursive: true);
        return File('${fallback.path}/$fileName');
      }
      // Last resort: app documents dir
      final appDir = await getApplicationDocumentsDirectory();
      return File('${appDir.path}/$fileName');
    }
  }

  Future<int?> _getAndroidSdkInt() async {
    try {
      const channel = MethodChannel('flutter/platform');
      // Use the standard Flutter platform channel to get Android version
      final info = await channel.invokeMethod<Map>('getDeviceInfo');
      return info?['sdkInt'] as int?;
    } catch (_) {
      // Can't determine — assume modern Android, skip storage permission request
      return null;
    }
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // ── IMPORT WARNING ───────────────────────────────────────

  void _showImportWarning(BuildContext context, bool dark) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: kSurface(dark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: kBorder(dark), width: 0.5)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF791F1F), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const Text('⚠️', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Text('Import data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText(dark))),
            ]),
            const SizedBox(height: 14),
            Text(
              'Your current expense data will be permanently overwritten with the contents of the CSV file.',
              style: TextStyle(fontSize: 13, color: kText(dark), height: 1.5),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kBg(dark),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder(dark), width: 0.5),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_outline, size: 14, color: kPurpleLight(dark)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'We recommend exporting your data first before importing, so you have a backup.',
                  style: TextStyle(fontSize: 12, color: kPurpleLight(dark), height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPurpleLight(dark),
                  side: BorderSide(color: kBorder(dark), width: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _exportCsv(context, dark);
                },
                child: const Text('Export first', style: TextStyle(fontSize: 13)),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF791F1F),
                  foregroundColor: const Color(0xFFF09595),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _pickAndImportCsv(context, dark);
                },
                child: const Text('Overwrite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── IMPORT ───────────────────────────────────────────────

  Future<void> _pickAndImportCsv(BuildContext context, bool dark) async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _importing = false);
        return;
      }

      final path = result.files.single.path;
      if (path == null) throw Exception('Could not read file path');

      final content = await File(path).readAsString();
      final imported = _parseCsv(content);

      final count = await _appState.importExpenses(imported);

      if (context.mounted) {
        _showSnackbar(context, dark,
          icon: Icons.check_circle_outline,
          color: const Color(0xFF4CAF50),
          message: 'Imported $count expense${count != 1 ? 's' : ''} successfully',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackbar(context, dark,
          icon: Icons.error_outline,
          color: const Color(0xFFE24B4A),
          message: 'Import failed: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  List<Expense> _parseCsv(String content) {
    final lines = content.trim().split('\n');
    if (lines.isEmpty) return [];

    // Validate header
    final header = lines.first.trim().toLowerCase();
    final hasIdCol = header.startsWith('id,');

    final expenses = <Expense>[];
    int autoId = 1;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = _splitCsvLine(line);

      try {
        if (hasIdCol) {
          // Format: id, date, description, category, amount, remarks
          if (cols.length < 5) continue;
          final id = int.tryParse(cols[0]) ?? autoId++;
          final date = DateTime.parse(cols[1]);
          final desc = cols[2].isEmpty ? 'Expense' : cols[2];
          final cat = cols[3];
          final amount = double.parse(cols[4]);
          final remarks = cols.length > 5 ? cols[5] : '';
          expenses.add(Expense(id: id, desc: desc, categoryName: cat, amount: amount, date: date, remarks: remarks));
        } else {
          // Legacy format: date, description, category, amount, remarks
          if (cols.length < 4) continue;
          final date = DateTime.parse(cols[0]);
          final desc = cols[1].isEmpty ? 'Expense' : cols[1];
          final cat = cols[2];
          final amount = double.parse(cols[3]);
          final remarks = cols.length > 4 ? cols[4] : '';
          expenses.add(Expense(id: autoId++, desc: desc, categoryName: cat, amount: amount, date: date, remarks: remarks));
        }
      } catch (_) {
        continue; // Skip malformed rows
      }
    }

    return expenses;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"'); i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(buf.toString()); buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString());
    return result;
  }

  // ── HELPERS ──────────────────────────────────────────────

  void _showSnackbar(BuildContext context, bool dark, {
    required IconData icon, required Color color, required String message, String? detail,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: kSurface(dark),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: kBorder(dark), width: 0.5)),
      duration: const Duration(seconds: 4),
      content: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(message, style: TextStyle(fontSize: 13, color: kText(dark), fontWeight: FontWeight.w500)),
          if (detail != null)
            Text(detail, style: TextStyle(fontSize: 10, color: kTextDim(dark)), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    ));
  }

  void _showAboutDialog(BuildContext context, bool dark) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: kSurface(dark),
      title: Text('GastosFlow', style: TextStyle(color: kText(dark))),
      content: Text('Version 1.1.1\nA personal expense tracker built with Flutter.', style: TextStyle(fontSize: 13, color: kPurpleLight(dark))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFF534AB7))))],
    ));
  }
}

class _SettingsGroup extends StatelessWidget {
  final String label;
  final List<Widget> items;
  final bool dark;
  const _SettingsGroup({required this.label, required this.items, required this.dark});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 6), child: Text(label.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 0.5, color: kPurpleLight(dark)))),
    Container(margin: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: kSurface(dark), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder(dark), width: 0.5)), child: Column(children: items)),
  ]);
}

class _SettingsStaticRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final bool dark;
  const _SettingsStaticRow({required this.label, required this.trailing, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorder(dark), width: 0.5))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 14, color: kText(dark))), trailing]),
  );
}

class _SettingsToggleRow extends StatelessWidget {
  final String label;
  final bool value, dark;
  final ValueChanged<bool> onChanged;
  const _SettingsToggleRow({required this.label, required this.value, required this.dark, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorder(dark), width: 0.5))),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 14, color: kText(dark))),
      Switch(value: value, activeColor: const Color(0xFF534AB7), onChanged: onChanged),
    ]),
  );
}

class _SettingsTapRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback onTap;
  final bool dark;
  const _SettingsTapRow({required this.label, required this.trailing, required this.onTap, required this.dark});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kBorder(dark), width: 0.5))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 14, color: kText(dark))), trailing]),
    ),
  );
}

// ─────────────────────────────────────────────
// CATEGORIES SCREEN
// ─────────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (_, __) {
        final dark = _appState.isDarkMode;
        return Scaffold(
          backgroundColor: kBg(dark),
          appBar: AppBar(
            backgroundColor: kBg(dark), foregroundColor: kPurpleLight(dark), elevation: 0,
            title: Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: kText(dark))),
          ),
          body: Column(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  decoration: BoxDecoration(color: kSurface(dark), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder(dark), width: 0.5)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ListView.builder(
                      itemCount: _appState.categories.length,
                      itemBuilder: (ctx, i) {
                        final c = _appState.categories[i];
                        final count = _appState.expenses.where((e) => e.categoryName == c.name).length;
                        return Container(
                          decoration: BoxDecoration(border: i < _appState.categories.length - 1 ? Border(bottom: BorderSide(color: kBorder(dark), width: 0.5)) : null),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Container(width: 36, height: 36, decoration: BoxDecoration(color: c.color.withOpacity(0.15), borderRadius: BorderRadius.circular(9)), alignment: Alignment.center, child: Text(c.icon, style: const TextStyle(fontSize: 18))),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText(dark))),
                              Text('$count expense${count != 1 ? 's' : ''}', style: TextStyle(fontSize: 10, color: kTextMuted(dark))),
                            ])),
                            GestureDetector(onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => CategoryFormSheet(existing: c)), child: const Padding(padding: EdgeInsets.all(6), child: Text('✏️', style: TextStyle(fontSize: 16)))),
                            GestureDetector(onTap: () => showDialog(context: context, builder: (_) => _DeleteDialog(title: 'Delete category?', body: '"${c.name}" — existing expenses will become uncategorized.', onConfirm: () => _appState.deleteCategory(c.id))), child: const Padding(padding: EdgeInsets.all(6), child: Text('🗑', style: TextStyle(fontSize: 16)))),
                          ]),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(width: double.infinity, child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: kPurpleLight(dark), side: const BorderSide(color: Color(0xFF534AB7), width: 0.5), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const CategoryFormSheet()),
                child: const Text('+ Add new category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              )),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY FORM SHEET
// ─────────────────────────────────────────────

const _kIcons = ['🍜','🍔','🍕','🥤','☕','🛒','🚌','🚗','⛽','✈️','💊','🏥','🎬','🎮','📱','💡','🏠','👕','💈','📚','🐾','💰','🎁','🏋️'];
const _kColors = [Color(0xFF534AB7),Color(0xFFE24B4A),Color(0xFF378ADD),Color(0xFF639922),Color(0xFFD85A30),Color(0xFFBA7517),Color(0xFFD4537E),Color(0xFF1D9E75),Color(0xFF888780)];

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
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedIcon = widget.existing?.icon ?? _kIcons[0];
    _selectedColor = widget.existing?.color ?? _kColors[0];
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

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
    final dark = _appState.isDarkMode;
    final previewName = _nameCtrl.text.isEmpty ? 'Category name' : _nameCtrl.text;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: kSurface(dark), borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), border: Border(top: BorderSide(color: kBorder(dark), width: 0.5))),
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorder(dark), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text(widget.existing != null ? 'Edit category' : 'New category', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText(dark))),
          const SizedBox(height: 12),
          Text('Category name', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
          const SizedBox(height: 4),
          TextField(
            controller: _nameCtrl, onChanged: (_) => setState(() {}),
            style: TextStyle(color: kText(dark), fontSize: 13),
            decoration: InputDecoration(
              filled: true, fillColor: kBg(dark),
              hintText: 'e.g. Entertainment', hintStyle: TextStyle(color: kTextDim(dark), fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kBorder(dark), width: 0.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF534AB7), width: 1)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
          const SizedBox(height: 12),
          Text('Choose icon', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: _kIcons.length,
            itemBuilder: (_, i) {
              final ic = _kIcons[i];
              final sel = ic == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = ic),
                child: Container(
                  decoration: BoxDecoration(color: sel ? kPurpleDarker(dark) : kBg(dark), borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? kPurpleLight(dark) : kBorder(dark), width: sel ? 1.5 : 0.5)),
                  alignment: Alignment.center,
                  child: Text(ic, style: const TextStyle(fontSize: 16)),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text('Choose color', style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: _kColors.map((c) {
            final sel = c == _selectedColor;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = c),
              child: Container(width: 28, height: 28, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2))),
            );
          }).toList()),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: dark ? const Color(0xFF141228) : const Color(0xFFF0EEFF), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: _selectedColor.withOpacity(0.2), borderRadius: BorderRadius.circular(9)), alignment: Alignment.center, child: Text(_selectedIcon, style: const TextStyle(fontSize: 18))),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(previewName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText(dark))),
                Text('Preview', style: TextStyle(fontSize: 10, color: kTextMuted(dark))),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF534AB7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _save,
            child: const Text('Save category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: TextButton(
            style: TextButton.styleFrom(foregroundColor: kPurpleLight(dark), padding: const EdgeInsets.symmetric(vertical: 10)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          )),
        ])),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DELETE DIALOG
// ─────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final String title, body;
  final VoidCallback onConfirm;
  const _DeleteDialog({required this.title, required this.body, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final dark = _appState.isDarkMode;
    return Dialog(
      backgroundColor: kSurface(dark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: kBorder(dark), width: 0.5)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🗑️', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText(dark))),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kTextMuted(dark))),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: kPurpleLight(dark), side: BorderSide(color: kBorder(dark), width: 0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(context), child: const Text('Cancel'),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF791F1F), foregroundColor: const Color(0xFFF09595), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () { Navigator.pop(context); onConfirm(); },
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w500)),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────

String _fmt(double v) => '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
