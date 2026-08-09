import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appointment_model.dart';
import '../constants/app_constants.dart';

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(FirebaseFirestore.instance);
});

class AppointmentsRepository {
  final FirebaseFirestore _db;

  AppointmentsRepository(this._db);

  Future<String> createAppointment(AppointmentModel appointment) async {
    final docRef = await _db
        .collection('appointments')
        .add(appointment.toMap());
    return docRef.id;
  }

  Future<void> updateAppointmentStatus(String appointmentId, bool isCompleted) async {
    await _db
        .collection('appointments')
        .doc(appointmentId)
        .update({
      'isCompleted': isCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _db.collection('appointments').doc(appointmentId).delete();
  }

  Stream<List<AppointmentModel>> getAllAppointmentsStream() {
    return _db
        .collection('appointments')
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<AppointmentModel>> getCollectorAppointmentsStream(String collectorUid) {
    return _db
        .collection('appointments')
        .where('collectorId', isEqualTo: collectorUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
          return list;
        });
  }
}
