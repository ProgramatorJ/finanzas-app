import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/rbac_service.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../clients/client_list_screen.dart';
import '../credits/credit_list_screen.dart';
import '../calendar/payment_calendar_screen.dart';
import '../reports/reports_main_screen.dart';
import '../notifications/alert_center_widget.dart';
import '../settings/settings_screen.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/firestore_service.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    // Ejecutar auto-escáner de mora una vez al iniciar sesión en el dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(firestoreServiceProvider).autoScanMora();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Activar sincronización de alarmas en segundo plano
    ref.watch(alarmSyncProvider);

    final userModel = ref.watch(currentUserModelProvider);

    return ResponsiveSidebarScaffold(
      selectedIndex: 0,
      title: 'Panel de Administrador',
      actions: const [
        AlertCenterWidget(),
        SizedBox(width: 8),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bienvenida Premium ────────────────────────────────────────────
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
                      user?.displayName ?? 'Administrador',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🔑 Administrador — Acceso Total',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                orElse: () => const CircularProgressIndicator(color: Colors.white),
              ),
            ),

            const SizedBox(height: 32),

            // ── Módulos del Sistema ──────────────────────────────────────────
            Text(
              'Módulos del Sistema',
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
                  _DashboardCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Clientes',
                    subtitle: 'Gestionar clientes',
                    color: Theme.of(context).colorScheme.primary,
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClientListScreen()),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Créditos',
                    subtitle: 'Gestionar préstamos',
                    color: Theme.of(context).colorScheme.secondary,
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreditListScreen()),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.people_rounded,
                    title: 'Cobradores',
                    subtitle: 'Gestionar cobradores',
                    color: Theme.of(context).colorScheme.tertiary,
                    available: false,
                  ),
                  _DashboardCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Informes',
                    subtitle: 'Ver estadísticas',
                    color: const Color(0xFFD97706),
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsMainScreen()),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Calendario',
                    subtitle: 'Ver calendario de pagos',
                    color: Theme.of(context).colorScheme.primary,
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentCalendarScreen()),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.settings_rounded,
                    title: 'Configuración',
                    subtitle: 'Tasas y parámetros',
                    color: Theme.of(context).colorScheme.secondary,
                    available: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool available;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.available,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: available
            ? onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Disponible en la Fase 2 🚀'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
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
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Fase 2',
                      style:
                          TextStyle(fontSize: 10, color: Color(0xFF1A73E8))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
