import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/appointment_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/rbac_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../clients/client_detail_screen.dart';

/// Stream de citas unificado (según rol, cargado desde Firestore)
final appointmentsStreamProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final db = ref.read(firestoreServiceProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value(<AppointmentModel>[]);
      if (user.role == UserRole.admin) {
        return db.getAllAppointmentsStream();
      } else {
        return db.getCollectorAppointmentsStream(user.uid);
      }
    },
    loading: () => Stream.value(<AppointmentModel>[]),
    error: (_, __) => Stream.value(<AppointmentModel>[]),
  );
});

/// Deprecated: usar appointmentsStreamProvider. Mantenido por compatibilidad.
final collectorAppointmentsProvider = appointmentsStreamProvider;

class AppointmentsAgendaScreen extends ConsumerStatefulWidget {
  const AppointmentsAgendaScreen({super.key});

  @override
  ConsumerState<AppointmentsAgendaScreen> createState() => _AppointmentsAgendaScreenState();
}

class _AppointmentsAgendaScreenState extends ConsumerState<AppointmentsAgendaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(collectorAppointmentsProvider);

    // Disparar sincronización de alarmas en el dispositivo para citas pendientes futuras
    appointmentsAsync.whenData((list) {
      final now = DateTime.now();
      final pendingFuture = list.where((a) => !a.isCompleted && a.scheduledTime.isAfter(now)).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(localNotificationServiceProvider).syncDeviceAppointments(pendingFuture);
      });
    });

    return ResponsiveSidebarScaffold(
      selectedIndex: 4,
      title: 'Agenda de Citas',
      child: Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0A0A14)
                : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFFA5A5B5) 
                  : Colors.black54,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Pendientes'),
                Tab(text: 'Completadas'),
              ],
            ),
          ),
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error al cargar agenda: $err', style: const TextStyle(color: AppTheme.errorColor)),
              ),
              data: (appointments) {
                final pending = appointments.where((a) => !a.isCompleted).toList();
                final completed = appointments.where((a) => a.isCompleted).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAppointmentsList(pending, isPendingList: true),
                    _buildAppointmentsList(completed, isPendingList: false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList(List<AppointmentModel> list, {required bool isPendingList}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendingList ? Icons.today_outlined : Icons.check_circle_outline_rounded,
              size: 64,
              color: secondaryTextColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isPendingList ? 'No tienes citas programadas pendientes.' : 'No hay citas completadas en tu historial.',
              style: TextStyle(color: secondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final copFormatter = DateFormat('dd MMMM yyyy, hh:mm a', 'es');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final appointment = list[index];
        final isOverdue = !appointment.isCompleted && appointment.scheduledTime.isBefore(DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: appointment.type == AppointmentType.call
                              ? AppTheme.primaryColor.withOpacity(0.15)
                              : AppTheme.warningColor.withOpacity(0.15),
                          child: Icon(
                            appointment.type == AppointmentType.call ? Icons.phone_rounded : Icons.home_rounded,
                            color: appointment.type == AppointmentType.call ? AppTheme.primaryColor : AppTheme.warningColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.clientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (appointment.creditId != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Crédito Ref: ${appointment.creditId!.substring(0, appointment.creditId!.length > 8 ? 8 : appointment.creditId!.length)}',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              appointment.type == AppointmentType.call ? 'Llamar por teléfono' : 'Visita presencial',
                              style: TextStyle(color: secondaryTextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'RETARDADO',
                          style: TextStyle(color: AppTheme.errorColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: secondaryTextColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        copFormatter.format(appointment.scheduledTime),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 16, color: secondaryTextColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.notes,
                        style: TextStyle(color: secondaryTextColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Botón para ver ficha del cliente
                    TextButton.icon(
                      icon: const Icon(Icons.person_outline_rounded, size: 16),
                      label: const Text('Cliente'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientDetailScreen(clientId: appointment.clientId),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                    ),
                    const Spacer(),
                    if (isPendingList) ...[
                      // Botón para eliminar/cancelar cita
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                        tooltip: 'Eliminar Cita',
                        onPressed: () => _confirmDelete(appointment),
                      ),
                      const SizedBox(width: 8),
                      // Botón para marcar completada
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Completar'),
                        onPressed: () {
                          ref.read(firestoreServiceProvider).updateAppointmentStatus(appointment.appointmentId, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ] else ...[
                      // Reabrir cita si fue completada por error
                      TextButton.icon(
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: const Text('Reabrir'),
                        onPressed: () {
                          ref.read(firestoreServiceProvider).updateAppointmentStatus(appointment.appointmentId, false);
                        },
                        style: TextButton.styleFrom(foregroundColor: AppTheme.warningColor),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(AppointmentModel appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => GlassmorphicContainer(
        child: AlertDialog(
          title: const Text('¿Cancelar Cita?'),
          content: const Text('Esta acción eliminará la cita programada y cancelará la alarma en el dispositivo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      // Cancelar alarma local
      try {
        await ref.read(localNotificationServiceProvider).cancelNotification(appointment.appointmentId.hashCode);
      } catch (e) {
        debugPrint('[Agenda] No se pudo cancelar alarma local: $e');
      }
      
      // Eliminar de Firestore
      await ref.read(firestoreServiceProvider).deleteAppointment(appointment.appointmentId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita cancelada correctamente.'),
            backgroundColor: AppTheme.secondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
