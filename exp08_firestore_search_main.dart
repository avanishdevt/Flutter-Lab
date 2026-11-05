// =============================================================================
// Experiment 8: Firestore Data Retrieval
//
// Aim: Retrieve records from Cloud Firestore based on the user's search
// input and display the matching records dynamically.
//
// How the search works:
//   * The user picks a field (Name / Employee ID / Department) and types.
//   * After a short pause (debounce) a Firestore prefix query is run:
//       where(field >= term) and where(field <= term + '')
//     so "pri" matches "Priya Sharma".
//   * Results arrive through a real-time stream, so they update live if
//     the data changes in Firestore.
//
// Uses the same 'employees' collection as Experiment 7 (nameLower and
// departmentLower fields make the search case-insensitive). If the
// collection is empty, tap the "Add sample employees" button.
//
// Setup: flutter pub add firebase_core cloud_firestore
//        flutterfire configure
// =============================================================================

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

final CollectionReference<Map<String, dynamic>> employeesCollection =
    FirebaseFirestore.instance.collection('employees');

// -----------------------------------------------------------------------------
// Model
// -----------------------------------------------------------------------------

class Employee {
  final String empId;
  final String name;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final double salary;

  const Employee({
    required this.empId,
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    required this.salary,
  });

  factory Employee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Employee(
      empId: (data['empId'] ?? doc.id) as String,
      name: (data['name'] ?? '') as String,
      designation: (data['designation'] ?? '') as String,
      department: (data['department'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      salary: (data['salary'] as num?)?.toDouble() ?? 0,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Which Firestore field the search runs against.
enum SearchField {
  name('Name', 'name', 'Search by employee name', 'nameLower', Icons.person_search),
  empId('Emp ID', 'ID', 'Search by employee ID (e.g. EMP00)', 'empId', Icons.badge),
  department('Dept.', 'department', 'Search by department', 'departmentLower', Icons.apartment);

  const SearchField(
    this.label,
    this.noun,
    this.hint,
    this.firestoreField,
    this.icon,
  );
  final String label;
  final String noun;
  final String hint;
  final String firestoreField;
  final IconData icon;

  /// IDs are stored in upper case; names/departments are searched in lower case.
  String normalise(String input) => this == SearchField.empId
      ? input.trim().toUpperCase()
      : input.trim().toLowerCase();

  /// The value shown (and highlighted) for this field in a result.
  String valueOf(Employee e) => switch (this) {
        SearchField.name => e.name,
        SearchField.empId => e.empId,
        SearchField.department => e.department,
      };
}

/// Builds the Firestore query for a search term.
Query<Map<String, dynamic>> buildSearchQuery(SearchField field, String term) {
  if (term.isEmpty) {
    return employeesCollection.orderBy('nameLower').limit(50);
  }
  return employeesCollection
      .where(field.firestoreField, isGreaterThanOrEqualTo: term)
      .where(field.firestoreField, isLessThanOrEqualTo: '$term')
      .orderBy(field.firestoreField)
      .limit(50);
}

// -----------------------------------------------------------------------------
// Sample data (so the experiment works even on an empty database)
// -----------------------------------------------------------------------------

const List<Map<String, Object>> sampleEmployees = [
  {'empId': 'EMP001', 'name': 'Arun Kumar', 'designation': 'Software Engineer', 'department': 'Engineering', 'email': 'arun.kumar@example.com', 'phone': '9876500001', 'salary': 65000},
  {'empId': 'EMP002', 'name': 'Priya Sharma', 'designation': 'HR Manager', 'department': 'Human Resources', 'email': 'priya.sharma@example.com', 'phone': '9876500002', 'salary': 72000},
  {'empId': 'EMP003', 'name': 'Rahul Menon', 'designation': 'Data Analyst', 'department': 'Analytics', 'email': 'rahul.menon@example.com', 'phone': '9876500003', 'salary': 58000},
  {'empId': 'EMP004', 'name': 'Sneha Reddy', 'designation': 'UI/UX Designer', 'department': 'Design', 'email': 'sneha.reddy@example.com', 'phone': '9876500004', 'salary': 61000},
  {'empId': 'EMP005', 'name': 'Vikram Singh', 'designation': 'DevOps Engineer', 'department': 'Engineering', 'email': 'vikram.singh@example.com', 'phone': '9876500005', 'salary': 70000},
  {'empId': 'EMP006', 'name': 'Ananya Iyer', 'designation': 'Marketing Executive', 'department': 'Marketing', 'email': 'ananya.iyer@example.com', 'phone': '9876500006', 'salary': 48000},
  {'empId': 'EMP007', 'name': 'Karthik Raja', 'designation': 'QA Engineer', 'department': 'Engineering', 'email': 'karthik.raja@example.com', 'phone': '9876500007', 'salary': 52000},
  {'empId': 'EMP008', 'name': 'Divya Nair', 'designation': 'Accountant', 'department': 'Finance', 'email': 'divya.nair@example.com', 'phone': '9876500008', 'salary': 55000},
];

Future<void> seedSampleEmployees() async {
  final batch = FirebaseFirestore.instance.batch();
  for (final e in sampleEmployees) {
    batch.set(
      employeesCollection.doc(e['empId'] as String),
      {
        ...e,
        'nameLower': (e['name'] as String).toLowerCase(),
        'departmentLower': (e['department'] as String).toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
  await batch.commit();
}

String formatInr(num value) {
  final digits = value.round().toString();
  if (digits.length <= 3) return '₹$digits';
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '₹${groups.join(',')},$last3';
}

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee Search',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.cyan, useMaterial3: true),
      home: const EmployeeSearchScreen(),
    );
  }
}

class EmployeeSearchScreen extends StatefulWidget {
  const EmployeeSearchScreen({super.key});

  @override
  State<EmployeeSearchScreen> createState() => _EmployeeSearchScreenState();
}

class _EmployeeSearchScreenState extends State<EmployeeSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  SearchField _field = SearchField.name;
  String _term = '';
  late Stream<QuerySnapshot<Map<String, dynamic>>> _results =
      buildSearchQuery(_field, _term).snapshots();
  bool _seeding = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Replaces the stream only when the search actually changes.
  void _runSearch() {
    final term = _field.normalise(_searchController.text);
    setState(() {
      _term = term;
      _results = buildSearchQuery(_field, term).snapshots();
    });
  }

  void _onSearchChanged(String _) {
    setState(() {}); // refresh the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  void _onFieldChanged(SearchField field) {
    _field = field;
    _runSearch();
  }

  void _clear() {
    _searchController.clear();
    _runSearch();
  }

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      await seedSampleEmployees();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${sampleEmployees.length} sample employees')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firestore error: ${e.message ?? e.code}')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _showDetails(Employee e) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EmployeeDetailSheet(employee: e),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Search'),
        actions: [
          IconButton(
            tooltip: 'Add sample employees',
            onPressed: _seeding ? null : _seed,
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _runSearch(),
              textInputAction: TextInputAction.search,
              textCapitalization: _field == SearchField.empId
                  ? TextCapitalization.characters
                  : TextCapitalization.words,
              decoration: InputDecoration(
                hintText: _field.hint,
                prefixIcon: Icon(_field.icon),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: _clear,
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<SearchField>(
                showSelectedIcon: false,
                segments: [
                  for (final f in SearchField.values)
                    ButtonSegment(
                      value: f,
                      icon: Icon(f.icon, size: 18),
                      label: Text(f.label),
                    ),
                ],
                selected: {_field},
                onSelectionChanged: (s) => _onFieldChanged(s.first),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _results,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _MessageView(
                    icon: Icons.error_outline,
                    title: 'Search failed',
                    message: '${snapshot.error}',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return _term.isEmpty
                      ? _MessageView(
                          icon: Icons.cloud_off,
                          title: 'No employees in Firestore yet',
                          message:
                              'Add records with Experiment 7, or load sample data.',
                          action: FilledButton.icon(
                            onPressed: _seeding ? null : _seed,
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Add sample employees'),
                          ),
                        )
                      : _MessageView(
                          icon: Icons.search_off,
                          title: 'No match found',
                          message:
                              'No employee ${_field.noun} starts with '
                              '"${_searchController.text.trim()}".',
                        );
                }

                final employees = docs.map(Employee.fromDoc).toList();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            _term.isEmpty
                                ? 'All employees (${employees.length})'
                                : '${employees.length} record(s) found',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            snapshot.data!.metadata.isFromCache
                                ? 'from cache'
                                : 'from server',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final e = employees[index];
                          return ResultCard(
                            employee: e,
                            field: _field,
                            searchText: _searchController.text.trim(),
                            onTap: () => _showDetails(e),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Widgets
// -----------------------------------------------------------------------------

class ResultCard extends StatelessWidget {
  final Employee employee;
  final SearchField field;
  final String searchText;
  final VoidCallback onTap;

  const ResultCard({
    super.key,
    required this.employee,
    required this.field,
    required this.searchText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget text(SearchField f, String value, {TextStyle? style}) => f == field
        ? HighlightedPrefix(text: value, prefix: searchText, style: style)
        : Text(value, style: style);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            employee.initials,
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ),
        title: text(
          SearchField.name,
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Flexible(child: Text('${employee.designation}  ·  ')),
            Flexible(child: text(SearchField.department, employee.department)),
          ],
        ),
        trailing: text(
          SearchField.empId,
          employee.empId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Highlights [prefix] at the start of [text] (case-insensitive).
class HighlightedPrefix extends StatelessWidget {
  final String text;
  final String prefix;
  final TextStyle? style;

  const HighlightedPrefix({
    super.key,
    required this.text,
    required this.prefix,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final matches = prefix.isNotEmpty &&
        text.toLowerCase().startsWith(prefix.toLowerCase());
    if (!matches) return Text(text, style: style, overflow: TextOverflow.ellipsis);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: text.substring(0, prefix.length),
            style: TextStyle(
              backgroundColor: Colors.yellow.shade300,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(prefix.length)),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class EmployeeDetailSheet extends StatelessWidget {
  final Employee employee;

  const EmployeeDetailSheet({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String value) => ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(label),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 32, child: Text(employee.initials)),
          const SizedBox(height: 8),
          Text(employee.name, style: Theme.of(context).textTheme.titleLarge),
          Text(employee.designation),
          const SizedBox(height: 8),
          row(Icons.badge_outlined, 'Employee ID', employee.empId),
          row(Icons.apartment, 'Department', employee.department),
          row(Icons.email_outlined, 'Email', employee.email),
          row(Icons.phone_outlined, 'Phone', employee.phone),
          row(Icons.payments_outlined, 'Monthly salary', formatInr(employee.salary)),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
