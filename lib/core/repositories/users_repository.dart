import '../enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../constants/app_constants.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(FirebaseFirestore.instance);
});

class UsersRepository {
  final FirebaseFirestore _db;

  UsersRepository(this._db);

  Future<void> setUser(UserModel user) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Stream<List<UserModel>> getAllUsersStream() {
    return _db
        .collection(AppConstants.usersCollection)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<UserModel>> getCollectorsStream() {
    return _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: UserRole.cobrador.name)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
