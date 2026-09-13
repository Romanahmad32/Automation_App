import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_filter.dart';

class PosteingangState {
  /// Alle bisher geladenen Zeilen, über sämtliche geblätterten Seiten hinweg
  /// **angehängt** (Entscheidung 8.2 zu Issue #134) — gedeckelt bei [deckel].
  final List<PosteingangEintrag> eintraege;

  /// Die zuletzt vom Dienst gelieferte Seite — trägt nur noch die
  /// Blätterkennung der nächsten Seite und die Gesamtzahl im Ordner.
  final PosteingangSeite? seite;

  final PosteingangFilter filter;

  /// `eintrag.id` → erkannter Vorgangsbezug, neu berechnet über
  /// `PosteingangCubit.bezuegeNeuRechnen`.
  final Map<String, Vorgangsbezug> bezuege;

  /// Normalisierte Message-Ids **aller** je gemeldeten Zentralruf-Antworten
  /// (offen und übernommen) — wächst nur, schrumpft nie in der Sitzung.
  final Set<String> zentralrufSchluessel;

  /// Teilmenge von [zentralrufSchluessel], die laut dem letzten
  /// `merkeZentralruf`-Aufruf noch **offen** ist. Was in [zentralrufSchluessel]
  /// steht, aber nicht mehr hier, gilt als übernommen — `MailboxInboxCubit`
  /// lädt nur offene Treffer (`includeAcknowledged: false`), die
  /// Übernommen-Markierung ergibt sich also daraus, dass ein Schlüssel aus
  /// dieser Menge verschwindet, nicht aus einer eigenen Meldung.
  final Set<String> zentralrufOffen;

  /// „Nicht zuordnen" — nur für die Sitzung, ändert nichts am Vorgang
  /// (§4.5). Unterdrückt den Vorschlag aus [bezuege], siehe [bezugFuer].
  final Set<String> nichtZuordnen;

  final bool anhangLaedt;
  final PosteingangEintrag? auswahl;
  final PosteingangInhalt? inhalt;
  final bool laedt;
  final bool inhaltLaedt;
  final bool neueNachrichten;
  final int seitennummer;
  final String? fehler;
  final String? inhaltFehler;

  /// Höchstzahl gleichzeitig gehaltener Zeilen (Entscheidung 8.2): 10 Seiten
  /// zu 50. Darüber bietet die Fußzeile kein „Ältere laden" mehr an.
  static const int deckel = 500;

  const PosteingangState({
    this.eintraege = const [],
    this.seite,
    this.filter = PosteingangFilter.alle,
    this.bezuege = const {},
    this.zentralrufSchluessel = const {},
    this.zentralrufOffen = const {},
    this.nichtZuordnen = const {},
    this.anhangLaedt = false,
    this.auswahl,
    this.inhalt,
    this.laedt = false,
    this.inhaltLaedt = false,
    this.neueNachrichten = false,
    this.seitennummer = 1,
    this.fehler,
    this.inhaltFehler,
  });

  PosteingangState copyWith({
    List<PosteingangEintrag>? eintraege,
    PosteingangSeite? seite,
    PosteingangFilter? filter,
    Map<String, Vorgangsbezug>? bezuege,
    Set<String>? zentralrufSchluessel,
    Set<String>? zentralrufOffen,
    Set<String>? nichtZuordnen,
    bool? anhangLaedt,
    PosteingangEintrag? auswahl,
    PosteingangInhalt? inhalt,
    bool? laedt,
    bool? inhaltLaedt,
    bool? neueNachrichten,
    int? seitennummer,
    String? fehler,
    String? inhaltFehler,
    bool leereAuswahl = false,
    bool leereFehler = false,
    bool leereInhalt = false,
  }) => PosteingangState(
    eintraege: eintraege ?? this.eintraege,
    seite: seite ?? this.seite,
    filter: filter ?? this.filter,
    bezuege: bezuege ?? this.bezuege,
    zentralrufSchluessel: zentralrufSchluessel ?? this.zentralrufSchluessel,
    zentralrufOffen: zentralrufOffen ?? this.zentralrufOffen,
    nichtZuordnen: nichtZuordnen ?? this.nichtZuordnen,
    anhangLaedt: anhangLaedt ?? this.anhangLaedt,
    auswahl: leereAuswahl ? null : auswahl ?? this.auswahl,
    inhalt: leereAuswahl || leereInhalt ? null : inhalt ?? this.inhalt,
    laedt: laedt ?? this.laedt,
    inhaltLaedt: inhaltLaedt ?? this.inhaltLaedt,
    neueNachrichten: neueNachrichten ?? this.neueNachrichten,
    seitennummer: seitennummer ?? this.seitennummer,
    fehler: leereFehler ? null : fehler ?? this.fehler,
    inhaltFehler: leereAuswahl || leereInhalt
        ? null
        : inhaltFehler ?? this.inhaltFehler,
  );

  /// Ob noch eine ältere Seite zu holen wäre — entweder, weil der Dienst
  /// keine weitere Blätterkennung mehr liefert, oder weil der Deckel greift.
  bool get alleGeladen =>
      seite?.naechsteSeite == null || eintraege.length >= deckel;

  /// Der Vorschlag zu einer Zeile — `null`, wenn keiner erkannt wurde **oder**
  /// der Anwalt ihn mit „Nicht zuordnen" für diese Sitzung unterdrückt hat.
  Vorgangsbezug? bezugFuer(String eintragId) =>
      nichtZuordnen.contains(eintragId) ? null : bezuege[eintragId];

  /// `null` = keine erfasste Zentralruf-Antwort zu dieser Message-Id; `false`
  /// = erfasst und noch offen; `true` = erfasst und übernommen.
  bool? zentralrufFuer(String? messageId) {
    final schluessel = normalisiereMailSchluessel(messageId);
    if (schluessel == null || !zentralrufSchluessel.contains(schluessel)) {
      return null;
    }
    return !zentralrufOffen.contains(schluessel);
  }

  /// Die Zahl für den Zentralruf-Filterchip: alle geladenen Zeilen mit
  /// erkannter Zentralruf-Antwort, offen oder übernommen.
  int get zentralrufAnzahl =>
      eintraege.where((e) => zentralrufFuer(e.messageId) != null).length;

  /// Die geladenen Zeilen nach dem gewählten [filter] — die Grundlage für
  /// `posteingang_liste.dart`.
  List<PosteingangEintrag> get sichtbar {
    switch (filter) {
      case PosteingangFilter.alle:
        return eintraege;
      case PosteingangFilter.zentralruf:
        return eintraege
            .where((e) => zentralrufFuer(e.messageId) != null)
            .toList();
      case PosteingangFilter.mitVorgang:
        return eintraege.where((e) => bezugFuer(e.id) != null).toList();
      case PosteingangFilter.ohneBezug:
        return eintraege.where((e) => bezugFuer(e.id) == null).toList();
    }
  }
}

/// Vergleichbare Fassung einer Message-Id: getrimmt, ohne spitze Klammern,
/// kleingeschrieben — die Abgleichsregel zwischen
/// `ReceivedReply.mailSchluessel` und `PosteingangEintrag.messageId`. Als
/// öffentliche Funktion, damit Cubit und Widgets dieselbe Regel verwenden statt
/// sie zu verdoppeln.
String? normalisiereMailSchluessel(String? wert) {
  final roh = (wert ?? '').trim();
  if (roh.isEmpty) return null;
  final ohneKlammern = roh.replaceAll('<', '').replaceAll('>', '').trim();
  return ohneKlammern.isEmpty ? null : ohneKlammern.toLowerCase();
}
