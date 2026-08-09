import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum InstallmentStatus {
  pending,
  partial,
  paid,
  overdue,
  consolidated;

  static InstallmentStatus fromString(String status) {
    return InstallmentStatus.values.firstWhere(
      (e) => e.name == status.toLowerCase(),
      orElse: () => InstallmentStatus.pending,
    );
  }
}

class InstallmentModel extends Equatable {
  final String installmentId;
  final String? creditId;
  final int installmentNumber;
  final DateTime dueDate;

  // Composición de la cuota
  final double principalPortion;      // Porción asignada a capital
  final double interestPortion;       // Porción asignada a interés corriente
  final double scheduledAmount;       // principalPortion + interestPortion

  // Estado de pago
  final InstallmentStatus status;
  final double paidAmount;            // Cuánto se ha pagado en total
  final double remainingAmount;       // Cuánto falta por pagar (scheduledAmount - paidAmount)

  // Motor de Mora
  final bool isMoraActive;
  final DateTime? moraStartDate;      // Fecha desde la cual aplica la mora (due date + 1)
  final double dailyMoraRate;          // Tasa de mora diaria copiada del crédito
  final double moraBase;              // Monto sobre el cual se calcula la mora
  final double accumulatedMora;       // Mora acumulada total calculada
  final double moraPaid;              // Mora ya cobrada de esta cuota
  final bool isMoraExempt;            // Indica si la cuota está exenta de cobrar mora

  // Consolidación (Bola de Nieve)
  final bool isConsolidated;
  final int? consolidatedIntoInstallment; // Número de la cuota en la que se consolidó
  final DateTime? consolidationDate;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Configuración de alarma
  final int alarmHour;
  final int alarmMinute;
  final bool isAlarmEnabled;
  final bool isAlarmSilent;

  InstallmentModel({
    required this.installmentId,
    this.creditId,
    required this.installmentNumber,
    required this.dueDate,
    required this.principalPortion,
    required this.interestPortion,
    required this.scheduledAmount,
    required this.status,
    required this.paidAmount,
    required this.remainingAmount,
    required this.isMoraActive,
    this.moraStartDate,
    required this.dailyMoraRate,
    required this.moraBase,
    required this.accumulatedMora,
    required this.moraPaid,
    required this.isConsolidated,
    this.consolidatedIntoInstallment,
    this.consolidationDate,
    required this.createdAt,
    required this.updatedAt,
    this.alarmHour = 9,
    this.alarmMinute = 0,
    this.isAlarmEnabled = true,
    this.isAlarmSilent = false,
    this.isMoraExempt = false,
  });

  factory InstallmentModel.fromMap(Map<String, dynamic> map, String documentId, {String? creditId}) {
    return InstallmentModel(
      installmentId: documentId,
      creditId: creditId ?? map['creditId'],
      installmentNumber: map['installmentNumber'] ?? 1,
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      principalPortion: (map['principalPortion'] as num?)?.toDouble() ?? 0.0,
      interestPortion: (map['interestPortion'] as num?)?.toDouble() ?? 0.0,
      scheduledAmount: (map['scheduledAmount'] as num?)?.toDouble() ?? 0.0,
      status: InstallmentStatus.fromString(map['status'] ?? 'pending'),
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      isMoraActive: map['isMoraActive'] ?? false,
      moraStartDate: (map['moraStartDate'] as Timestamp?)?.toDate() ?? (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dailyMoraRate: (map['dailyMoraRate'] as num?)?.toDouble() ?? 0.007,
      moraBase: (map['moraBase'] as num?)?.toDouble() ?? 0.0,
      accumulatedMora: (map['accumulatedMora'] as num?)?.toDouble() ?? 0.0,
      moraPaid: (map['moraPaid'] as num?)?.toDouble() ?? 0.0,
      isConsolidated: map['isConsolidated'] ?? false,
      consolidatedIntoInstallment: map['consolidatedIntoInstallment'],
      consolidationDate: (map['consolidationDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      alarmHour: map['alarmHour'] ?? 9,
      alarmMinute: map['alarmMinute'] ?? 0,
      isAlarmEnabled: map['isAlarmEnabled'] ?? true,
      isAlarmSilent: map['isAlarmSilent'] ?? false,
      isMoraExempt: map['isMoraExempt'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (creditId != null) 'creditId': creditId,
      'installmentNumber': installmentNumber,
      'dueDate': Timestamp.fromDate(dueDate),
      'principalPortion': principalPortion,
      'interestPortion': interestPortion,
      'scheduledAmount': scheduledAmount,
      'status': status.name,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'isMoraActive': isMoraActive,
      'moraStartDate': moraStartDate != null ? Timestamp.fromDate(moraStartDate!) : null,
      'dailyMoraRate': dailyMoraRate,
      'moraBase': moraBase,
      'accumulatedMora': accumulatedMora,
      'moraPaid': moraPaid,
      'isConsolidated': isConsolidated,
      'consolidatedIntoInstallment': consolidatedIntoInstallment,
      'consolidationDate': consolidationDate != null ? Timestamp.fromDate(consolidationDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'alarmHour': alarmHour,
      'alarmMinute': alarmMinute,
      'isAlarmEnabled': isAlarmEnabled,
      'isAlarmSilent': isAlarmSilent,
      'isMoraExempt': isMoraExempt,
    };
  }

  InstallmentModel copyWith({
    String? installmentId,
    String? creditId,
    int? installmentNumber,
    DateTime? dueDate,
    double? principalPortion,
    double? interestPortion,
    double? scheduledAmount,
    InstallmentStatus? status,
    double? paidAmount,
    double? remainingAmount,
    bool? isMoraActive,
    DateTime? moraStartDate,
    double? dailyMoraRate,
    double? moraBase,
    double? accumulatedMora,
    double? moraPaid,
    bool? isConsolidated,
    int? consolidatedIntoInstallment,
    DateTime? consolidationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? alarmHour,
    int? alarmMinute,
    bool? isAlarmEnabled,
    bool? isAlarmSilent,
    bool? isMoraExempt,
  }) {
    return InstallmentModel(
      installmentId: installmentId ?? this.installmentId,
      creditId: creditId ?? this.creditId,
      installmentNumber: installmentNumber ?? this.installmentNumber,
      dueDate: dueDate ?? this.dueDate,
      principalPortion: principalPortion ?? this.principalPortion,
      interestPortion: interestPortion ?? this.interestPortion,
      scheduledAmount: scheduledAmount ?? this.scheduledAmount,
      status: status ?? this.status,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      isMoraActive: isMoraActive ?? this.isMoraActive,
      moraStartDate: moraStartDate ?? this.moraStartDate,
      dailyMoraRate: dailyMoraRate ?? this.dailyMoraRate,
      moraBase: moraBase ?? this.moraBase,
      accumulatedMora: accumulatedMora ?? this.accumulatedMora,
      moraPaid: moraPaid ?? this.moraPaid,
      isConsolidated: isConsolidated ?? this.isConsolidated,
      consolidatedIntoInstallment: consolidatedIntoInstallment ?? this.consolidatedIntoInstallment,
      consolidationDate: consolidationDate ?? this.consolidationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      alarmHour: alarmHour ?? this.alarmHour,
      alarmMinute: alarmMinute ?? this.alarmMinute,
      isAlarmEnabled: isAlarmEnabled ?? this.isAlarmEnabled,
      isAlarmSilent: isAlarmSilent ?? this.isAlarmSilent,
      isMoraExempt: isMoraExempt ?? this.isMoraExempt,
    );
  }

  @override
  List<Object?> get props => [installmentId, creditId, installmentNumber, dueDate, principalPortion, interestPortion, scheduledAmount, status, paidAmount, remainingAmount, isMoraActive, moraStartDate, dailyMoraRate, moraBase, accumulatedMora, moraPaid, isMoraExempt, isConsolidated, consolidatedIntoInstallment, consolidationDate, createdAt, updatedAt, alarmHour, alarmMinute, isAlarmEnabled, isAlarmSilent];
}
