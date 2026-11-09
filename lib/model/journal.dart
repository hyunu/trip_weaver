import 'models.dart';

class JournalBook {
  final Map<String, Map<String, String>> _byTrip = {};

  String? text(String tripId, DateTime day) {
    final note = _byTrip[tripId]?[journalDayKey(day)];
    if (note == null || note.isEmpty) return null;
    return note;
  }

  bool has(String tripId, DateTime day) => text(tripId, day) != null;

  /// Saves trimmed text for one trip day. Blank text removes the note.
  /// Returns whether the stored note changed.
  bool save(String tripId, DateTime day, String raw) {
    final key = journalDayKey(day);
    final notes = _byTrip.putIfAbsent(tripId, () => <String, String>{});
    final next = raw.trim();
    final previous = notes[key] ?? '';
    if (next == previous) return false;
    if (next.isEmpty) {
      notes.remove(key);
      if (notes.isEmpty) _byTrip.remove(tripId);
    } else {
      notes[key] = next;
    }
    return true;
  }

  Map<String, Map<String, String>> export() => {
    for (final entry in _byTrip.entries) entry.key: Map.of(entry.value),
  };

  void replaceAll(Map<String, Map<String, String>> notes) {
    _byTrip
      ..clear()
      ..addAll({
        for (final entry in notes.entries)
          if (entry.value.isNotEmpty) entry.key: Map.of(entry.value),
      });
  }
}

String journalDayKey(DateTime value) {
  final day = dateOnly(value);
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}
