import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethod {
  cash,
  transfer,
  other;

  static PaymentMethod fromString(String method) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == method.toLowerCase(),
      orElse: () => PaymentMethod.cash,
    );
  }
}

class PaymentModel {
  final String paymentId;
  final String? creditId;
  final String registeredByUid;
  final DateTime paymentDate;
  final double amountReceived; // Dinero físico recibido

  // Cascada de distribución global (Prioridad 1→2→3)
  final double appliedToMora;      // P1: Mora acumulada
  final double appliedToInterest;  // P2: Interés corriente
  final double appliedToPrincipal; // P3: Abono a capital

  final List<int> affectedInstallmentNumbers;

  /// Distribución individual por cuota afectada.
  /// Clave: número de cuota como String (ej: "1", "2").
  /// Valor: mapa con claves 'mora', 'interes', 'capital'.
  final Map<String, Map<String, double>> installmentBreakdowns;

  final PaymentMethod paymentMethod;
  final String? receiptNumber;
  final String? notes;
  final DateTime createdAt;

  PaymentModel({
    required this.paymentId,
    this.creditId,
    required this.registeredByUid,
    required this.paymentDate,
    required this.amountReceived,
    required this.appliedToMora,
    required this.appliedToInterest,
    required this.appliedToPrincipal,
    required this.affectedInstallmentNumbers,
    this.installmentBreakdowns = const {},
    required this.paymentMethod,
    this.receiptNumber,
    this.notes,
    required this.createdAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String documentId, {String? creditId}) {
    // Deserializar installmentBreakdowns desde Firestore
    final rawBreakdowns = map['installmentBreakdowns'] as Map<String, dynamic>? ?? {};
    final Map<String, Map<String, double>> breakdowns = {};
    for (final entry in rawBreakdowns.entries) {
      final innerMap = entry.value as Map<String, dynamic>? ?? {};
      breakdowns[entry.key] = {
        'mora': (innerMap['mora'] as num?)?.toDouble() ?? 0.0,
        'interes': (innerMap['interes'] as num?)?.toDouble() ?? 0.0,
        'capital': (innerMap['capital'] as num?)?.toDouble() ?? 0.0,
      };
    }

    return PaymentModel(
      paymentId: documentId,
      creditId: creditId ?? map['creditId'],
      registeredByUid: map['registeredByUid'] ?? '',
      paymentDate: (map['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amountReceived: (map['amountReceived'] as num?)?.toDouble() ?? 0.0,
      appliedToMora: (map['appliedToMora'] as num?)?.toDouble() ?? 0.0,
      appliedToInterest: (map['appliedToInterest'] as num?)?.toDouble() ?? 0.0,
      appliedToPrincipal: (map['appliedToPrincipal'] as num?)?.toDouble() ?? 0.0,
      affectedInstallmentNumbers:
          List<int>.from(map['affectedInstallmentNumbers'] ?? []),
      installmentBreakdowns: breakdowns,
      paymentMethod: PaymentMethod.fromString(map['paymentMethod'] ?? 'cash'),
      receiptNumber: map['receiptNumber'],
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (creditId != null) 'creditId': creditId,
      'registeredByUid': registeredByUid,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'amountReceived': amountReceived,
      'appliedToMora': appliedToMora,
      'appliedToInterest': appliedToInterest,
      'appliedToPrincipal': appliedToPrincipal,
      'affectedInstallmentNumbers': affectedInstallmentNumbers,
      'installmentBreakdowns': installmentBreakdowns,
      'paymentMethod': paymentMethod.name,
      'receiptNumber': receiptNumber,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
