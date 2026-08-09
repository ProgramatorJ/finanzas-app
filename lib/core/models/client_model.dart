import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel extends Equatable {
  final String clientId;
  final String fullName;
  final String idNumber;
  final String phone;
  final String address;
  final List<String> assignedCollectorIds;
  final String createdByUid;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClientModel({
    required this.clientId,
    required this.fullName,
    required this.idNumber,
    required this.phone,
    required this.address,
    required this.assignedCollectorIds,
    required this.createdByUid,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClientModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ClientModel(
      clientId: documentId,
      fullName: map['fullName'] ?? '',
      idNumber: map['idNumber'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      assignedCollectorIds: List<String>.from(map['assignedCollectorIds'] ?? []),
      createdByUid: map['createdByUid'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'idNumber': idNumber,
      'phone': phone,
      'address': address,
      'assignedCollectorIds': assignedCollectorIds,
      'createdByUid': createdByUid,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ClientModel copyWith({
    String? clientId,
    String? fullName,
    String? idNumber,
    String? phone,
    String? address,
    List<String>? assignedCollectorIds,
    String? createdByUid,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientModel(
      clientId: clientId ?? this.clientId,
      fullName: fullName ?? this.fullName,
      idNumber: idNumber ?? this.idNumber,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      assignedCollectorIds: assignedCollectorIds ?? this.assignedCollectorIds,
      createdByUid: createdByUid ?? this.createdByUid,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [clientId, fullName, idNumber, phone, address, assignedCollectorIds, createdByUid, isActive, createdAt, updatedAt];
}
