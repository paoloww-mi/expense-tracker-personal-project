import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Expense({required this.id, required this.desc, required this.categoryName, required this.amount, required this.date});

  Map<String, dynamic> toJson() => {
    'id': id, 'desc': desc, 'categoryName': categoryName,
    'amount': amount, 'date': date.toIso8601String(),
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'], desc: j['desc'], categoryName: j['categoryName'],
    amount: (j['amount'] as num).toDouble(), date: DateTime.parse(j['date']),
  );
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
      _nextCatId = categories.isEmpty ? 1 : categories.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
    }

    final expJson = prefs.getString('expenses');
    if (expJson != null) {
      final list = jsonDecode(expJson) as List;
      expenses = list.map((e) => Expense.fromJson(e)).toList();
      _nextExpenseId = expenses.isEmpty ? 1 : expenses.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
    } else {
      _seedSampleData();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDarkMode);
    await prefs.setBool('notifications', notificationsEnabled);
    await prefs.setString('categories', jsonEncode(categories.map((c) => c.toJson()).toList()));
    await prefs.setString('expenses', jsonEncode(expenses.map((e) => e.toJson()).toList()));
  }

  void _seedSampleData() {
    final now = DateTime.now();
    expenses = [
      Expense(id: _nextExpenseId++, desc: 'Jollibee', categoryName: 'Food & Dining', amount: 185, date: DateTime(now.year, now.month, now.day)),
      Expense(id: _nextExpenseId++, desc: 'Commute (jeep)', categoryName: 'Transport', amount: 56, date: DateTime(now.year, now.month, now.day)),
      Expense(id: _nextExpenseId++, desc: 'SM Grocery run', categoryName: 'Groceries', amount: 1240, date: DateTime(now.year, now.month, now.day - 1)),
      Expense(id: _nextExpenseId++, desc: 'Mercury Drug', categoryName: 'Health', amount: 320, date: DateTime(now.year, now.month, now.day - 1)),
      Expense(id: _nextExpenseId++, desc: "Bo's Coffee", categoryName: 'Food & Dining', amount: 210, date: DateTime(now.year, now.month, now.day - 2)),
      Expense(id: _nextExpenseId++, desc: 'Globe Load', categoryName: 'Utilities', amount: 99, date: DateTime(now.year, now.month, now.day - 3)),
      Expense(id: _nextExpenseId++, desc: 'Netflix subscription', categoryName: 'Entertainment', amount: 459, date: DateTime(now.year, now.month, now.day - 4)),
      Expense(id: _nextExpenseId++, desc: 'Grab ride', categoryName: 'Transport', amount: 135, date: DateTime(now.year, now.month, now.day - 4)),
      Expense(id: _nextExpenseId++, desc: 'Shopee haul', categoryName: 'Shopping', amount: 890, date: DateTime(now.year, now.month, now.day - 5)),
      Expense(id: _nextExpenseId++, desc: 'Mang Inasal', categoryName: 'Food & Dining', amount: 175, date: DateTime(now.year, now.month, now.day - 6)),
    ];
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
    return _sumWhere((e) => !e.date.isBefore(weekStart) && !e.date.isAfter(DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59)));
  }

  double get avgPerDay {
    final now = DateTime.now();
    final days = expenses.where((e) => e.date.year == now.year && e.date.month == now.month).map((e) => e.date.day).toSet().length;
    return days == 0 ? 0 : monthTotal / days;
  }

  List<double> get weeklyAmounts {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return List.generate(7, (i) {
      final d = weekStart.add(Duration(days: i));
      return _sumWhere((e) => e.date.year == d.year && e.date.month == d.month && e.date.day == d.day);
    });
  }

  int get todayIndex => DateTime.now().weekday - 1;

  void toggleDarkMode() { isDarkMode = !isDarkMode; _save(); notifyListeners(); }
  void toggleNotifications() { notificationsEnabled = !notificationsEnabled; _save(); notifyListeners(); }

  void addExpense(Expense e) { e.id = _nextExpenseId++; expenses.insert(0, e); _save(); notifyListeners(); }
  void updateExpense(Expense u) { final i = expenses.indexWhere((e) => e.id == u.id); if (i != -1) expenses[i] = u; _save(); notifyListeners(); }
  void deleteExpense(int id) { expenses.removeWhere((e) => e.id == id); _save(); notifyListeners(); }

  void addCategory(Category c) { c.id = _nextCatId++; categories.add(c); _save(); notifyListeners(); }
  void updateCategory(Category u) { final i = categories.indexWhere((c) => c.id == u.id); if (i != -1) categories[i] = u; _save(); notifyListeners(); }
  void deleteCategory(int id) { categories.removeWhere((c) => c.id == id); _save(); notifyListeners(); }
}

final _appState = AppState();

// ─────────────────────────────────────────────
// THEME HELPERS
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
        title: 'Expense Tracker',
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
                    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                    builder: (_) => const ExpenseFormSheet(),
                  ),
                  child: const Icon(Icons.add, size: 28),
                )
              : null,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(color: kSurface(dark), border: Border(top: BorderSide(color: kBorder(dark), width: 0.5))),
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(DateFormat('EEEE, MMM d').format(now), style: TextStyle(fontSize: 12, color: kTextMuted(dark))),
                  const SizedBox(height: 2),
                  Text('Good ${_greeting()} 👋', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: kText(dark))),
                ]),
              ),
              // Hero spending card
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
                  if (val > 0) Text(_fmtShort(val), style: TextStyle(fontSize: 8, color: kPurpleLight(dark))),
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
// EXPENSES SCREEN
// ─────────────────────────────────────────────

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _filter = 'This month';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _filters = ['Today', 'This week', 'This month'];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<Expense> get _filtered {
    final now = DateTime.now();
    List<Expense> list;
    switch (_filter) {
      case 'Today':
        list = _appState.expenses.where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day).toList();
        break;
      case 'This week':
        final ws = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final we = ws.add(const Duration(days: 6));
        list = _appState.expenses.where((e) => !e.date.isBefore(ws) && !e.date.isAfter(DateTime(we.year, we.month, we.day, 23, 59))).toList();
        break;
      default:
        list = _appState.expenses.where((e) => e.date.year == now.year && e.date.month == now.month).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) => e.desc.toLowerCase().contains(q) || e.categoryName.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (_, __) {
        final dark = _appState.isDarkMode;
        final list = _filtered;
        final total = list.fold(0.0, (s, e) => s + e.amount);

        return SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: Text('Expenses', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: kText(dark))),
            ),
            // Functional search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: kText(dark), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  hintStyle: TextStyle(color: kTextDim(dark), fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: kTextDim(dark)),
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
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: _filters.map((f) {
                final active = f == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF534AB7) : kSurface(dark),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? const Color(0xFF534AB7) : kBorder(dark), width: 0.5),
                      ),
                      child: Text(f, style: TextStyle(fontSize: 12, color: active ? Colors.white : kPurpleLight(dark))),
                    ),
                  ),
                );
              }).toList()),
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
                  decoration: BoxDecoration(color: kSurface(dark), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder(dark), width: 0.5)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(children: [
                      Container(
                        color: dark ? const Color(0xFF141228) : const Color(0xFFF0EEFF),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text('Description', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted(dark)))),
                          Expanded(flex: 3, child: Text('Category', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted(dark)))),
                          Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted(dark)))),
                          Expanded(flex: 2, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextMuted(dark)))),
                        ]),
                      ),
                      Expanded(
                        child: list.isEmpty
                            ? Center(child: Text('No expenses found', style: TextStyle(color: kTextDim(dark), fontSize: 13)))
                            : ListView.builder(
                                itemCount: list.length,
                                itemBuilder: (ctx, i) => _ExpenseTableRow(
                                  expense: list[i],
                                  showBorder: i < list.length - 1,
                                  dark: dark,
                                  onEdit: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => ExpenseFormSheet(existing: list[i])),
                                  onDelete: () => showDialog(context: context, builder: (_) => _DeleteDialog(title: 'Delete expense?', body: '"${list[i].desc}" will be removed.', onConfirm: () => _appState.deleteExpense(list[i].id))),
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

class _ExpenseTableRow extends StatelessWidget {
  final Expense expense;
  final bool showBorder, dark;
  final VoidCallback onEdit, onDelete;
  const _ExpenseTableRow({required this.expense, required this.showBorder, required this.dark, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cat = _appState.getCategoryByName(expense.categoryName);
    final color = cat?.color ?? const Color(0xFF888780);
    final icon = cat?.icon ?? '🏷️';
    final shortCat = expense.categoryName.split(' ').first;
    return Container(
      decoration: BoxDecoration(border: showBorder ? Border(bottom: BorderSide(color: kBorder(dark), width: 0.5)) : null),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(children: [
        Expanded(flex: 3, child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Expanded(child: Text(expense.desc, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kText(dark)), overflow: TextOverflow.ellipsis)),
        ])),
        Expanded(flex: 3, child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 3),
            Flexible(child: Text(shortCat, style: TextStyle(fontSize: 10, color: color), overflow: TextOverflow.ellipsis)),
          ]),
        ))),
        Expanded(flex: 2, child: Text(_fmt(expense.amount), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kText(dark)))),
        Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(onTap: onEdit, child: const Padding(padding: EdgeInsets.all(4), child: Text('✏️', style: TextStyle(fontSize: 13)))),
          GestureDetector(onTap: onDelete, child: const Padding(padding: EdgeInsets.all(4), child: Text('🗑', style: TextStyle(fontSize: 13)))),
        ])),
      ]),
    );
  }
}

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
    return Container(
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
  late TextEditingController _amountCtrl, _descCtrl;
  late String _selectedCat;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amountCtrl = TextEditingController(text: e != null ? e.amount.toStringAsFixed(0) : '');
    _descCtrl = TextEditingController(text: e?.desc ?? '');
    _selectedCat = e?.categoryName ?? (_appState.categories.isNotEmpty ? _appState.categories.first.name : '');
    _selectedDate = e?.date ?? DateTime.now();
  }

  @override
  void dispose() { _amountCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

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
    final dark = _appState.isDarkMode;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: kSurface(dark), borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), border: Border(top: BorderSide(color: kBorder(dark), width: 0.5))),
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
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF534AB7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

  Widget _buildField(String label, TextEditingController ctrl, {required bool dark, bool isNumber = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: kPurpleLight(dark))),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
        style: TextStyle(color: kText(dark), fontSize: 13),
        decoration: InputDecoration(
          filled: true, fillColor: kBg(dark),
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
            context: context, initialDate: _selectedDate,
            firstDate: DateTime(2020), lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF534AB7), surface: Color(0xFF18162E))), child: child!),
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
    final validCat = _appState.categories.any((c) => c.name == _selectedCat) ? _selectedCat : (_appState.categories.isNotEmpty ? _appState.categories.first.name : '');
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                _SettingsTapRow(label: 'Manage categories', dark: dark, trailing: Icon(Icons.chevron_right, color: kTextDim(dark), size: 18),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
              ]),
              const SizedBox(height: 4),
              _SettingsGroup(label: 'Data', dark: dark, items: [
                _SettingsTapRow(label: 'Export data', dark: dark, trailing: Text('CSV ›', style: TextStyle(fontSize: 12, color: kTextDim(dark))), onTap: () => _showExportDialog(context, dark)),
                _SettingsTapRow(label: 'Import data', dark: dark, trailing: Icon(Icons.chevron_right, color: kTextDim(dark), size: 18), onTap: () => _showImportDialog(context, dark)),
              ]),
              const SizedBox(height: 4),
              _SettingsGroup(label: 'General', dark: dark, items: [
                _SettingsToggleRow(label: 'Notifications', value: _appState.notificationsEnabled, dark: dark, onChanged: (_) => _appState.toggleNotifications()),
                _SettingsTapRow(label: 'About', dark: dark, trailing: Text('v1.0 ›', style: TextStyle(fontSize: 12, color: kTextDim(dark))), onTap: () => _showAboutDialog(context, dark)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  void _showExportDialog(BuildContext context, bool dark) {
    final csv = StringBuffer('Date,Description,Category,Amount\n');
    for (final e in _appState.expenses) {
      csv.writeln('${DateFormat('yyyy-MM-dd').format(e.date)},${e.desc},${e.categoryName},${e.amount.toStringAsFixed(2)}');
    }
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: kSurface(dark),
      title: Text('Export data', style: TextStyle(color: kText(dark))),
      content: SingleChildScrollView(child: SelectableText(csv.toString(), style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: kPurpleLight(dark)))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Color(0xFF534AB7))))],
    ));
  }

  void _showImportDialog(BuildContext context, bool dark) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: kSurface(dark),
      title: Text('Import data', style: TextStyle(color: kText(dark))),
      content: Text('File import will be available in v2.\n\nFor now, use Export to view your data in CSV format.', style: TextStyle(fontSize: 13, color: kPurpleLight(dark))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFF534AB7))))],
    ));
  }

  void _showAboutDialog(BuildContext context, bool dark) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: kSurface(dark),
      title: Text('Expense Tracker', style: TextStyle(color: kText(dark))),
      content: Text('Version 1.0.0\nA personal expense tracker built with Flutter.', style: TextStyle(fontSize: 13, color: kPurpleLight(dark))),
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
