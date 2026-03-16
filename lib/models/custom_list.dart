class CustomList {
  final String id;
  final String name;
  final List<String> movieIds;

  CustomList({required this.id, required this.name, required this.movieIds});

  String get formattedName {
    if (name.isEmpty) return '';
    return name
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  factory CustomList.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return CustomList(
      id: documentId,
      name: data['name'] ?? 'Unnamed List',
      movieIds: List<String>.from(data['movieIds'] ?? []),
    );
  }
}
