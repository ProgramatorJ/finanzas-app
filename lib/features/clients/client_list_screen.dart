import 'package:finanzas_app/core/enums/user_role.dart';
import 'package:finanzas_app/core/enums/credit_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/client_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/rbac_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import 'client_form_screen.dart';
import 'client_detail_screen.dart';
import '../credits/credit_list_screen.dart';
import '../../core/models/credit_model.dart';
import '../../main.dart'; // import sharedPreferences

/// Proveedores de streams de clientes según rol
final clientsListStreamProvider = StreamProvider<List<ClientModel>>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final db = ref.read(firestoreServiceProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      if (user.role == UserRole.admin) {
        return db.getAllClientsStream();
      } else {
        return db.getAssignedClientsStream(user.uid);
      }
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

enum ClientFilter {
  all,
  active,
  onTime,
  inMora,
  inactive,
}

enum ClientSort {
  alphabetical,
  creationDate,
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ClientFilter _selectedFilter = ClientFilter.all;
  ClientSort _selectedSort = ClientSort.alphabetical;

  @override
  void initState() {
    super.initState();
    final savedFilter = sharedPreferences.getString('client_filter');
    if (savedFilter != null) {
      _selectedFilter = ClientFilter.values.firstWhere(
        (e) => e.name == savedFilter,
        orElse: () => ClientFilter.all,
      );
    }
    final savedSort = sharedPreferences.getString('client_sort');
    if (savedSort != null) {
      _selectedSort = ClientSort.values.firstWhere(
        (e) => e.name == savedSort,
        orElse: () => ClientSort.alphabetical,
      );
    }
  }

  Color _clientColor(ClientModel client, List<CreditModel> allCredits) {
    final clientCredits = allCredits.where((c) => c.clientId == client.clientId).toList();
    final hasActiveCredit = clientCredits.any((c) => c.status != CreditStatus.completed);
    
    if (!hasActiveCredit) {
      return Colors.grey.shade400; // Inactivo
    }
    final hasMora = clientCredits.any((c) => c.status == CreditStatus.defaulted);
    if (hasMora) {
      return AppTheme.errorColor; // En mora
    }
    return AppTheme.primaryColor; // Al día
  }

  String _filterLabel(ClientFilter filter) {
    switch (filter) {
      case ClientFilter.all:
        return 'General';
      case ClientFilter.active:
        return 'Activos';
      case ClientFilter.onTime:
        return 'Al día';
      case ClientFilter.inMora:
        return 'En mora';
      case ClientFilter.inactive:
        return 'Inactivos';
    }
  }

  String _sortLabel(ClientSort sort) {
    switch (sort) {
      case ClientSort.alphabetical:
        return 'Alfabético';
      case ClientSort.creationDate:
        return 'Fecha de Creación';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userModelAsync = ref.watch(currentUserModelProvider);
    final clientsAsync = ref.watch(clientsListStreamProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final isDark = theme.brightness == Brightness.dark;

    final isAdmin = userModelAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin,
      orElse: () => false,
    );

    return ResponsiveSidebarScaffold(
      selectedIndex: 1,
      title: _filterLabel(_selectedFilter),
      child: Column(
        children: [
          // --- Barra de Búsqueda y Filtros Premium ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.outfit(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Buscar por nombre o documento...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF121A30) : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge filtro (Menú Desplegable)
                      Row(
                        children: [
                          PopupMenuButton<ClientFilter>(
                            tooltip: 'Filtrar clientes',
                            onSelected: (ClientFilter filter) {
                              setState(() {
                                _selectedFilter = filter;
                                sharedPreferences.setString('client_filter', filter.name);
                              });
                            },
                            itemBuilder: (context) => ClientFilter.values.map((filter) {
                              return PopupMenuItem<ClientFilter>(
                                value: filter,
                                child: Text(
                                  _filterLabel(filter),
                                  style: GoogleFonts.outfit(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.filter_list_rounded, size: 14),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge Ordenamiento
                          PopupMenuButton<ClientSort>(
                            tooltip: 'Ordenar clientes',
                            onSelected: (ClientSort sort) {
                              setState(() {
                                _selectedSort = sort;
                                sharedPreferences.setString('client_sort', sort.name);
                              });
                            },
                            itemBuilder: (context) => ClientSort.values.map((sort) {
                              return PopupMenuItem<ClientSort>(
                                value: sort,
                                child: Text(
                                  _sortLabel(sort),
                                  style: GoogleFonts.outfit(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                    _sortLabel(_selectedSort),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.sort_rounded, size: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Botón Nuevo Cliente
                      if (isAdmin)
                        Container(
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A84E6), Color(0xFF2B5292)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A84E6).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ClientFormScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'Nuevo Cliente',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- Lista/Grilla de Clientes ---
          Expanded(
            child: clientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error al cargar clientes: $err',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
              data: (clients) {
                final creditsAsync = ref.watch(allCreditsStreamProvider);
                final List<CreditModel> allCredits = creditsAsync.maybeWhen(
                  data: (list) => list,
                  orElse: () => <CreditModel>[],
                );

                final filteredClients = clients.where((client) {
                  // 1. Filtro por búsqueda
                  final name = client.fullName.toLowerCase();
                  final idNum = client.idNumber.toLowerCase();
                  final matchesSearch = name.contains(_searchQuery) || idNum.contains(_searchQuery);
                  if (!matchesSearch) return false;

                  // 2. Filtro por estado desplegable
                  switch (_selectedFilter) {
                    case ClientFilter.all:
                      return true;
                    case ClientFilter.active:
                      return allCredits.any((c) => c.clientId == client.clientId && c.status != CreditStatus.completed);
                    case ClientFilter.inactive:
                      return !allCredits.any((c) => c.clientId == client.clientId && c.status != CreditStatus.completed);
                    case ClientFilter.onTime:
                      final clientCredits = allCredits.where((c) => c.clientId == client.clientId).toList();
                      if (clientCredits.isEmpty) return false;
                      final activeCredits = clientCredits.where((c) => c.status != CreditStatus.completed).toList();
                      if (activeCredits.isEmpty) return false;
                      return activeCredits.every((c) => c.status == CreditStatus.active || c.status == CreditStatus.restructured);
                    case ClientFilter.inMora:
                      return allCredits.any((c) => c.clientId == client.clientId && c.status == CreditStatus.defaulted);
                  }
                }).toList();

                // Sort logic
                filteredClients.sort((a, b) {
                  if (_selectedSort == ClientSort.alphabetical) {
                    return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
                  } else {
                    return b.createdAt.compareTo(a.createdAt); // Descending order (newest first)
                  }
                });

                if (filteredClients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.people_outline_rounded
                              : Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No hay clientes registrados.'
                              : 'No se encontraron resultados.',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Si es pantalla ancha, mostramos en Grid para mejor aspecto web
                if (isWide) {
                  return GridView.builder(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 90),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size.width > 1200 ? 3 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 3.2,
                    ),
                    itemCount: filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = filteredClients[index];
                      final clientColor = _clientColor(client, allCredits);

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: clientColor.withValues(alpha: 0.06),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: clientColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          elevation: 0,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClientDetailScreen(clientId: client.clientId),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar con borde del color de estado
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: clientColor.withValues(alpha: 0.5), width: 1.5),
                                    ),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: clientColor.withValues(alpha: 0.22),
                                      child: Text(
                                        client.fullName.substring(0, 1).toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          color: clientColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          client.fullName,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'DNI: ${client.idNumber}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }

                // Disposición para pantallas móviles
                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
                  itemCount: filteredClients.length,
                  itemBuilder: (context, index) {
                    final client = filteredClients[index];
                    final clientColor = _clientColor(client, allCredits);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: clientColor.withValues(alpha: 0.06),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: clientColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          elevation: 0,
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClientDetailScreen(clientId: client.clientId),
                                ),
                              );
                            },
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: clientColor.withValues(alpha: 0.5), width: 1.5),
                              ),
                              child: CircleAvatar(
                                backgroundColor: clientColor.withValues(alpha: 0.22),
                                child: Text(
                                  client.fullName.substring(0, 1).toUpperCase(),
                                  style: GoogleFonts.outfit(color: clientColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            title: Text(
                              client.fullName,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'DNI: ${client.idNumber}',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final color = isActive ? const Color(0xFF10B981) : Colors.grey;
    final text = isActive ? 'ACTIVO' : 'INACTIVO';

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
}
