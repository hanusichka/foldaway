class Trip {
  final String id;
  final String title;
  final String destination;
  final String? startDate;
  final String? endDate;
  final String? coverImageUrl;

  Trip({
    required this.id,
    required this.title,
    required this.destination,
    this.startDate,
    this.endDate,
    this.coverImageUrl,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      title: json['title'],
      destination: json['destination'] ?? '',
      startDate: json['start_date'],
      endDate: json['end_date'],
      coverImageUrl: json['cover_image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'destination': destination,
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}