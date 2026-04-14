import 'package:flutter/foundation.dart';

@immutable
class FrequentGuest {
  final int? id;
  final String name;
  final String idType;
  final String idNumber;
  final String? phone;
  final String relationship;

  const FrequentGuest({
    this.id,
    required this.name,
    this.idType = 'idcard',
    this.idNumber = '',
    this.phone,
    this.relationship = 'self',
  });

  factory FrequentGuest.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['id_type'] ??= normalized['idType'] ?? normalized['document_type'] ?? 'idcard';
    normalized['id_number'] ??= normalized['idNumber'] ?? normalized['id_card'] ?? normalized['document_number'] ?? '';
    normalized['relationship'] ??= normalized['relation'] ?? 'self';

    return FrequentGuest(
      id: normalized['id'] as int?,
      name: normalized['name']?.toString() ?? '',
      idType: normalized['id_type']?.toString() ?? 'idcard',
      idNumber: normalized['id_number']?.toString() ?? '',
      phone: normalized['phone']?.toString(),
      relationship: normalized['relationship']?.toString() ?? 'self',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'id_type': idType,
      'id_number': idNumber,
      'phone': phone ?? '',
      'relationship': relationship,
    };
  }

  String get idTypeLabel {
    switch (idType) {
      case 'idcard': return '身份证';
      case 'passport': return '护照';
      case 'hk_macao': return '港澳通行证';
      default: return '证件';
    }
  }

  String get relationshipLabel {
    switch (relationship) {
      case 'self': return '本人';
      case 'spouse': return '配偶';
      case 'child': return '子女';
      case 'parent': return '父母';
      case 'friend': return '朋友';
      case 'colleague': return '同事';
      default: return '其他';
    }
  }

  String get maskedIdNumber {
    if (idNumber.isEmpty) return '-';
    if (idNumber.length <= 10) return idNumber;
    return '${idNumber.substring(0, 6)}********${idNumber.substring(14)}';
  }

  FrequentGuest copyWith({int? id, String? name, String? idType, String? idNumber, String? phone, String? relationship}) {
    return FrequentGuest(
      id: id ?? this.id,
      name: name ?? this.name,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
    );
  }
}
