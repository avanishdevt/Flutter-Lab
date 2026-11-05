// =============================================================================
// Experiment 9: Firestore Data Update
//
// Aim: Let the user update existing records stored in Cloud Firestore and
// display the updated information.
//
// Flow:
//   1. The list screen streams every employee from Firestore (live).
//   2. Tapping a record opens the edit form, pre-filled with its values.
//   3. The user edits fields; "Update" is enabled only when something changed.
//   4. A confirmation dialog lists each change (old -> new).
//   5. docRef.update({...}) writes only the edited fields + updatedAt.
//   6. The "Stored in Firestore" card on the same screen is a live stream of
//      the document, so it refreshes with the new values straight away, and
//      the list shows an "Updated" badge.
//
// Uses the same 'employees' collection as Experiments 7 and 8. If it is empty,
// tap "Add sample employees".
//
// Setup: flutter pub add firebase_core cloud_firestore
//        flutterfire configure
// =============================================================================

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
  final DateTime? updatedAt;

  const Employee({
    required this.empId,
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    required this.salary,
    this.updatedAt,
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
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Fields the user is allowed to edit (employee ID is the document key).
  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'nameLower': name.toLowerCase(),
        'designation': designation,
        'department': department,
        'departmentLower': department.toLowerCase(),
        'email': email,
        'phone': phone,
        'salary': salary,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get recentlyUpdated =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) < const Duration(minutes: 10);
}

class FieldChange {
  final String label;
  final String from;
  final String to;

  const FieldChange(this.label, this.from, this.to);
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

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

String formatDateTime(DateTime? dt) {
  if (dt == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} '
      '${dt.year}, $hour:$minute $period';
}

/// Salary as it should appear in the text field (no ".0" for whole numbers).
String salaryText(double salary) => salary == salary.roundToDouble()
    ? salary.toStringAsFixed(0)
    : salary.toStringAsFixed(2);

const List<Map<String, Object>> sampleEmployees = [
  {'empId': 'EMP001', 'name': 'Arun Kumar', 'designation': 'Software Engineer', 'department': 'Engineering', 'email': 'arun.kumar@example.com', 'phone': '9876500001', 'salary': 65000},
  {'empId': 'EMP002', 'name': 'Priya Sharma', 'designation': 'HR Manager', 'department': 'Human Resources', 'email': 'priya.sharma@example.com', 'phone': '9876500002', 'salary': 72000},
  {'empId': 'EMP003', 'name': 'Rahul Menon', 'designation': 'Data Analyst', 'department': 'Analytics', 'email': 'rahul.menon@example.com', 'phone': '9876500003', 'salary': 58000},
  {'empId': 'EMP004', 'name': 'Sneha Reddy', 'designation': 'UI/UX Designer', 'department': 'Design', 'email': 'sneha.reddy@example.com', 'phone': '9876500004', 'salary': 61000},
  {'empId': 'EMP005', 'name': 'Vikram Singh', 'designation': 'DevOps Engineer', 'department': 'Engineering', 'email': 'vikram.singh@example.com', 'phone': '9876500005', 'salary': 70000},
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

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Update Employee Records',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      home: const EmployeeListScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// List screen
// -----------------------------------------------------------------------------

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final _filterController = TextEditingController();
  final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      employeesCollection.orderBy('nameLower').snapshots();
  bool _seeding = false;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      await seedSampleEmployees();
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore error: ${e.message ?? e.code}')),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _openEditor(Employee employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditEmployeeScreen(initial: employee),
      ),
    );
  }

  bool _matches(Employee e, String filter) {
    if (filter.isEmpty) return true;
    return e.name.toLowerCase().contains(filter) ||
        e.empId.toLowerCase().contains(filter) ||
        e.department.toLowerCase().contains(filter);
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filterController.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Employee Records'),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _filterController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Find by name, employee ID or department',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined, size: 16),
                SizedBox(width: 6),
                Text('Tap a record to edit it'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!.docs.map(Employee.fromDoc).toList();
                if (all.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No employee records in Firestore'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _seeding ? null : _seed,
                          icon: const Icon(Icons.playlist_add),
                          label: const Text('Add sample employees'),
                        ),
                      ],
                    ),
                  );
                }

                final visible = all.where((e) => _matches(e, filter)).toList();
                if (visible.isEmpty) {
                  return const Center(child: Text('No matching employee'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final e = visible[index];
                    return _EmployeeTile(
                      employee: e,
                      onTap: () => _openEditor(e),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;

  const _EmployeeTile({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
        title: Row(
          children: [
            Flexible(
              child: Text(
                employee.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (employee.recentlyUpdated) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Updated',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${employee.empId}  ·  ${employee.designation}\n'
          'Last updated: ${formatDateTime(employee.updatedAt)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Edit screen
// -----------------------------------------------------------------------------

class EditEmployeeScreen extends StatefulWidget {
  final Employee initial;

  const EditEmployeeScreen({super.key, required this.initial});

  @override
  State<EditEmployeeScreen> createState() => _EditEmployeeScreenState();
}

class _EditEmployeeScreenState extends State<EditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  late final DocumentReference<Map<String, dynamic>> _docRef =
      employeesCollection.doc(widget.initial.empId);
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _docStream =
      _docRef.snapshots(includeMetadataChanges: true);

  /// Values last saved to Firestore; used to detect unsaved edits.
  late Employee _original = widget.initial;

  late final _nameController = TextEditingController(text: _original.name);
  late final _designationController =
      TextEditingController(text: _original.designation);
  late final _departmentController =
      TextEditingController(text: _original.department);
  late final _emailController = TextEditingController(text: _original.email);
  late final _phoneController = TextEditingController(text: _original.phone);
  late final _salaryController =
      TextEditingController(text: salaryText(_original.salary));

  bool _saving = false;

  List<TextEditingController> get _controllers => [
        _nameController,
        _designationController,
        _departmentController,
        _emailController,
        _phoneController,
        _salaryController,
      ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Employee built from what is currently typed in the form.
  Employee get _edited => Employee(
        empId: _original.empId,
        name: _nameController.text.trim(),
        designation: _designationController.text.trim(),
        department: _departmentController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phone: _phoneController.text.trim(),
        salary: double.tryParse(_salaryController.text.trim()) ?? -1,
      );

  List<FieldChange> get _changes {
    final o = _original;
    final n = _edited;
    return [
      if (o.name != n.name) FieldChange('Name', o.name, n.name),
      if (o.designation != n.designation)
        FieldChange('Designation', o.designation, n.designation),
      if (o.department != n.department)
        FieldChange('Department', o.department, n.department),
      if (o.email != n.email) FieldChange('Email', o.email, n.email),
      if (o.phone != n.phone) FieldChange('Phone', o.phone, n.phone),
      if (o.salary != n.salary)
        FieldChange(
          'Salary',
          formatInr(o.salary),
          n.salary < 0 ? _salaryController.text : formatInr(n.salary),
        ),
    ];
  }

  void _discardChanges() {
    _nameController.text = _original.name;
    _designationController.text = _original.designation;
    _departmentController.text = _original.department;
    _emailController.text = _original.email;
    _phoneController.text = _original.phone;
    _salaryController.text = salaryText(_original.salary);
    _formKey.currentState?.validate();
    setState(() {});
  }

  Future<void> _update() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final changes = _changes;
    if (changes.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm update'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update ${changes.length} field(s) for ${_original.empId}?'),
              const SizedBox(height: 12),
              for (final c in changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${c.label}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: c.from,
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                        const TextSpan(text: '  →  '),
                        TextSpan(
                          text: c.to,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final updated = _edited;
    try {
      // update() fails if the document no longer exists, unlike set().
      await _docRef.update(updated.toUpdateMap());
      if (!mounted) return;
      setState(() => _original = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${changes.length} field(s) updated in Firestore'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'not-found'
          ? 'This record was deleted from Firestore'
          : 'Update failed: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    final hasChanges = _changes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('Edit ${_original.empId}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StoredRecordCard(stream: _docStream),
                const SizedBox(height: 20),
                Text(
                  'Edit details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: () => setState(() {}),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            _decoration('Full name', Icons.person_outline),
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (!RegExp(r"^[A-Za-z .']{3,}$").hasMatch(text)) {
                            return 'Enter at least 3 letters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _designationController,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            _decoration('Designation', Icons.work_outline),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Designation is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _departmentController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration('Department', Icons.apartment),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Department is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoration('Email', Icons.email_outlined),
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (!RegExp(
                            r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$',
                          ).hasMatch(text)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: _decoration('Phone', Icons.phone_outlined),
                        validator: (v) {
                          if (!RegExp(r'^[6-9]\d{9}$')
                              .hasMatch(v?.trim() ?? '')) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _salaryController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _decoration(
                          'Monthly salary (₹)',
                          Icons.payments_outlined,
                        ),
                        validator: (v) {
                          final salary = double.tryParse(v?.trim() ?? '');
                          if (salary == null) return 'Enter a valid amount';
                          if (salary <= 0) return 'Salary must be greater than 0';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            hasChanges && !_saving ? _discardChanges : null,
                        child: const Text('Discard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: hasChanges && !_saving ? _update : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync),
                        label: Text(
                          _saving
                              ? 'Updating…'
                              : hasChanges
                                  ? 'Update (${_changes.length})'
                                  : 'No changes',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live view of the document as it is stored in Firestore right now.
class StoredRecordCard extends StatelessWidget {
  final Stream<DocumentSnapshot<Map<String, dynamic>>> stream;

  const StoredRecordCard({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(child: ListTile(title: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final doc = snapshot.data!;
        if (!doc.exists) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('This record no longer exists in Firestore'),
            ),
          );
        }

        final e = Employee.fromDoc(doc);
        final pending = doc.metadata.hasPendingWrites;

        Widget row(String label, String value) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      label,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );

        return Card(
          color: Color.lerp(scheme.primary, Colors.white, 0.92),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      pending ? Icons.cloud_upload : Icons.cloud_done,
                      color: pending ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pending ? 'Saving to Firestore…' : 'Stored in Firestore',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(e.empId),
                  ],
                ),
                const Divider(height: 20),
                row('Name', e.name),
                row('Designation', e.designation),
                row('Department', e.department),
                row('Email', e.email),
                row('Phone', e.phone),
                row('Salary', formatInr(e.salary)),
                row(
                  'Last updated',
                  pending ? 'just now' : formatDateTime(e.updatedAt),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
