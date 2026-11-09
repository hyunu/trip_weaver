import 'model/models.dart';

const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String weekdayKo(DateTime date) => weekdays[date.weekday - 1];

String formatDot(DateTime date) => '${date.year}.${date.month}.${date.day}';

String formatRange(DateTime start, DateTime end) {
  if (start.year == end.year) {
    return '${formatDot(start)} – ${end.month}.${end.day}';
  }
  return '${formatDot(start)} – ${formatDot(end)}';
}

String formatHm(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatStamp(DateTime? date) {
  if (date == null) return '없음';
  return '${formatDot(date)} ${formatHm(date)}';
}

String formatMonthDay(DateTime date) => '${date.month}월 ${date.day}일';

String cityTripLabel(String? cityName, String tripTitle) {
  if (cityName == null || cityName.isEmpty) return displayTitle(tripTitle);
  return '$cityName · ${displayTitle(tripTitle)}';
}

String displayTitle(String title) => title.trim().isEmpty ? '제목 없는 여행' : title;

/// City names for a trip card; long lists name the first three only.
String citySummary(Trip trip, {int shown = 3}) {
  final names = trip.cities.map((city) => city.name.trim().isEmpty ? '이름 없는 도시' : city.name).toList();
  if (names.isEmpty) return '도시 없음';
  if (names.length <= shown) return '${names.join(', ')} · 도시 ${names.length}곳';
  return '${names.take(shown).join(', ')} 외 ${names.length - shown}곳 · 도시 ${names.length}곳';
}

String itemTimeLabel(PlanItem item) {
  if (item.start != null && item.end != null) {
    final minutes = item.end!.difference(item.start!).inMinutes;
    return '${formatHm(item.start!)}–${formatHm(item.end!)} · $minutes분';
  }
  if (item.start != null) return formatHm(item.start!);
  return '시각 없음';
}

String kindLabel(ItemKind kind) {
  switch (kind) {
    case ItemKind.move:
      return '이동';
    case ItemKind.stay:
      return '체류';
    case ItemKind.meal:
      return '식사';
    case ItemKind.rest:
      return '휴식';
    case ItemKind.gap:
      return '미확인';
  }
}

String categoryLabel(PlaceCategory category) {
  switch (category) {
    case PlaceCategory.attraction:
      return '관광지';
    case PlaceCategory.restaurant:
      return '음식점';
    case PlaceCategory.shopping:
      return '쇼핑';
    case PlaceCategory.culture:
      return '문화시설';
  }
}

String statusLabel(TripStatus status) {
  switch (status) {
    case TripStatus.draft:
      return '초안';
    case TripStatus.active:
      return '진행 중';
    case TripStatus.completed:
      return '지난 여행';
    case TripStatus.archived:
      return '보관';
  }
}

String decisionLabel(Decision decision, {required bool saved}) {
  switch (decision) {
    case Decision.selected:
      return saved ? '일정에 선택됨 · 관심' : '일정에 선택됨';
    case Decision.excluded:
      return '제외됨';
    case Decision.none:
      return saved ? '관심' : '선택 전';
  }
}

String warningLabel(ItemWarning warning) {
  switch (warning) {
    case ItemWarning.hoursUnconfirmed:
      return '운영시간이 확인되지 않았습니다';
    case ItemWarning.closureUnconfirmed:
      return '휴무 여부가 확인되지 않았습니다';
    case ItemWarning.hoursConflict:
      return '운영시간 자료가 서로 다릅니다';
    case ItemWarning.outsideHours:
      return '확인된 운영시간 밖입니다';
    case ItemWarning.cityUnassigned:
      return '이 날짜의 도시가 지정되지 않았습니다';
    case ItemWarning.estimatedGeometry:
      return '직선 거리 기반 추정, 실제 경로 아님';
    case ItemWarning.noReplacement:
      return '대체 장소가 없습니다';
    case ItemWarning.weatherUnavailable:
      return '날씨 자료가 없어 날씨로 일정을 바꾸지 않았습니다';
  }
}

String badgeLabel(FactValidity validity) {
  switch (validity) {
    case FactValidity.corroborated:
      return '확인됨';
    case FactValidity.collected:
      return '출처 1곳, 미확인';
    case FactValidity.conflicted:
      return '출처마다 다릅니다';
    case FactValidity.stale:
      return '다시 확인이 필요합니다';
    case FactValidity.suspended:
      return '운영 중단 또는 폐업 자료가 있습니다';
    case FactValidity.unknown:
      return '확인되지 않음';
  }
}

FactValidity rowBadge(Place place) {
  final values = place.claims.map((claim) => claim.validity).toSet();
  if (values.contains(FactValidity.suspended)) return FactValidity.suspended;
  if (values.contains(FactValidity.conflicted)) return FactValidity.conflicted;
  if (values.contains(FactValidity.stale)) return FactValidity.stale;
  if (values.contains(FactValidity.collected)) return FactValidity.collected;
  if (values.contains(FactValidity.unknown)) return FactValidity.unknown;
  if (values.contains(FactValidity.corroborated)) return FactValidity.corroborated;
  return FactValidity.unknown;
}

String sourceKindLabel(SourceKind kind) {
  switch (kind) {
    case SourceKind.official:
      return '공식 자료';
    case SourceKind.review:
      return '후기';
    case SourceKind.user:
      return '직접 입력';
  }
}

String fieldLabel(String field) {
  switch (field) {
    case 'coordinate':
      return '좌표';
    case 'address':
      return '주소';
    case 'localAddress':
      return '현지어 주소';
    case 'hours':
      return '운영시간';
    case 'closure':
      return '휴무';
    case 'price':
      return '가격';
    case 'reservation':
      return '예약';
    case 'business':
      return '폐업';
    default:
      return field;
  }
}

const factFieldOrder = ['coordinate', 'address', 'localAddress', 'hours', 'closure', 'price', 'reservation', 'business'];

String addressLine(Place place) {
  final rows = place.claimsFor('address');
  if (rows.isEmpty) return '주소 미확인';
  final values = rows.map((claim) => claim.value).toSet();
  if (rows.any((claim) => claim.validity == FactValidity.conflicted) || values.length > 1) {
    return '주소는 출처마다 다릅니다';
  }
  return rows.first.value ?? '주소 미확인';
}

String moneyLabel(int? amount, String? currency) {
  if (amount == null || currency == null) return '예산 없음';
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final fromEnd = digits.length - index;
    buffer.write(digits[index]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return '$buffer $currency';
}
