import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation.dart';

class ReservationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'reservations';

  // Get user's reservations
  static Future<List<Reservation>> getUserReservations(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('reservationDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Reservation.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting user reservations: $e');
      rethrow;
    }
  }

  // Create a new reservation
  static Future<String> createReservation(Reservation reservation) async {
    try {
      final doc = await _firestore.collection(_collection).add(reservation.toMap());
      return doc.id;
    } catch (e) {
      print('Error creating reservation: $e');
      rethrow;
    }
  }

  // Update reservation status
  static Future<void> updateReservationStatus(
    String reservationId,
    ReservationStatus status,
  ) async {
    try {
      await _firestore.collection(_collection).doc(reservationId).update({
        'status': status.toString().split('.').last,
      });
    } catch (e) {
      print('Error updating reservation status: $e');
      rethrow;
    }
  }

  // Cancel reservation
  static Future<void> cancelReservation(String reservationId) async {
    try {
      await updateReservationStatus(reservationId, ReservationStatus.cancelled);
    } catch (e) {
      print('Error cancelling reservation: $e');
      rethrow;
    }
  }
} 