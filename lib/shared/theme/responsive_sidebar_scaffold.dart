import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/rbac_service.dart';
import '../../core/models/user_model.dart';
import 'app_theme.dart';
import 'circuit_background_painter.dart';

// Pantallas para Admin
import '../../features/dashboard/admin_dashboard.dart';
import '../../features/clients/client_list_screen.dart';
import '../../features/credits/credit_list_screen.dart';
import '../../features/calendar/payment_calendar_screen.dart';
import '../../features/reports/reports_main_screen.dart';
import '../../features/treasury/treasury_screen.dart';

// Pantallas adicionales para Cobrador
import '../../features/dashboard/cobrador_dashboard.dart';
import '../../features/appointments/appointments_agenda_screen.dart';
import '../../features/payments/payments_history_screen.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final Widget screen;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.screen,
  });
}

class ResponsiveSidebarScaffold extends ConsumerWidget {
  final Widget child;
  final int selectedIndex;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isDetailScreen;

  const ResponsiveSidebarScaffold({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.isDetailScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserModelProvider);
    final isDark = theme.brightness == Brightness.dark;

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (user) {
        if (user == null) return const Scaffold(body: Center(child: Text('Sin sesión')));

        final isAdmin = user.role == UserRole.admin;
        final items = isAdmin ? _getAdminItems() : _getCobradorItems();

        if (!isWide) {
          if (isDetailScreen) return child;
          // --- DISEÑO PARA MÓVIL CON NAV BAR FLOTANTE DE CRISTAL ---
          return Scaffold(
            appBar: AppBar(
              title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                if (actions != null) ...actions!,
                PopupMenuButton<ThemeMode>(
                  icon: Icon(
                    isDark ? Icons.settings_rounded : Icons.settings_outlined,
                  ),
                  tooltip: 'Configuración de Tema',
                  onSelected: (mode) {
                    ref.read(themeModeProvider.notifier).state = mode;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ThemeMode.light,
                      child: Row(
                        children: [
                          Icon(Icons.light_mode_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Modo Claro'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ThemeMode.dark,
                      child: Row(
                        children: [
                          Icon(Icons.dark_mode_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Modo Oscuro'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: ThemeMode.system,
                      child: Row(
                        children: [
                          Icon(Icons.settings_suggest_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Tema del Sistema'),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Cerrar sesión',
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                ),
              ],
            ),
            body: CircuitBackgroundWidget(
              isDark: isDark,
              color: theme.colorScheme.primary,
              child: child,
            ),
            drawer: _buildDrawer(context, ref, user, isAdmin, items, theme),
            bottomNavigationBar: _buildMobileBottomBar(context, items, theme),
            floatingActionButton: floatingActionButton != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: floatingActionButton,
                  )
                : null,
          );
        }

        // --- DISEÑO PREMIUM PARA WEB/ESCRITORIO (SIDEBAR) ---
        return Scaffold(
          body: Row(
            children: [
              // Barra Lateral (Sidebar) con Glassmorphism
              Container(
                width: 260,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242B3D).withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.85),
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Column(
                      children: [
                        // Encabezado del Sistema
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [theme.colorScheme.primary, theme.colorScheme.secondary]
                                        : [theme.colorScheme.primary, theme.colorScheme.tertiary],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.wallet_rounded, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'BANX',
                                      style: GoogleFonts.outfit(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const Text(
                                      'Gestión Financiera',
                                      style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Lista de Opciones
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isSelected = index == selectedIndex;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    if (isDetailScreen) {
                                      if (isSelected) {
                                        Navigator.pop(context);
                                      } else {
                                        Navigator.popUntil(context, (route) => route.isFirst);
                                        Navigator.pushReplacement(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (context, anim1, anim2) => item.screen,
                                            transitionDuration: Duration.zero,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (!isSelected) {
                                        Navigator.pushReplacement(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder: (context, anim1, anim2) => item.screen,
                                            transitionDuration: Duration.zero,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isSelected
                                          ? Border.all(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                              width: 1.0,
                                            )
                                          : Border.all(color: Colors.transparent),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : isDark
                                                  ? const Color(0xFFA5A5B5)
                                                  : Colors.black54,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : isDark
                                                    ? const Color(0xFFE2E2EC)
                                                    : Colors.black87,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const Spacer(),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: theme.colorScheme.primary,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                )
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Perfil de Usuario
                        const Divider(height: 1),
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Datos usuario
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    radius: 18,
                                    child: Text(
                                      (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
                                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.displayName ?? (isAdmin ? 'Administrador' : 'Cobrador'),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          isAdmin ? 'Rol: Admin 🔑' : 'Rol: Cobrador 💼',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                                    tooltip: 'Cerrar sesión',
                                    onPressed: () => ref.read(authServiceProvider).signOut(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Área de Contenido Principal (con cabecera premium e integración de contenido)
              Expanded(
                child: isDetailScreen 
                  ? child 
                  : Column(
                  children: [
                    // Cabecera premium web
                    Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.scaffoldBackgroundColor.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.6),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Row(
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              if (actions != null) ...actions!,
                              PopupMenuButton<ThemeMode>(
                                icon: Icon(
                                  isDark ? Icons.settings_rounded : Icons.settings_outlined,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                tooltip: 'Configuración de Tema',
                                onSelected: (mode) {
                                  ref.read(themeModeProvider.notifier).state = mode;
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: ThemeMode.light,
                                    child: Row(
                                      children: [
                                        Icon(Icons.light_mode_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Modo Claro'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: ThemeMode.dark,
                                    child: Row(
                                      children: [
                                        Icon(Icons.dark_mode_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Modo Oscuro'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: ThemeMode.system,
                                    child: Row(
                                      children: [
                                        Icon(Icons.settings_suggest_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Tema del Sistema'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Cuerpo del contenido (Con fondo de circuitos en modo oscuro)
                    Expanded(
                      child: CircuitBackgroundWidget(
                        isDark: isDark,
                        color: theme.colorScheme.primary,
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: isDetailScreen ? null : floatingActionButton,
        );
      },
    );
  }

  // Menú lateral desplegable para móvil
  Widget _buildDrawer(BuildContext context, WidgetRef ref, UserModel user, bool isAdmin, List<SidebarItem> items, ThemeData theme) {
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 24),
              ),
            ),
            accountName: Text(user.displayName ?? (isAdmin ? 'Administrador' : 'Cobrador'), style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text(user.email),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                return ListTile(
                  leading: Icon(item.icon, color: isSelected ? theme.colorScheme.primary : null),
                  title: Text(item.label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : null)),
                  selected: isSelected,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => item.screen),
                      );
                    }
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent)),
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Barra de navegación inferior móvil de cristal flotante
  Widget _buildMobileBottomBar(BuildContext context, List<SidebarItem> items, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    // Mapear los primeros 5 elementos para la barra inferior (Inicio, Clientes, Créditos, Calendario, Informes).
    final List<SidebarItem> barItems = items.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 65,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF242B3D).withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < barItems.length; i++) ...[
                  _buildBottomNavItem(
                    context: context,
                    icon: barItems[i].icon,
                    label: barItems[i].label,
                    isSelected: i == selectedIndex,
                    onTap: () {
                      if (i != selectedIndex) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => barItems[i].screen),
                        );
                      }
                    },
                    theme: theme,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.brightness == Brightness.dark
        ? const Color(0xFFA5A5B5)
        : Colors.black45;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SidebarItem> _getAdminItems() {
    return const [
      SidebarItem(
        icon: Icons.dashboard_customize_rounded,
        label: 'Inicio',
        screen: AdminDashboard(),
      ),
      SidebarItem(
        icon: Icons.people_alt_rounded,
        label: 'Clientes',
        screen: ClientListScreen(),
      ),
      SidebarItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Créditos',
        screen: CreditListScreen(),
      ),
      SidebarItem(
        icon: Icons.calendar_month_rounded,
        label: 'Calendario',
        screen: PaymentCalendarScreen(),
      ),
      SidebarItem(
        icon: Icons.account_balance,
        label: 'Tesorería',
        screen: TreasuryScreen(),
      ),
      SidebarItem(
        icon: Icons.bar_chart_rounded,
        label: 'Informes',
        screen: ReportsMainScreen(),
      ),
    ];
  }

  List<SidebarItem> _getCobradorItems() {
    return const [
      SidebarItem(
        icon: Icons.dashboard_customize_rounded,
        label: 'Inicio',
        screen: CobradorDashboard(),
      ),
      SidebarItem(
        icon: Icons.people_alt_rounded,
        label: 'Clientes',
        screen: ClientListScreen(),
      ),
      SidebarItem(
        icon: Icons.calendar_month_rounded,
        label: 'Calendario',
        screen: PaymentCalendarScreen(),
      ),
      SidebarItem(
        icon: Icons.bar_chart_rounded,
        label: 'Informes',
        screen: ReportsMainScreen(),
      ),
      SidebarItem(
        icon: Icons.today_rounded,
        label: 'Agenda',
        screen: AppointmentsAgendaScreen(),
      ),
      SidebarItem(
        icon: Icons.history_rounded,
        label: 'Historial',
        screen: PaymentsHistoryScreen(),
      ),
    ];
  }
}
