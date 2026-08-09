import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/repositories/users_repository.dart';
import '../../core/enums/user_role.dart';
import '../../shared/theme/app_theme.dart';
import 'user_form_screen.dart';

final allUsersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.read(usersRepositoryProvider).getAllUsersStream();
});

class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(allUsersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserFormScreen()),
              );
            },
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error)),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: user.role == UserRole.admin 
                        ? AppTheme.primaryColor 
                        : AppTheme.secondaryColor,
                    child: Icon(
                      user.role == UserRole.admin ? Icons.admin_panel_settings : Icons.directions_walk_rounded,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${user.email}\nRol: ${user.role == UserRole.admin ? 'Administrador' : 'Cobrador'}',
                  ),
                  trailing: Icon(
                    user.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: user.isActive ? Colors.green : Colors.red,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserFormScreen(userToEdit: user)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
