class Supplier {
  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String? address;
  final String? notes;

  Supplier({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    this.address,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as String,
        name: map['name'] as String,
        contactPerson: map['contactPerson'] as String,
        phone: map['phone'] as String,
        email: map['email'] as String,
        address: map['address'] as String?,
        notes: map['notes'] as String?,
      );

  Supplier copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) =>
      Supplier(
        id: id,
        name: name ?? this.name,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        notes: notes ?? this.notes,
      );
}
