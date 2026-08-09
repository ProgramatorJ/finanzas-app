import 'package:finanzas_app/core/enums/credit_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/appointment_model.dart';
import '../../core/models/credit_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../shared/theme/app_theme.dart';
import '../clients/client_detail_screen.dart';

class AppointmentFormDialog extends ConsumerStatefulWidget {
  final String clientId;
  final String clientName;

  const AppointmentFormDialog({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  ConsumerState<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends ConsumerState<AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  AppointmentType _appointmentType = AppointmentType.visit;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final _notesController = TextEditingController();
  String? _selectedCreditId;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (scheduledDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha y hora de la cita deben ser futuras.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('No hay usuario autenticado.');

      final db = ref.read(firestoreServiceProvider);

      final appointment = AppointmentModel(
        appointmentId: '', // Autogenerado por Firestore
        clientId: widget.clientId,
        clientName: widget.clientName,
        collectorUid: user.uid,
        scheduledTime: scheduledDateTime,
        type: _appointmentType,
        notes: _notesController.text.trim(),
        isCompleted: false,
        creditId: _selectedCreditId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Guardar en Firestore
      final appointmentId = await db.createAppointment(appointment);

      // 2. Programar alarma local (solo en móviles, se maneja de forma segura)
      final appointmentWithId = AppointmentModel(
        appointmentId: appointmentId,
        clientId: appointment.clientId,
        clientName: appointment.clientName,
        collectorUid: appointment.collectorUid,
        scheduledTime: appointment.scheduledTime,
        type: appointment.type,
        notes: appointment.notes,
        isCompleted: appointment.isCompleted,
        creditId: appointment.creditId,
        createdAt: appointment.createdAt,
        updatedAt: appointment.updatedAt,
      );

      // Intentar programar la notificación nativa
      try {
        await ref.read(localNotificationServiceProvider).scheduleAppointmentNotification(appointmentWithId);
      } catch (e) {
        debugPrint('[AppointmentForm] No se pudo programar alarma local (posiblemente en Web): $e');
      }

      if (mounted) {
        Navigator.pop(context, true); // Cerrar y retornar éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cita programada con éxito para el ${DateFormat('dd/MM a las hh:mm a').format(scheduledDateTime)}'),
            backgroundColor: AppTheme.secondaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al programar cita: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? const Color(0xFFA5A5B5) : Colors.black54;
    final surfaceColor = isDark ? const Color(0xFF1E2536) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassmorphicContainer(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Programar Cita',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // --- Tipo de Cita (SegmentedButton) ---
                SegmentedButton<AppointmentType>(
                  segments: const [
                    ButtonSegment(
                      value: AppointmentType.visit,
                      label: Text('Visita 🚶'),
                    ),
                    ButtonSegment(
                      value: AppointmentType.call,
                      label: Text('Llamar 📞'),
                    ),
                  ],
                  selected: {_appointmentType},
                  onSelectionChanged: (Set<AppointmentType> newSelection) {
                    setState(() {
                      _appointmentType = newSelection.first;
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                    selectedForegroundColor: isDark ? Colors.white : Theme.of(context).colorScheme.primary,
                    foregroundColor: secondaryColor,
                  ),
                ),
                const SizedBox(height: 20),

                // --- Vincular a Crédito (Dropdown) ---
                ref.watch(clientCreditsProvider(widget.clientId)).when(
                  data: (credits) {
                    final activeCredits = credits.where((c) => c.status != CreditStatus.completed).toList();
                    if (activeCredits.isEmpty) return const SizedBox();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String?>(
                          value: _selectedCreditId,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: const InputDecoration(
                            labelText: 'Vincular a Crédito (Opcional)',
                            prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                          ),
                          dropdownColor: isDark ? const Color(0xFF1E2536) : Colors.white,
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('General / Nuevo Crédito', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            ),
                            ...activeCredits.map((c) {
                              final refStr = c.creditId.length > 8 
                                  ? c.creditId.substring(0, 8) 
                                  : c.creditId;
                              return DropdownMenuItem<String?>(
                                value: c.creditId,
                                child: Text(
                                  'Ref: $refStr (Saldo: \$${NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0).format(c.outstandingBalance).trim()})',
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedCreditId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, __) => const SizedBox(),
                ),

                // --- Selectores de Fecha y Hora ---
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: surfaceColor,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _pickDate(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(_selectedTime.format(context)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: surfaceColor,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _pickTime(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // --- Campo de Notas/Descripción ---
                TextFormField(
                  controller: _notesController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Instrucciones / Notas',
                    alignLabelWithHint: true,
                    hintText: 'Ej. cobrar cuota atrasada en el local...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa notas para la cita.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // --- Botones de Acción ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text('Cancelar', style: TextStyle(color: secondaryColor)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveAppointment,
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
                          : const Text('Programar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
