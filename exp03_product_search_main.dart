// =============================================================================
// Experiment 3: Add Interactivity to App – Input and Forms
//
// Aim: Display a predefined list of products and let the user search and
// filter them using input widgets.
//
// Input widgets used:
//   TextField          -> live keyword search (with clear button)
//   FilterChip         -> multi-select category filter
//   RangeSlider        -> price range filter
//   SwitchListTile     -> "in stock only" toggle
//   PopupMenuButton    -> sort order
// Matching text in the results is highlighted as the user types.
// =============================================================================

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
  final bool inStock;
  final IconData icon;

  const Product({
    required this.name,
    required this.category,
    required this.price,
    required this.rating,
    required this.inStock,
    required this.icon,
  });
}

const List<Product> allProducts = [
  Product(name: 'Wireless Earbuds', category: 'Electronics', price: 1999, rating: 4.3, inStock: true, icon: Icons.headphones),
  Product(name: 'Smart Watch', category: 'Electronics', price: 4999, rating: 4.1, inStock: true, icon: Icons.watch),
  Product(name: 'Bluetooth Speaker', category: 'Electronics', price: 2499, rating: 4.4, inStock: false, icon: Icons.speaker),
  Product(name: 'Laptop Stand', category: 'Electronics', price: 899, rating: 4.0, inStock: true, icon: Icons.laptop),
  Product(name: 'Cotton T-Shirt', category: 'Clothing', price: 499, rating: 4.2, inStock: true, icon: Icons.checkroom),
  Product(name: 'Denim Jacket', category: 'Clothing', price: 2299, rating: 4.5, inStock: true, icon: Icons.checkroom),
  Product(name: 'Woollen Scarf', category: 'Clothing', price: 599, rating: 3.8, inStock: false, icon: Icons.checkroom),
  Product(name: 'Running Shoes', category: 'Sports', price: 3499, rating: 4.6, inStock: true, icon: Icons.directions_run),
  Product(name: 'Yoga Mat', category: 'Sports', price: 799, rating: 4.3, inStock: false, icon: Icons.self_improvement),
  Product(name: 'Cricket Bat', category: 'Sports', price: 2899, rating: 4.4, inStock: true, icon: Icons.sports_cricket),
  Product(name: 'Football', category: 'Sports', price: 699, rating: 4.1, inStock: true, icon: Icons.sports_soccer),
  Product(name: 'Flutter App Development', category: 'Books', price: 649, rating: 4.7, inStock: true, icon: Icons.menu_book),
  Product(name: 'Data Structures in C', category: 'Books', price: 399, rating: 4.2, inStock: true, icon: Icons.menu_book),
  Product(name: 'Machine Learning Basics', category: 'Books', price: 899, rating: 4.5, inStock: false, icon: Icons.menu_book),
  Product(name: 'Steel Water Bottle', category: 'Home', price: 349, rating: 4.3, inStock: true, icon: Icons.local_drink),
  Product(name: 'LED Desk Lamp', category: 'Home', price: 1199, rating: 4.0, inStock: true, icon: Icons.lightbulb_outline),
  Product(name: 'Coffee Mug Set', category: 'Home', price: 599, rating: 3.9, inStock: true, icon: Icons.local_cafe),
  Product(name: 'Wall Clock', category: 'Home', price: 899, rating: 4.1, inStock: false, icon: Icons.access_time),
];

enum SortOption {
  nameAsc('Name (A–Z)'),
  priceLow('Price: Low to High'),
  priceHigh('Price: High to Low'),
  rating('Top Rated');

  const SortOption(this.label);
  final String label;
}

String formatPrice(num value) => '₹${value.round()}';

// -----------------------------------------------------------------------------
// App
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const ProductSearchScreen(),
    );
  }
}

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  static const double _maxPrice = 5000;
  static const RangeValues _fullRange = RangeValues(0, _maxPrice);

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCategories = {};
  final List<String> _categories =
      allProducts.map((p) => p.category).toSet().toList();

  String _query = '';
  RangeValues _priceRange = _fullRange;
  bool _inStockOnly = false;
  SortOption _sort = SortOption.nameAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _priceRange != _fullRange ||
      _inStockOnly;

  /// Applies every filter, then sorts.
  List<Product> get _filteredProducts {
    final q = _query.trim().toLowerCase();

    final results = allProducts.where((p) {
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      final matchesCategory = _selectedCategories.isEmpty ||
          _selectedCategories.contains(p.category);
      final matchesPrice =
          p.price >= _priceRange.start && p.price <= _priceRange.end;
      final matchesStock = !_inStockOnly || p.inStock;
      return matchesQuery && matchesCategory && matchesPrice && matchesStock;
    }).toList();

    switch (_sort) {
      case SortOption.nameAsc:
        results.sort((a, b) => a.name.compareTo(b.name));
      case SortOption.priceLow:
        results.sort((a, b) => a.price.compareTo(b.price));
      case SortOption.priceHigh:
        results.sort((a, b) => b.price.compareTo(a.price));
      case SortOption.rating:
        results.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return results;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _resetAll() {
    _searchController.clear();
    setState(() {
      _query = '';
      _selectedCategories.clear();
      _priceRange = _fullRange;
      _inStockOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Finder'),
        actions: [
          PopupMenuButton<SortOption>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final option in SortOption.values)
                PopupMenuItem(value: option, child: Text(option.label)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          _buildCategoryChips(),
          _buildMoreFilters(),
          _buildResultSummary(results.length),
          Expanded(
            child: results.isEmpty
                ? const EmptyResults()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: results.length,
                    itemBuilder: (context, index) =>
                        ProductTile(product: results[index], query: _query),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search products or categories…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final category in _categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category),
                selected: _selectedCategories.contains(category),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(category);
                    } else {
                      _selectedCategories.remove(category);
                    }
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoreFilters() {
    final priceText =
        '${formatPrice(_priceRange.start)} – ${formatPrice(_priceRange.end)}';

    return ExpansionTile(
      leading: const Icon(Icons.tune),
      title: const Text('More filters'),
      subtitle: Text('$priceText${_inStockOnly ? '  ·  In stock only' : ''}'),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          children: [
            const Text('Price range'),
            const Spacer(),
            Text(priceText, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: _maxPrice,
          divisions: 50,
          labels: RangeLabels(
            formatPrice(_priceRange.start),
            formatPrice(_priceRange.end),
          ),
          onChanged: (values) => setState(() => _priceRange = values),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show in-stock items only'),
          value: _inStockOnly,
          onChanged: (value) => setState(() => _inStockOnly = value),
        ),
      ],
    );
  }

  Widget _buildResultSummary(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Text(
            'Showing $count of ${allProducts.length} products',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const Spacer(),
          if (_hasActiveFilters)
            TextButton.icon(
              onPressed: _resetAll,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear all'),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Reusable widgets
// -----------------------------------------------------------------------------

class ProductTile extends StatelessWidget {
  final Product product;
  final String query;

  const ProductTile({super.key, required this.product, required this.query});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(product.icon, color: scheme.onPrimaryContainer),
        ),
        title: HighlightedText(text: product.name, query: query),
        subtitle: Row(
          children: [
            Flexible(
              child: HighlightedText(text: product.category, query: query),
            ),
            const SizedBox(width: 8),
            Icon(Icons.star, size: 14, color: Colors.amber.shade700),
            Text(' ${product.rating}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatPrice(product.price),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              product.inStock ? 'In stock' : 'Out of stock',
              style: TextStyle(
                fontSize: 12,
                color: product.inStock
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [text] with every occurrence of [query] highlighted.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const HighlightedText({super.key, required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return Text(text, overflow: TextOverflow.ellipsis);

    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lower.indexOf(q, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + q.length),
          style: TextStyle(
            backgroundColor: Colors.yellow.shade300,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = index + q.length;
    }

    return Text.rich(TextSpan(children: spans), overflow: TextOverflow.ellipsis);
  }
}

class EmptyResults extends StatelessWidget {
  const EmptyResults({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No products match your search',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different keyword or clear the filters.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
