class Restaurant {
  final String id;
  final String name;
  final String image;
  final String cuisine;
  final double rating;
  final String deliveryTime;
  final String distance;
  final List<String> tags;
  final String description;
  final Map<String, List<MenuItem>> menu;
  final List<TableType> availableTables;
  final OpeningHours openingHours;
  final String address;
  final String phoneNumber;
  final bool isFeatured;
  final List<String> searchTags;

  const Restaurant({
    required this.id,
    required this.name,
    required this.image,
    required this.cuisine,
    required this.rating,
    required this.deliveryTime,
    required this.distance,
    required this.tags,
    required this.description,
    required this.menu,
    required this.availableTables,
    required this.openingHours,
    required this.address,
    required this.phoneNumber,
    this.isFeatured = false,
    this.searchTags = const [],
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'] as String,
      name: map['name'] as String,
      image: map['image'] as String,
      cuisine: map['cuisine'] as String,
      rating: (map['rating'] as num).toDouble(),
      deliveryTime: map['deliveryTime'] as String,
      distance: map['distance'] as String,
      tags: List<String>.from(map['tags'] as List),
      description: map['description'] as String,
      menu: (map['menu'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as List).map((item) => MenuItem.fromMap(item)).toList(),
        ),
      ),
      availableTables: (map['availableTables'] as List)
          .map((table) => TableType.fromMap(table))
          .toList(),
      openingHours: OpeningHours.fromMap(map['openingHours']),
      address: map['address'] as String,
      phoneNumber: map['phoneNumber'] as String,
      isFeatured: map['isFeatured'] as bool? ?? false,
      searchTags: List<String>.from(map['searchTags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'cuisine': cuisine,
      'rating': rating,
      'deliveryTime': deliveryTime,
      'distance': distance,
      'tags': tags,
      'description': description,
      'menu': menu.map(
        (key, value) => MapEntry(key, value.map((item) => item.toMap()).toList()),
      ),
      'availableTables': availableTables.map((table) => table.toMap()).toList(),
      'openingHours': openingHours.toMap(),
      'address': address,
      'phoneNumber': phoneNumber,
      'isFeatured': isFeatured,
      'searchTags': searchTags,
    };
  }

  // Generate search tags from restaurant data
  static List<String> _generateSearchTags({
    required String name,
    required String cuisine,
    required List<String> tags,
    required Map<String, List<MenuItem>> menu,
  }) {
    final Set<String> searchSet = {};

    // Add individual characters
    searchSet.addAll(name.toLowerCase().split(''));
    searchSet.addAll(cuisine.toLowerCase().split(''));

    // Add complete words
    searchSet.addAll(name.toLowerCase().split(' '));
    searchSet.add(name.toLowerCase());
    
    searchSet.addAll(cuisine.toLowerCase().split(' '));
    searchSet.add(cuisine.toLowerCase());
    
    // Add tags
    for (final tag in tags) {
      searchSet.addAll(tag.toLowerCase().split(' '));
      searchSet.add(tag.toLowerCase());
    }

    // Add menu items
    for (final category in menu.values) {
      for (final item in category) {
        searchSet.addAll(item.name.toLowerCase().split(' '));
        searchSet.add(item.name.toLowerCase());
      }
    }

    return searchSet.toList();
  }
}

class MenuItem {
  final String name;
  final String description;
  final double price;
  final String? image;
  final List<String> allergens;
  final bool isVegetarian;
  final bool isVegan;
  final bool isSpicy;

  const MenuItem({
    required this.name,
    required this.description,
    required this.price,
    this.image,
    required this.allergens,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isSpicy = false,
  });

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    return MenuItem(
      name: map['name'] as String,
      description: map['description'] as String,
      price: (map['price'] as num).toDouble(),
      image: map['image'] as String?,
      allergens: List<String>.from(map['allergens'] as List),
      isVegetarian: map['isVegetarian'] as bool? ?? false,
      isVegan: map['isVegan'] as bool? ?? false,
      isSpicy: map['isSpicy'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'image': image,
      'allergens': allergens,
      'isVegetarian': isVegetarian,
      'isVegan': isVegan,
      'isSpicy': isSpicy,
    };
  }
}

class TableType {
  final String id;
  final int capacity;
  final String type;
  final bool isAvailable;
  final double minimumSpend;

  const TableType({
    required this.id,
    required this.capacity,
    required this.type,
    required this.isAvailable,
    required this.minimumSpend,
  });

  factory TableType.fromMap(Map<String, dynamic> map) {
    return TableType(
      id: map['id'] as String,
      capacity: map['capacity'] as int,
      type: map['type'] as String,
      isAvailable: map['isAvailable'] as bool,
      minimumSpend: (map['minimumSpend'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'capacity': capacity,
      'type': type,
      'isAvailable': isAvailable,
      'minimumSpend': minimumSpend,
    };
  }
}

class OpeningHours {
  final Map<String, DayHours> weeklyHours;

  const OpeningHours({required this.weeklyHours});

  factory OpeningHours.fromMap(Map<String, dynamic> map) {
    return OpeningHours(
      weeklyHours: map.map(
        (key, value) => MapEntry(key, DayHours.fromMap(value)),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return weeklyHours.map(
      (key, value) => MapEntry(key, value.toMap()),
    );
  }
}

class DayHours {
  final bool isOpen;
  final String? openTime;
  final String? closeTime;
  final String? breakStartTime;
  final String? breakEndTime;

  const DayHours({
    required this.isOpen,
    this.openTime,
    this.closeTime,
    this.breakStartTime,
    this.breakEndTime,
  });

  factory DayHours.fromMap(Map<String, dynamic> map) {
    return DayHours(
      isOpen: map['isOpen'] as bool,
      openTime: map['openTime'] as String?,
      closeTime: map['closeTime'] as String?,
      breakStartTime: map['breakStartTime'] as String?,
      breakEndTime: map['breakEndTime'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isOpen': isOpen,
      'openTime': openTime,
      'closeTime': closeTime,
      'breakStartTime': breakStartTime,
      'breakEndTime': breakEndTime,
    };
  }
} 