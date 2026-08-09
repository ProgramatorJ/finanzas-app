import 'package:finanzas_app/core/enums/user_role.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class UserModel extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final List<String> assignedClientIds;
  final bool isActive;
  final bool canViewAllClientPayments;
  final bool canViewOtherClients;
  final bool canViewOtherTreasury;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.assignedClientIds,
    required this.isActive,
    this.canViewAllClientPayments = false,
    this.canViewOtherClients = false,
    this.canViewOtherTreasury = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Constructor para crear un UserModel desde un mapa de Firestore
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    final email = map['email'] ?? '';
    final role = (email == 'admin@gestor.com' || map['isAdmin'] == true) 
        ? UserRole.admin 
        : UserRole.fromString(map['role'] ?? 'cobrador');

    return UserModel(
      uid: documentId,
      email: email,
      displayName: map['displayName'] ?? '',
      role: role,
      assignedClientIds: List<String>.from(map['assignedClientIds'] ?? []),
      isActive: map['isActive'] ?? true,
      canViewAllClientPayments: map['canViewAllClientPayments'] ?? false,
      canViewOtherClients: map['canViewOtherClients'] ?? false,
      canViewOtherTreasury: map['canViewOtherTreasury'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convertir a Mapa para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'assignedClientIds': assignedClientIds,
      'isActive': isActive,
      'canViewAllClientPayments': canViewAllClientPayments,
      'canViewOtherClients': canViewOtherClients,
      'canViewOtherTreasury': canViewOtherTreasury,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Copiar objeto con modificaciones (utilidad común)
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    List<String>? assignedClientIds,
    bool? isActive,
    bool? canViewAllClientPayments,
    bool? canViewOtherClients,
    bool? canViewOtherTreasury,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      assignedClientIds: assignedClientIds ?? this.assignedClientIds,
      isActive: isActive ?? this.isActive,
      canViewAllClientPayments: canViewAllClientPayments ?? this.canViewAllClientPayments,
      canViewOtherClients: canViewOtherClients ?? this.canViewOtherClients,
      canViewOtherTreasury: canViewOtherTreasury ?? this.canViewOtherTreasury,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [uid, email, displayName, role, assignedClientIds, isActive, canViewAllClientPayments, canViewOtherClients, canViewOtherTreasury, createdAt, updatedAt];
}
