import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../constants/app_constants.dart';
import 'auth_service.dart';

/// Servicio de Control de Acceso Basado en Roles (RBAC).
/// Consulta el documento del usuario en Firestore para obtener su rol
/// y determinar qué acciones puede realizar en la aplicación.
class RbacService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene el [UserModel] completo del usuario actual desde Firestore.
  /// Devuelve null si no existe el documento.
  Future<UserModel?> getCurrentUserModel(String uid) async {
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Stream del [UserModel] del usuario actualmente autenticado.
  /// Emite actualizaciones en tiempo real si cambia el documento.
  Stream<UserModel?> getUserModelStream(String uid) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Verifica si el usuario actual tiene rol de administrador.
  Future<bool> isAdmin(String uid) async {
    final user = await getCurrentUserModel(uid);
    return user?.role == UserRole.admin;
  }

  /// Verifica si el cobrador tiene acceso al cliente especificado.
  Future<bool> collectorHasAccessToClient({
    required String collectorUid,
    required String clientId,
  }) async {
    final doc = await _db
        .collection(AppConstants.clientsCollection)
        .doc(clientId)
        .get();

    if (!doc.exists || doc.data() == null) return false;
    final List<String> assignedIds =
        List<String>.from(doc.data()!['assignedCollectorIds'] ?? []);
    return assignedIds.contains(collectorUid);
  }
}

// ─── Providers de Riverpod ─────────────────────────────────────────────────

/// Provider del servicio RBAC
final rbacServiceProvider = Provider<RbacService>((ref) => RbacService());

/// Stream Provider del UserModel del usuario autenticado actual.
/// Se actualiza automáticamente si el rol cambia en Firestore.
final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.read(rbacServiceProvider).getUserModelStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (err, stack) => Stream.value(null),
  );
});
