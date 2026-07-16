/// A user-defined event category (e.g. 본당 행사, 성당 청소, 연령회).
///
/// Replaces free-text event titles: the user builds their own set of
/// categories and picks one when adding an event. Stored on-device only.
class EventCategory {
  const EventCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  /// Stable local id.
  final String id;

  /// User-visible label; this becomes the event's title.
  final String name;

  /// ARGB color value used for the category swatch / event accent.
  final int color;

  EventCategory copyWith({String? id, String? name, int? color}) {
    return EventCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory EventCategory.fromJson(Map<String, dynamic> json) => EventCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    color: (json['color'] as num).toInt(),
  );
}
