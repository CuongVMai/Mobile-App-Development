class Folder {
  final int? id;
  final String name;
  final String createdAt;
  final int cardCount;

  const Folder({this.id, required this.name, required this.createdAt, this.cardCount = 0});

  factory Folder.fromMap(Map<String, Object?> map) => Folder(
    id: map['id'] as int,
    name: map['name'] as String,
    createdAt: map['created_at'] as String,
    cardCount: (map['card_count'] as int?) ?? 0,
  );

  Map<String, Object?> toMap() => {
    'name': name,
    'created_at': createdAt,
  };
}
