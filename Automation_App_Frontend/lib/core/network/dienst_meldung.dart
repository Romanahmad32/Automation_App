import 'package:dio/dio.dart';

/// Der Klartext, den der Dienst einer fehlgeschlagenen Anfrage mitgibt.
///
/// Das Backend antwortet auf 400 und 409 mit einem fertigen deutschen Satz —
/// welcher Name schon vergeben ist, welches Pflichtfeld fehlt. Ohne ihn bliebe
/// im Dialog nur „Fehler 409" stehen, und der Anwalt wüsste nicht, was er
/// ändern soll. null heisst: Der Dienst hat nichts geschickt, dann setzt der
/// Aufrufer seinen eigenen Satz ein.
///
/// Eine Stelle statt einer je Datasource (zusammengezogen am 03.09.2026): Die
/// drei Mail-Bestände trugen dieselben fünf Zeilen dreimal.
class DienstMeldung {
  const DienstMeldung._();

  static String? aus(DioException fehler) {
    final daten = fehler.response?.data;
    if (daten is String && daten.trim().isNotEmpty) return daten.trim();
    return null;
  }
}
