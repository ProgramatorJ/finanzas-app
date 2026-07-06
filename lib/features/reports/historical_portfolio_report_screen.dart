import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/theme/app_theme.dart';

import '../../core/models/credit_model.dart';
import '../../core/models/installment_model.dart';
import '../calendar/calendar_providers.dart'; // Para joinedInstallmentsProvider
import '../credits/credit_list_screen.dart'; // Para allCreditsStreamProvider, creditsClientsStreamProvider

enum HistoricalPeriod {
  daily,
  weekly,
  monthly,
  quarterly,
  biannual,
  yearly,
}

class _HistoricalPeriodData {
  double capitalSaldo = 0;
  double interesMoraSaldo = 0;
  double totalSaldo = 0;
}

class HistoricalPortfolioReportScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const HistoricalPortfolioReportScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<HistoricalPortfolioReportScreen> createState() => _HistoricalPortfolioReportScreenState();
}

class _HistoricalPortfolioReportScreenState extends ConsumerState<HistoricalPortfolioReportScreen> {
  final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  HistoricalPeriod _selectedPeriod = HistoricalPeriod.monthly;
  int _chartPeriodsToDisplay = 6;

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  DateTime _getPeriodStart(DateTime date, HistoricalPeriod resolution) {
    switch (resolution) {
      case HistoricalPeriod.daily:
        return DateTime(date.year, date.month, date.day);
      case HistoricalPeriod.weekly:
        return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
      case HistoricalPeriod.monthly:
        return DateTime(date.year, date.month, 1);
      case HistoricalPeriod.quarterly:
        int qMonth = ((date.month - 1) ~/ 3) * 3 + 1;
        return DateTime(date.year, qMonth, 1);
      case HistoricalPeriod.biannual:
        int hMonth = ((date.month - 1) ~/ 6) * 6 + 1;
        return DateTime(date.year, hMonth, 1);
      case HistoricalPeriod.yearly:
        return DateTime(date.year, 1, 1);
    }
  }

  DateTime _getPeriodEnd(DateTime start, HistoricalPeriod resolution) {
    switch (resolution) {
      case HistoricalPeriod.daily:
        return start.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.weekly:
        return start.add(const Duration(days: 7)).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.monthly:
        return DateTime(start.year, start.month + 1, 1).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.quarterly:
        return DateTime(start.year, start.month + 3, 1).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.biannual:
        return DateTime(start.year, start.month + 6, 1).subtract(const Duration(microseconds: 1));
      case HistoricalPeriod.yearly:
        return DateTime(start.year + 1, 1, 1).subtract(const Duration(microseconds: 1));
    }
  }

  DateTime _getPrevPeriod(DateTime current, HistoricalPeriod resolution) {
    switch (resolution) {
      case HistoricalPeriod.daily:
        return current.subtract(const Duration(days: 1));
      case HistoricalPeriod.weekly:
        return current.subtract(const Duration(days: 7));
      case HistoricalPeriod.monthly:
        return DateTime(current.year, current.month - 1, 1);
      case HistoricalPeriod.quarterly:
        return DateTime(current.year, current.month - 3, 1);
      case HistoricalPeriod.biannual:
        return DateTime(current.year, current.month - 6, 1);
      case HistoricalPeriod.yearly:
        return DateTime(current.year - 1, 1, 1);
    }
  }

  String _formatPeriodLabel(DateTime date, HistoricalPeriod resolution) {
    switch (resolution) {
      case HistoricalPeriod.daily:
        return DateFormat('dd MMM').format(date);
      case HistoricalPeriod.weekly:
        final end = date.add(const Duration(days: 6));
        return '${date.day}-${end.day} ${DateFormat('MMM').format(date)}';
      case HistoricalPeriod.monthly:
        return DateFormat('MMM yy').format(date);
      case HistoricalPeriod.quarterly:
        int quarter = ((date.month - 1) ~/ 3) + 1;
        return 'Q$quarter ${date.year.toString().substring(2)}';
      case HistoricalPeriod.biannual:
        int half = ((date.month - 1) ~/ 6) + 1;
        return 'S$half ${date.year.toString().substring(2)}';
      case HistoricalPeriod.yearly:
        return '${date.year}';
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final creditsAsync = ref.watch(allCreditsStreamProvider);
    final clientsAsync = ref.watch(creditsClientsStreamProvider);
    final allInstallmentsAsync = ref.watch(allInstallmentsStreamProvider);

    if (creditsAsync.isLoading || clientsAsync.isLoading || allInstallmentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final credits = creditsAsync.value ?? [];
    final clients = clientsAsync.value ?? [];
    final installments = allInstallmentsAsync.value ?? [];

    final clientMap = {for (final cl in clients) cl.clientId: cl};
    
    final activeCredits = credits.where((c) => c.status == CreditStatus.active || c.status == CreditStatus.restructured || c.outstandingBalance > 0).toList();

    activeCredits.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnIndex) {
        case 0: cmp = a.creditId.compareTo(b.creditId); break;
        case 1: cmp = a.disbursementDate.compareTo(b.disbursementDate); break;
        case 2: 
          final cA = clientMap[a.clientId]?.fullName ?? '';
          final cB = clientMap[b.clientId]?.fullName ?? '';
          cmp = cA.compareTo(cB); 
          break;
        case 3: cmp = a.clientId.compareTo(b.clientId); break;
        case 4: cmp = a.principalAmount.compareTo(b.principalAmount); break;
        case 5: cmp = a.termInMonths.compareTo(b.termInMonths); break;
        case 6: cmp = (a.totalAmount + a.accumulatedMora).compareTo(b.totalAmount + b.accumulatedMora); break;
        case 7: cmp = a.paymentFrequency.name.compareTo(b.paymentFrequency.name); break;
        case 8: cmp = a.numberOfInstallments.compareTo(b.numberOfInstallments); break;
        case 9: cmp = a.installmentAmount.compareTo(b.installmentAmount); break;
        case 10: cmp = a.totalPaid.compareTo(b.totalPaid); break;
        case 11: cmp = (a.principalAmount - a.totalPaidPrincipal).compareTo(b.principalAmount - b.totalPaidPrincipal); break;
        case 12: cmp = (a.totalInterest - a.totalPaidInterest).compareTo(b.totalInterest - b.totalPaidInterest); break;
        case 13: cmp = (a.accumulatedMora - a.totalPaidMora).compareTo(b.accumulatedMora - b.totalPaidMora); break;
        case 14: 
          final saldoA = (a.principalAmount - a.totalPaidPrincipal) + (a.totalInterest - a.totalPaidInterest) + (a.accumulatedMora - a.totalPaidMora);
          final saldoB = (b.principalAmount - b.totalPaidPrincipal) + (b.totalInterest - b.totalPaidInterest) + (b.accumulatedMora - b.totalPaidMora);
          cmp = saldoA.compareTo(saldoB); 
          break;
        case 15: cmp = a.status.name.compareTo(b.status.name); break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    final now = DateTime.now();
    DateTime latestPeriodStart = _getPeriodStart(now, _selectedPeriod);
    
    List<DateTime> contiguousPeriods = [];
    DateTime current = latestPeriodStart;
    for (int i = 0; i < _chartPeriodsToDisplay; i++) {
      contiguousPeriods.add(current);
      current = _getPrevPeriod(current, _selectedPeriod);
    }
    contiguousPeriods = contiguousPeriods.reversed.toList();

    final installmentsByCredit = <String, List<InstallmentModel>>{};
    for (var inst in installments) {
      if (inst.creditId != null) {
        installmentsByCredit.putIfAbsent(inst.creditId!, () => []).add(inst);
      }
    }

    final Map<DateTime, _HistoricalPeriodData> dataByPeriod = {};
    for (var p in contiguousPeriods) {
      dataByPeriod[p] = _HistoricalPeriodData();
    }

    for (var p in contiguousPeriods) {
      final pEnd = _getPeriodEnd(p, _selectedPeriod);
      final md = dataByPeriod[p]!;

      double totalCapitalDesembolsado = 0;
      double totalCapitalPagado = 0;
      
      double totalInteresEsperado = 0;
      double totalInteresPagado = 0;
      
      double totalMoraGenerada = 0;
      double totalMoraPagada = 0;

      for (var c in credits) {
        if (c.disbursementDate.isBefore(pEnd) || c.disbursementDate.isAtSameMomentAs(pEnd)) {
          totalCapitalDesembolsado += c.principalAmount;
          totalInteresEsperado += c.totalInterest;
          
          final insts = installmentsByCredit[c.creditId] ?? [];
          for (var inst in insts) {
            if (inst.paidAmount > 0 && (inst.updatedAt.isBefore(pEnd) || inst.updatedAt.isAtSameMomentAs(pEnd))) {
               double capitalPagado = inst.status == InstallmentStatus.paid ? inst.principalPortion : 0;
               if (inst.status != InstallmentStatus.paid && inst.paidAmount > inst.accumulatedMora + inst.interestPortion) {
                 capitalPagado = inst.paidAmount - inst.accumulatedMora - inst.interestPortion;
               }
               totalCapitalPagado += capitalPagado;

               double interesPagado = inst.status == InstallmentStatus.paid ? inst.interestPortion : 0;
               if (inst.status != InstallmentStatus.paid && inst.paidAmount > 0) {
                 double moraCobrada = inst.paidAmount > inst.accumulatedMora ? inst.accumulatedMora : inst.paidAmount;
                 double resto = inst.paidAmount - moraCobrada;
                 interesPagado = resto > inst.interestPortion ? inst.interestPortion : resto;
               }
               totalInteresPagado += interesPagado;
               
               totalMoraPagada += inst.moraPaid;
            }

            final moraStart = inst.moraStartDate ?? inst.dueDate;
            if (moraStart.isBefore(pEnd) && inst.isMoraActive && !inst.isMoraExempt) {
               DateTime endCalculationDate = pEnd;
               if (inst.status == InstallmentStatus.paid && inst.updatedAt.isBefore(pEnd)) {
                 endCalculationDate = inst.updatedAt;
               }
               
               int daysLate = endCalculationDate.difference(moraStart).inDays;
               if (daysLate > 0) {
                 double moraHistorica = inst.moraBase * inst.dailyMoraRate * daysLate;
                 if (moraHistorica > inst.accumulatedMora && endCalculationDate == pEnd && inst.status != InstallmentStatus.paid) {
                   moraHistorica = inst.accumulatedMora;
                 } else if (inst.status == InstallmentStatus.paid) {
                   moraHistorica = inst.accumulatedMora;
                 }
                 totalMoraGenerada += moraHistorica;
               }
            }
          }
        }
      }

      md.capitalSaldo = totalCapitalDesembolsado - totalCapitalPagado;
      if (md.capitalSaldo < 0) md.capitalSaldo = 0;
      
      md.interesMoraSaldo = (totalInteresEsperado - totalInteresPagado) + (totalMoraGenerada - totalMoraPagada);
      if (md.interesMoraSaldo < 0) md.interesMoraSaldo = 0;
      
      md.totalSaldo = md.capitalSaldo + md.interesMoraSaldo;
    }

    double maxY = 0;
    for (var p in contiguousPeriods) {
      final val = dataByPeriod[p]!.totalSaldo;
      if (val > maxY) maxY = val;
    }
    if (maxY == 0) maxY = 100;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A84E6).withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<HistoricalPeriod>(
                  value: _selectedPeriod,
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedPeriod = v);
                  },
                  items: const [
                    DropdownMenuItem(value: HistoricalPeriod.daily, child: Text('Días')),
                    DropdownMenuItem(value: HistoricalPeriod.weekly, child: Text('Semanas')),
                    DropdownMenuItem(value: HistoricalPeriod.monthly, child: Text('Meses')),
                    DropdownMenuItem(value: HistoricalPeriod.quarterly, child: Text('Trimestres')),
                    DropdownMenuItem(value: HistoricalPeriod.biannual, child: Text('Semestres')),
                    DropdownMenuItem(value: HistoricalPeriod.yearly, child: Text('Años')),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Mostrar: '),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (_chartPeriodsToDisplay > 2) {
                          setState(() => _chartPeriodsToDisplay--);
                        }
                      },
                    ),
                    Text('$_chartPeriodsToDisplay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        if (_chartPeriodsToDisplay < 30) {
                          setState(() => _chartPeriodsToDisplay++);
                        }
                      },
                    ),
                    const Text(' periodos'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Capital Total (Evolución de Saldos)', isDark),
          const SizedBox(height: 16),
          Container(
            height: 350,
            padding: const EdgeInsets.only(top: 24, right: 24, left: 16, bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A84E6).withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white10 : Colors.black12,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= contiguousPeriods.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _formatPeriodLabel(contiguousPeriods[value.toInt()], _selectedPeriod),
                            style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        return Text(
                          '\$${(value / 1000).toStringAsFixed(0)}k',
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black54),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (contiguousPeriods.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(contiguousPeriods.length, (i) {
                      return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.capitalSaldo);
                    }),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFF4A84E6), Color(0xFF6BA0FF)]),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF4A84E6),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF4A84E6).withValues(alpha: 0.15), const Color(0xFF4A84E6).withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(contiguousPeriods.length, (i) {
                      return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.interesMoraSaldo);
                    }),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFFD54F)]),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFFFFA726),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.amber.withValues(alpha: 0.15), Colors.amber.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(contiguousPeriods.length, (i) {
                      return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.totalSaldo);
                    }),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)]),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 5,
                        color: const Color(0xFF7C4DFF),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF7C4DFF).withValues(alpha: 0.15), const Color(0xFF7C4DFF).withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => isDark ? const Color(0xFF1A1A2E) : Colors.grey.shade200,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = contiguousPeriods[spot.x.toInt()];
                        String label = '';
                        if (spot.barIndex == 0) label = 'Capital: ';
                        if (spot.barIndex == 1) label = 'Int+Mora: ';
                        if (spot.barIndex == 2) label = 'Total: ';
                        return LineTooltipItem(
                          '$label${copFormatter.format(spot.y)}',
                          TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendDot(const Color(0xFF4A84E6), 'Saldo Capital'),
                _buildLegendDot(Colors.amber, 'Saldo Interés+Mora'),
                _buildLegendDot(const Color(0xFF7C4DFF), 'Saldo Total'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('Detalle de Créditos Activos', isDark),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14141E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: activeCredits.isEmpty 
              ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No hay créditos activos')))
              : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(label: const Text('ID Crédito'), onSort: _onSort),
                  DataColumn(label: const Text('Fecha Inicio'), onSort: _onSort),
                  DataColumn(label: const Text('Cliente'), onSort: _onSort),
                  DataColumn(label: const Text('ID Cliente'), onSort: _onSort),
                  DataColumn(label: const Text('Valor Crédito'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Plazo'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Total (C+I+M)'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Periodo'), onSort: _onSort),
                  DataColumn(label: const Text('Cuotas'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Valor Cuota'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Pagado'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Saldo Capital'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Saldo Interés'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Saldo Mora'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Saldo Total'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Estado'), onSort: _onSort),
                ],
                rows: activeCredits.map((c) {
                  final clientName = clientMap[c.clientId]?.fullName ?? 'Desconocido';
                  final totalCIM = c.totalAmount + c.accumulatedMora;
                  final saldoCap = c.principalAmount - c.totalPaidPrincipal;
                  final saldoInt = c.totalInterest - c.totalPaidInterest;
                  final saldoMora = c.accumulatedMora - c.totalPaidMora;
                  final saldoTotal = saldoCap + saldoInt + saldoMora;

                  return DataRow(
                    cells: [
                      DataCell(Text(c.creditId.length > 8 ? c.creditId.substring(0,8) : c.creditId)),
                      DataCell(Text(DateFormat('dd/MM/yyyy').format(c.disbursementDate))),
                      DataCell(Text(clientName)),
                      DataCell(Text(c.clientId.length > 8 ? c.clientId.substring(0,8) : c.clientId)),
                      DataCell(Text(copFormatter.format(c.principalAmount))),
                      DataCell(Text('${c.termInMonths} m')),
                      DataCell(Text(copFormatter.format(totalCIM))),
                      DataCell(Text(c.paymentFrequency.name)),
                      DataCell(Text('${c.numberOfInstallments}')),
                      DataCell(Text(copFormatter.format(c.installmentAmount))),
                      DataCell(Text(copFormatter.format(c.totalPaid), style: const TextStyle(color: Colors.green))),
                      DataCell(Text(copFormatter.format(saldoCap))),
                      DataCell(Text(copFormatter.format(saldoInt))),
                      DataCell(Text(copFormatter.format(saldoMora))),
                      DataCell(Text(copFormatter.format(saldoTotal), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(c.status.name.toUpperCase())),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Capital Total')),
      body: content,
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A84E6), Color(0xFF00C9A7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
