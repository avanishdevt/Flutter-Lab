// =============================================================================
// Experiment 2: Adaptive and Responsive UI Design
//
// Aim: An E-Commerce Product Catalog built from reusable product widgets that
// adapts to different screen sizes.
//
// Responsive techniques used:
//   * MediaQuery.sizeOf()  -> picks the overall layout (mobile / tablet / desktop)
//   * Breakpoints          -> 600 px (tablet) and 1024 px (desktop)
//   * LayoutBuilder        -> grid column count from the space actually available
//   * Flexible / Expanded  -> cards stretch to fill their cell
//
//   Mobile  (< 600)  : category chips on top, 2-column grid
//   Tablet  (600+)   : category side panel + 3-column grid
//   Desktop (1024+)  : wider side panel + 4 to 6 column grid
//
// Reusable widgets: ProductCard, ProductImage, RatingBar, PriceLabel,
//   CategoryChips, CategorySidePanel, ProductGrid, LayoutBadge
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

// -----------------------------------------------------------------------------
// Data
// -----------------------------------------------------------------------------

class Product {
  final String name;
  final String category;
  final double price;
  final double rating;
  final int reviews;
  final IconData icon;
  final Color color;

  const Product({
    required this.name,
    required this.category,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.icon,
    required this.color,
  });
}

const List<Product> products = [
  Product(name: 'Wireless Headphones', category: 'Audio', price: 2999, rating: 4.5, reviews: 1280, icon: Icons.headphones, color: Color(0xFF5C6BC0)),
  Product(name: 'Bluetooth Speaker', category: 'Audio', price: 1799, rating: 4.2, reviews: 860, icon: Icons.speaker, color: Color(0xFF26A69A)),
  Product(name: 'Smart Watch', category: 'Wearables', price: 4499, rating: 4.3, reviews: 2104, icon: Icons.watch, color: Color(0xFFEF5350)),
  Product(name: 'Fitness Band', category: 'Wearables', price: 1999, rating: 4.0, reviews: 640, icon: Icons.directions_run, color: Color(0xFFAB47BC)),
  Product(name: 'Ultrabook Laptop', category: 'Computers', price: 64999, rating: 4.6, reviews: 412, icon: Icons.laptop_mac, color: Color(0xFF42A5F5)),
  Product(name: 'Mechanical Keyboard', category: 'Computers', price: 3499, rating: 4.4, reviews: 978, icon: Icons.keyboard, color: Color(0xFF8D6E63)),
  Product(name: 'Wireless Mouse', category: 'Computers', price: 899, rating: 4.1, reviews: 1543, icon: Icons.mouse, color: Color(0xFF78909C)),
  Product(name: '5G Smartphone', category: 'Mobiles', price: 18999, rating: 4.3, reviews: 3320, icon: Icons.phone_android, color: Color(0xFF66BB6A)),
  Product(name: 'Android Tablet', category: 'Mobiles', price: 21999, rating: 4.2, reviews: 715, icon: Icons.tablet_android, color: Color(0xFFFFA726)),
  Product(name: 'Power Bank 20000 mAh', category: 'Accessories', price: 1499, rating: 4.4, reviews: 2890, icon: Icons.battery_charging_full, color: Color(0xFF29B6F6)),
  Product(name: 'Laptop Backpack', category: 'Accessories', price: 1299, rating: 4.1, reviews: 530, icon: Icons.backpack, color: Color(0xFF7E57C2)),
  Product(name: 'Game Controller', category: 'Gaming', price: 3999, rating: 4.5, reviews: 1102, icon: Icons.sports_esports, color: Color(0xFFEC407A)),
  Product(name: 'Action Camera', category: 'Cameras', price: 12999, rating: 4.3, reviews: 389, icon: Icons.camera_alt, color: Color(0xFF26C6DA)),
  Product(name: 'Smart TV 43"', category: 'Home', price: 27999, rating: 4.4, reviews: 1876, icon: Icons.tv, color: Color(0xFF5D4037)),
];

/// 'All' followed by each category in the order it first appears.
final List<String> categories = [
  'All',
  ...{for (final p in products) p.category},
];

/// Formats a number as Indian Rupees with Indian digit grouping (1,29,999).
String formatPrice(num value) {
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
// Breakpoints
// -----------------------------------------------------------------------------

enum DeviceType { mobile, tablet, desktop }

class Breakpoints {
  static const double tablet = 600;
  static const double desktop = 1024;

  static DeviceType of(double width) {
    if (width >= desktop) return DeviceType.desktop;
    if (width >= tablet) return DeviceType.tablet;
    return DeviceType.mobile;
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
      title: 'ShopEase Catalog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const CatalogScreen(),
    );
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _selectedCategory = 'All';
  int _cartCount = 0;

  List<Product> get _visibleProducts => _selectedCategory == 'All'
      ? products
      : products.where((p) => p.category == _selectedCategory).toList();

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
  }

  void _addToCart(Product product) {
    setState(() => _cartCount++);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final device = Breakpoints.of(width);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShopEase Catalog'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () {},
            icon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: device == DeviceType.mobile
          ? _buildMobileLayout(device)
          : _buildWideLayout(device),
    );
  }

  /// Mobile: chips on top, grid below.
  Widget _buildMobileLayout(DeviceType device) {
    final visible = _visibleProducts;
    return Column(
      children: [
        CategoryChips(
          categories: categories,
          selected: _selectedCategory,
          onSelected: _selectCategory,
        ),
        ResultHeader(count: visible.length, device: device),
        Expanded(
          child: ProductGrid(products: visible, onAddToCart: _addToCart),
        ),
      ],
    );
  }

  /// Tablet / desktop: side panel on the left, grid on the right.
  Widget _buildWideLayout(DeviceType device) {
    final visible = _visibleProducts;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: device == DeviceType.desktop ? 260 : 200,
          child: CategorySidePanel(
            categories: categories,
            selected: _selectedCategory,
            onSelected: _selectCategory,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              ResultHeader(count: visible.length, device: device),
              Expanded(
                child: ProductGrid(products: visible, onAddToCart: _addToCart),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Reusable widgets
// -----------------------------------------------------------------------------

/// Grid that decides its own column count from the width it is given.
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onAddToCart;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // About 190 px per card; never fewer than 2 or more than 6 columns.
        final columns =
            math.max(2, math.min(6, (constraints.maxWidth / 190).floor()));

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 290,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onAddToCart: () => onAddToCart(product),
            );
          },
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ProductImage(icon: product.icon, color: product.color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.category.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                RatingBar(rating: product.rating, reviews: product.reviews),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 4, 6),
            child: Row(
              children: [
                Expanded(child: PriceLabel(price: product.price)),
                IconButton.filledTonal(
                  tooltip: 'Add to cart',
                  onPressed: onAddToCart,
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder "photo": a gradient box with the product icon, sized to fit.
class ProductImage extends StatelessWidget {
  final IconData icon;
  final Color color;

  const ProductImage({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.80)!,
            Color.lerp(color, Colors.white, 0.50)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return Icon(icon, size: side * 0.5, color: color);
        },
      ),
    );
  }
}

class RatingBar extends StatelessWidget {
  final double rating;
  final int reviews;

  const RatingBar({super.key, required this.rating, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            rating >= i + 1
                ? Icons.star
                : rating >= i + 0.5
                    ? Icons.star_half
                    : Icons.star_border,
            size: 14,
            color: Colors.amber.shade700,
          ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '($reviews)',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}

class PriceLabel extends StatelessWidget {
  final double price;

  const PriceLabel({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    return Text(
      formatPrice(price),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

/// Horizontal chip strip used on phones.
class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          return ChoiceChip(
            label: Text(category),
            selected: category == selected,
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}

/// Vertical category list used on tablets and desktops.
class CategorySidePanel extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const CategorySidePanel({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  int _countFor(String category) => category == 'All'
      ? products.length
      : products.where((p) => p.category == category).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Text(
            'Categories',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              selected: category == selected,
              selectedTileColor: scheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: Icon(
                category == 'All' ? Icons.grid_view : Icons.label_outline,
              ),
              title: Text(category),
              trailing: Text('${_countFor(category)}'),
              onTap: () => onSelected(category),
            ),
          ),
      ],
    );
  }
}

/// "N products" line plus a badge showing which layout is active.
class ResultHeader extends StatelessWidget {
  final int count;
  final DeviceType device;

  const ResultHeader({super.key, required this.count, required this.device});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            '$count products',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          LayoutBadge(device: device),
        ],
      ),
    );
  }
}

class LayoutBadge extends StatelessWidget {
  final DeviceType device;

  const LayoutBadge({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (device) {
      DeviceType.mobile => (Icons.smartphone, 'Mobile layout'),
      DeviceType.tablet => (Icons.tablet_mac, 'Tablet layout'),
      DeviceType.desktop => (Icons.desktop_windows, 'Desktop layout'),
    };
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
