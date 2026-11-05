// =============================================================================
// Experiment 1: Working with Widgets and Layouts
//
// Aim: Display a list of fruit items using Row, Column, Container, Card and
// ListView widgets, organised into reusable custom widgets.
//
// Reusable widgets in this file:
//   SummaryBanner, FruitCard, FruitAvatar, InfoRow, PriceTag,
//   FruitDetailSheet, DetailTile
// =============================================================================

import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

// -----------------------------------------------------------------------------
// Data model
// -----------------------------------------------------------------------------

class Fruit {
  final String name;
  final String emoji;
  final String origin;
  final int pricePerKg;
  final int calories; // kcal per 100 g
  final String season;
  final Color color;

  const Fruit({
    required this.name,
    required this.emoji,
    required this.origin,
    required this.pricePerKg,
    required this.calories,
    required this.season,
    required this.color,
  });
}

const List<Fruit> fruits = [
  Fruit(
    name: 'Apple',
    emoji: '🍎',
    origin: 'Himachal Pradesh',
    pricePerKg: 180,
    calories: 52,
    season: 'Aug – Nov',
    color: Color(0xFFE53935),
  ),
  Fruit(
    name: 'Banana',
    emoji: '🍌',
    origin: 'Kerala',
    pricePerKg: 60,
    calories: 89,
    season: 'All year',
    color: Color(0xFFF57F17),
  ),
  Fruit(
    name: 'Mango',
    emoji: '🥭',
    origin: 'Ratnagiri',
    pricePerKg: 250,
    calories: 60,
    season: 'Apr – Jun',
    color: Color(0xFFFF8F00),
  ),
  Fruit(
    name: 'Orange',
    emoji: '🍊',
    origin: 'Nagpur',
    pricePerKg: 120,
    calories: 47,
    season: 'Nov – Feb',
    color: Color(0xFFEF6C00),
  ),
  Fruit(
    name: 'Grapes',
    emoji: '🍇',
    origin: 'Nashik',
    pricePerKg: 140,
    calories: 69,
    season: 'Jan – Apr',
    color: Color(0xFF7B1FA2),
  ),
  Fruit(
    name: 'Pineapple',
    emoji: '🍍',
    origin: 'Meghalaya',
    pricePerKg: 90,
    calories: 50,
    season: 'Jul – Sep',
    color: Color(0xFF9E9D24),
  ),
  Fruit(
    name: 'Watermelon',
    emoji: '🍉',
    origin: 'Karnataka',
    pricePerKg: 30,
    calories: 30,
    season: 'Mar – May',
    color: Color(0xFF2E7D32),
  ),
  Fruit(
    name: 'Strawberry',
    emoji: '🍓',
    origin: 'Mahabaleshwar',
    pricePerKg: 400,
    calories: 32,
    season: 'Dec – Mar',
    color: Color(0xFFD81B60),
  ),
  Fruit(
    name: 'Kiwi',
    emoji: '🥝',
    origin: 'Arunachal Pradesh',
    pricePerKg: 320,
    calories: 61,
    season: 'Oct – Dec',
    color: Color(0xFF558B2F),
  ),
  Fruit(
    name: 'Cherries',
    emoji: '🍒',
    origin: 'Kashmir',
    pricePerKg: 600,
    calories: 50,
    season: 'May – Jun',
    color: Color(0xFFC62828),
  ),
];

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fruit List',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const FruitListScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// Screen: Column -> [SummaryBanner, Expanded(ListView of FruitCards)]
// -----------------------------------------------------------------------------

class FruitListScreen extends StatelessWidget {
  const FruitListScreen({super.key});

  void _showDetails(BuildContext context, Fruit fruit) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => FruitDetailSheet(fruit: fruit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fresh Fruits'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SummaryBanner(itemCount: fruits.length),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: fruits.length,
              itemBuilder: (context, index) {
                final fruit = fruits[index];
                return FruitCard(
                  fruit: fruit,
                  onTap: () => _showDetails(context, fruit),
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
// Reusable widgets
// -----------------------------------------------------------------------------

/// Gradient header built with Container + Row + Column.
class SummaryBanner extends StatelessWidget {
  final int itemCount;

  const SummaryBanner({super.key, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_basket, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Fresh Picks",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap a fruit to see its details',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$itemCount items',
              style: const TextStyle(
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One fruit row: Card -> Row -> [FruitAvatar, Column(details), PriceTag].
class FruitCard extends StatelessWidget {
  final Fruit fruit;
  final VoidCallback? onTap;

  const FruitCard({super.key, required this.fruit, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FruitAvatar(emoji: fruit.emoji, color: fruit.color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fruit.name,
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    InfoRow(icon: Icons.place_outlined, text: fruit.origin),
                    const SizedBox(height: 2),
                    InfoRow(
                      icon: Icons.local_fire_department_outlined,
                      text: '${fruit.calories} kcal / 100 g',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PriceTag(price: fruit.pricePerKg, color: fruit.color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular Container showing the fruit emoji on a tinted background.
class FruitAvatar extends StatelessWidget {
  final String emoji;
  final Color color;
  final double size;

  const FruitAvatar({
    super.key,
    required this.emoji,
    required this.color,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(color, Colors.white, 0.82),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Small icon + text row used inside the card.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Coloured price badge.
class PriceTag extends StatelessWidget {
  final int price;
  final Color color;

  const PriceTag({super.key, required this.price, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '₹$price',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'per kg',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// Bottom sheet shown when a fruit card is tapped.
class FruitDetailSheet extends StatelessWidget {
  final Fruit fruit;

  const FruitDetailSheet({super.key, required this.fruit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FruitAvatar(emoji: fruit.emoji, color: fruit.color, size: 90),
          const SizedBox(height: 12),
          Text(
            fruit.name,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${fruit.pricePerKg} per kg',
            style: TextStyle(color: fruit.color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailTile(icon: Icons.place, label: 'Origin', value: fruit.origin),
              DetailTile(
                icon: Icons.calendar_today,
                label: 'Season',
                value: fruit.season,
              ),
              DetailTile(
                icon: Icons.local_fire_department,
                label: 'Calories',
                value: '${fruit.calories} kcal',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const DetailTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
