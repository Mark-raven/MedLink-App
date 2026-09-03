class Medicine {
  final String name;
  final int hour;
  final int minute;

  Medicine({required this.name, required this.hour, required this.minute});

  Map<String, dynamic> toJson() {
    return {'name': name, 'hour': hour, 'minute': minute};
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json['name'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
    );
  }
}
