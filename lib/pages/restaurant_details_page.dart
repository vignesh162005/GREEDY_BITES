import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';
import '../models/reservation.dart';
import '../models/review.dart';
import '../services/reservation_service.dart';
import '../services/review_service.dart';
import 'package:intl/intl.dart';

class RestaurantDetailsPage extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailsPage({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _selectedDate;
  String? _selectedTime;
  int _guestCount = 2;
  Review? _userReview;
  bool _isLoadingReviews = false;

  final List<String> _availableTimes = [
    '11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM',
    '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
    '5:00 PM', '5:30 PM', '6:00 PM', '6:30 PM',
    '7:00 PM', '7:30 PM', '8:00 PM', '8:30 PM',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserReview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset time when date changes
      });
    }
  }

  Future<void> _loadUserReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isLoadingReviews = true);
      try {
        final reviews = await ReviewService.getUserReviews(user.uid);
        final userReview = reviews.firstWhere(
          (review) => review.restaurantId == widget.restaurant.id,
          orElse: () => Review(
            id: '',
            userId: user.uid,
            userName: user.displayName ?? 'Anonymous',
            userImage: user.photoURL ?? '',
            restaurantId: widget.restaurant.id,
            rating: 0,
            comment: '',
            date: DateTime.now(),
          ),
        );
        if (mounted) {
          setState(() {
            _userReview = userReview;
            _isLoadingReviews = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingReviews = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading review: $e')),
          );
        }
      }
    }
  }

  void _showReservationDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to make a reservation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? specialRequests;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Reservation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Restaurant: ${widget.restaurant.name}'),
                const SizedBox(height: 8),
                Text('Date: ${_selectedDate?.toString().split(' ')[0]}'),
                const SizedBox(height: 8),
                Text('Time: $_selectedTime'),
                const SizedBox(height: 8),
                Text('Number of Guests: $_guestCount'),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Special Requests (Optional)',
                    hintText: 'e.g., Birthday celebration, Allergies, etc.',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) => specialRequests = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Find an available table that matches the guest count
                  final availableTable = widget.restaurant.availableTables
                      .firstWhere((table) => 
                          table.isAvailable && 
                          table.capacity >= _guestCount &&
                          table.capacity <= _guestCount + 2,
                        orElse: () => widget.restaurant.availableTables
                            .firstWhere((table) => table.isAvailable,
                                orElse: () => throw Exception('No tables available')));

                  final reservation = Reservation(
                    id: '', // Will be set by Firestore
                    userId: user.uid,
                    restaurantId: widget.restaurant.id,
                    restaurantName: widget.restaurant.name,
                    restaurantImage: widget.restaurant.image,
                    reservationDate: _selectedDate!,
                    reservationTime: _selectedTime!,
                    numberOfGuests: _guestCount,
                    tableId: availableTable.id,
                    tableType: availableTable.type,
                    status: ReservationStatus.pending,
                    createdAt: DateTime.now(),
                    specialRequests: specialRequests?.trim(),
                  );

                  await ReservationService.createReservation(reservation);
                  
                  if (mounted) {
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reservation request sent! Please wait for confirmation.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showReviewDialog({bool isEdit = false}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to leave a review')),
      );
      return;
    }

    double rating = _userReview?.rating ?? 0;
    final commentController = TextEditingController(text: _userReview?.comment ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Review' : 'Add Review'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      rating = index + 1.0;
                      (context as Element).markNeedsBuild();
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Your Review',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (isEdit && _userReview?.id.isNotEmpty == true)
            TextButton(
              onPressed: () async {
                try {
                  await ReviewService.deleteReview(
                    _userReview!.id,
                    widget.restaurant.id,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() => _userReview = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Review deleted successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting review: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () async {
              if (rating == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a rating')),
                );
                return;
              }

              final review = Review(
                id: _userReview?.id ?? '',
                userId: user.uid,
                userName: user.displayName ?? 'Anonymous',
                userImage: user.photoURL ?? '',
                restaurantId: widget.restaurant.id,
                rating: rating,
                comment: commentController.text.trim(),
                date: DateTime.now(),
              );

              try {
                if (isEdit && review.id.isNotEmpty) {
                  await ReviewService.updateReview(review.id, review);
                } else {
                  await ReviewService.createReview(review);
                }

                if (mounted) {
                  Navigator.pop(context);
                  setState(() => _userReview = review);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit ? 'Review updated successfully' : 'Review added successfully',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving review: $e')),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Update' : 'Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        ReviewService.getRestaurantReviews(widget.restaurant.id),
        ReviewService.getReviewStats(widget.restaurant.id),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final reviews = snapshot.data![0] as List<Review>;
        final stats = snapshot.data![1] as ReviewStats;
        final user = FirebaseAuth.instance.currentUser;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await _loadUserReview();
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Rating Overview Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                stats.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    index < stats.averageRating
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${stats.totalReviews} reviews',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            child: Column(
                              children: [5, 4, 3, 2, 1].map((rating) {
                                final percentage = stats.ratingPercentages[rating] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Text(
                                        '$rating',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star, size: 12),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percentage / 100,
                                            backgroundColor: Colors.grey[200],
                                            minHeight: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 32,
                                        child: Text(
                                          '${percentage.round()}%',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // User's Review Section
              if (user != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Review',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingReviews)
                          const Center(child: CircularProgressIndicator())
                        else if (_userReview?.id.isEmpty ?? true)
                          Center(
                            child: ElevatedButton(
                              onPressed: () => _showReviewDialog(),
                              child: const Text('Add Review'),
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    return Icon(
                                      index < (_userReview?.rating ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                    );
                                  }),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _showReviewDialog(isEdit: true),
                                    child: const Text('Edit'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_userReview?.comment ?? ''),
                              const SizedBox(height: 8),
                              Text(
                                'Posted on ${DateFormat('MMM d, yyyy').format(_userReview?.date ?? DateTime.now())}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],

              // All Reviews Section
              const Text(
                'All Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (reviews.isEmpty)
                const Center(
                  child: Text('No reviews yet. Be the first to review!'),
                )
              else
                ...reviews
                    .where((review) => review.userId != user?.uid)
                    .map((review) => Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: review.userImage.isNotEmpty
                                          ? NetworkImage(review.userImage)
                                          : null,
                                      child: review.userImage.isEmpty
                                          ? Text(review.userName[0])
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            review.userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('MMM d, yyyy')
                                                .format(review.date),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < review.rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 20,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                if (review.comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(review.comment),
                                ],
                              ],
                            ),
                          ),
                        ))
                    .toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.restaurant.image,
                fit: BoxFit.cover,
              ),
              title: Text(
                widget.restaurant.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            widget.restaurant.rating.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(widget.restaurant.deliveryTime),
                          const SizedBox(width: 16),
                          Icon(Icons.location_on, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(widget.restaurant.distance),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: widget.restaurant.tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            backgroundColor: Colors.grey[200],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Reserve'),
                    Tab(text: 'Menu'),
                    Tab(text: 'Reviews'),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 300,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Make a Reservation',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Date Selection
                            ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: Text(
                                _selectedDate == null
                                    ? 'Select Date'
                                    : _selectedDate.toString().split(' ')[0],
                              ),
                              tileColor: Colors.grey[100],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              onTap: () => _selectDate(context),
                            ),
                            const SizedBox(height: 16),
                            // Time Selection
                            if (_selectedDate != null) ...[
                              const Text(
                                'Available Times',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _availableTimes.map((time) {
                                  return ChoiceChip(
                                    label: Text(time),
                                    selected: _selectedTime == time,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedTime = selected ? time : null;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 24),
                            // Guest Count
                            Row(
                              children: [
                                const Text(
                                  'Number of Guests',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _guestCount > 1
                                      ? () => setState(() => _guestCount--)
                                      : null,
                                ),
                                Text(
                                  _guestCount.toString(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _guestCount < 10
                                      ? () => setState(() => _guestCount++)
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Reserve Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_selectedDate != null &&
                                        _selectedTime != null)
                                    ? _showReservationDialog
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Reserve Table'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Center(child: Text('Menu Coming Soon')),
                      _buildReviewsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 