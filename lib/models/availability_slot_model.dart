class AvailabilitySlot {
  final String? id;
  final String workerId;
  final int dayOfWeek;
  final String period;
  final bool isAvailable;

  AvailabilitySlot({
    this.id,
    required this.workerId,
    required this.dayOfWeek,
    required this.period,
    this.isAvailable = true,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      id: json['id'] as String?,
      workerId: json['worker_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      period: json['period'] as String,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'worker_id': workerId,
      'day_of_week': dayOfWeek,
      'period': period,
      'is_available': isAvailable,
    };
  }

  AvailabilitySlot copyWith({bool? isAvailable}) {
    return AvailabilitySlot(
      id: id,
      workerId: workerId,
      dayOfWeek: dayOfWeek,
      period: period,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
