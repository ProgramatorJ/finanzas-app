import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_model.dart';
import '../constants/app_constants.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(FirebaseFirestore.instance);
});

class ClientsRepository {
  final FirebaseFirestore _db;

  ClientsRepository(this._db);

  CollectionReference get _clientsRef => _db.collection(AppConstants.clientsCollection);

  /// Obtiene un stream paginado de clientes
  Stream<List<ClientModel>> getClientsStream({int limit = 10000}) {
    return _clientsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ClientModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Obtiene un stream paginado de clientes asignados a un cobrador
  Stream<List<ClientModel>> getAssignedClientsStream(String collectorUid, {int limit = 10000}) {
    return _clientsRef
        .where('assignedCollectorIds', arrayContains: collectorUid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ClientModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Crea un nuevo cliente
  Future<String> createClient(ClientModel client) async {
    final docRef = _clientsRef.doc();
    final clientData = client.toMap();
    clientData['createdAt'] = FieldValue.serverTimestamp();
    clientData['updatedAt'] = FieldValue.serverTimestamp();
    
    await docRef.set(clientData);
    return docRef.id;
  }

  /// Actualiza un cliente
  Future<void> updateClient(String clientId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _clientsRef.doc(clientId).update(data);
  }

  /// Elimina un cliente lógicamente (o físicamente, dependiendo de las reglas)
  Future<void> deleteClient(String clientId) async {
    // Si se bloqueó el delete en reglas de Firestore, esto fallará si no está en un Cloud Function,
    // o se puede hacer borrado lógico haciendo un update de un campo 'isDeleted': true.
    // Por ahora mantenemos la interfaz original.
    await _clientsRef.doc(clientId).delete();
  }
}
