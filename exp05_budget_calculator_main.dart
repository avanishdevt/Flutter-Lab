// =============================================================================
// Experiment 5: Application State Management
//
// Aim: A Personal Budget Calculator that accepts income and expenses,
// calculates the remaining balance and shows the financial status.
//
// State management: the `provider` package.
//   * BudgetModel extends ChangeNotifier   -> holds the app state + logic
//   * ChangeNotifierProvider (above MaterialApp) -> makes it available app-wide
//   * context.watch / Consumer             -> widgets rebuild when state changes
//   * context.read                         -> call methods without rebuilding
//   * context.select                       -> rebuild only when one value changes
//
// Add package:  flutter pub add provider
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => BudgetModel(),
      child: const MyApp(),
    ),
  );
}

// -----------------------------------------------------------------------------
// Models
// -----------------------------------------------------------------------------

enum ExpenseCategory {
  food('Food', Icons.restaurant, Color(0xFFEF6C00)),
  rent('Rent', Icons.home, Color(0xFF5E35B1)),
  transport('Transport', Icons.directions_bus, Color(0xFF1E88E5)),
  bills('Bills', Icons.receipt_long, Color(0xFF00897B)),
  shopping('Shopping', Icons.shopping_bag, Color(0xFFD81B60)),
  education('Education', Icons.school, Color(0xFF3949AB)),
  health('Health', Icons.medical_services, Color(0xFFC62828)),
  other('Other', Icons.category, Color(0xFF616161));

  const ExpenseCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;

  Expense({
    required this.title,
    required this.amount,
    required this.category,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();
}

enum BudgetStatus {
  notStarted(
    'Getting started',
    'Enter your monthly income and add your expenses.',
    Icons.info_outline,
    Color(0xFF546E7A),
  ),
  healthy(
    'Healthy',
    'Great! You are saving 20% or more of your income.',
    Icons.verified,
    Color(0xFF2E7D32),
  ),
  tight(
    'Tight budget',
    'You are within budget but saving less than 20%.',
    Icons.warning_amber_rounded,
    Color(0xFFEF6C00),
  ),
  overBudget(
    'Over budget',
    'Your expenses are more than your income.',
    Icons.error_outline,
    Color(0xFFC62828),
  );

  const BudgetStatus(this.label, this.message, this.icon, this.color);
  final String label;
  final String message;
  final IconData icon;
  final Color color;
}

/// The single source of truth for the app. Widgets listen to it.
class BudgetModel extends ChangeNotifier {
  double _income = 0;
  final List<Expense> _expenses = [];
  int _resetCount = 0;

  double get income => _income;
  List<Expense> get expenses => List.unmodifiable(_expenses);
  int get resetCount => _resetCount;

  double get totalExpenses =>
      _expenses.fold<double>(0, (sum, e) => sum + e.amount);

  double get balance => _income - totalExpenses;

  /// Fraction of income that has been spent (can exceed 1).
  double get spentRatio => _income <= 0 ? 0 : totalExpenses / _income;

  double get savingsRate => _income <= 0 ? 0 : balance / _income;

  BudgetStatus get status {
    if (_income <= 0 && _expenses.isEmpty) return BudgetStatus.notStarted;
    if (balance < 0) return BudgetStatus.overBudget;
    if (savingsRate < 0.2) return BudgetStatus.tight;
    return BudgetStatus.healthy;
  }

  /// Total per category, largest first.
  List<MapEntry<ExpenseCategory, double>> get totalsByCategory {
    final totals = <ExpenseCategory, double>{};
    for (final e in _expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  void setIncome(double value) {
    if (value == _income) return;
    _income = value;
    notifyListeners();
  }

  void addExpense(Expense expense) {
    _expenses.insert(0, expense);
    notifyListeners();
  }

  /// Removes an expense and returns its old position (for undo).
  int removeExpense(String id) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _expenses.removeAt(index);
      notifyListeners();
    }
    return index;
  }

  void restoreExpense(int index, Expense expense) {
    final safeIndex =
        index < 0 ? 0 : (index > _expenses.length ? _expenses.length : index);
    _expenses.insert(safeIndex, expense);
    notifyListeners();
  }

  void reset() {
    _income = 0;
    _expenses.clear();
    _resetCount++;
    notifyListeners();
  }
}

/// ₹ with Indian digit grouping, e.g. -₹1,25,000.50
String formatInr(double value, {bool showDecimals = false}) {
  final negative = value < 0;
  final cents = (value.abs() * 100).round();
  final whole = (cents ~/ 100).toString();
  final decimals =
      showDecimals ? '.${(cents % 100).toString().padLeft(2, '0')}' : '';

  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    grouped = '${groups.join(',')},$last3';
  }
  return '${negative ? '-' : ''}₹$grouped$decimals';
}

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Budget Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const BudgetHomeScreen(),
    );
  }
}

class BudgetHomeScreen extends StatelessWidget {
  const BudgetHomeScreen({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text('This clears your income and all expenses.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<BudgetModel>().reset();
    }
  }

  void _openAddExpense(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddExpenseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild this widget only when the model is reset, so the income field
    // gets a fresh (empty) controller.
    final resetCount = context.select<BudgetModel, int>((m) => m.resetCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Calculator'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: () => _confirmReset(context),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddExpense(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              IncomeCard(key: ValueKey(resetCount)),
              const SizedBox(height: 12),
              const SummaryCard(),
              const SizedBox(height: 12),
              const CategoryBreakdownCard(),
              const SizedBox(height: 12),
              const ExpenseList(),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Widgets
// -----------------------------------------------------------------------------

class IncomeCard extends StatefulWidget {
  const IncomeCard({super.key});

  @override
  State<IncomeCard> createState() => _IncomeCardState();
}

class _IncomeCardState extends State<IncomeCard> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final income = context.read<BudgetModel>().income;
    _controller = TextEditingController(
      text: income > 0 ? income.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final budget = context.read<BudgetModel>();
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      setState(() => _error = null);
      budget.setIncome(0);
      return;
    }
    final value = double.tryParse(trimmed);
    if (value == null) {
      setState(() => _error = 'Enter a valid amount');
    } else if (value > 100000000) {
      setState(() => _error = 'That amount looks too large');
    } else {
      setState(() => _error = null);
      budget.setIncome(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined),
                SizedBox(width: 8),
                Text(
                  'Monthly Income',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              onChanged: _onChanged,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: 'Enter your monthly income',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Balance, status and spending progress. Uses context.watch.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetModel>();
    final status = budget.status;
    final spent = budget.spentRatio.clamp(0.0, 1.0).toDouble();

    return Card(
      color: Color.lerp(status.color, Colors.white, 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: status.color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Remaining Balance'),
            const SizedBox(height: 4),
            Text(
              formatInr(budget.balance, showDecimals: true),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: status.color,
              ),
            ),
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(status.icon, color: status.color, size: 18),
              label: Text(
                status.label,
                style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              side: BorderSide(color: status.color),
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              status.message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: spent,
                minHeight: 10,
                color: status.color,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              budget.income > 0
                  ? '${(budget.spentRatio * 100).toStringAsFixed(1)}% of income spent'
                  : 'Add your income to track spending',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _AmountTile(
                    label: 'Income',
                    amount: budget.income,
                    icon: Icons.arrow_downward,
                    color: Colors.green.shade700,
                  ),
                ),
                Expanded(
                  child: _AmountTile(
                    label: 'Expenses',
                    amount: budget.totalExpenses,
                    icon: Icons.arrow_upward,
                    color: Colors.red.shade700,
                  ),
                ),
                Expanded(
                  child: _AmountTile(
                    label: 'Savings',
                    amount: budget.balance < 0 ? 0 : budget.balance,
                    icon: Icons.savings_outlined,
                    color: Colors.blue.shade700,
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

class _AmountTile extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _AmountTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatInr(amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Spending per category. Uses Consumer.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetModel>(
      builder: (context, budget, _) {
        final totals = budget.totalsByCategory;
        if (totals.isEmpty) return const SizedBox.shrink();
        final total = budget.totalExpenses;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spending by Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (final entry in totals)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(entry.key.icon, color: entry.key.color, size: 20),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, child: Text(entry.key.label)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : entry.value / total,
                              minHeight: 8,
                              color: entry.key.color,
                              backgroundColor: Colors.grey.shade200,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 84,
                          child: Text(
                            formatInr(entry.value),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w600),
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
    );
  }
}

/// List of expenses; swipe left to delete (with undo). Uses Consumer.
class ExpenseList extends StatelessWidget {
  const ExpenseList({super.key});

  void _delete(BuildContext context, Expense expense) {
    final budget = context.read<BudgetModel>();
    final index = budget.removeExpense(expense.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${expense.title}"'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => budget.restoreExpense(index, expense),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetModel>(
      builder: (context, budget, _) {
        final expenses = budget.expenses;

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Expenses',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (expenses.isNotEmpty)
                        Text(
                          'Swipe left to delete',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No expenses yet. Tap "Add Expense" to begin.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                for (final expense in expenses)
                  Dismissible(
                    key: ValueKey(expense.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _delete(context, expense),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red.shade400,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Color.lerp(expense.category.color, Colors.white, 0.85),
                        child: Icon(
                          expense.category.icon,
                          color: expense.category.color,
                        ),
                      ),
                      title: Text(expense.title),
                      subtitle: Text(expense.category.label),
                      trailing: Text(
                        '- ${formatInr(expense.amount, showDecimals: true)}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
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

/// Bottom-sheet form for a new expense.
class AddExpenseSheet extends StatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.food;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<BudgetModel>().addExpense(
          Expense(
            title: _titleController.text.trim(),
            amount: double.parse(_amountController.text.trim()),
            category: _category,
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Groceries',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter a description';
                  if (text.length < 2) return 'Description is too short';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter an amount';
                  final amount = double.tryParse(text);
                  if (amount == null) return 'Enter a valid amount';
                  if (amount <= 0) return 'Amount must be greater than 0';
                  if (amount > 10000000) return 'That amount looks too large';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Category'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in ExpenseCategory.values)
                    ChoiceChip(
                      avatar: Icon(category.icon, size: 18),
                      label: Text(category.label),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
