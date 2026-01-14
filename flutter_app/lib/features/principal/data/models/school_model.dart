import 'package:equatable/equatable.dart';

class SchoolModel extends Equatable {
  final String id;
  final String name;
  final String? code;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? phone;
  final String? website;
  final String? logo;
  final Map<String, int>? counts;
  final List<Map<String, dynamic>>? gradingScale;

  const SchoolModel({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.phone,
    this.website,
    this.logo,
    this.counts,
    this.gradingScale,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'],
      address: json['address'],
      city: json['city'],
      state: json['state'],
      country: json['country'],
      postalCode: json['postalCode'],
      phone: json['phone'],
      website: json['website'],
      logo: json['logo'],
      counts:
          json['_count'] != null ? Map<String, int>.from(json['_count']) : null,
      gradingScale: json['gradingScale'] != null
          ? List<Map<String, dynamic>>.from(json['gradingScale'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, name, code];
}
