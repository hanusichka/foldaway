class ListItem {
  final String id;
  final String listId;
  final String title;
  final String description;
  final String address;
  final String mapSymbol;
  final String photoUrl;
  final String externalLink;
  final bool isDone;
  final int position;

  ListItem({
    required this.id,
    required this.listId,
    required this.title,
    this.description = '',
    this.address = '',
    this.mapSymbol = '',
    this.photoUrl = '',
    this.externalLink = '',
    this.isDone = false,
    this.position = 0,
  });

  factory ListItem.fromJson(Map<String, dynamic> json) {
    return ListItem(
      id: json['id'],
      listId: json['list'],
      title: json['title'],
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      mapSymbol: json['map_symbol'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      externalLink: json['external_link'] ?? '',
      isDone: json['is_done'] ?? false,
      position: json['position'] ?? 0,
    );
  }
}