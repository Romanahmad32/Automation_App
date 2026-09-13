import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';

/// Eine Tagesgruppe der Posteingangsliste: alle Zeilen desselben Kalendertags,
/// in der Reihenfolge, in der sie ankamen.
class PosteingangTagesgruppe {
  final DateTime tag;
  final List<PosteingangEintrag> eintraege;
  const PosteingangTagesgruppe({required this.tag, required this.eintraege});

  /// Der Tagesanfang (00:00 Uhr lokal) zu einem Zeitpunkt — Vergleichsgrundlage
  /// für die Gruppierung und für „Heute"/„Gestern". Nachrichten ohne Datum
  /// (der Dienst liefert es praktisch immer) landen zusammen auf dem
  /// 1.1.1970, statt die Gruppierung der übrigen Zeilen zu stören.
  static DateTime tagVon(DateTime? zeitpunkt) {
    final wert = zeitpunkt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime(wert.year, wert.month, wert.day);
  }
}

/// Gruppiert Posteingangszeilen nach Kalendertag, ohne die Reihenfolge
/// innerhalb eines Tages zu verändern. Die Gruppen selbst stehen in der
/// Reihenfolge, in der ihr erster Eintrag auftaucht — bei der servergegebenen
/// Sortierung (neueste zuerst) ist das absteigend nach Datum.
List<PosteingangTagesgruppe> gruppierePosteingangNachTag(
  List<PosteingangEintrag> eintraege,
) {
  final gruppen = <DateTime, List<PosteingangEintrag>>{};
  for (final eintrag in eintraege) {
    final tag = PosteingangTagesgruppe.tagVon(eintrag.datum);
    (gruppen[tag] ??= <PosteingangEintrag>[]).add(eintrag);
  }
  return [
    for (final eintrag in gruppen.entries)
      PosteingangTagesgruppe(tag: eintrag.key, eintraege: eintrag.value),
  ];
}

/// Die Beschriftung einer Tagesgruppe (§4.5): „Heute", „Gestern" oder der
/// Wochentag innerhalb der letzten sieben Tage, jeweils gefolgt von
/// `· TT.MM.JJJJ` — darüber hinaus nur das Datum. [jetzt] ist ausschließlich
/// für Tests gedacht, sonst die tatsächliche Zeit.
String posteingangTagesbeschriftung(DateTime tag, {DateTime? jetzt}) {
  final heute = PosteingangTagesgruppe.tagVon(jetzt ?? DateTime.now());
  final differenz = heute.difference(tag).inDays;
  final datum = deutschesDatum(tag);
  if (differenz == 0) return 'Heute · $datum';
  if (differenz == 1) return 'Gestern · $datum';
  if (differenz > 1 && differenz < 7) {
    const wochentage = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];
    return '${wochentage[tag.weekday - 1]} · $datum';
  }
  return datum;
}
