import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Servicio de Autenticación con Firebase Auth.
/// Maneja el inicio de sesión, cierre de sesión y el stream del usuario actual.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream del usuario autenticado actualmente (null si no hay sesión)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Usuario actualmente autenticado (puede ser null)
  User? get currentUser => _auth.currentUser;

  /// Iniciar sesión con correo y contraseña.
  /// Devuelve el [UserCredential] si es exitoso.
  /// Lanza [FirebaseAuthException] si falla.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Cerrar sesión del usuario actual.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Crear un nuevo usuario con correo y contraseña.
  /// Solo debe ser llamado por el servicio de Firestore del Admin.
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Enviar correo de restablecimiento de contraseña.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}

// ─── Providers de Riverpod ─────────────────────────────────────────────────

/// Provider del servicio de autenticación
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream Provider del estado de autenticación (User? → null si no hay sesión)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authServiceProvider).authStateChanges;
});
