import 'package:cloud_firestore/cloud_firestore.dart';

enum ReservationStatus {
  pending,
  confirmed,
  completed,
  cancelled
}

class Reservation {
  final String id;
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final DateTime reservationDate;
  final String reservationTime;
  final int numberOfGuests;
  final String tableId;
  final String tableType;
  final ReservationStatus status;
  final DateTime createdAt;
  final String? specialRequests;

  const Reservation({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImage,
    required this.reservationDate,
    required this.reservationTime,
    required this.numberOfGuests,
    required this.tableId,
    required this.tableType,
    required this.status,
    required this.createdAt,
    this.specialRequests,
  });

  factory Reservation.fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: map['id'] as String,
      userId: map['userId'] as String,
      restaurantId: map['restaurantId'] as String,
      restaurantName: map['restaurantName'] as String,
      restaurantImage: map['restaurantImage'] as String,
      reservationDate: (map['reservationDate'] as Timestamp).toDate(),
      reservationTime: map['reservationTime'] as String,
      numberOfGuests: map['numberOfGuests'] as int,
      tableId: map['tableId'] as String,
      tableType: map['tableType'] as String,
      status: ReservationStatus.values.firstWhere(
        (e) => e.toString() == 'ReservationStatus.${map['status']}',
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      specialRequests: map['specialRequests'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantImage': restaurantImage,
      'reservationDate': Timestamp.fromDate(reservationDate),
      'reservationTime': reservationTime,
      'numberOfGuests': numberOfGuests,
      'tableId': tableId,
      'tableType': tableType,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'specialRequests': specialRequests,
    };
  }
} 