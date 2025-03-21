import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import '../services/restaurant_service.dart';
import '../services/review_service.dart';
import 'restaurant_details_page.dart';
import 'dart:async';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Restaurant>? _searchResults;
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;

  // Filter states
  final Set<String> _selectedCuisines = {};
  final Set<String> _selectedTags = {};
  RangeValues _priceRange = const RangeValues(0, 4); // 0-4 price range ($-$$$$)
  double _minRating = 0;
  String _sortBy = 'rating'; // Default sort by rating

  // Available filter options
  final List<String> _availableCuisines = [
    'Indian',
    'Italian',
    'Chinese',
    'Japanese',
    'Mexican',
    'Thai',
    'American',
    'Mediterranean'
  ];

  final List<String> _availableTags = [
    'Vegetarian',
    'Vegan',
    'Halal',
    'Gluten-Free',
    'Spicy',
    'Breakfast',
    'Lunch',
    'Dinner'
  ];

  final List<String> _sortOptions = [
    'rating',
    'distance',
    'price_low',
    'price_high',
    'name'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();

    // Cancel any previous search
    _debounceTimer?.cancel();

    // If query is empty, clear results
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    // Start loading state immediately
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Debounce the search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await RestaurantService.searchRestaurants(query);

        // Apply filters
        var filteredResults = results.where((restaurant) {
          // Filter by cuisine
          if (_selectedCuisines.isNotEmpty &&
              !_selectedCuisines.contains(restaurant.cuisine)) {
            return false;
          }

          // Filter by tags
          if (_selectedTags.isNotEmpty &&
              !restaurant.tags.any((tag) => _selectedTags.contains(tag))) {
            return false;
          }

          // Filter by price range
          final menuItems = restaurant.menu.values.expand((items) => items).toList();
          if (menuItems.isNotEmpty) {
            final totalPrice = menuItems.fold<double>(
              0,
              (sum, item) => sum + item.price,
            );
            final avgPrice = totalPrice / menuItems.length;
            // Calculate price level (0-4) based on average price
            // Assuming price ranges:
            // $ = 0-15
            // $$ = 15-30
            // $$$ = 30-50
            // $$$$ = 50+
            final priceLevel = avgPrice <= 15 
                ? 0 
                : avgPrice <= 30 
                    ? 1 
                    : avgPrice <= 50 
                        ? 2 
                        : avgPrice <= 75 
                            ? 3 
                            : 4;
            
            if (priceLevel < _priceRange.start || priceLevel > _priceRange.end) {
              return false;
            }
          }

          // Filter by rating
          if (restaurant.rating < _minRating) {
            return false;
          }

          return true;
        }).toList();

        // Apply sorting
        filteredResults.sort((a, b) {
          switch (_sortBy) {
            case 'rating':
              return b.rating.compareTo(a.rating);
            case 'distance':
              // Convert distance strings (e.g., "2.5 km") to numbers for comparison
              final aDistance = double.tryParse(a.distance.split(' ').first) ?? 0;
              final bDistance = double.tryParse(b.distance.split(' ').first) ?? 0;
              return aDistance.compareTo(bDistance);
            case 'price_low':
            case 'price_high':
              // Calculate average price for each restaurant
              final aPrice = a.menu.values
                  .expand((items) => items)
                  .map((item) => item.price)
                  .fold<double>(0, (sum, price) => sum + price) /
                  a.menu.values.expand((items) => items).length;
              final bPrice = b.menu.values
                  .expand((items) => items)
                  .map((item) => item.price)
                  .fold<double>(0, (sum, price) => sum + price) /
                  b.menu.values.expand((items) => items).length;
              return _sortBy == 'price_low'
                  ? aPrice.compareTo(bPrice)
                  : bPrice.compareTo(aPrice);
            case 'name':
              return a.name.compareTo(b.name);
            default:
              return 0;
          }
        });

        if (mounted) {
          setState(() {
            _searchResults = filteredResults;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Failed to search restaurants. Please try again.';
            _isLoading = false;
          });
        }
      }
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCuisines.clear();
                            _selectedTags.clear();
                            _priceRange = const RangeValues(0, 4);
                            _minRating = 0;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cuisines
                  const Text(
                    'Cuisines',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _availableCuisines.map((cuisine) {
                      return FilterChip(
                        label: Text(cuisine),
                        selected: _selectedCuisines.contains(cuisine),
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedCuisines.add(cuisine);
                            } else {
                              _selectedCuisines.remove(cuisine);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  const Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _availableTags.map((tag) {
                      return FilterChip(
                        label: Text(tag),
                        selected: _selectedTags.contains(tag),
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Price Range
                  const Text(
                    'Price Range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 4,
                    divisions: 4,
                    labels: RangeLabels(
                      '\$' * (_priceRange.start.round() + 1),
                      '\$' * (_priceRange.end.round() + 1),
                    ),
                    onChanged: (values) {
                      setModalState(() {
                        _priceRange = values;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Minimum Rating
                  const Text(
                    'Minimum Rating',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _minRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    label: _minRating.toString(),
                    onChanged: (value) {
                      setModalState(() {
                        _minRating = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleSearch();
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...ListTile.divideTiles(
              context: context,
              tiles: _sortOptions.map(
                (option) => ListTile(
                  title: Text(
                    option.split('_').map((word) => 
                      word[0].toUpperCase() + word.substring(1)
                    ).join(' '),
                  ),
                  trailing: _sortBy == option
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _sortBy = option;
                    });
                    Navigator.pop(context);
                    _handleSearch();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search restaurants, cuisines, or dishes',
                    prefixIcon: _isLoading 
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          )
                        : const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  onChanged: (value) => _handleSearch(),
                ),
                const SizedBox(height: 16),

                // Filter and Sort Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showFilterSheet,
                        icon: const Icon(Icons.filter_list),
                        label: Text(
                          'Filters ${_selectedCuisines.isNotEmpty || _selectedTags.isNotEmpty || _minRating > 0 ? '(Active)' : ''}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showSortSheet,
                        icon: const Icon(Icons.sort),
                        label: Text(
                          'Sort by ${_sortBy.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ')}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _handleSearch,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _searchResults == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Search for restaurants\nby name, cuisine, or dishes',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _searchResults!.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No restaurants found for\n"${_searchController.text}"',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _searchResults!.length,
                                itemBuilder: (context, index) {
                                  final restaurant = _searchResults![index];
                                  return RestaurantCard(restaurant: restaurant);
                                },
                              ),
          ),
        ],
      ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantCard({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantDetailsPage(
                restaurant: restaurant,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  restaurant.image,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisine,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<ReviewStats>(
                      future: ReviewService.getReviewStats(restaurant.id),
                      builder: (context, snapshot) {
                        final rating = snapshot.hasData &&
                                snapshot.data!.averageRating > 0
                            ? snapshot.data!.averageRating
                            : restaurant.rating;
                        final reviewCount =
                            snapshot.hasData ? snapshot.data!.totalReviews : 0;

                        return Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber[600], size: 20),
                            const SizedBox(width: 4),
                            Text(
                                '$rating ${reviewCount > 0 ? '($reviewCount)' : ''}'),
                            const SizedBox(width: 12),
                            Icon(Icons.location_on,
                                color: Colors.grey[600], size: 20),
                            const SizedBox(width: 4),
                            Text(restaurant.distance),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: restaurant.tags.map((tag) {
                        return Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.grey[200],
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 