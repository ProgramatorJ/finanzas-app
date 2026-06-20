import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/installment_model.dart';
import '../models/user_model.dart';
import '../../features/calendar/calendar_providers.dart';
import '../../features/appointments/appointments_agenda_screen.dart';
import '../../core/services/rbac_service.dart';

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final LocalNotificationService _instance = LocalNotificationService._internal();

  factory LocalNotificationService() {
    return _instance;
  }

  LocalNotificationService._internal();

  // Función callback para manejar clics en notificaciones cuando la app está abierta o en segundo plano
  static void Function(String? clientId)? onNotificationTapped;

  /// Inicializa el servicio de notificaciones y la base de datos de zonas horarias.
  Future<void> initialize() async {
    debugPrint('[NotificationService] Inicializando...');
    
    // 1. Inicializar base de datos de zonas horarias locales
    tz.initializeTimeZones();
    // Configurar la zona horaria del dispositivo actual (por defecto Bogotá/Colombia o local)
    // En Flutter, podemos obtener el nombre del huso horario o usar el local predeterminado
    // Para simplificar, configuramos el huso horario por defecto a la hora local
    final String timeZoneName = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    } catch (_) {
      // Fallback si no encuentra America/Bogota o no se puede resolver
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint('[NotificationService] Error al establecer ubicación de zona horaria: $e. Usando UTC/Local.');
      }
    }

    // 2. Configurar inicialización de Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Unir configuraciones de plataformas
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // 4. Inicializar el plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        debugPrint('[NotificationService] Notificación presionada con payload (clientId): $payload');
        if (payload != null && onNotificationTapped != null) {
          onNotificationTapped!(payload);
        }
      },
    );

    // 5. Solicitar permisos para Android 13+
    await requestPermissions();
    debugPrint('[NotificationService] Inicializado con éxito.');
  }

  /// Solicita permisos de notificaciones para Android 13+ (Post 33).
  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      debugPrint('[NotificationService] Permiso de notificaciones otorgado: $granted');
      
      // Intentar solicitar permiso de alarmas exactas si es necesario
      final bool? alarmPermission = await androidImplementation.requestExactAlarmsPermission();
      debugPrint('[NotificationService] Permiso de alarmas exactas otorgado: $alarmPermission');
    }
  }

  /// Programa una alarma local nativa para una cita en tiempo real.
  Future<void> scheduleAppointmentNotification(AppointmentModel appointment) async {
    if (appointment.isCompleted) return;

    final now = DateTime.now();
    if (appointment.scheduledTime.isBefore(now)) {
      debugPrint('[NotificationService] No se programa cita #${appointment.appointmentId} porque es una fecha pasada.');
      return;
    }

    // Identificador entero único a partir del hash del ID de la cita
    final int notificationId = appointment.appointmentId.hashCode;

    // Convertir la fecha de la cita a TZDateTime compatible
    final tz.TZDateTime scheduledTZTime = tz.TZDateTime.from(appointment.scheduledTime, tz.local);

    // Configuración específica de la notificación de Android
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'loans_reminder_channel_id',
      'Recordatorios de Cobro',
      channelDescription: 'Canal para alertas y alarmas de citas con clientes programadas',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // Despierta la pantalla
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    debugPrint('[NotificationService] Programando alarma para: $scheduledTZTime (Cita: ${appointment.appointmentId})');

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      appointment.type == AppointmentType.call ? '📞 Llamar a Cliente' : '🚶 Visita Programada',
      'Cita con ${appointment.clientName}\nDetalles: ${appointment.notes}',
      scheduledTZTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: appointment.clientId, // Enviamos el clientId para abrir la ficha al hacer tap
    );
  }

  /// Cancela una alarma de notificación programada.
  Future<void> cancelNotification(int notificationId) async {
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
    debugPrint('[NotificationService] Alarma cancelada con ID: $notificationId');
  }

  /// Programa una alarma local nativa para una cuota de pago.
  Future<void> scheduleInstallmentNotification(InstallmentModel installment, String clientName, double remainingAmount) async {
    final now = DateTime.now();
    
    // Calcular la fecha y hora de la alarma
    final DateTime alarmDateTime = DateTime(
      installment.dueDate.year,
      installment.dueDate.month,
      installment.dueDate.day,
      installment.alarmHour,
      installment.alarmMinute,
    );

    if (alarmDateTime.isBefore(now)) {
      debugPrint('[NotificationService] No se programa cuota #${installment.installmentId} porque la fecha de alarma es pasada.');
      return;
    }

    // Identificador entero único a partir del hash del ID de la cuota
    final int notificationId = ('inst_' + installment.installmentId).hashCode;

    // Convertir a TZDateTime
    final tz.TZDateTime scheduledTZTime = tz.TZDateTime.from(alarmDateTime, tz.local);

    // Configuración según sea silenciosa o no
    final String channelId = installment.isAlarmSilent ? 'loans_silent_channel_id' : 'loans_alarm_channel_id';
    final String channelName = installment.isAlarmSilent ? 'Recordatorios Silenciosos' : 'Alarmas de Cobro';
    final String channelDesc = installment.isAlarmSilent 
        ? 'Canal para recordatorios de pago silenciosos' 
        : 'Canal para alarmas sonoras de pago de cuotas';

    final AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: installment.isAlarmSilent ? Importance.low : Importance.max,
      priority: installment.isAlarmSilent ? Priority.low : Priority.high,
      playSound: !installment.isAlarmSilent,
      enableVibration: !installment.isAlarmSilent,
      fullScreenIntent: !installment.isAlarmSilent, // Despierta la pantalla si no es silenciosa
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    debugPrint('[NotificationService] Programando alarma de cuota para: $scheduledTZTime (Cuota: ${installment.installmentId}, Silenciosa: ${installment.isAlarmSilent})');

    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      '💰 Cobro de Cuota',
      'Cuota #${installment.installmentNumber} de $clientName\nValor: ${formatter.format(remainingAmount)}',
      scheduledTZTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: installment.creditId, // Usamos creditId para relacionarlo o si hubiera clientId
    );
  }

  /// Sincroniza todas las citas y cuotas activas de Firestore con el planificador local del dispositivo.
  Future<void> syncAllAlarms({
    required List<AppointmentModel> appointments,
    required List<JoinedInstallment> installments,
  }) async {
    try {
      debugPrint('[NotificationService] Iniciando sincronización global de alarmas locales...');
      final now = DateTime.now();

      // 1. Obtener alarmas ya programadas en el celular
      final List<PendingNotificationRequest> pendingRequests =
          await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      
      final Set<int> pendingIds = pendingRequests.map((r) => r.id).toSet();
      
      // 2. Mapear IDs de notificaciones activas
      final Map<int, dynamic> activeAlarms = {};
      
      // Añadir citas a las alarmas activas
      for (final appointment in appointments) {
        if (!appointment.isCompleted && appointment.scheduledTime.isAfter(now)) {
          activeAlarms[appointment.appointmentId.hashCode] = appointment;
        }
      }
      
      // Añadir cuotas a las alarmas activas
      for (final item in installments) {
        final inst = item.installment;
        if (inst.isAlarmEnabled && 
            inst.status != InstallmentStatus.paid && 
            inst.status != InstallmentStatus.consolidated) {
          
          final alarmDateTime = DateTime(
            inst.dueDate.year,
            inst.dueDate.month,
            inst.dueDate.day,
            inst.alarmHour,
            inst.alarmMinute,
          );
          
          if (alarmDateTime.isAfter(now)) {
            final int id = ('inst_' + inst.installmentId).hashCode;
            activeAlarms[id] = item; // Guardamos el JoinedInstallment
          }
        }
      }

      // 3. Cancelar alarmas programadas que ya no existen en las alarmas activas
      for (final pendingRequest in pendingRequests) {
        if (!activeAlarms.containsKey(pendingRequest.id)) {
          await cancelNotification(pendingRequest.id);
        }
      }

      // 4. Programar alarmas nuevas o actualizadas
      for (final entry in activeAlarms.entries) {
        final id = entry.key;
        final data = entry.value;
        
        if (data is AppointmentModel) {
          await scheduleAppointmentNotification(data);
        } else if (data is JoinedInstallment) {
          await scheduleInstallmentNotification(
            data.installment,
            data.client.fullName,
            data.installment.remainingAmount,
          );
        }
      }

      debugPrint('[NotificationService] Sincronización global finalizada con éxito.');
    } catch (e) {
      debugPrint('[NotificationService] Error durante la sincronización global: $e');
    }
  }

  /// Sincroniza todas las citas activas de Firestore con el planificador local del dispositivo (obsoleto, usar syncAllAlarms).
  Future<void> syncDeviceAppointments(List<AppointmentModel> upcomingAppointments) async {
    await syncAllAlarms(appointments: upcomingAppointments, installments: []);
  }
}

// ─── Provider de Riverpod ─────────────────────────────────────────────────
final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

/// Provider auto-sincronizador de alarmas (corre reactivamente en segundo plano en Android)
final alarmSyncProvider = Provider<void>((ref) {
  if (kIsWeb) return;

  final userAsync = ref.watch(currentUserModelProvider);
  userAsync.whenData((user) {
    if (user == null) return;
    
    // Escuchar citas
    final appointmentsAsync = user.role == UserRole.admin 
        ? ref.watch(appointmentsStreamProvider) 
        : ref.watch(collectorAppointmentsProvider);

    // Escuchar cuotas
    final installmentsAsync = ref.watch(joinedInstallmentsProvider);

    if (appointmentsAsync.hasValue && installmentsAsync.hasValue) {
      final appointments = appointmentsAsync.value ?? [];
      final joinedInstallments = installmentsAsync.value ?? [];
      
      final service = ref.read(localNotificationServiceProvider);
      
      // Ejecutar sincronización
      service.syncAllAlarms(
        appointments: appointments,
        installments: joinedInstallments,
      );
    }
  });
});
