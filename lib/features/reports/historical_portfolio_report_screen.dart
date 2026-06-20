import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../shared/theme/app_theme.dart';
import '../../core/models/credit_model.dart';
import '../../core/models/installment_model.dart';
import '../../core/services/firestore_service.dart';
import '../calendar/calendar_providers.dart'; // Para joinedInstallmentsProvider

enum HistoricalPeriod {
  daily,
  weekly,
  monthly,
  quarterly,
  biannual,
  yearly,
}

class _HistoricalPeriodData {
  double nuevosDesembolsos = 0;
  double capitalRecaudado = 0;
  double carteraActiva = 0;
  double ingresosUtilidad = 0;
}

enum HistoricalMetric {
  carteraActiva,
  utilidadNeta,
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
  HistoricalMetric _selectedMetric = HistoricalMetric.carteraActiva;

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
    final creditsAsync = ref.watch(firestoreServiceProvider).getAllCreditsStream();
    final joinedAsync = ref.watch(joinedInstallmentsProvider);

    return StreamBuilder<List<CreditModel>>(
      stream: creditsAsync,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || joinedAsync.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final credits = snapshot.data ?? [];
        final allJoined = joinedAsync.value ?? [];

    // Generar periodos a mostrar
    final now = DateTime.now();
    DateTime latestPeriodStart = _getPeriodStart(now, _selectedPeriod);
    
    List<DateTime> contiguousPeriods = [];
    DateTime current = latestPeriodStart;
    for (int i = 0; i < _chartPeriodsToDisplay; i++) {
      contiguousPeriods.add(current);
      current = _getPrevPeriod(current, _selectedPeriod);
    }
    contiguousPeriods = contiguousPeriods.reversed.toList();

    // Calcular datos históricos
    final Map<DateTime, _HistoricalPeriodData> dataByPeriod = {};
    for (var p in contiguousPeriods) {
      dataByPeriod[p] = _HistoricalPeriodData();
    }

    // Calcular montos exactos evaluando crédito por crédito y cuota por cuota
    // para los periodos que vamos a mostrar.
    for (var p in contiguousPeriods) {
      final pStart = p;
      final pEnd = _getPeriodEnd(p, _selectedPeriod);
      final md = dataByPeriod[p]!;

      // 1. Cartera Activa al cierre del periodo (Foto en pEnd)
      double totalDesembolsadoHistorico = 0;
      for (var c in credits) {
        if (c.disbursementDate.isBefore(pEnd) || c.disbursementDate.isAtSameMomentAs(pEnd)) {
          totalDesembolsadoHistorico += c.principalAmount;
          // Si el crédito se desembolsó DENTRO de este periodo, sumarlo a "Nuevos Desembolsos"
          if (!c.disbursementDate.isBefore(pStart)) {
            md.nuevosDesembolsos += c.principalAmount;
          }
        }
      }

      double totalCapitalRecaudadoHistorico = 0;
      for (var j in allJoined) {
        final inst = j.installment;
        if (inst.status == InstallmentStatus.paid || inst.paidAmount > 0) {
          // Consideramos el pago si la fecha de actualización es anterior o igual al fin del periodo
          if (inst.updatedAt.isBefore(pEnd) || inst.updatedAt.isAtSameMomentAs(pEnd)) {
            // Asumimos que si está pagado, se recuperó principalPortion. 
            // Si es parcial, podríamos prorratear, pero como no hay control exacto, sumamos lo que alcance a cubrir el capital.
            double capitalPagado = inst.status == InstallmentStatus.paid ? inst.principalPortion : 0;
            if (inst.status != InstallmentStatus.paid && inst.paidAmount > inst.accumulatedMora + inst.interestPortion) {
              capitalPagado = inst.paidAmount - inst.accumulatedMora - inst.interestPortion;
            }
            totalCapitalRecaudadoHistorico += capitalPagado;

            // Si el pago se hizo DENTRO de este periodo, sumarlo a "Capital Recaudado" y "Utilidad"
            if (!inst.updatedAt.isBefore(pStart)) {
              md.capitalRecaudado += capitalPagado;
              
              double utilidadPagada = 0;
              if (inst.status == InstallmentStatus.paid) {
                utilidadPagada = inst.interestPortion + inst.moraPaid;
              } else if (inst.paidAmount > 0) {
                // Pago parcial de utilidad
                double moraCobrada = inst.paidAmount > inst.accumulatedMora ? inst.accumulatedMora : inst.paidAmount;
                double resto = inst.paidAmount - moraCobrada;
                double intCobrado = resto > inst.interestPortion ? inst.interestPortion : resto;
                utilidadPagada = moraCobrada + intCobrado;
              }
              md.ingresosUtilidad += utilidadPagada;
            }
          }
        }
      }

      md.carteraActiva = totalDesembolsadoHistorico - totalCapitalRecaudadoHistorico;
      if (md.carteraActiva < 0) md.carteraActiva = 0;
    }

    // Preparar para la tabla
    final tablePeriods = contiguousPeriods.toList();
    tablePeriods.sort((a, b) {
      int cmp = 0;
      if (_sortColumnIndex == 0) {
        cmp = a.compareTo(b);
      } else {
        final da = dataByPeriod[a]!;
        final db = dataByPeriod[b]!;
        switch (_sortColumnIndex) {
          case 1: cmp = da.nuevosDesembolsos.compareTo(db.nuevosDesembolsos); break;
          case 2: cmp = da.capitalRecaudado.compareTo(db.capitalRecaudado); break;
          case 3: cmp = da.carteraActiva.compareTo(db.carteraActiva); break;
          case 4: cmp = da.ingresosUtilidad.compareTo(db.ingresosUtilidad); break;
        }
      }
      return _sortAscending ? cmp : -cmp;
    });

    // Preparar para la gráfica
    double maxY = 0;
    for (var p in contiguousPeriods) {
      final md = dataByPeriod[p]!;
      double val = _selectedMetric == HistoricalMetric.carteraActiva ? md.carteraActiva : md.ingresosUtilidad;
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
          // --- Controles de Filtro ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
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
                DropdownButton<HistoricalMetric>(
                  value: _selectedMetric,
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedMetric = v);
                  },
                  items: const [
                    DropdownMenuItem(value: HistoricalMetric.carteraActiva, child: Text('Ver Cartera Activa')),
                    DropdownMenuItem(value: HistoricalMetric.utilidadNeta, child: Text('Ver Ganancia (Interés+Mora)')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- Gráfica ---
          Text(_selectedMetric == HistoricalMetric.carteraActiva ? 'Evolución de Cartera Activa' : 'Ganancia por Periodo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Container(
            height: 300,
            padding: const EdgeInsets.only(top: 24, right: 24, left: 16, bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: _selectedMetric == HistoricalMetric.carteraActiva
              ? LineChart(
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
                          return FlSpot(i.toDouble(), dataByPeriod[contiguousPeriods[i]]!.carteraActiva);
                        }),
                        isCurved: true,
                        color: AppTheme.primaryColor,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppTheme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => isDark ? Colors.blueGrey.shade900 : Colors.white,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final date = contiguousPeriods[spot.x.toInt()];
                            final val = dataByPeriod[date]!.carteraActiva;
                            return LineTooltipItem(
                              '${_formatPeriodLabel(date, _selectedPeriod)}\n${copFormatter.format(val)}',
                              TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY * 1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => isDark ? Colors.blueGrey.shade900 : Colors.white,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final date = contiguousPeriods[group.x];
                          final val = dataByPeriod[date]!.ingresosUtilidad;
                          return BarTooltipItem(
                            '${_formatPeriodLabel(date, _selectedPeriod)}\n${copFormatter.format(val)}',
                            TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
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
                            if (value.toInt() < 0 || value.toInt() >= contiguousPeriods.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
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
                        barRods: [
                          BarChartRodData(
                            toY: md.ingresosUtilidad,
                            color: Colors.amber.shade600,
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY * 1.2,
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
          ),

          const SizedBox(height: 32),

          // --- Tabla de Datos ---
          Text('Detalle por Periodo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(label: const Text('Periodo'), onSort: _onSort),
                  DataColumn(label: const Text('Nuevos Desembolsos'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Capital Recaudado'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Cartera Activa'), numeric: true, onSort: _onSort),
                  DataColumn(label: const Text('Ganancia (Int+Mora)'), numeric: true, onSort: _onSort),
                ],
                rows: tablePeriods.map((p) {
                  final md = dataByPeriod[p]!;
                  return DataRow(
                    cells: [
                      DataCell(Text(_formatPeriodLabel(p, _selectedPeriod))),
                      DataCell(Text(copFormatter.format(md.nuevosDesembolsos), style: const TextStyle(color: Colors.blueAccent))),
                      DataCell(Text(copFormatter.format(md.capitalRecaudado), style: const TextStyle(color: Colors.green))),
                      DataCell(Text(copFormatter.format(md.carteraActiva), style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(copFormatter.format(md.ingresosUtilidad), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
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
      appBar: AppBar(title: const Text('Evolución y Ganancias')),
      body: content,
    );
      }
    );
  }
}
