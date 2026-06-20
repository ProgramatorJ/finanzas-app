import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'firebase_options.dart';
import 'features/auth/auth_gate.dart';
import 'shared/theme/app_theme.dart';
import 'core/services/local_notification_service.dart';
import 'features/clients/client_detail_screen.dart';

// Key de navegación global para abrir la app desde alarmas fuera de contexto
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

late final SharedPreferences sharedPreferences;

Future<void> main() async {
  // Asegura que los bindings de Flutter estén listos antes de usar plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Capturar errores de Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('=== FLUTTER ERROR ===');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack?.toString());
  };

  // Capturar errores no controlados de la plataforma/asíncronos
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('=== UNCAUGHT DART ERROR ===');
    debugPrint(error.toString());
    debugPrint(stack.toString());
    return true;
  };

  // Inicializar SharedPreferences de manera global y síncrona para el resto de la app
  sharedPreferences = await SharedPreferences.getInstance();

  // Inicializar localización para formateo de fechas en español
  try {
    await initializeDateFormatting('es', null);
    await initializeDateFormatting('es_CO', null);
  } catch (e) {
    debugPrint('Error al inicializar date formatting: $e');
  }

  // Inicializar Firebase con la configuración generada por FlutterFire CLI
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar servicio de notificaciones locales (alarmas nativas)
  try {
    await LocalNotificationService().initialize();
    
    // Configurar redirección automática al tocar la campana/alarma nativa
    LocalNotificationService.onNotificationTapped = (clientId) {
      if (clientId != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ClientDetailScreen(clientId: clientId),
          ),
        );
      }
    };
  } catch (e) {
    debugPrint('Error al inicializar LocalNotificationService: $e');
  }

  runApp(
    // ProviderScope envuelve toda la app para habilitar Riverpod
    const ProviderScope(
      child: FinanzasApp(),
    ),
  );
}

class FinanzasApp extends ConsumerWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'GestorPréstamos — Sistema Financiero',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      // AuthGate decide qué pantalla mostrar según el estado de sesión
      home: const AuthGate(),
    );
  }
}
