import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/client_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/repositories/users_repository.dart';

/// Proveedor para obtener el stream de cobradores
final collectorsStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.read(usersRepositoryProvider).getCollectorsStream();
});

class ClientFormScreen extends ConsumerStatefulWidget {
  final ClientModel? clientToEdit;

  const ClientFormScreen({super.key, this.clientToEdit});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  List<String> _selectedCollectorIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.clientToEdit != null) {
      _nameController.text = widget.clientToEdit!.fullName;
      _idController.text = widget.clientToEdit!.idNumber;
      _phoneController.text = widget.clientToEdit!.phone;
      _addressController.text = widget.clientToEdit!.address;
      _selectedCollectorIds = List.from(widget.clientToEdit!.assignedCollectorIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    // Transferencia Destructiva: Check if any previously assigned collector was removed
    if (widget.clientToEdit != null) {
      final originalCollectors = widget.clientToEdit!.assignedCollectorIds;
      final removedCollectors = originalCollectors.where((id) => !_selectedCollectorIds.contains(id)).toList();
      
      if (removedCollectors.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Transferencia de Cliente'),
            content: const Text('Estás a punto de quitar a uno o más cobradores de este cliente. Si continúas, este cliente desaparecerá de su vista y perderán acceso a su historial. ¿Deseas continuar?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Sí, Transferir', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
    }

    setState(() => _isSaving = true);

    final currentUser = ref.read(authServiceProvider).currentUser;
    final db = ref.read(firestoreServiceProvider);

    final clientData = ClientModel(
      clientId: widget.clientToEdit?.clientId ?? '',
      fullName: _nameController.text.trim(),
      idNumber: _idController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      assignedCollectorIds: _selectedCollectorIds,
      createdByUid: widget.clientToEdit?.createdByUid ?? currentUser?.uid ?? '',
      isActive: widget.clientToEdit?.isActive ?? true,
      createdAt: widget.clientToEdit?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.clientToEdit == null) {
        await db.createClient(clientData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente creado con éxito.'),
              backgroundColor: AppTheme.secondaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        await db.updateClient(widget.clientToEdit!.clientId, clientData.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente actualizado con éxito.'),
              backgroundColor: AppTheme.secondaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectorsAsync = ref.watch(collectorsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clientToEdit == null ? 'Nuevo Cliente' : 'Editar Cliente'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Información Personal Card ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_outline, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Datos Personales',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Campo Nombre completo
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre Completo',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre completo' : null,
                          ),
                          const SizedBox(height: 16),

                          // Campo Cédula/DNI
                          TextFormField(
                            controller: _idController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cédula / DNI',
                              prefixIcon: Icon(Icons.fingerprint_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el documento de identidad' : null,
                          ),
                          const SizedBox(height: 16),

                          // Campo Teléfono
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Número de Teléfono',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el teléfono' : null,
                          ),
                          const SizedBox(height: 16),

                          // Campo Dirección
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Dirección de Domicilio',
                              prefixIcon: Icon(Icons.home_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa la dirección' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Asignación de Cobradores Card ---
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assignment_ind_outlined, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Asignar Cobradores',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Los cobradores seleccionados tendrán acceso a los créditos y cobros de este cliente.',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 16),

                          collectorsAsync.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            error: (err, _) => Text(
                              'Error al cargar cobradores: $err',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            data: (collectors) {
                              if (collectors.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'No hay cobradores activos registrados en el sistema. Registra un cobrador primero.',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: collectors.length,
                                itemBuilder: (context, index) {
                                  final collector = collectors[index];
                                  final isSelected = _selectedCollectorIds.contains(collector.uid);

                                  return CheckboxListTile(
                                    activeColor: theme.colorScheme.primary,
                                    checkColor: Colors.white,
                                    title: Text(
                                      collector.displayName.isNotEmpty ? collector.displayName : collector.email,
                                      style: TextStyle(color: theme.colorScheme.onSurface),
                                    ),
                                    subtitle: Text(
                                      collector.email,
                                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                                    ),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedCollectorIds.add(collector.uid);
                                        } else {
                                          _selectedCollectorIds.remove(collector.uid);
                                        }
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón Guardar
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.brightness == Brightness.dark
                            ? [const Color(0xFF00E5FF), const Color(0xFF0083B0)]
                            : [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : theme.colorScheme.primary)
                              .withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveClient,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              widget.clientToEdit == null ? 'Crear Cliente' : 'Guardar Cambios',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
