import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/models/payment_model.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../../core/models/user_model.dart';
import '../../core/models/installment_model.dart';
import '../../core/services/rbac_service.dart';

import '../calendar/calendar_providers.dart';

enum ReportPeriod {
  daily,
  weekly,
  monthly,
  quarterly,
  biannual,
  yearly,
  custom,
}

class _PeriodData {
  double expectedValue = 0;
  double paidValue = 0;

  double expectedInterestMora = 0;
  double paidInterestMora = 0;
}

class UpcomingPaymentsReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const UpcomingPaymentsReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<UpcomingPaymentsReportScreen> createState() => _UpcomingPaymentsReportScreenState();
}

class ReportEntry {
  final JoinedInstallment joinedInstallment;
  final PaymentModel? payment;
  final DateTime date;
  final double cobrado;
  final double capitalPaid;
  final double interestPaid;
  final double moraPaid;
  final String statusLabel;
  final Color statusColor;

  ReportEntry({
    required this.joinedInstallment,
    this.payment,
    required this.date,
    required this.cobrado,
    required this.capitalPaid,
    required this.interestPaid,
    required this.moraPaid,
    required this.statusLabel,
    required this.statusColor,
  });
}

class _UpcomingPaymentsReportScreenState extends ConsumerState<UpcomingPaymentsReportScreen> {
  final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  ReportPeriod _selectedPeriod = ReportPeriod.monthly;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  int _chartPeriodsToDisplay = 6;
  final TextEditingController _maxYController = TextEditingController();
  double? _customMaxY;

  @override
  void dispose() {
    _maxYController.dispose();
    super.dispose();
  }

  bool _isDateInRange(DateTime date) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final dateMidnight = DateTime(date.year, date.month, date.day);

    switch (_selectedPeriod) {
      case ReportPeriod.daily:
        return dateMidnight.isAtSameMomentAs(todayMidnight);
      case ReportPeriod.weekly:
        final startOfWeek = todayMidnight.subtract(Duration(days: todayMidnight.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return dateMidnight.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
               dateMidnight.isBefore(endOfWeek.add(const Duration(days: 1)));
      case ReportPeriod.monthly:
        return dateMidnight.year == todayMidnight.year && dateMidnight.month == todayMidnight.month;
      case ReportPeriod.quarterly:
        int currentQ = ((todayMidnight.month - 1) ~/ 3) + 1;
        int dateQ = ((dateMidnight.month - 1) ~/ 3) + 1;
        return dateMidnight.year == todayMidnight.year && dateQ == currentQ;
      case ReportPeriod.biannual:
        int currentS = ((todayMidnight.month - 1) ~/ 6) + 1;
        int dateS = ((dateMidnight.month - 1) ~/ 6) + 1;
        return dateMidnight.year == todayMidnight.year && dateS == currentS;
      case ReportPeriod.yearly:
        return dateMidnight.year == todayMidnight.year;
      case ReportPeriod.custom:
        if (_customStartDate == null || _customEndDate == null) return true;
        final startMidnight = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
        final endMidnight = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day);
        return dateMidnight.isAfter(startMidnight.subtract(const Duration(days: 1))) &&
               dateMidnight.isBefore(endMidnight.add(const Duration(days: 1)));
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
    } else {
      if (_customStartDate == null) {
        setState(() {
          _selectedPeriod = ReportPeriod.monthly;
        });
      }
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  ReportPeriod _getEffectiveResolution() {
    if (_selectedPeriod != ReportPeriod.custom) return _selectedPeriod;
    if (_customStartDate == null || _customEndDate == null) return ReportPeriod.monthly;
    final diff = _customEndDate!.difference(_customStartDate!).inDays;
    if (diff <= 14) return ReportPeriod.daily;
    if (diff <= 60) return ReportPeriod.weekly;
    return ReportPeriod.monthly;
  }

  DateTime _getPeriodStart(DateTime date, ReportPeriod resolution) {
    switch (resolution) {
      case ReportPeriod.daily:
        return DateTime(date.year, date.month, date.day);
      case ReportPeriod.weekly:
        return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
      case ReportPeriod.monthly:
        return DateTime(date.year, date.month, 1);
      case ReportPeriod.quarterly:
        int qMonth = ((date.month - 1) ~/ 3) * 3 + 1;
        return DateTime(date.year, qMonth, 1);
      case ReportPeriod.biannual:
        int hMonth = ((date.month - 1) ~/ 6) * 6 + 1;
        return DateTime(date.year, hMonth, 1);
      case ReportPeriod.yearly:
        return DateTime(date.year, 1, 1);
      case ReportPeriod.custom:
        return date;
    }
  }

  DateTime _getPrevPeriod(DateTime current, ReportPeriod resolution) {
    switch (resolution) {
      case ReportPeriod.daily:
        return current.subtract(const Duration(days: 1));
      case ReportPeriod.weekly:
        return current.subtract(const Duration(days: 7));
      case ReportPeriod.monthly:
        return DateTime(current.year, current.month - 1, 1);
      case ReportPeriod.quarterly:
        return DateTime(current.year, current.month - 3, 1);
      case ReportPeriod.biannual:
        return DateTime(current.year, current.month - 6, 1);
      case ReportPeriod.yearly:
        return DateTime(current.year - 1, 1, 1);
      case ReportPeriod.custom:
        return current;
    }
  }

  String _formatPeriodLabel(DateTime date, ReportPeriod resolution) {
    switch (resolution) {
      case ReportPeriod.daily:
        return DateFormat('dd MMM').format(date);
      case ReportPeriod.weekly:
        final end = date.add(const Duration(days: 6));
        return '${date.day}-${end.day} ${DateFormat('MMM').format(date)}';
      case ReportPeriod.monthly:
        return DateFormat('MMM yy').format(date);
      case ReportPeriod.quarterly:
        int quarter = ((date.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${date.year.toString().substring(2)}';
      case ReportPeriod.biannual:
        int half = ((date.month - 1) ~/ 6) + 1;
        return 'S$half ${date.year.toString().substring(2)}';
      case ReportPeriod.yearly:
        return '${date.year}';
      case ReportPeriod.custom:
        return '';
    }
  }

  String _getResolutionLabel() {
    switch (_getEffectiveResolution()) {
      case ReportPeriod.daily: return 'Días';
      case ReportPeriod.weekly: return 'Semanas';
      case ReportPeriod.monthly: return 'Meses';
      case ReportPeriod.quarterly: return 'Trimestres';
      case ReportPeriod.biannual: return 'Semestres';
      case ReportPeriod.yearly: return 'Años';
      case ReportPeriod.custom: return 'Periodos';
    }
  }

  @override
  Widget build(BuildContext context) {
    final joinedAsync = ref.watch(joinedInstallmentsProvider);
    final paymentsAsync = ref.watch(allPaymentsProvider);
    final userAsync = ref.watch(currentUserModelProvider);
    final selectedIndex = userAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin ? 4 : 3,
      orElse: () => 3,
    );

    if (joinedAsync.isLoading || paymentsAsync.isLoading) {
      if (widget.isEmbedded) {
        return const Center(child: CircularProgressIndicator());
      }
      return ResponsiveSidebarScaffold(
        selectedIndex: selectedIndex,
        title: 'Informe de Pagos',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final allJoined = joinedAsync.value ?? [];
    final allPayments = paymentsAsync.value ?? [];

    final List<ReportEntry> reportEntries = [];

    for (final j in allJoined) {
      final inst = j.installment;
      
      final instPayments = allPayments.where((p) => p.affectedInstallmentNumbers.contains(inst.installmentNumber) && p.creditId == j.credit.creditId).toList();
      
      double totalCapitalPaidSoFar = 0.0;
      double totalInterestPaidSoFar = 0.0;
      double totalMoraPaidSoFar = 0.0;

      for (final p in instPayments) {
        final breakdown = p.installmentBreakdowns['${inst.installmentNumber}'];
        if (breakdown == null) continue;
        
        final double capital = breakdown['capital'] ?? 0.0;
        final double interes = breakdown['interes'] ?? 0.0;
        final double mora = breakdown['mora'] ?? 0.0;
        final double cobrado = capital + interes + mora;
        
        totalCapitalPaidSoFar += capital;
        totalInterestPaidSoFar += interes;
        totalMoraPaidSoFar += mora;

        if (cobrado > 0) {
          String estado = 'PARCIAL';
          Color col = const Color(0xFFFFA500); // Naranja
          
          if (inst.status == InstallmentStatus.paid && p == instPayments.last) {
             estado = 'PAGADO';
             col = Colors.blue; // Azul
          }

          reportEntries.add(ReportEntry(
            joinedInstallment: j,
            payment: p,
            date: p.paymentDate,
            cobrado: cobrado,
            capitalPaid: capital,
            interestPaid: interes,
            moraPaid: mora,
            statusLabel: estado,
            statusColor: col,
          ));
        }
      }

      if (inst.status != InstallmentStatus.paid) {
        final double remainingCapital = inst.scheduledAmount > 0 ? inst.remainingAmount * (inst.principalPortion / inst.scheduledAmount) : inst.remainingAmount;
        final double remainingInterest = inst.scheduledAmount > 0 ? inst.remainingAmount * (inst.interestPortion / inst.scheduledAmount) : 0.0;
        
        reportEntries.add(ReportEntry(
          joinedInstallment: j,
          payment: null,
          date: inst.dueDate,
          cobrado: 0.0,
          capitalPaid: remainingCapital,
          interestPaid: remainingInterest,
          moraPaid: inst.accumulatedMora - totalMoraPaidSoFar,
          statusLabel: 'PENDIENTE',
          statusColor: Colors.red,
        ));
      }
    }

    final filtered = reportEntries.where((entry) => _isDateInRange(entry.date)).toList();

    filtered.sort((a, b) {
      int compare;
      switch (_sortColumnIndex) {
        case 0:
          compare = a.joinedInstallment.installment.dueDate.compareTo(b.joinedInstallment.installment.dueDate);
          break;
        case 1:
          compare = a.date.compareTo(b.date);
          break;
        case 2:
          compare = a.joinedInstallment.credit.creditId.compareTo(b.joinedInstallment.credit.creditId);
          break;
        case 3:
          compare = a.joinedInstallment.client.fullName.compareTo(b.joinedInstallment.client.fullName);
          break;
        case 4:
          compare = a.cobrado.compareTo(b.cobrado);
          break;
        case 5:
          compare = a.capitalPaid.compareTo(b.capitalPaid);
          break;
        case 6:
          compare = a.interestPaid.compareTo(b.interestPaid);
          break;
        case 7:
          compare = a.moraPaid.compareTo(b.moraPaid);
          break;
        case 8:
          compare = a.joinedInstallment.installment.installmentNumber.compareTo(b.joinedInstallment.installment.installmentNumber);
          break;
        case 9:
          compare = a.statusLabel.compareTo(b.statusLabel);
          break;
        default:
          compare = 0;
      }
      return _sortAscending ? compare : -compare;
    });

    double totalPaidCapital = 0;
    double totalPaidInterest = 0;
    double totalPaidMora = 0;
    
    double totalPendingCapital = 0;
    double totalPendingInterest = 0;
    double totalPendingMora = 0;

    int countPaid = 0;
    int countPending = 0;

    for (final item in filtered) {
      if (item.statusLabel == 'PENDIENTE') {
        totalPendingCapital += item.capitalPaid;
        totalPendingInterest += item.interestPaid;
        totalPendingMora += item.moraPaid;
        countPending++;
      } else {
        totalPaidCapital += item.capitalPaid;
        totalPaidInterest += item.interestPaid;
        totalPaidMora += item.moraPaid;
        countPaid++;
      }
    }

    final totalPaid = totalPaidCapital + totalPaidInterest + totalPaidMora;
    final totalPending = totalPendingCapital + totalPendingInterest + totalPendingMora;
    final grandTotal = totalPaid + totalPending;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF0A0A14) : Colors.white,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Periodo en Tabla:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<ReportPeriod>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  items: const [
                    DropdownMenuItem(value: ReportPeriod.daily, child: Text('Hoy')),
                    DropdownMenuItem(value: ReportPeriod.weekly, child: Text('Esta Semana')),
                    DropdownMenuItem(value: ReportPeriod.monthly, child: Text('Este Mes')),
                    DropdownMenuItem(value: ReportPeriod.quarterly, child: Text('Este Trimestre')),
                    DropdownMenuItem(value: ReportPeriod.biannual, child: Text('Este Semestre')),
                    DropdownMenuItem(value: ReportPeriod.yearly, child: Text('Este Año')),
                    DropdownMenuItem(value: ReportPeriod.custom, child: Text('Personalizado')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPeriod = val);
                      if (val == ReportPeriod.custom) {
                        _selectCustomDateRange();
                      }
                    }
                  },
                ),
                if (_selectedPeriod == ReportPeriod.custom && _customStartDate != null)
                  Text(
                    '(${DateFormat('dd/MM/yy').format(_customStartDate!)} - ${DateFormat('dd/MM/yy').format(_customEndDate!)})',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceEvenly,
                    children: [
                      _buildTotalCard('Abonos Recibidos', totalPaid, totalPaidMora, countPaid, AppTheme.primaryColor, isDark),
                      _buildTotalCard('Saldos Pendientes', totalPending, totalPendingMora, countPending, Colors.red, isDark),
                      _buildTotalCard('Total General', grandTotal, totalPaidMora + totalPendingMora, countPaid + countPending, AppTheme.secondaryColor, isDark),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Nuevo Gráfico Histórico Dinámico Contiguo
                  _buildHistoricalChartSection(allJoined, isDark, theme),
                    
                  const SizedBox(height: 24),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        headingRowColor: WidgetStateProperty.all(AppTheme.primaryColor),
                        columns: [
                          DataColumn(label: const Text('FECHA AGENDADA'), onSort: _onSort),
                          DataColumn(label: const Text('FECHA PAGO'), onSort: _onSort),
                          DataColumn(label: const Text('ID CREDITO'), onSort: _onSort),
                          DataColumn(label: const Text('CLIENTE'), onSort: _onSort),
                          DataColumn(label: const Text('VALOR PAGADO', textAlign: TextAlign.right), onSort: _onSort),
                          DataColumn(label: const Text('SALDO', textAlign: TextAlign.right), onSort: _onSort),
                          DataColumn(label: const Text('INTERES', textAlign: TextAlign.right), onSort: _onSort),
                          DataColumn(label: const Text('MORA', textAlign: TextAlign.right), onSort: _onSort),
                          DataColumn(label: const Text('N. CUOTA'), onSort: _onSort),
                          DataColumn(label: const Text('ESTADO'), onSort: _onSort),
                        ],
                        rows: filtered.map((entry) {
                          final inst = entry.joinedInstallment.installment;
                          final j = entry.joinedInstallment;
                          
                          return DataRow(cells: [
                            DataCell(Text(DateFormat('dd/MM/yyyy').format(inst.dueDate))),
                            DataCell(Text(entry.statusLabel != 'PENDIENTE' ? DateFormat('dd/MM/yyyy').format(entry.date) : '-')),
                            DataCell(Text(j.credit.creditId.substring(0, 8))),
                            DataCell(Text(j.client.fullName)),
                            DataCell(Text(copFormatter.format(entry.cobrado))),
                            DataCell(Text(copFormatter.format(entry.capitalPaid))),
                            DataCell(Text(copFormatter.format(entry.interestPaid))),
                            DataCell(Text(copFormatter.format(entry.moraPaid))),
                            DataCell(Text('${inst.installmentNumber}')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: entry.statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  entry.statusLabel,
                                  style: TextStyle(
                                    color: entry.statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

    if (widget.isEmbedded) {
      return content;
    }

    return ResponsiveSidebarScaffold(
      selectedIndex: selectedIndex,
      title: 'Módulo de Informes',
      child: content,
    );
  }

  Widget _buildTotalCard(String title, double amount, double moraAmount, int count, Color color, bool isDark) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(copFormatter.format(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$count cuotas', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text('Mora: ${copFormatter.format(moraAmount)}', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHistoricalChartSection(List<JoinedInstallment> allJoined, bool isDark, ThemeData theme) {
    final resolution = _getEffectiveResolution();
    final today = DateTime.now();

    // Generar rango de llaves temporales contiguas (desde atrás hasta el actual en último lugar)
    List<DateTime> contiguousPeriods = [];
    DateTime iter = _getPeriodStart(today, resolution);
    
    for (int i = 0; i < _chartPeriodsToDisplay; i++) {
      contiguousPeriods.add(iter);
      iter = _getPrevPeriod(iter, resolution);
    }
    // Revertir para que la fecha más antigua esté primero, y la fecha actual esté al final.
    contiguousPeriods = contiguousPeriods.reversed.toList();

    // Inicializar los datos en cero para cada periodo contiguo
    final Map<DateTime, _PeriodData> dataByPeriod = {};
    for (final p in contiguousPeriods) {
      dataByPeriod[p] = _PeriodData();
    }
    
    // Clasificar las cuotas en los periodos correspondientes
    for (final j in allJoined) {
      final inst = j.installment;
      final date = (inst.status == InstallmentStatus.paid || inst.paidAmount > 0) ? inst.updatedAt : inst.dueDate;
      final periodStart = _getPeriodStart(date, resolution);
      
      // Si el periodo cae dentro de los que estamos mostrando en la gráfica, sumar
      if (dataByPeriod.containsKey(periodStart)) {
        final md = dataByPeriod[periodStart]!;

        // VALOR: Capital + Interés
        final expectedValor = inst.principalPortion + inst.interestPortion;
        md.expectedValue += expectedValor;

        final double intRatio = inst.scheduledAmount > 0 ? inst.interestPortion / inst.scheduledAmount : 0.0;
        final double capRatio = inst.scheduledAmount > 0 ? inst.principalPortion / inst.scheduledAmount : 0.0;
        double pInterest = inst.paidAmount * intRatio;
        double pCapital = inst.paidAmount * capRatio;
        final paidValor = pCapital + pInterest;
        md.paidValue += paidValor;

        // INTERÉS + RECARGOS
        final expectedInterestMora = inst.interestPortion + inst.accumulatedMora;
        md.expectedInterestMora += expectedInterestMora;

        final paidInterestMora = pInterest + inst.moraPaid;
        md.paidInterestMora += paidInterestMora;
      }
    }

    double calcMaxY = 100;
    for (final p in contiguousPeriods) {
      final md = dataByPeriod[p]!;
      calcMaxY = max(calcMaxY, md.expectedValue);
      calcMaxY = max(calcMaxY, md.expectedInterestMora);
    }
    
    final maxY = _customMaxY ?? (calcMaxY * 1.1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Histórico de Recaudos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Límite de Periodos (Contador +/-)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_getResolutionLabel()}:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_chartPeriodsToDisplay > 2) {
                            setState(() => _chartPeriodsToDisplay--);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text('$_chartPeriodsToDisplay', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (_chartPeriodsToDisplay < 60) {
                            setState(() => _chartPeriodsToDisplay++);
                          }
                        },
                      ),
                    ],
                  ),
                  // Límite Y Editable
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Max Y:', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _maxYController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                            hintText: 'Auto',
                          ),
                          onSubmitted: (val) {
                            setState(() {
                              _customMaxY = double.tryParse(val);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(AppTheme.primaryColor, 'Valor Pagado'),
              const SizedBox(width: 16),
              _buildLegendItem(isDark ? Colors.white24 : Colors.black12, 'Valor Meta', isOutline: true),
              const SizedBox(width: 24),
              _buildLegendItem(AppTheme.errorColor, 'Int+Mora Pagado'),
              const SizedBox(width: 16),
              _buildLegendItem(isDark ? Colors.white24 : Colors.black12, 'Int+Mora Meta', isOutline: true),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: contiguousPeriods.isEmpty
              ? Center(child: Text('No hay datos históricos', style: TextStyle(color: theme.disabledColor)))
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY == 0 ? 100 : maxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final isValor = rodIndex == 0;
                          final label = isValor ? 'VALOR' : 'INT+MORA';
                          final meta = rod.backDrawRodData.toY;
                          return BarTooltipItem(
                            '${_formatPeriodLabel(contiguousPeriods[groupIndex], resolution)}\n$label\nPagado: ${copFormatter.format(rod.toY)}\nMeta: ${copFormatter.format(meta)}',
                            TextStyle(color: isValor ? AppTheme.primaryColor : AppTheme.errorColor, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value < 0 || value >= contiguousPeriods.length) return const SizedBox.shrink();
                            final date = contiguousPeriods[value.toInt()];
                            final label = _formatPeriodLabel(date, resolution);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            return Text(NumberFormat.compactCurrency(symbol: '\$').format(value), style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: isDark ? Colors.white10 : Colors.black12,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(contiguousPeriods.length, (i) {
                      final md = dataByPeriod[contiguousPeriods[i]]!;
                      return BarChartGroupData(
                        x: i,
                        barsSpace: 12,
                        barRods: [
                          BarChartRodData(
                            toY: md.paidValue,
                            color: AppTheme.primaryColor,
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: max(md.expectedValue, md.paidValue),
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            ),
                          ),
                          BarChartRodData(
                            toY: md.paidInterestMora,
                            color: AppTheme.errorColor,
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: max(md.expectedInterestMora, md.paidInterestMora),
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text, {bool isOutline = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isOutline ? Colors.transparent : color,
            border: isOutline ? Border.all(color: color, width: 2) : null,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
