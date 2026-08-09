import 'package:equatable/equatable.dart';
import '../enums/adjustment_type.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para ajustes manuales de caja.
/// Permite al usuario corregir el saldo real cuando hay movimientos
/// históricos que no fueron registrados en el sistema.
class CashAdjustmentModel extends Equatable {
  final String adjustmentId;
  final double amount;          // Puede ser positivo (entrada) o negativo (salida)
  final String description;
  final DateTime date;          // Fecha real del ajuste (editable)
  final String createdBy;
  final DateTime createdAt;     // Timestamp de cuándo se registró en el sistema

  CashAdjustmentModel({
    required this.adjustmentId,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'adjustmentId': adjustmentId,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CashAdjustmentModel.fromMap(Map<String, dynamic> map, String id) {
    return CashAdjustmentModel(
      adjustmentId: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }


  CashAdjustmentModel copyWith({
    String? adjustmentId,
    double? amount,
    String? description,
    DateTime? date,
    String? createdBy,
    DateTime? createdAt
  }) {
    return CashAdjustmentModel(
      adjustmentId: adjustmentId ?? this.adjustmentId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt
    );
  }
  @override
  List<Object?> get props => [adjustmentId, amount, description, date, createdBy, createdAt];
}
