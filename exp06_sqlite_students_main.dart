// =============================================================================
// Experiment 6: Data Persistence using SQLite
//
// Aim: Store and retrieve student records in a local SQLite database,
// implementing the Create and Read operations.
//
//   CREATE : DatabaseHelper.insertStudent()   -> INSERT INTO students ...
//   READ   : DatabaseHelper.getAllStudents()  -> SELECT * FROM students
//            DatabaseHelper.searchStudents()  -> SELECT ... WHERE ... LIKE ?
//            DatabaseHelper.countStudents()   -> SELECT COUNT(*) ...
//
// Records stay on the device after the app is closed and reopened.
//
// Add packages:  flutter pub add sqflite path sqflite_common_ffi_web
// One-time web setup (copies sqlite3.wasm + worker into web/):
//   dart run sqflite_common_ffi_web:setup
// Run on Chrome:  flutter run -d chrome   (data is stored in browser IndexedDB)
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Use the WebAssembly SQLite implementation when running in Chrome.
    databaseFactory = databaseFactoryFfiWeb;
  }
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// Model
// -----------------------------------------------------------------------------

class Student {
  final int? id;
  final String regNo;
  final String name;
  final String department;
  final int year;
  final double cgpa;
  final String email;

  const Student({
    this.id,
    required this.regNo,
    required this.name,
    required this.department,
    required this.year,
    required this.cgpa,
    required this.email,
  });

  /// Converts to a row for the `students` table.
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'reg_no': regNo,
        'name': name,
        'department': department,
        'year': year,
        'cgpa': cgpa,
        'email': email,
      };

  /// Builds a Student from a row read from the database.
  factory Student.fromMap(Map<String, Object?> map) => Student(
        id: map['id'] as int?,
        regNo: map['reg_no'] as String,
        name: map['name'] as String,
        department: map['department'] as String,
        year: map['year'] as int,
        cgpa: (map['cgpa'] as num).toDouble(),
        email: map['email'] as String,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

// -----------------------------------------------------------------------------
// Database helper (singleton)
// -----------------------------------------------------------------------------

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'students.db';
  static const _dbVersion = 1;
  static const table = 'students';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $table (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            reg_no      TEXT    NOT NULL UNIQUE,
            name        TEXT    NOT NULL,
            department  TEXT    NOT NULL,
            year        INTEGER NOT NULL,
            cgpa        REAL    NOT NULL,
            email       TEXT    NOT NULL
          )
        ''');
      },
    );
  }

  // CREATE -------------------------------------------------------------------

  /// Inserts a student and returns the new row id.
  /// Throws a [DatabaseException] if the register number already exists.
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return db.insert(
      table,
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // READ ---------------------------------------------------------------------

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final rows = await db.query(table, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((row) => Student.fromMap(row)).toList();
  }

  Future<List<Student>> searchStudents(String keyword) async {
    final db = await database;
    final pattern = '%${keyword.trim()}%';
    final rows = await db.query(
      table,
      where: 'name LIKE ? OR reg_no LIKE ? OR department LIKE ?',
      whereArgs: [pattern, pattern, pattern],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map((row) => Student.fromMap(row)).toList();
  }

  Future<int> countStudents() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Records',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const StudentListScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// READ screen
// -----------------------------------------------------------------------------

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();

  late Future<List<Student>> _studentsFuture;
  late Future<int> _countFuture;

  @override
  void initState() {
    super.initState();
    _queryDatabase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Starts the READ queries (all rows, or rows matching the search box).
  void _queryDatabase() {
    final keyword = _searchController.text.trim();
    _studentsFuture = keyword.isEmpty
        ? _db.getAllStudents()
        : _db.searchStudents(keyword);
    _countFuture = _db.countStudents();
  }

  void _loadStudents() => setState(_queryDatabase);

  Future<void> _openAddStudent() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
    );
    if (added == true) {
      _loadStudents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student record saved to SQLite')),
      );
    }
  }

  void _showDetails(Student s) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StudentDetailSheet(student: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Records'),
        actions: [
          FutureBuilder<int>(
            future: _countFuture,
            builder: (context, snapshot) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Chip(
                avatar: const Icon(Icons.storage, size: 18),
                label: Text('${snapshot.data ?? 0} saved'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStudent,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadStudents(),
              decoration: InputDecoration(
                hintText: 'Search by name, register no. or department',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadStudents();
                        },
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final students = snapshot.data ?? [];
                if (students.isEmpty) {
                  return _EmptyState(
                    searching: _searchController.text.trim().isNotEmpty,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: students.length,
                  itemBuilder: (context, index) => StudentTile(
                    student: students[index],
                    onTap: () => _showDetails(students[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StudentTile extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;

  const StudentTile({super.key, required this.student, required this.onTap});

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
            student.initials,
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${student.regNo}  ·  ${student.department}  ·  Year ${student.year}',
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              student.cgpa.toStringAsFixed(2),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: scheme.primary,
              ),
            ),
            const Text('CGPA', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class StudentDetailSheet extends StatelessWidget {
  final Student student;

  const StudentDetailSheet({super.key, required this.student});

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
          CircleAvatar(radius: 32, child: Text(student.initials)),
          const SizedBox(height: 8),
          Text(student.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          row(Icons.tag, 'Record ID', '${student.id}'),
          row(Icons.badge_outlined, 'Register No.', student.regNo),
          row(Icons.apartment, 'Department', student.department),
          row(Icons.school_outlined, 'Year', '${student.year}'),
          row(Icons.grade_outlined, 'CGPA', student.cgpa.toStringAsFixed(2)),
          row(Icons.email_outlined, 'Email', student.email),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool searching;

  const _EmptyState({required this.searching});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.folder_open,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              searching ? 'No matching students' : 'No student records yet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              searching
                  ? 'Try another name or register number.'
                  : 'Tap "Add Student" to create the first record.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CREATE screen
// -----------------------------------------------------------------------------

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _regNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _cgpaController = TextEditingController();
  final _emailController = TextEditingController();
  int _year = 1;
  bool _saving = false;

  @override
  void dispose() {
    _regNoController.dispose();
    _nameController.dispose();
    _departmentController.dispose();
    _cgpaController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final student = Student(
      regNo: _regNoController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      department: _departmentController.text.trim().toUpperCase(),
      year: _year,
      cgpa: double.parse(_cgpaController.text.trim()),
      email: _emailController.text.trim().toLowerCase(),
    );

    try {
      await DatabaseHelper.instance.insertStudent(student);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DatabaseException catch (e) {
      if (!mounted) return;
      final message = e.isUniqueConstraintError()
          ? 'A student with register number ${student.regNo} already exists'
          : 'Could not save: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
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
                  controller: _regNoController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Register number',
                    Icons.badge_outlined,
                    hint: 'e.g. URK23CS1001',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Register number is required';
                    if (!RegExp(r'^[A-Za-z0-9]{5,15}$').hasMatch(text)) {
                      return 'Use 5–15 letters/digits, no spaces';
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
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Name is required';
                    if (text.length < 3) return 'Name is too short';
                    if (!RegExp(r"^[A-Za-z .']+$").hasMatch(text)) {
                      return 'Use letters, spaces, dots and apostrophes only';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _departmentController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Department',
                    Icons.apartment,
                    hint: 'e.g. CSE',
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Department is required'
                      : null,
                ),
                const SizedBox(height: 14),
                const Text('Year of study'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1st')),
                    ButtonSegment(value: 2, label: Text('2nd')),
                    ButtonSegment(value: 3, label: Text('3rd')),
                    ButtonSegment(value: 4, label: Text('4th')),
                  ],
                  selected: {_year},
                  onSelectionChanged: (selection) =>
                      setState(() => _year = selection.first),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cgpaController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'CGPA',
                    Icons.grade_outlined,
                    hint: '0.00 – 10.00',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'CGPA is required';
                    final cgpa = double.tryParse(text);
                    if (cgpa == null) return 'Enter a valid number';
                    if (cgpa < 0 || cgpa > 10) {
                      return 'CGPA must be between 0 and 10';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: _decoration('Email', Icons.email_outlined),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email is required';
                    final emailRegex =
                        RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$');
                    if (!emailRegex.hasMatch(text)) {
                      return 'Enter a valid email address';
                    }
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
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving…' : 'Save to Database'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
