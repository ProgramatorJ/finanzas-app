import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/user_model.dart';
import '../../core/repositories/users_repository.dart';
import '../../core/enums/user_role.dart';
import '../../shared/theme/app_theme.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  final UserModel? userToEdit;

  const UserFormScreen({super.key, this.userToEdit});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  UserRole _selectedRole = UserRole.cobrador;
  bool _isActive = true;
  bool _canViewOtherClients = false;
  bool _canViewOtherTreasury = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.userToEdit != null) {
      _emailController.text = widget.userToEdit!.email;
      _displayNameController.text = widget.userToEdit!.displayName;
      _selectedRole = widget.userToEdit!.role;
      _isActive = widget.userToEdit!.isActive;
      _canViewOtherClients = widget.userToEdit!.canViewOtherClients;
      _canViewOtherTreasury = widget.userToEdit!.canViewOtherTreasury;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final uid = widget.userToEdit?.uid ?? Uuid().v4();
      final now = DateTime.now();

      final user = UserModel(
        uid: uid,
        email: _emailController.text.trim(),
        displayName: _displayNameController.text.trim(),
        role: _selectedRole,
        assignedClientIds: widget.userToEdit?.assignedClientIds ?? [],
        isActive: _isActive,
        canViewOtherClients: _canViewOtherClients,
        canViewOtherTreasury: _canViewOtherTreasury,
        canViewAllClientPayments: false, // Deprecated, keeping false
        createdAt: widget.userToEdit?.createdAt ?? now,
        updatedAt: now,
      );

      await ref.read(usersRepositoryProvider).setUser(user);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.userToEdit == null ? 'Usuario creado' : 'Usuario actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCobrador = _selectedRole == UserRole.cobrador;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userToEdit == null ? 'Nuevo Usuario' : 'Editar Usuario'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _displayNameController,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Nombre Completo',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              enabled: !_isSaving && widget.userToEdit == null, // Can't change email after creation easily in Firebase Auth, but let's keep it simple here
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa el correo';
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rol y Estado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol del Usuario',
                        prefixIcon: Icon(Icons.admin_panel_settings),
                      ),
                      items: const [
                        DropdownMenuItem(value: UserRole.admin, child: Text('Administrador')),
                        DropdownMenuItem(value: UserRole.cobrador, child: Text('Cobrador')),
                      ],
                      onChanged: _isSaving ? null : (val) {
                        if (val != null) {
                          setState(() => _selectedRole = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Usuario Activo'),
                      subtitle: const Text('Si se desactiva, no podrá acceder a la app.'),
                      value: _isActive,
                      activeColor: Colors.green,
                      onChanged: _isSaving ? null : (val) => setState(() => _isActive = val),
                    ),
                  ],
                ),
              ),
            ),
            
            if (isCobrador) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Permisos de Jerarquía', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Ver clientes ajenos'),
                        subtitle: const Text('Permite ver la cartera de otros cobradores.'),
                        value: _canViewOtherClients,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: _isSaving ? null : (val) => setState(() => _canViewOtherClients = val),
                      ),
                      SwitchListTile(
                        title: const Text('Ver caja ajena'),
                        subtitle: const Text('Permite ver el cuadre de caja (tesorería) de otros cobradores.'),
                        value: _canViewOtherTreasury,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: _isSaving ? null : (val) => setState(() => _canViewOtherTreasury = val),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveUser,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar Usuario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
