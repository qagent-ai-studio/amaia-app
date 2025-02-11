class Information {
  final int id;
  final String name;
  final dynamic value;

  Information({required this.id, required this.name, required this.value});

  // Método para convertir un QueryRow (desde sqlite) a un objeto Information
  factory Information.fromMap(Map<String, dynamic> map) {
    return Information(
      id: map['id'],
      name: map['name'],
      value: map['value'],
    );
  }
}
