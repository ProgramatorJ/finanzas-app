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
import 'credit_form_screen.dart';
import 'credit_detail_screen.dart';
import '../../core/utils/commercial_calendar.dart';
import '../../main.dart'; // import sharedPreferences

/// Stream de todos los créditos del sistema (según rol)
final allCreditsStreamProvider = StreamProvider<List<CreditModel>>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final db = ref.read(firestoreServiceProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value(<CreditModel>[]);
      if (user.role == UserRole.admin) {
        return db.getAllCreditsStream();
      } else {
        // Cobrador: obtiene todos los créditos y filtra en memoria por sus clientes asignados
        return db.getAllCreditsStream().map((credits) {
          return credits.where((credit) => user.assignedClientIds.contains(credit.clientId)).toList();
        });
      }
    },
    loading: () => Stream.value(<CreditModel>[]),
    error: (err, stack) => Stream.value(<CreditModel>[]),
  );
});

/// Stream de clientes (para realizar la unión / join en memoria)
final creditsClientsStreamProvider = StreamProvider<List<ClientModel>>((ref) {
  final userAsync = ref.watch(currentUserModelProvider);
  final db = ref.read(firestoreServiceProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value(<ClientModel>[]);
      if (user.role == UserRole.admin) {
        return db.getAllClientsStream();
      } else {
        return db.getAssignedClientsStream(user.uid);
      }
    },
    loading: () => Stream.value(<ClientModel>[]),
    error: (err, stack) => Stream.value(<ClientModel>[]),
  );
});

class CreditListScreen extends ConsumerStatefulWidget {
  const CreditListScreen({super.key});

  @override
  ConsumerState<CreditListScreen> createState() => _CreditListScreenState();
}

enum CreditFilter {
  all,
  active,
  onTime,
  inMora,
  completed,
}

enum CreditSort {
  clientName,
  disbursementDate,
}

class _CreditListScreenState extends ConsumerState<CreditListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  CreditFilter _selectedFilter = CreditFilter.all;
  CreditSort _selectedSort = CreditSort.disbursementDate;

  @override
  void initState() {
    super.initState();
    final savedFilter = sharedPreferences.getString('credit_filter');
    if (savedFilter != null) {
      _selectedFilter = CreditFilter.values.firstWhere(
        (e) => e.name == savedFilter,
        orElse: () => CreditFilter.all,
      );
    }
    final savedSort = sharedPreferences.getString('credit_sort');
    if (savedSort != null) {
      _selectedSort = CreditSort.values.firstWhere(
        (e) => e.name == savedSort,
        orElse: () => CreditSort.disbursementDate,
      );
    }
  }

  String _filterLabel(CreditFilter filter) {
    switch (filter) {
      case CreditFilter.all:
        return 'Créditos General';
      case CreditFilter.active:
        return 'Créditos Activos';
      case CreditFilter.onTime:
        return 'Créditos Activos al Día';
      case CreditFilter.inMora:
        return 'Créditos en Mora';
      case CreditFilter.completed:
        return 'Finalizados';
    }
  }

  String _sortLabel(CreditSort sort) {
    switch (sort) {
      case CreditSort.clientName:
        return 'Alfabético';
      case CreditSort.disbursementDate:
        return 'Fecha Desembolso';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Muestra un modal de selección de cliente para crear un crédito
  void _showClientSelectionDialog(BuildContext context, List<ClientModel> clients) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;

            final filteredClients = clients.where((c) {
              return c.fullName.toLowerCase().contains(filter.toLowerCase()) ||
                     c.idNumber.toLowerCase().contains(filter.toLowerCase());
            }).toList();

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
                              color: secondaryColor,
                              borderRadius: const BorderRadius.all(Radius.circular(2)),
                            ),
                          ),
                        ),
                        Text(
                          'Seleccionar Cliente',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: const InputDecoration(
                            hintText: 'Buscar por nombre o documento...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              filter = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: filteredClients.isEmpty
                              ? Center(
                                  child: Text('No se encontraron clientes.',
                                      style: TextStyle(color: secondaryColor)),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  itemCount: filteredClients.length,
                                  itemBuilder: (context, index) {
                                    final client = filteredClients[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        title: Text(client.fullName,
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('DNI: ${client.idNumber}',
                                            style: TextStyle(color: secondaryColor, fontSize: 12)),
                                        onTap: () {
                                          Navigator.pop(context); // Cierra modal
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreditFormScreen(clientId: client.clientId),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;
    final isDark = theme.brightness == Brightness.dark;

    final userModelAsync = ref.watch(currentUserModelProvider);
    final creditsAsync = ref.watch(allCreditsStreamProvider);
    final clientsAsync = ref.watch(creditsClientsStreamProvider);
    final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final isAdmin = userModelAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin,
      orElse: () => false,
    );

    return ResponsiveSidebarScaffold(
      selectedIndex: 2,
      title: _filterLabel(_selectedFilter),
      child: Column(
        children: [
          // --- Barra de Búsqueda y Botón Nuevo Préstamo Premium ---
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
                              hintText: 'Buscar por cliente o ID de préstamo...',
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
                      PopupMenuButton<CreditFilter>(
                        tooltip: 'Filtrar créditos',
                        onSelected: (CreditFilter filter) {
                          setState(() {
                            _selectedFilter = filter;
                            sharedPreferences.setString('credit_filter', filter.name);
                          });
                        },
                        itemBuilder: (context) => CreditFilter.values.map((filter) {
                          return PopupMenuItem<CreditFilter>(
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
                      PopupMenuButton<CreditSort>(
                        tooltip: 'Ordenar créditos',
                        onSelected: (CreditSort sort) {
                          setState(() {
                            _selectedSort = sort;
                            sharedPreferences.setString('credit_sort', sort.name);
                          });
                        },
                        itemBuilder: (context) => CreditSort.values.map((sort) {
                          return PopupMenuItem<CreditSort>(
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
                      const Spacer(),
                      // Botón Nuevo Préstamo
                      if (isAdmin)
                        clientsAsync.maybeWhen(
                          data: (clientsList) => clientsList.isNotEmpty
                              ? Container(
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
                                    onPressed: () => _showClientSelectionDialog(context, clientsList),
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
                                        const Icon(Icons.add_card_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Nuevo Préstamo',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          orElse: () => const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- Listado General de Créditos ---
          Expanded(
            child: creditsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error al cargar créditos: $err', style: TextStyle(color: theme.colorScheme.error)),
              ),
              data: (credits) {
                return clientsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text('Error al cargar datos adicionales: $err',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                  data: (clients) {
                    // Mapeo en memoria
                    final List<Map<String, dynamic>> combined = credits.map((credit) {
                      final client = clients.firstWhere(
                        (c) => c.clientId == credit.clientId,
                        orElse: () => ClientModel(
                          clientId: credit.clientId,
                          fullName: 'Cliente Desconocido',
                          idNumber: 'N/A',
                          phone: '',
                          address: '',
                          assignedCollectorIds: [],
                          createdByUid: '',
                          isActive: true,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );
                      return {
                        'credit': credit,
                        'client': client,
                      };
                    }).toList();

                    // Filtrado de la búsqueda y dropdown
                    final filtered = combined.where((item) {
                      final client = item['client'] as ClientModel;
                      final credit = item['credit'] as CreditModel;
                      
                      // 1. Búsqueda por texto
                      final matchesSearch = client.fullName.toLowerCase().contains(_searchQuery) ||
                             client.idNumber.toLowerCase().contains(_searchQuery) ||
                             credit.creditId.toLowerCase().contains(_searchQuery);
                      if (!matchesSearch) return false;

                      // 2. Filtro por dropdown
                      switch (_selectedFilter) {
                        case CreditFilter.all:
                          return true;
                        case CreditFilter.active:
                          return credit.status != CreditStatus.completed;
                        case CreditFilter.onTime:
                          return credit.status == CreditStatus.active || credit.status == CreditStatus.restructured;
                        case CreditFilter.inMora:
                          return credit.status == CreditStatus.defaulted;
                        case CreditFilter.completed:
                          return credit.status == CreditStatus.completed;
                      }
                    }).toList();

                    // Sort logic
                    filtered.sort((a, b) {
                      final clientA = a['client'] as ClientModel;
                      final clientB = b['client'] as ClientModel;
                      final creditA = a['credit'] as CreditModel;
                      final creditB = b['credit'] as CreditModel;
                      
                      if (_selectedSort == CreditSort.clientName) {
                        return clientA.fullName.toLowerCase().compareTo(clientB.fullName.toLowerCase());
                      } else {
                        return creditB.disbursementDate.compareTo(creditA.disbursementDate); // Descending (newest first)
                      }
                    });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isEmpty ? Icons.account_balance_wallet_outlined : Icons.search_off_rounded,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No hay créditos registrados.' : 'No se encontraron resultados.',
                              style: const TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    if (isWide) {
                      return GridView.builder(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 90),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: size.width > 1200 ? 3 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 3.1,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final credit = item['credit'] as CreditModel;
                          final client = item['client'] as ClientModel;
                          final statusColorVal = _statusColor(credit.status);

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColorVal.withValues(alpha: 0.06),
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
                                  color: statusColorVal.withValues(alpha: 0.4),
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
                                      builder: (_) => CreditDetailScreen(
                                        creditId: credit.creditId,
                                        clientId: credit.clientId,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: statusColorVal.withValues(alpha: 0.3), width: 1.5),
                                        ),
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundColor: statusColorVal.withValues(alpha: 0.1),
                                          child: Icon(Icons.monetization_on_rounded, color: statusColorVal, size: 20),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Ref: ${credit.creditId}',
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              client.fullName,
                                              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 14, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Desembolso: ${DateFormat('dd/MM/yyyy').format(credit.disbursementDate)} | Finaliza: ${DateFormat('dd/MM/yyyy').format(_calculateEndDate(credit.firstInstallmentDate, credit.numberOfInstallments, credit.paymentFrequency))}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            copFormatter.format(credit.principalAmount),
                                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: statusColorVal),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cuotas: ${credit.paidInstallments}/${credit.numberOfInstallments}',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final credit = item['credit'] as CreditModel;
                        final client = item['client'] as ClientModel;
                        final statusColorVal = _statusColor(credit.status);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColorVal.withValues(alpha: 0.06),
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
                                  color: statusColorVal.withValues(alpha: 0.4),
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
                                        clientId: credit.clientId,
                                      ),
                                    ),
                                  );
                                },
                                leading: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: statusColorVal.withValues(alpha: 0.5), width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    backgroundColor: statusColorVal.withValues(alpha: 0.22),
                                    child: Icon(Icons.monetization_on_rounded, color: statusColorVal, size: 20),
                                  ),
                                ),
                                title: Text(
                                  'Ref: ${credit.creditId}',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client.fullName,
                                        style: TextStyle(
                                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Desembolso: ${DateFormat('dd/MM/yyyy').format(credit.disbursementDate)} | Finaliza: ${DateFormat('dd/MM/yyyy').format(_calculateEndDate(credit.firstInstallmentDate, credit.numberOfInstallments, credit.paymentFrequency))}\nCuotas: ${credit.paidInstallments}/${credit.numberOfInstallments}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Valor: ${copFormatter.format(credit.principalAmount)}',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: statusColorVal),
                                      ),
                                    ],
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditStatusBadge(CreditStatus status, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final color = _statusColor(status);
    final text = _translateStatus(status);

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
        return 'ACTIVO';
      case CreditStatus.completed:
        return 'PAGADO';
      case CreditStatus.defaulted:
        return 'EN MORA';
      case CreditStatus.restructured:
        return 'REESTRUCTURADO';
    }
  }

  DateTime _calculateEndDate(DateTime firstInstallment, int installments, PaymentFrequency freq) {
    final dates = CommercialCalendar.generateInstallmentDates(
      firstInstallmentDate: firstInstallment,
      numberOfInstallments: installments,
      frequency: freq.name,
    );
    return dates.isNotEmpty ? dates.last : firstInstallment;
  }
}
