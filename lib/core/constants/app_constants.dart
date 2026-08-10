class AppConstants {
  // Versión actual de la lógica matemática (usado para migraciones forzadas)
  static const int currentMathSchemaVersion = 3;

  // Tasas financieras por defecto (editables por el admin en base de datos)
  static const double defaultMonthlyInterestRate = 0.10; // 10% mensual
  static const double defaultDailyMoraRate = 0.007;      // 0.7% diario

  // Configuración de Moneda
  static const String defaultCurrency = 'COP';
  static const List<String> supportedCurrencies = ['COP', 'USD', 'MXN', 'EUR'];

  // Nombres de Colecciones en Firestore
  static const String usersCollection = 'users';
  static const String clientsCollection = 'clients';
  static const String creditsCollection = 'credits';
  static const String installmentsSubCollection = 'installments';
  static const String paymentsSubCollection = 'payments';
  static const String configCollection = 'appConfig';
  static const String appointmentsCollection = 'appointments';

  // ID de la configuración global en Firestore
  static const String globalConfigId = 'global';
}
