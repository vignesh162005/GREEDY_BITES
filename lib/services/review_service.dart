import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';

// Review statistics class
class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingCounts;
  final Map<int, double> ratingPercentages;

  ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingCounts,
    required this.ratingPercentages,
  });
}

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'reviews';

  // Get reviews for a restaurant
  static Future<List<Review>> getRestaurantReviews(String restaurantId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('restaurantId', isEqualTo: restaurantId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting restaurant reviews: $e');
      rethrow;
    }
  }

  // Get user's reviews
  static Future<List<Review>> getUserReviews(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting user reviews: $e');
      rethrow;
    }
  }

  // Get blogger's reviews
  static Future<List<Review>> getBloggerReviews(String bloggerId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: bloggerId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Review.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      if (e.toString().contains('indexes?create')) {
        print('Index not ready for blogger reviews. Falling back to unordered query.');
        // Fallback to unordered query
        final snapshot = await _firestore
            .collection(_collection)
            .where('userId', isEqualTo: bloggerId)
            .get();

        final reviews = snapshot.docs
            .map((doc) => Review.fromMap({...doc.data(), 'id': doc.id}))
            .toList();
        
        // Sort in memory
        reviews.sort((a, b) => b.date.compareTo(a.date));
        return reviews;
      }
      print('Error getting blogger reviews: $e');
      rethrow;
    }
  }

  // Create a new review
  static Future<String> createReview(Review review) async {
    try {
      final doc = await _firestore.collection(_collection).add(review.toMap());
      await _updateRestaurantRating(review.restaurantId);
      return doc.id;
    } catch (e) {
      print('Error creating review: $e');
      rethrow;
    }
  }

  // Update a review
  static Future<void> updateReview(String reviewId, Review review) async {
    try {
      await _firestore.collection(_collection).doc(reviewId).update(review.toMap());
      await _updateRestaurantRating(review.restaurantId);
    } catch (e) {
      print('Error updating review: $e');
      rethrow;
    }
  }

  // Delete a review
  static Future<void> deleteReview(String reviewId, String restaurantId) async {
    try {
      await _firestore.collection(_collection).doc(reviewId).delete();
      await _updateRestaurantRating(restaurantId);
    } catch (e) {
      print('Error deleting review: $e');
      rethrow;
    }
  }

  // Get review statistics for a restaurant
  static Future<ReviewStats> getReviewStats(String restaurantId) async {
    try {
      final reviews = await getRestaurantReviews(restaurantId);
      if (reviews.isEmpty) {
        return ReviewStats(
          averageRating: 0,
          totalReviews: 0,
          ratingCounts: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
          ratingPercentages: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        );
      }

      // Calculate average rating
      final averageRating = reviews.fold<double>(
        0,
        (sum, review) => sum + review.rating,
      ) / reviews.length;

      // Calculate rating counts
      final ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      for (final review in reviews) {
        final rating = review.rating.round();
        if (rating >= 1 && rating <= 5) {
          ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
        }
      }

      // Calculate percentages
      final ratingPercentages = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0};
      ratingCounts.forEach((rating, count) {
        ratingPercentages[rating] = (count / reviews.length) * 100;
      });

      return ReviewStats(
        averageRating: double.parse(averageRating.toStringAsFixed(2)),
        totalReviews: reviews.length,
        ratingCounts: ratingCounts,
        ratingPercentages: ratingPercentages,
      );
    } catch (e) {
      print('Error getting review stats: $e');
      rethrow;
    }
  }

  // Update restaurant rating based on reviews
  static Future<void> _updateRestaurantRating(String restaurantId) async {
    try {
      final stats = await getReviewStats(restaurantId);
      await _firestore.collection('restaurants').doc(restaurantId).update({
        'rating': stats.averageRating > 0 ? stats.averageRating : null,
      });
    } catch (e) {
      print('Error updating restaurant rating: $e');
      rethrow;
    }
  }
} 