import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/client_model.dart';
import '../../core/models/credit_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/rbac_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import 'client_form_screen.dart';
import '../credits/credit_form_screen.dart';
import '../credits/credit_detail_screen.dart';
import '../appointments/appointment_form_dialog.dart';
import '../../core/models/appointment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Stream del cliente por ID
final clientProvider = StreamProvider.family<ClientModel?, String>((ref, clientId) {
  return ref.read(firestoreServiceProvider).getAllClientsStream().map((list) {
    return list.firstWhere((c) => c.clientId == clientId);
  });
});

/// Stream de créditos de un cliente por ID
final clientCreditsProvider = StreamProvider.family<List<CreditModel>, String>((ref, clientId) {
  return ref.read(firestoreServiceProvider).getClientCreditsStream(clientId);
});

/// Stream de citas activas de un cliente específico
final clientAppointmentsProvider = StreamProvider.family<List<AppointmentModel>, String>((ref, clientId) {
  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('appointments')
      .where('clientId', isEqualTo: clientId)
      .where('isCompleted', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList());
});

class ClientDetailScreen extends ConsumerStatefulWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

enum ClientCreditFilter {
  all,
  active,
  onTime,
  inMora,
  inactive, // Completed
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  ClientCreditFilter _selectedFilter = ClientCreditFilter.all;

  String _filterLabel(ClientCreditFilter filter) {
    switch (filter) {
      case ClientCreditFilter.all:
        return 'Todos';
      case ClientCreditFilter.active:
        return 'Activos';
      case ClientCreditFilter.onTime:
        return 'Al día';
      case ClientCreditFilter.inMora:
        return 'En mora';
      case ClientCreditFilter.inactive:
        return 'Inactivos';
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync = ref.watch(clientProvider(widget.clientId));
    final creditsAsync = ref.watch(clientCreditsProvider(widget.clientId));
    final userModelAsync = ref.watch(currentUserModelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isAdmin = userModelAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin,
      orElse: () => false,
    );

    return ResponsiveSidebarScaffold(
      selectedIndex: 1, // Clientes
      title: 'Detalle de Cliente',
      isDetailScreen: true,
      child: Scaffold(
      appBar: AppBar(
        title: Text('Detalle de Cliente', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          if (isAdmin)
            clientAsync.maybeWhen(
              data: (client) => client != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar Cliente',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientFormScreen(clientToEdit: client),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                          tooltip: 'Eliminar Cliente',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => GlassmorphicContainer(
                                child: AlertDialog(
                                  title: const Text('¿Eliminar Cliente?'),
                                  content: const Text(
                                    'Esto eliminará permanentemente al cliente y todos sus créditos, cuotas e historial de abonos asociados. Esta acción no se puede deshacer.'
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancelar'),
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
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Eliminando cliente...'))
                                );
                              }
                              await ref.read(firestoreServiceProvider).deleteClient(client.clientId);
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                        ),
                      ],
                    )
                  : const SizedBox(),
              orElse: () => const SizedBox(),
            ),
        ],
      ),
      body: clientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar cliente: $err',
              style: const TextStyle(color: AppTheme.errorColor)),
        ),
        data: (client) {
          if (client == null) {
            return const Center(
              child: Text('Cliente no encontrado.',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final size = MediaQuery.of(context).size;
          final isWide = size.width > 900;

          final clientCredits = creditsAsync.maybeWhen(
            data: (list) => list,
            orElse: () => <CreditModel>[],
          );
          final bool hasMora = clientCredits.any((c) => c.status == CreditStatus.defaulted);
          final Color clientColor = !client.isActive
              ? Colors.grey.shade400
              : (hasMora ? AppTheme.errorColor : AppTheme.primaryColor);

          // Widget de tarjeta de información del cliente
          Widget buildClientInfoCard() {
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: clientColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de Perfil del Cliente
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: clientColor.withValues(alpha: 0.5), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: clientColor.withValues(alpha: 0.22),
                            child: Text(
                              client.fullName.substring(0, 1).toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: clientColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client.fullName,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'DNI: ${client.idNumber}',
                                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text(
                      'Información General',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoRow(Icons.phone_rounded, 'Teléfono', client.phone, theme),
                    _infoRow(Icons.home_rounded, 'Dirección', client.address, theme),
                    _infoRow(
                      Icons.assignment_ind_rounded,
                      'Cobradores Asignados',
                      client.assignedCollectorIds.isEmpty
                          ? 'Ninguno asignado'
                          : '${client.assignedCollectorIds.length} cobrador(es)',
                      theme,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text('Programar Cita (Visita/Llamada)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        foregroundColor: theme.colorScheme.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AppointmentFormDialog(
                            clientId: client.clientId,
                            clientName: client.fullName,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Widget de citas programadas
          Widget buildAppointmentsSection() {
            return ref.watch(clientAppointmentsProvider(widget.clientId)).when(
              data: (appointments) {
                if (appointments.isEmpty) return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Citas Programadas',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...appointments.map((app) {
                      final timeStr = DateFormat('dd/MM/yyyy a las hh:mm a').format(app.scheduledTime);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: app.type == AppointmentType.call
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : theme.colorScheme.tertiary.withValues(alpha: 0.15),
                              child: Icon(
                                app.type == AppointmentType.call ? Icons.phone_rounded : Icons.home_rounded,
                                color: app.type == AppointmentType.call ? theme.colorScheme.primary : theme.colorScheme.tertiary,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    app.type == AppointmentType.call ? 'Llamada Telefónica' : 'Visita Presencial',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (app.creditId != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Ref: ${app.creditId}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '$timeStr\nNotas: ${app.notes}',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.secondary),
                              tooltip: 'Marcar como Completada',
                              onPressed: () {
                                ref.read(firestoreServiceProvider).updateAppointmentStatus(app.appointmentId, true);
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const SizedBox(),
              error: (err, stack) => const SizedBox(),
            );
          }

          // Widget de historial de créditos
          Widget buildCreditsSection() {
            final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Historial de Créditos',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        PopupMenuButton<ClientCreditFilter>(
                          tooltip: 'Filtrar créditos',
                          onSelected: (ClientCreditFilter filter) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          itemBuilder: (context) => ClientCreditFilter.values.map((filter) {
                            return PopupMenuItem<ClientCreditFilter>(
                              value: filter,
                              child: Text(
                                _filterLabel(filter),
                                style: GoogleFonts.outfit(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF121A30) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _filterLabel(_selectedFilter),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.filter_list_rounded, size: 12),
                              ],
                            ),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nuevo Crédito'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreditFormScreen(clientId: client.clientId),
                            ),
                          );
                        },
                      ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                creditsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text(
                    'Error al cargar créditos: $err',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  data: (credits) {
                    if (credits.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          child: Column(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined,
                                  size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'Este cliente no tiene créditos registrados.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: credits.length,
                      itemBuilder: (context, index) {
                        final credit = credits[index];
                        final statusCol = _statusColor(credit.status);

                        // Aplicar filtro
                        if (_selectedFilter == ClientCreditFilter.active && (credit.status == CreditStatus.completed)) return const SizedBox();
                        if (_selectedFilter == ClientCreditFilter.onTime && credit.status != CreditStatus.active && credit.status != CreditStatus.restructured) return const SizedBox();
                        if (_selectedFilter == ClientCreditFilter.inMora && credit.status != CreditStatus.defaulted) return const SizedBox();
                        if (_selectedFilter == ClientCreditFilter.inactive && credit.status != CreditStatus.completed) return const SizedBox();

                        final endDate = credit.disbursementDate.add(Duration(
                          days: credit.paymentFrequency == PaymentFrequency.weekly ? 7 * credit.numberOfInstallments
                              : credit.paymentFrequency == PaymentFrequency.biweekly ? 15 * credit.numberOfInstallments
                              : 30 * credit.numberOfInstallments
                        ));
                        final endDateStr = DateFormat('dd/MM/yyyy').format(endDate);
                        final cuotaVal = copFormatter.format(credit.totalAmount / credit.numberOfInstallments);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: statusCol.withValues(alpha: 0.06),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: statusCol.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            elevation: 0,
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreditDetailScreen(
                                          creditId: credit.creditId,
                                          clientId: widget.clientId,
                                        ),
                                      ),
                                    );
                                  },
                              leading: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: statusCol.withValues(alpha: 0.5), width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: statusCol.withValues(alpha: 0.22),
                                    child: Icon(
                                      Icons.monetization_on_rounded,
                                      color: statusCol,
                                      size: 20,
                                    ),
                                  ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    copFormatter.format(credit.principalAmount),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: statusCol,
                                    ),
                                  ),
                                  Text(
                                    'Ref: ${credit.creditId}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Frecuencia: ${_translateFrequency(credit.paymentFrequency)} | Cuotas: ${credit.paidInstallments}/${credit.numberOfInstallments}\nValor Cuota: $cuotaVal | Finaliza: $endDateStr',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          }

          // ── RENDERIZADO RESPONSIVO (WEB vs MÓVIL) ────────────────────
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna izquierda (Datos y Citas)
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buildClientInfoCard(),
                            buildAppointmentsSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Columna derecha (Créditos)
                      Expanded(
                        flex: 3,
                        child: buildCreditsSection(),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildClientInfoCard(),
                      buildAppointmentsSection(),
                      const SizedBox(height: 24),
                      buildCreditsSection(),
                    ],
                  ),
          );
        },
      ),
    ));
  }
  Widget _infoRow(IconData icon, String label, String value, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditStatusBadge(CreditStatus status, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final color = _statusColor(status);
    final text = _translateStatus(status).toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _statusColor(CreditStatus status) {
    switch (status) {
      case CreditStatus.completed:
        return Colors.grey.shade400;
      case CreditStatus.defaulted:
        return AppTheme.errorColor;
      case CreditStatus.active:
      case CreditStatus.restructured:
        return AppTheme.primaryColor;
    }
  }

  String _translateStatus(CreditStatus status) {
    switch (status) {
      case CreditStatus.active:
        return 'Activo';
      case CreditStatus.completed:
        return 'Pagado';
      case CreditStatus.defaulted:
        return 'En Mora';
      case CreditStatus.restructured:
        return 'Reestructurado';
    }
  }

  String _translateFrequency(PaymentFrequency freq) {
    switch (freq) {
      case PaymentFrequency.weekly:
        return 'Semanal';
      case PaymentFrequency.biweekly:
        return 'Quincenal';
      case PaymentFrequency.monthly:
        return 'Mensual';
    }
  }
}
