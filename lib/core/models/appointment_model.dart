import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentType {
  visit,
  call;

  static AppointmentType fromString(String type) {
    return AppointmentType.values.firstWhere(
      (e) => e.name == type.toLowerCase(),
      orElse: () => AppointmentType.visit,
    );
  }
}

class AppointmentModel {
  final String appointmentId;
  final String clientId;
  final String clientName;
  final String collectorUid;
  final DateTime scheduledTime;
  final AppointmentType type;
  final String notes;
  final bool isCompleted;
  final String? creditId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppointmentModel({
    required this.appointmentId,
    required this.clientId,
    required this.clientName,
    required this.collectorUid,
    required this.scheduledTime,
    required this.type,
    required this.notes,
    required this.isCompleted,
    this.creditId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AppointmentModel(
      appointmentId: documentId,
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      collectorUid: map['collectorUid'] ?? '',
      scheduledTime: (map['scheduledTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: AppointmentType.fromString(map['type'] ?? 'visit'),
      notes: map['notes'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      creditId: map['creditId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'collectorUid': collectorUid,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'type': type.name,
      'notes': notes,
      'isCompleted': isCompleted,
      if (creditId != null) 'creditId': creditId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
