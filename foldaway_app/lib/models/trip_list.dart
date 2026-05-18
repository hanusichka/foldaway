class TripList {
  final String id;
  final String trip;
  final String title;
  final String icon;
  final String? coverImageUrl;
  final int position;

  TripList({
    required this.id,
    required this.trip,
    required this.title,
    required this.icon,
    required this.coverImageUrl,
    required this.position,
  });

  factory TripList.fromJson(Map<String, dynamic> json) {
    return TripList(
      id: json['id'].toString(),
      trip: json['trip'].toString(),
      title: json['title'] ?? '',
      icon: json['icon'] ?? '📍',
      coverImageUrl: json['cover_image_url'],
      position: json['position'] ?? 0,
    );
  }
}