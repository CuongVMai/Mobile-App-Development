class CatalogCard {
  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  const CatalogCard({this.id, required this.title, required this.suit,
    this.notes = '', this.imageRef, required this.folderId});

  factory CatalogCard.fromMap(Map<String, Object?> map) => CatalogCard(
    id: map['id'] as int,
    title: map['title'] as String,
    suit: map['suit'] as String,
    notes: map['notes'] as String? ?? '',
    imageRef: map['image_ref'] as String?,
    folderId: map['folder_id'] as int,
  );

  Map<String, Object?> toMap() => {
    'title': title,
    'suit': suit,
    'notes': notes,
    'image_ref': imageRef,
    'folder_id': folderId,
  };
}
