// =============================================================================
// Experiment 7: Data Persistence using Google Cloud Firestore
//
// Aim: Store and retrieve employee information in Cloud Firestore so the
// data is still there after the app is closed and reopened.
//
//   Store    : EmployeeRepository.addEmployee() -> collection('employees').doc(id).set()
//   Retrieve : EmployeeRepository.watchEmployees() -> real-time snapshots()
//
// The banner at the top shows whether the list came from the Firestore
// server or from the on-device cache (Firestore keeps an offline copy).
//
// Setup (see README):
//   flutter pub add firebase_core cloud_firestore
//   flutterfire configure  (select the Web platform)          -> creates lib/firebase_options.dart
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
  final DateTime? createdAt;

  const Employee({
    required this.empId,
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    required this.salary,
    this.createdAt,
  });

  /// Fields written to Firestore. The *Lower fields support case-insensitive
  /// search in Experiment 8.
  Map<String, dynamic> toMap() => {
        'empId': empId,
        'name': name,
        'nameLower': name.toLowerCase(),
        'designation': designation,
        'department': department,
        'departmentLower': department.toLowerCase(),
        'email': email,
        'phone': phone,
        'salary': salary,
      };

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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class DuplicateEmployeeException implements Exception {
  final String empId;
  const DuplicateEmployeeException(this.empId);
}

// -----------------------------------------------------------------------------
// Firestore repository
// -----------------------------------------------------------------------------

class EmployeeRepository {
  final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('employees');

  /// Live list of employees, newest first. includeMetadataChanges lets the UI
  /// show whether data is from the cache and whether writes are pending.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchEmployees() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  /// Saves a new employee, using the employee ID as the document ID.
  Future<void> addEmployee(Employee employee) async {
    final docRef = _collection.doc(employee.empId);
    final existing = await docRef.get();
    if (existing.exists) throw DuplicateEmployeeException(employee.empId);

    await docRef.set({
      ...employee.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
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
  if (dt == null) return 'Saving…';
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

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee Directory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: const EmployeeListScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// Retrieve: live list
// -----------------------------------------------------------------------------

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final _repository = EmployeeRepository();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      _repository.watchEmployees();

  Future<void> _openAddEmployee() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEmployeeScreen(repository: _repository),
      ),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee saved to Firestore')),
      );
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
      appBar: AppBar(title: const Text('Employee Directory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddEmployee,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Employee'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageView(
              icon: Icons.error_outline,
              title: 'Could not load employees',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final query = snapshot.data!;
          final docs = query.docs;

          return Column(
            children: [
              SyncBanner(
                fromCache: query.metadata.isFromCache,
                count: docs.length,
              ),
              Expanded(
                child: docs.isEmpty
                    ? const _MessageView(
                        icon: Icons.groups_outlined,
                        title: 'No employees yet',
                        message:
                            'Tap "Add Employee" to store the first record.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final employee = Employee.fromDoc(doc);
                          return EmployeeTile(
                            employee: employee,
                            pending: doc.metadata.hasPendingWrites,
                            onTap: () => _showDetails(employee),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SyncBanner extends StatelessWidget {
  final bool fromCache;
  final int count;

  const SyncBanner({super.key, required this.fromCache, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = fromCache ? Colors.orange.shade800 : Colors.green.shade700;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Color.lerp(color, Colors.white, 0.88),
      child: Row(
        children: [
          Icon(
            fromCache ? Icons.cloud_off : Icons.cloud_done,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fromCache
                  ? 'Showing data saved on this device (offline cache)'
                  : 'Synced with Cloud Firestore',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Text('$count records', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class EmployeeTile extends StatelessWidget {
  final Employee employee;
  final bool pending;
  final VoidCallback onTap;

  const EmployeeTile({
    super.key,
    required this.employee,
    required this.pending,
    required this.onTap,
  });

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
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${employee.designation}  ·  ${employee.department}'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              employee.empId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Icon(
              pending ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
              size: 16,
              color: pending ? Colors.orange : Colors.green,
            ),
          ],
        ),
      ),
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
          row(Icons.schedule, 'Added on', formatDateTime(employee.createdAt)),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Store: add employee form
// -----------------------------------------------------------------------------

class AddEmployeeScreen extends StatefulWidget {
  final EmployeeRepository repository;

  const AddEmployeeScreen({super.key, required this.repository});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _salaryController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _idController,
      _nameController,
      _designationController,
      _departmentController,
      _emailController,
      _phoneController,
      _salaryController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final employee = Employee(
      empId: _idController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      designation: _designationController.text.trim(),
      department: _departmentController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      phone: _phoneController.text.trim(),
      salary: double.parse(_salaryController.text.trim()),
    );

    try {
      await widget.repository.addEmployee(employee);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DuplicateEmployeeException catch (e) {
      _showError('Employee ID ${e.empId} already exists');
    } on FirebaseException catch (e) {
      _showError('Firestore error: ${e.message ?? e.code}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String? _required(String? value, String field) =>
      (value?.trim().isEmpty ?? true) ? '$field is required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Employee')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _idController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Employee ID',
                    Icons.badge_outlined,
                    hint: 'e.g. EMP101',
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Employee ID is required';
                    if (!RegExp(r'^[A-Za-z0-9]{3,12}$').hasMatch(text)) {
                      return 'Use 3–12 letters/digits, no spaces';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Full name', Icons.person_outline),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Name is required';
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
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Designation',
                    Icons.work_outline,
                    hint: 'e.g. Software Engineer',
                  ),
                  validator: (v) => _required(v, 'Designation'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _departmentController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Department',
                    Icons.apartment,
                    hint: 'e.g. Engineering',
                  ),
                  validator: (v) => _required(v, 'Department'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Email', Icons.email_outlined),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$')
                        .hasMatch(text)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  maxLength: 10,
                  decoration: _decoration('Phone', Icons.phone_outlined),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(text)) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _salaryController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_saving ? 'Saving…' : 'Save to Firestore'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
