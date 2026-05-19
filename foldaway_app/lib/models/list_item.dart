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
  final double? latitude;
  final double? longitude;
  

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
    this.latitude,
    this.longitude,
  });

  factory ListItem.fromJson(Map<String, dynamic> json) {
    return ListItem(
      id: json['id'].toString(),
      listId: json['list'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      mapSymbol: json['map_symbol'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      externalLink: json['external_link'] ?? '',
      isDone: json['is_done'] ?? false,
      position: json['position'] ?? 0,
      latitude: _toDoubleOrNull(json['latitude']),
      longitude: _toDoubleOrNull(json['longitude']),
    );
  }
  
  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    if (value is String) {
      if (value.trim().isEmpty) return null;
      return double.tryParse(value);
    }

    return null;
  }
}