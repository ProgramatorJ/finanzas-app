import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/responsive_sidebar_scaffold.dart';
import '../../core/services/rbac_service.dart';
import '../../core/models/user_model.dart';
import '../credits/credit_detail_screen.dart';
import 'calendar_providers.dart';
import '../../core/models/installment_model.dart';
import '../../core/services/firestore_service.dart';
import '../reports/reports_main_screen.dart';

class PaymentCalendarScreen extends ConsumerStatefulWidget {
  const PaymentCalendarScreen({super.key});

  @override
  ConsumerState<PaymentCalendarScreen> createState() => _PaymentCalendarScreenState();
}

class _PaymentCalendarScreenState extends ConsumerState<PaymentCalendarScreen> {
  DateTime _currentMonthDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  final copFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  // Genera los 42 días necesarios para rellenar la cuadrícula mensual (6 semanas de Lunes a Domingo)
  List<DateTime> _generateCalendarDays(DateTime monthDate) {
    final first = DateTime(monthDate.year, monthDate.month, 1);
    // En Dart: 1 = Lunes, 7 = Domingo.
    // Desfase para que la semana empiece en Lunes.
    final int prefixOffset = first.weekday - 1;
    final startOfGrid = first.subtract(Duration(days: prefixOffset));
    return List.generate(42, (index) => startOfGrid.add(Duration(days: index)));
  }

  // Agrupa las cuotas por fecha formateada 'yyyy-MM-dd' para búsquedas O(1)
  Map<String, List<JoinedInstallment>> _groupInstallmentsByDate(List<JoinedInstallment> list) {
    final map = <String, List<JoinedInstallment>>{};
    for (final item in list) {
      final dateKey = DateFormat('yyyy-MM-dd').format(item.installment.dueDate);
      map.putIfAbsent(dateKey, () => []).add(item);
    }
    return map;
  }

  void _nextMonth() {
    setState(() {
      _currentMonthDate = DateTime(_currentMonthDate.year, _currentMonthDate.month + 1, 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _currentMonthDate = DateTime(_currentMonthDate.year, _currentMonthDate.month - 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
    final joinedAsync = ref.watch(joinedInstallmentsProvider);

    final userAsync = ref.watch(currentUserModelProvider);
    final selectedIndex = userAsync.maybeWhen(
      data: (user) => user?.role == UserRole.admin ? 3 : 2,
      orElse: () => 2,
    );

    return ResponsiveSidebarScaffold(
      selectedIndex: selectedIndex,
      title: 'Calendario de Pagos',
      child: joinedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar calendario: $err', style: const TextStyle(color: AppTheme.errorColor)),
        ),
        data: (joinedList) {
          final grouped = _groupInstallmentsByDate(joinedList);
          final calendarDays = _generateCalendarDays(_currentMonthDate);
          final selectedDateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
          final selectedDateInstallments = grouped[selectedDateKey] ?? [];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
              // ── Cabecera del Mes / Navegador ────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 28),
                      onPressed: _prevMonth,
                    ),
                    Text(
                      DateFormat('MMMM yyyy', 'es').format(_currentMonthDate).toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 28),
                      onPressed: _nextMonth,
                    ),
                    const Spacer(),
                    // Atajo a Informes
                    IconButton(
                      icon: const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryColor),
                      tooltip: 'Ir a Informes',
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportsMainScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Cabecera de los Días de la Semana ────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((day) {
                    return SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: secondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // ── Cuadrícula del Calendario (GridView de Días) ────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      final dayDate = calendarDays[index];
                      final isCurrentMonth = dayDate.month == _currentMonthDate.month;
                      final isSelected = DateFormat('yyyy-MM-dd').format(dayDate) == selectedDateKey;
                      
                      final now = DateTime.now();
                      final isToday = dayDate.year == now.year && 
                                      dayDate.month == now.month && 
                                      dayDate.day == now.day;

                      final dayDateKey = DateFormat('yyyy-MM-dd').format(dayDate);
                      final dayInstallments = grouped[dayDateKey] ?? [];

                      // Determinar los colores de los indicadores según las cuotas del día
                      bool hasOverdue = false;
                      bool hasPending = false;
                      bool hasDisbursement = false;
                      bool hasPaid = false;

                      for (final item in dayInstallments) {
                        final inst = item.installment;
                        final credit = item.credit;
                        
                        // Check if this day is the disbursement day
                        final disburseMidnight = DateTime(credit.disbursementDate.year, credit.disbursementDate.month, credit.disbursementDate.day);
                        final dayMidnight = DateTime(dayDate.year, dayDate.month, dayDate.day);
                        if (disburseMidnight.isAtSameMomentAs(dayMidnight)) {
                          hasDisbursement = true;
                        }

                        if (inst.status == InstallmentStatus.paid) {
                          hasPaid = true;
                        } else if (inst.status == InstallmentStatus.consolidated) {
                          // Consolidado no marca en el calendario porque se asume movido
                        } else {
                          // Pendiente o Vencido
                          final dueMidnight = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
                          final todayMidnight = DateTime(now.year, now.month, now.day);
                          if (dueMidnight.isBefore(todayMidnight)) {
                            hasOverdue = true;
                          } else {
                            hasPending = true;
                          }
                        }
                      }

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDate = dayDate;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? AppTheme.primaryColor.withOpacity(0.2)
                                : isToday 
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? AppTheme.primaryColor
                                  : isToday
                                      ? secondaryColor.withOpacity(0.3)
                                      : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                dayDate.day.toString(),
                                style: TextStyle(
                                  fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected 
                                      ? Colors.white 
                                      : isCurrentMonth 
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : secondaryColor.withOpacity(0.4),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Fila de puntitos indicadores
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (hasDisbursement)
                                    _buildIndicatorDot(Colors.blue), // Azul para desembolsos
                                  if (hasOverdue)
                                    _buildIndicatorDot(AppTheme.errorColor),
                                  if (hasPending)
                                    _buildIndicatorDot(AppTheme.warningColor),
                                  if (hasPaid)
                                    _buildIndicatorDot(AppTheme.secondaryColor),
                                  if (!hasDisbursement && !hasOverdue && !hasPending && !hasPaid)
                                    const SizedBox(height: 4),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Título del Detalle Diario ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.event_note_rounded, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Cobros para el ${DateFormat("dd MMMM", "es").format(_selectedDate)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Listado de cuotas del día seleccionado ──────────────
              Expanded(
                child: selectedDateInstallments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 48, color: secondaryColor.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Sin pagos programados para este día.',
                              style: TextStyle(color: secondaryColor, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: selectedDateInstallments.length,
                        itemBuilder: (context, index) {
                          final item = selectedDateInstallments[index];
                          final inst = item.installment;
                          final credit = item.credit;
                          final client = item.client;

                          final isDisbursementDay = DateTime(credit.disbursementDate.year, credit.disbursementDate.month, credit.disbursementDate.day)
                                  .isAtSameMomentAs(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));

                          Color statusColor = Colors.grey;
                          String statusText = '';
                          
                          if (inst.status == InstallmentStatus.paid) {
                            statusColor = AppTheme.secondaryColor;
                            statusText = 'PAGADO';
                          } else {
                            final now = DateTime.now();
                            final dueMidnight = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
                            final todayMidnight = DateTime(now.year, now.month, now.day);
                            if (dueMidnight.isBefore(todayMidnight)) {
                              statusColor = AppTheme.errorColor;
                              statusText = 'EN MORA';
                            } else {
                              statusColor = AppTheme.warningColor;
                              statusText = 'PENDIENTE';
                            }
                          }

                          final alarmTimeText = inst.isAlarmEnabled 
                              ? ' (${inst.alarmHour.toString().padLeft(2, '0')}:${inst.alarmMinute.toString().padLeft(2, '0')}${inst.isAlarmSilent ? ' 🔕' : ' 🔔'})'
                              : ' (Alarma 📴)';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
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
                              leading: IconButton(
                                icon: Icon(
                                  inst.isAlarmEnabled 
                                      ? (inst.isAlarmSilent ? Icons.notifications_paused_rounded : Icons.notifications_active_rounded) 
                                      : Icons.notifications_off_rounded,
                                  color: inst.isAlarmEnabled 
                                      ? (inst.isAlarmSilent ? AppTheme.warningColor : AppTheme.secondaryColor) 
                                      : secondaryColor,
                                ),
                                tooltip: 'Configurar Alarma de Cuota',
                                onPressed: () {
                                  _showAlarmDialog(context, ref, inst, credit.creditId, client.fullName);
                                },
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    client.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (isDisbursementDay) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('DESEMBOLSO', style: TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Ref: ${credit.creditId.substring(0, credit.creditId.length > 8 ? 8 : credit.creditId.length)} | Cuota #${inst.installmentNumber}$alarmTimeText',
                                  style: TextStyle(color: secondaryColor, fontSize: 11),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    copFormatter.format(inst.remainingAmount > 0 ? inst.remainingAmount : inst.scheduledAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
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
      ),
    );
  }

  void _showAlarmDialog(BuildContext context, WidgetRef ref, InstallmentModel installment, String creditId, String clientName) {
    showDialog(
      context: context,
      builder: (_) => InstallmentAlarmDialog(
        installment: installment,
        creditId: creditId,
        clientName: clientName,
        ref: ref,
      ),
    );
  }

  Widget _buildIndicatorDot(Color color) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class InstallmentAlarmDialog extends StatefulWidget {
  final InstallmentModel installment;
  final String creditId;
  final String clientName;
  final WidgetRef ref;

  const InstallmentAlarmDialog({
    super.key,
    required this.installment,
    required this.creditId,
    required this.clientName,
    required this.ref,
  });

  @override
  State<InstallmentAlarmDialog> createState() => _InstallmentAlarmDialogState();
}

class _InstallmentAlarmDialogState extends State<InstallmentAlarmDialog> {
  late bool _isAlarmEnabled;
  late bool _isAlarmSilent;
  late TimeOfDay _alarmTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isAlarmEnabled = widget.installment.isAlarmEnabled;
    _isAlarmSilent = widget.installment.isAlarmSilent;
    _alarmTime = TimeOfDay(
      hour: widget.installment.alarmHour,
      minute: widget.installment.alarmMinute,
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _alarmTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _alarmTime = pickedTime;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final db = widget.ref.read(firestoreServiceProvider);
      await db.updateInstallment(widget.creditId, widget.installment.installmentId, {
        'alarmHour': _alarmTime.hour,
        'alarmMinute': _alarmTime.minute,
        'isAlarmEnabled': _isAlarmEnabled,
        'isAlarmSilent': _isAlarmSilent,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alarma de cuota configurada con éxito.'),
            backgroundColor: AppTheme.secondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuración: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassmorphicContainer(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Alarma de Cuota',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente: ${widget.clientName}',
                  style: TextStyle(color: secondaryColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Switch Habilitado
                SwitchListTile(
                  title: const Text('Activar Alarma'),
                  subtitle: Text('Sonar a la hora programada', style: TextStyle(color: secondaryColor, fontSize: 12)),
                  value: _isAlarmEnabled,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (val) {
                    setState(() {
                      _isAlarmEnabled = val;
                    });
                  },
                ),
                const Divider(),

                // Picker de Hora
                ListTile(
                  title: const Text('Hora de Alarma'),
                  subtitle: Text(_alarmTime.format(context), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  trailing: Icon(Icons.edit_calendar_rounded, color: secondaryColor),
                  enabled: _isAlarmEnabled,
                  onTap: () => _pickTime(context),
                ),
                const Divider(),

                // Switch Silencioso
                SwitchListTile(
                  title: const Text('Modo Silencioso'),
                  subtitle: Text('Mostrar notificación sin sonido', style: TextStyle(color: secondaryColor, fontSize: 12)),
                  value: _isAlarmSilent,
                  activeColor: AppTheme.warningColor,
                  onChanged: _isAlarmEnabled 
                      ? (val) {
                          setState(() {
                            _isAlarmSilent = val;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 24),

                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text('Cancelar', style: TextStyle(color: secondaryColor)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
