import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/client_model.dart';
import '../../core/models/credit_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/rbac_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../clients/client_list_screen.dart';
import '../payments/payment_form_screen.dart';
import '../payments/payments_history_screen.dart';
import '../calendar/payment_calendar_screen.dart';
import '../reports/reports_main_screen.dart';
import '../notifications/alert_center_widget.dart';
import '../appointments/appointments_agenda_screen.dart';
import '../../core/services/local_notification_service.dart';

class CobradorDashboard extends ConsumerStatefulWidget {
  const CobradorDashboard({super.key});

  @override
  ConsumerState<CobradorDashboard> createState() => _CobradorDashboardState();
}

class _CobradorDashboardState extends ConsumerState<CobradorDashboard> {
  @override
  void initState() {
    super.initState();
    // Ejecutar auto-escáner de mora una vez al iniciar sesión en el dashboard del cobrador
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(firestoreServiceProvider).autoScanMora();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Activar sincronización de alarmas en segundo plano
    ref.watch(alarmSyncProvider);

    final userModel = ref.watch(currentUserModelProvider);
    final theme = Theme.of(context);

    return ResponsiveSidebarScaffold(
      selectedIndex: 0,
      title: 'Panel de Cobrador',
      actions: const [
        AlertCenterWidget(),
        SizedBox(width: 8),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bienvenida Cobrador Premium ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [const Color(0xFF1E2638), const Color(0xFF121724)]
                      : [const Color(0xFF252F46), const Color(0xFF171E2D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: userModel.maybeWhen(
                data: (user) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bienvenido,',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.displayName ?? 'Cobrador',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '💼 Cobrador',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${user?.assignedClientIds.length ?? 0} clientes asignados',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                orElse: () => const CircularProgressIndicator(color: Colors.white),
              ),
            ),

            const SizedBox(height: 32),

            // ── Acciones disponibles ─────────────────────────────────
            Text(
              'Mis Funciones',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 1200
                    ? 4
                    : MediaQuery.of(context).size.width > 700
                        ? 3
                        : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.35,
                children: [
                  _CobradorCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Mis Clientes',
                    subtitle: 'Ver clientes asignados',
                    color: Theme.of(context).colorScheme.secondary,
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClientListScreen()),
                      );
                    },
                  ),
                  _CobradorCard(
                    icon: Icons.attach_money_rounded,
                    title: 'Registrar Pago',
                    subtitle: 'Anotar abono recibido',
                    color: Theme.of(context).colorScheme.primary,
                    available: true,
                    onTap: () {
                      final user = ref.read(authServiceProvider).currentUser;
                      if (user != null) {
                        _showRegistrarPagoFlow(context, ref, user.uid);
                      }
                    },
                  ),
                  _CobradorCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'Historial',
                    subtitle: 'Ver abonos registrados',
                    color: const Color(0xFFD97706),
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentsHistoryScreen()),
                      );
                    },
                  ),
                  _CobradorCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Mi Calendario',
                    subtitle: 'Cobros calendarizados',
                    color: Theme.of(context).colorScheme.primary,
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentCalendarScreen()),
                      );
                    },
                  ),
                  _CobradorCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Reportes de Cobro',
                    subtitle: 'Próximos cobros y KPIs',
                    color: Theme.of(context).colorScheme.tertiary,
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsMainScreen()),
                      );
                    },
                  ),
                  _CobradorCard(
                    icon: Icons.today_rounded,
                    title: 'Agenda de Citas',
                    subtitle: 'Visitas y llamadas programadas',
                    color: const Color(0xFF5E5BF6),
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AppointmentsAgendaScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Aviso de permisos restringidos ────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardTheme.color?.withValues(alpha: 0.5) ?? theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Solo tienes acceso a los clientes que te han sido asignados por el administrador.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Disponible en la Fase 2 🚀'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRegistrarPagoFlow(BuildContext context, WidgetRef ref, String userId) {
    final db = ref.read(firestoreServiceProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return StreamBuilder<List<ClientModel>>(
          stream: db.getAssignedClientsStream(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      snapshot.hasError 
                          ? 'Error al cargar clientes: ${snapshot.error}' 
                          : 'No tienes clientes asignados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5A5B5) : Colors.black54,
                      ),
                    ),
                  ),
                ),
              );
            }

            final clients = snapshot.data!;
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return GlassmorphicContainer(
                  isBottomSheet: true,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5A5B5) : Colors.black54,
                            borderRadius: const BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                      Text(
                        'Seleccionar Cliente para Abono',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: clients.length,
                          itemBuilder: (context, index) {
                            final client = clients[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                  title: Text(client.fullName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                      )),
                                  subtitle: Text('DNI: ${client.idNumber}',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5A5B5) : Colors.black54,
                                        fontSize: 12,
                                      )),
                                onTap: () {
                                  Navigator.pop(context); // Cerrar bottom sheet de cliente
                                  _showCreditSelectionFlow(context, ref, client);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreditSelectionFlow(BuildContext context, WidgetRef ref, ClientModel client) {
    final db = ref.read(firestoreServiceProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return StreamBuilder<List<CreditModel>>(
          stream: db.getClientCreditsStream(client.clientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final activeCredits = (snapshot.data ?? [])
                .where((c) => c.status != CreditStatus.completed)
                .toList();

            if (activeCredits.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'El cliente ${client.fullName} no tiene créditos activos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5A5B5) : Colors.black54,
                      ),
                    ),
                  ),
                ),
              );
            }

            // Si tiene exactamente 1 crédito activo, ir directo al formulario de pago
            if (activeCredits.length == 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context); // Cerrar este bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentFormScreen(
                      clientId: client.clientId,
                      creditId: activeCredits.first.creditId,
                      dailyMoraRate: activeCredits.first.dailyMoraRate,
                    ),
                  ),
                );
              });
              return const SizedBox();
            }

            // Si tiene múltiples créditos, mostrarlos en lista
            final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

            return GlassmorphicContainer(
              isBottomSheet: true,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5A5B5) : Colors.black54,
                        borderRadius: const BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                  Text(
                    'Seleccionar Crédito de ${client.fullName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: activeCredits.length,
                      itemBuilder: (context, index) {
                        final credit = activeCredits[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(
                              'Capital: ${copFormatter.format(credit.principalAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              'Ref: ${credit.creditId.substring(0, credit.creditId.length > 8 ? 8 : credit.creditId.length)} | Saldo: ${copFormatter.format(credit.outstandingBalance)}',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA5A5B5) : Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context); // Cerrar bottom sheet de crédito
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentFormScreen(
                                    clientId: client.clientId,
                                    creditId: credit.creditId,
                                    dailyMoraRate: credit.dailyMoraRate,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
}

class _CobradorCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool available;
  final VoidCallback onTap;

  const _CobradorCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.available,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11, color: isDark ? const Color(0xFFA5A5B5) : Colors.black54)),
              if (!available)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Fase 2',
                      style: TextStyle(
                          fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
