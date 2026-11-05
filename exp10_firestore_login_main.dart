// =============================================================================
// Experiment 10: User Authentication using Firestore
//
// Aim: A secure User Login System using email and password credentials
// stored in Cloud Firestore, with proper validation and a professional UI.
//
// Security measures:
//   * Passwords are NEVER stored in plain text. Each user gets a random
//     16-byte salt and the password is hashed with PBKDF2-HMAC-SHA256
//     (10,000 iterations). Only the salt and hash are saved.
//   * Hashing runs in a background isolate (compute) so the UI stays smooth.
//   * Hashes are compared in constant time.
//   * Login errors never reveal whether the email or the password was wrong.
//   * The email (lower-case) is the document ID, so it is unique.
//   * Strong-password rules + live strength meter at registration.
//
// Firestore: collection 'users', document ID = email
//   { name, email, passwordHash, salt, iterations, algorithm,
//     createdAt, lastLoginAt }
//
// Setup: flutter pub add firebase_core cloud_firestore crypto
//        flutterfire configure
// =============================================================================

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// Password hashing (PBKDF2-HMAC-SHA256)
// -----------------------------------------------------------------------------

const int kHashIterations = 10000;

typedef HashRequest = ({String password, String salt, int iterations});

/// Top-level so it can run in a separate isolate via compute().
String pbkdf2Sha256(HashRequest request) {
  final hmac = Hmac(sha256, utf8.encode(request.password));
  // First block: U1 = HMAC(password, salt || INT(1))
  var block = hmac.convert([...utf8.encode(request.salt), 0, 0, 0, 1]).bytes;
  final result = List<int>.of(block);
  // U2..Un, XOR-ed together
  for (var i = 1; i < request.iterations; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return base64Encode(result);
}

String generateSalt([int length = 16]) {
  final random = Random.secure();
  return base64Encode(List<int>.generate(length, (_) => random.nextInt(256)));
}

bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

// -----------------------------------------------------------------------------
// Auth service
// -----------------------------------------------------------------------------

class AppUser {
  final String name;
  final String email;
  final DateTime? createdAt;
  final DateTime? previousLogin;

  const AppUser({
    required this.name,
    required this.email,
    this.createdAt,
    this.previousLogin,
  });
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final CollectionReference<Map<String, dynamic>> _users =
      FirebaseFirestore.instance.collection('users');

  static const _invalidCredentials = 'Incorrect email or password.';

  Future<String> _hash(String password, String salt, int iterations) {
    return compute(
      pbkdf2Sha256,
      (password: password, salt: salt, iterations: iterations),
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final docRef = _users.doc(normalizedEmail);

    final existing = await docRef.get();
    if (existing.exists) {
      throw const AuthException('An account with this email already exists.');
    }

    final salt = generateSalt();
    final hash = await _hash(password, salt, kHashIterations);

    await docRef.set({
      'name': name.trim(),
      'email': normalizedEmail,
      'passwordHash': hash,
      'salt': salt,
      'iterations': kHashIterations,
      'algorithm': 'PBKDF2-HMAC-SHA256',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': null,
    });
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final docRef = _users.doc(normalizedEmail);
    final snapshot = await docRef.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw const AuthException(_invalidCredentials);
    }

    final salt = data['salt'] as String?;
    final storedHash = data['passwordHash'] as String?;
    final iterations = (data['iterations'] as num?)?.toInt() ?? kHashIterations;
    if (salt == null || storedHash == null) {
      throw const AuthException(_invalidCredentials);
    }

    final hash = await _hash(password, salt, iterations);
    if (!constantTimeEquals(hash, storedHash)) {
      throw const AuthException(_invalidCredentials);
    }

    await docRef.update({'lastLoginAt': FieldValue.serverTimestamp()});

    return AppUser(
      name: (data['name'] as String?) ?? '',
      email: normalizedEmail,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      previousLogin: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }
}

// -----------------------------------------------------------------------------
// Validation
// -----------------------------------------------------------------------------

class Validators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Name is required';
    if (text.length < 3) return 'Name must be at least 3 characters';
    if (!RegExp(r"^[A-Za-z .']+$").hasMatch(text)) {
      return 'Use letters, spaces, dots and apostrophes only';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (!_email.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 8) return 'Use at least 8 characters';
    if (text.contains(' ')) return 'Password cannot contain spaces';
    if (!RegExp(r'[A-Z]').hasMatch(text)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(text)) return 'Add a lowercase letter';
    if (!RegExp(r'\d').hasMatch(text)) return 'Add a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(text)) {
      return 'Add a special character (e.g. @ # \$ %)';
    }
    return null;
  }

  /// 0–5: one point per rule met.
  static int passwordScore(String text) {
    var score = 0;
    if (text.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(text)) score++;
    if (RegExp(r'[a-z]').hasMatch(text)) score++;
    if (RegExp(r'\d').hasMatch(text)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(text)) score++;
    return score;
  }
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return 'First login';
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

String friendlyError(Object error) {
  if (error is AuthException) return error.message;
  if (error is FirebaseException) {
    if (error.code == 'unavailable') {
      return 'Cannot reach the server. Check your internet connection.';
    }
    if (error.code == 'permission-denied') {
      return 'Firestore rules are blocking access to the users collection.';
    }
    return 'Server error: ${error.message ?? error.code}';
  }
  return 'Something went wrong. Please try again.';
}

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3949AB)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared UI pieces
// -----------------------------------------------------------------------------

/// Gradient background with a centred, width-limited card.
class AuthScaffold extends StatelessWidget {
  final Widget child;

  const AuthScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF7E57C2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, size: 34, color: scheme.primary),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

InputDecoration authInputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );
}

/// Password field with a show / hide toggle.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      decoration: authInputDecoration(widget.label, Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade800)),
          ),
        ],
      ),
    );
  }
}

class LoadingButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const LoadingButton({
    super.key,
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final score = Validators.passwordScore(password);
    final (String label, Color color) = switch (score) {
      0 || 1 || 2 => ('Weak', Colors.red.shade600),
      3 => ('Fair', Colors.orange.shade700),
      4 => ('Good', Colors.blue.shade600),
      _ => ('Strong', Colors.green.shade700),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < score ? color : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          password.isEmpty
              ? '8+ characters with upper & lower case, a number and a symbol'
              : 'Password strength: $label',
          style: TextStyle(
            fontSize: 12,
            color: password.isEmpty ? Colors.grey.shade600 : color,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Login screen
// -----------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
      _passwordController.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRegister() async {
    final registeredEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (registeredEmail != null && mounted) {
      _emailController.text = registeredEmail;
      _passwordController.clear();
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please sign in.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              icon: Icons.lock_outline,
              title: 'Welcome back',
              subtitle: 'Sign in with your email and password',
            ),
            const SizedBox(height: 28),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              decoration: authInputDecoration('Email', Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              validator: Validators.loginPassword,
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 24),
            LoadingButton(loading: _loading, label: 'Sign In', onPressed: _login),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: _loading ? null : _openRegister,
                  child: const Text('Create one'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Register screen
// -----------------------------------------------------------------------------

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _loading = true);
    try {
      await AuthService.instance.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, _emailController.text.trim().toLowerCase());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back to sign in',
                onPressed: _loading ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            const AuthHeader(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Create account',
              subtitle: 'Your password is stored only as a salted hash',
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: Validators.name,
              decoration: authInputDecoration('Full name', Icons.person_outline),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              decoration: authInputDecoration('Email', Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              validator: Validators.newPassword,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            PasswordStrengthMeter(password: _passwordController.text),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirmController,
              label: 'Confirm password',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 24),
            LoadingButton(
              loading: _loading,
              label: 'Create Account',
              onPressed: _register,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Home screen (after login)
// -----------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  final AppUser user;

  const HomeScreen({super.key, required this.user});

  String get _initials {
    final parts = user.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your password to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget infoTile(IconData icon, String label, String value) => ListTile(
          leading: Icon(icon, color: scheme.primary),
          title: Text(label),
          subtitle: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3949AB), Color(0xFF7E57C2)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3949AB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Signed in successfully',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hello, ${user.name}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    infoTile(Icons.email_outlined, 'Email', user.email),
                    const Divider(height: 1),
                    infoTile(
                      Icons.calendar_today_outlined,
                      'Member since',
                      user.createdAt == null
                          ? '—'
                          : formatDateTime(user.createdAt),
                    ),
                    const Divider(height: 1),
                    infoTile(
                      Icons.history,
                      'Previous sign-in',
                      formatDateTime(user.previousLogin),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.green.shade50,
                child: const ListTile(
                  leading: Icon(Icons.verified_user, color: Colors.green),
                  title: Text('Your password is protected'),
                  subtitle: Text(
                    'It is stored in Firestore only as a salted '
                    'PBKDF2-SHA256 hash, never as plain text.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
