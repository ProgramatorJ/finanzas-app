import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/rbac_service.dart';
import '../../core/models/user_model.dart';
import '../auth/login_screen.dart';
import '../dashboard/admin_dashboard.dart';
import '../dashboard/cobrador_dashboard.dart';

/// AuthGate: Puerta de entrada de la app.
/// Escucha el estado de autenticación en tiempo real y redirige al
/// dashboard correcto según el rol del usuario (admin o cobrador).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF1E1E2E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A73E8)),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (user) {
        // No hay sesión → ir a Login
        if (user == null) return const LoginScreen();

        // Hay sesión → cargar el modelo del usuario para conocer su rol
        final userModelAsync = ref.watch(currentUserModelProvider);

        return userModelAsync.when(
          loading: () => const Scaffold(
            backgroundColor: Color(0xFF1E1E2E),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1A73E8)),
                  SizedBox(height: 16),
                  Text(
                    'Verificando permisos...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          error: (error, _) => Scaffold(
            body: Center(child: Text('Error de permisos: $error')),
          ),
          data: (userModel) {
            if (userModel == null) {
              // El usuario existe en Auth pero no en Firestore → sin acceso
              return Scaffold(
                backgroundColor: const Color(0xFF1E1E2E),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline,
                          color: Colors.redAccent, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Acceso no autorizado',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tu cuenta no tiene permisos asignados.\nContacta al administrador.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () =>
                            ref.read(authServiceProvider).signOut(),
                        child: const Text('Cerrar sesión',
                            style: TextStyle(color: Color(0xFF1A73E8))),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Redirigir según el rol
            if (userModel.role == UserRole.admin) {
              return const AdminDashboard();
            } else {
              return const CobradorDashboard();
            }
          },
        );
      },
    );
  }
}
