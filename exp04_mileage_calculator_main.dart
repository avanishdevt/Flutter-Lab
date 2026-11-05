// =============================================================================
// Experiment 4: Form Validation using Stateful Widgets
//
// Aim: A Car Mileage Calculator built with Form, TextFormField, input widgets
// and a StatefulWidget. Inputs are validated and the mileage is shown
// dynamically.
//
//   Mileage (km/l)  = (final odometer − initial odometer) / fuel used
//   Consumption     = fuel used / distance × 100   (litres per 100 km)
//   Cost per km     = fuel used × price per litre / distance  (optional)
//
// After the first successful calculation the result updates live as the user
// edits any field, and validation errors appear as they type.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

// -----------------------------------------------------------------------------
// Result model
// -----------------------------------------------------------------------------

class MileageResult {
  final String vehicle;
  final double distance;
  final double fuel;
  final double? fuelPrice;

  const MileageResult({
    required this.vehicle,
    required this.distance,
    required this.fuel,
    this.fuelPrice,
  });

  double get kmPerLitre => distance / fuel;
  double get litresPer100Km => fuel / distance * 100;
  double? get totalCost => fuelPrice == null ? null : fuel * fuelPrice!;
  double? get costPerKm => fuelPrice == null ? null : totalCost! / distance;

  String get rating {
    if (kmPerLitre >= 20) return 'Excellent';
    if (kmPerLitre >= 15) return 'Good';
    if (kmPerLitre >= 10) return 'Average';
    return 'Poor';
  }

  Color get ratingColor {
    if (kmPerLitre >= 20) return Colors.green.shade700;
    if (kmPerLitre >= 15) return Colors.teal.shade600;
    if (kmPerLitre >= 10) return Colors.orange.shade800;
    return Colors.red.shade700;
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
      title: 'Car Mileage Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const MileageCalculatorScreen(),
    );
  }
}

class MileageCalculatorScreen extends StatefulWidget {
  const MileageCalculatorScreen({super.key});

  @override
  State<MileageCalculatorScreen> createState() =>
      _MileageCalculatorScreenState();
}

class _MileageCalculatorScreenState extends State<MileageCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _vehicleController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _fuelController = TextEditingController();
  final _priceController = TextEditingController();

  bool _includeCost = false;
  bool _hasCalculated = false;
  MileageResult? _result;

  List<TextEditingController> get _controllers => [
        _vehicleController,
        _startController,
        _endController,
        _fuelController,
        _priceController,
      ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validators
  // ---------------------------------------------------------------------------

  String? _validateVehicle(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the vehicle name';
    if (text.length < 2) return 'Name is too short';
    return null;
  }

  String? _validateReading(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the $label';
    final number = double.tryParse(text);
    if (number == null) return 'Enter a valid number';
    if (number < 0) return 'Reading cannot be negative';
    if (number > 9999999) return 'Reading is too large';
    return null;
  }

  String? _validateStart(String? value) =>
      _validateReading(value, 'initial odometer reading');

  String? _validateEnd(String? value) {
    final basic = _validateReading(value, 'final odometer reading');
    if (basic != null) return basic;

    final start = double.tryParse(_startController.text.trim());
    final end = double.parse(value!.trim());
    if (start != null && end <= start) {
      return 'Must be greater than the initial reading';
    }
    if (start != null && end - start > 5000) {
      return 'Distance over 5000 km for one fill-up is not realistic';
    }
    return null;
  }

  String? _validateFuel(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the fuel consumed';
    final number = double.tryParse(text);
    if (number == null) return 'Enter a valid number';
    if (number <= 0) return 'Fuel must be greater than 0';
    if (number > 200) return 'Enter a realistic amount (max 200 L)';
    return null;
  }

  String? _validatePrice(String? value) {
    if (!_includeCost) return null;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the fuel price';
    final number = double.tryParse(text);
    if (number == null) return 'Enter a valid number';
    if (number <= 0) return 'Price must be greater than 0';
    if (number > 500) return 'Enter a realistic price (max ₹500)';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Builds the result from the controllers. Only call after validation passes.
  MileageResult _computeResult() {
    final start = double.parse(_startController.text.trim());
    final end = double.parse(_endController.text.trim());
    final fuel = double.parse(_fuelController.text.trim());
    final price =
        _includeCost ? double.tryParse(_priceController.text.trim()) : null;

    return MileageResult(
      vehicle: _vehicleController.text.trim(),
      distance: end - start,
      fuel: fuel,
      fuelPrice: price,
    );
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      setState(() => _result = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please correct the highlighted fields')),
        );
      return;
    }

    setState(() {
      _hasCalculated = true;
      _result = _computeResult();
    });
  }

  /// Live update once the user has calculated at least once.
  void _onFieldChanged([String? _]) {
    if (!_hasCalculated) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    setState(() => _result = isValid ? _computeResult() : null);
  }

  void _reset() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _formKey.currentState?.reset();
    setState(() {
      _includeCost = false;
      _hasCalculated = false;
      _result = null;
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixText: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String suffix,
    required FormFieldValidator<String> validator,
    String? hint,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // digits with at most one decimal point and two decimal places
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      textInputAction: action,
      validator: validator,
      onChanged: _onFieldChanged,
      onFieldSubmitted: action == TextInputAction.done ? (_) => _calculate() : null,
      decoration: _decoration(
        label: label,
        icon: icon,
        hint: hint,
        suffix: suffix,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Mileage Calculator'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                autovalidateMode: _hasCalculated
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HeaderCard(),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _vehicleController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: _validateVehicle,
                      onChanged: _onFieldChanged,
                      decoration: _decoration(
                        label: 'Vehicle name',
                        icon: Icons.directions_car,
                        hint: 'e.g. Maruti Swift',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _numberField(
                      controller: _startController,
                      label: 'Initial odometer reading',
                      icon: Icons.speed,
                      suffix: 'km',
                      hint: 'e.g. 12500',
                      validator: _validateStart,
                    ),
                    const SizedBox(height: 14),
                    _numberField(
                      controller: _endController,
                      label: 'Final odometer reading',
                      icon: Icons.speed,
                      suffix: 'km',
                      hint: 'e.g. 12950',
                      validator: _validateEnd,
                    ),
                    const SizedBox(height: 14),
                    _numberField(
                      controller: _fuelController,
                      label: 'Fuel consumed',
                      icon: Icons.local_gas_station,
                      suffix: 'litres',
                      hint: 'e.g. 25',
                      validator: _validateFuel,
                      action: _includeCost
                          ? TextInputAction.next
                          : TextInputAction.done,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Also calculate fuel cost'),
                      subtitle: const Text('Needs the price per litre'),
                      value: _includeCost,
                      onChanged: (value) {
                        setState(() => _includeCost = value);
                        // Re-validate after the price field has been
                        // added to / removed from the form.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _onFieldChanged();
                        });
                      },
                    ),
                    if (_includeCost) ...[
                      _numberField(
                        controller: _priceController,
                        label: 'Fuel price',
                        icon: Icons.currency_rupee,
                        suffix: '₹ / litre',
                        hint: 'e.g. 102.50',
                        validator: _validatePrice,
                        action: TextInputAction.done,
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.clear),
                            label: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _calculate,
                            icon: const Icon(Icons.calculate),
                            label: const Text('Calculate Mileage'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _result == null
                          ? const SizedBox.shrink()
                          : MileageResultCard(
                              key: const ValueKey('result'),
                              result: _result!,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Widgets
// -----------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_gas_station, size: 40, color: scheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Enter your odometer readings and the fuel you filled to '
                'find out how many kilometres your car gives per litre.',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MileageResultCard extends StatelessWidget {
  final MileageResult result;

  const MileageResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.ratingColor;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              result.vehicle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              result.kmPerLitre.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Text('km per litre'),
            const SizedBox(height: 10),
            Chip(
              avatar: Icon(Icons.eco, color: color, size: 18),
              label: Text(
                '${result.rating} fuel efficiency',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              side: BorderSide(color: color),
            ),
            const Divider(height: 28),
            _ResultRow(
              label: 'Distance travelled',
              value: '${result.distance.toStringAsFixed(1)} km',
            ),
            _ResultRow(
              label: 'Fuel consumed',
              value: '${result.fuel.toStringAsFixed(2)} L',
            ),
            _ResultRow(
              label: 'Consumption',
              value: '${result.litresPer100Km.toStringAsFixed(2)} L / 100 km',
            ),
            if (result.totalCost != null) ...[
              _ResultRow(
                label: 'Total fuel cost',
                value: '₹${result.totalCost!.toStringAsFixed(2)}',
              ),
              _ResultRow(
                label: 'Cost per km',
                value: '₹${result.costPerKm!.toStringAsFixed(2)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
