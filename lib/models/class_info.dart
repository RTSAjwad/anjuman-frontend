class ClassInfo {
  final int id;
  final String name;

  ClassInfo({required this.id, required this.name});

  factory ClassInfo.fromJson(Map<String, dynamic> json) =>
      ClassInfo(id: json['id'], name: json['name']);
}
