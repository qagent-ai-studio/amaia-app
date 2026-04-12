class Alive {
  final String status;
  final String message;

  Alive({required this.status, required this.message});

  factory Alive.fromJson(Map<String, dynamic> json) {
    return Alive(
        status: json['status'], message: json['message']);
  }
}
