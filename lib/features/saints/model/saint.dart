class Saint {
  const Saint({
    required this.id,
    required this.nameKo,
    required this.nameLatin,
    this.feastMonth,
    this.feastDay,
    this.status = '',
    this.kind = '',
    this.regionKo = '',
    this.regionEn = '',
    this.yearText = '',
    this.url = '',
  });

  final int id;
  final String nameKo;
  final String nameLatin;
  final int? feastMonth;
  final int? feastDay;
  final String status;
  final String kind;
  final String regionKo;
  final String regionEn;
  final String yearText;
  final String url;

  String get feastLabel {
    if (feastMonth == null) return '축일 미상';
    final day = feastDay == null ? '' : ' ${feastDay!}일';
    return '${feastMonth!}월$day';
  }

  String get subtitle {
    final parts = [
      if (nameLatin.isNotEmpty) nameLatin,
      feastLabel,
      if (status.isNotEmpty) status,
      if (yearText.isNotEmpty) yearText,
    ];
    return parts.join(' · ');
  }

  factory Saint.fromJson(Map<String, dynamic> json) => Saint(
    id: (json['id'] as num).toInt(),
    nameKo: json['nameKo'] as String? ?? '',
    nameLatin: json['nameLatin'] as String? ?? '',
    feastMonth: (json['feastMonth'] as num?)?.toInt(),
    feastDay: (json['feastDay'] as num?)?.toInt(),
    status: json['status'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    regionKo: json['regionKo'] as String? ?? '',
    regionEn: json['regionEn'] as String? ?? '',
    yearText: json['yearText'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );
}
