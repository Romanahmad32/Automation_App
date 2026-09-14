import 'dart:async';

import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_push_notifier.dart';
import 'package:automation_app/features/mailbox/domain/repositories/posteingang_repository.dart';
import 'package:automation_app/features/mailbox/domain/services/vorgangsbezug_erkenner.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_filter.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// `@lazySingleton` statt `@injectable` (Review #134, Befund 4): Der
/// Postfach-Tab baut den Posteingang und „Gesendet" als zwei Bereiche
/// desselben `SegmentedButton` auf (`mailbox_bereiche.dart`) — als Factory
/// verlor ein Wechsel dorthin und zurück „Nicht zuordnen", den
/// Zentralruf-Schlüsselbestand und die nachgeladenen Seiten, obwohl der
/// Zustand „für die Sitzung" gilt (`PosteingangState`).
@lazySingleton
class PosteingangCubit extends Cubit<PosteingangState> {
  final PosteingangRepository _repository;
  final List<String?> _verlauf = [];
  String? _cursor;
  int _seitenAnfrage = 0;
  int _inhaltAnfrage = 0;
  StreamSubscription<void>? _push;
  Timer? _entprellung;

  /// Der zuletzt über [bezuegeNeuRechnen] übergebene Erkenner — gemerkt, damit
  /// [oeffnen] ihn nach dem Laden des Inhalts erneut befragen kann (Befund 3).
  VorgangsbezugErkenner? _erkenner;

  PosteingangCubit(this._repository, MailboxPushNotifier hub)
    : super(const PosteingangState()) {
    _push = hub.onPosteingangChanged.listen((_) {
      _entprellung?.cancel();
      _entprellung = Timer(const Duration(seconds: 1), () {
        if (isClosed) return;
        if (!state.laedt && state.auswahl == null && _cursor == null) {
          aktualisieren();
        } else {
          emit(state.copyWith(neueNachrichten: true));
        }
      });
    });
    hub.ensureConnected();
  }

  /// Lädt die neueste Seite frisch — ersetzt die angehängten Zeilen.
  Future<void> aktualisieren() => _lade(null, [], ersetzen: true);

  /// Lädt die erste Seite nur, wenn noch keine da ist (Befund 4): Der Cubit
  /// lebt jetzt als `@lazySingleton` für die ganze Sitzung und darf beim
  /// erneuten Wechsel in den Posteingang nicht von vorn beginnen.
  void ladenWennNoetig() {
    if (state.seite == null && !state.laedt) aktualisieren();
  }

  /// Hängt die nächstältere Seite an (Entscheidung 8.2). Kein Aufruf mehr,
  /// sobald [PosteingangState.alleGeladen] gilt — Deckel oder Ordnerende.
  Future<void> aeltere() async {
    if (state.laedt || state.alleGeladen) return;
    final cursor = state.seite?.naechsteSeite;
    if (cursor == null) return;
    await _lade(cursor, [..._verlauf, _cursor], ersetzen: false);
  }

  Future<void> _lade(
    String? cursor,
    List<String?> verlauf, {
    required bool ersetzen,
  }) async {
    final anfrage = ++_seitenAnfrage;
    ++_inhaltAnfrage;
    _repository.abbrechen();
    emit(
      state.copyWith(
        laedt: true,
        leereFehler: true,
        // Nur beim Neuladen der ersten Seite leeren, nie bei "Ältere laden"
        // (Befund 6): Sonst schlösse jedes Nachladen die geöffnete Mail.
        leereAuswahl: ersetzen,
        inhaltLaedt: false,
      ),
    );
    try {
      final seite = await _repository.ladeSeite(cursor: cursor);
      if (isClosed || anfrage != _seitenAnfrage) return;
      _cursor = cursor;
      _verlauf
        ..clear()
        ..addAll(verlauf);
      final eintraege = ersetzen
          ? seite.nachrichten
          : _gedeckelt([...state.eintraege, ...seite.nachrichten]);
      emit(
        state.copyWith(
          seite: seite,
          eintraege: eintraege,
          seitennummer: verlauf.length + 1,
          laedt: false,
        ),
      );
    } catch (error) {
      if (!isClosed && anfrage == _seitenAnfrage) {
        emit(state.copyWith(laedt: false, fehler: _meldung(error)));
      }
    }
  }

  /// Deckel 500 (Entscheidung 8.2): Wächst die Liste darüber, wird nicht mehr
  /// weitergeladen — ältere Nachrichten bleiben nur im Mailprogramm einsehbar.
  List<PosteingangEintrag> _gedeckelt(List<PosteingangEintrag> eintraege) =>
      eintraege.length <= PosteingangState.deckel
      ? eintraege
      : eintraege.sublist(0, PosteingangState.deckel);

  Future<void> oeffnen(PosteingangEintrag mail) async {
    if (state.laedt) return;
    final anfrage = ++_inhaltAnfrage;
    emit(state.copyWith(auswahl: mail, leereInhalt: true, inhaltLaedt: true));
    try {
      final inhalt = await _repository.ladeInhalt(mail.id);
      if (!isClosed && anfrage == _inhaltAnfrage) {
        emit(state.copyWith(inhalt: inhalt, inhaltLaedt: false));
        _bezugAusInhaltNachrechnen(mail, inhalt);
      }
    } catch (error) {
      if (!isClosed && anfrage == _inhaltAnfrage) {
        emit(state.copyWith(inhaltLaedt: false, inhaltFehler: _meldung(error)));
      }
    }
  }

  /// Schließt die geöffnete Nachricht. Gebraucht vom Zurück-Pfeil der schmalen
  /// Ansicht (dort liegt das Detail als Vollbild über der Liste) und nach dem
  /// Übernehmen einer Zentralruf-Antwort — dort wechselt die App gleich darauf
  /// zum Word-Assistenten und soll bei der Rückkehr nicht dieselbe, inzwischen
  /// erledigte Nachricht wieder offen zeigen.
  void schliessen() {
    if (state.auswahl == null) return;
    // Ein noch laufender Inhaltsabruf darf die geschlossene Nachricht nicht
    // nachträglich wieder aufmachen.
    ++_inhaltAnfrage;
    emit(state.copyWith(leereAuswahl: true, inhaltLaedt: false));
  }

  void setzeFilter(PosteingangFilter filter) {
    if (filter == state.filter) return;
    _emitUndAuswahlBereinigen(state.copyWith(filter: filter));
  }

  /// „Nicht zuordnen" (§4.5) — nur für die Sitzung, ändert nichts am Vorgang.
  void nichtZuordnen(String eintragId) {
    if (state.nichtZuordnen.contains(eintragId)) return;
    _emitUndAuswahlBereinigen(
      state.copyWith(nichtZuordnen: {...state.nichtZuordnen, eintragId}),
    );
  }

  /// Emittiert [naechster] — und räumt zuvor die Auswahl, falls die geöffnete
  /// Mail durch [setzeFilter] oder [nichtZuordnen] aus
  /// `PosteingangState.sichtbar` fällt (Befund 5): Sonst bliebe eine Mail
  /// geöffnet, die die Liste gar nicht mehr zeigt.
  void _emitUndAuswahlBereinigen(PosteingangState naechster) {
    final auswahl = naechster.auswahl;
    final faelltHeraus =
        auswahl != null &&
        !naechster.sichtbar.any((eintrag) => eintrag.id == auswahl.id);
    if (!faelltHeraus) {
      emit(naechster);
      return;
    }
    // Wie in `schliessen()`: Ein noch laufender Inhaltsabruf darf die
    // geräumte Auswahl nicht nachträglich wieder aufmachen.
    ++_inhaltAnfrage;
    emit(naechster.copyWith(leereAuswahl: true));
  }

  /// Berechnet den Vorgangsbezug jeder geladenen Zeile neu — nach jeder
  /// Seitenladung und wann immer sich der Vorgangsbestand ändert (§4.3). Der
  /// Erkenner selbst ändert nie etwas; er wird hier nur ausgewertet.
  void bezuegeNeuRechnen(VorgangsbezugErkenner erkenner) {
    _erkenner = erkenner;
    final bezuege = <String, Vorgangsbezug>{};
    for (final eintrag in state.eintraege) {
      final bezug = erkenner.fuer(eintrag);
      if (bezug != null) bezuege[eintrag.id] = bezug;
    }
    emit(state.copyWith(bezuege: bezuege));
  }

  /// Rechnet den Bezug einer geöffneten Mail anhand ihres Inhalts nach
  /// (Befund 3, §4.3 dritte Stufe: Zeichen/Schadennummer in der Nachricht) —
  /// nur, solange die Kopfdatenstufe keinen **sicheren** Treffer hatte. Der
  /// Klassenkommentar von `VorgangsbezugErkenner` verspricht diese Stufe,
  /// bis dahin blieb `fuerInhalt` ohne Aufrufer.
  void _bezugAusInhaltNachrechnen(
    PosteingangEintrag eintrag,
    PosteingangInhalt inhalt,
  ) {
    final erkenner = _erkenner;
    if (erkenner == null) return;
    if (state.bezuege[eintrag.id]?.sicherheit == BezugSicherheit.sicher) {
      return;
    }
    final bezug = erkenner.fuerInhalt(eintrag, inhalt);
    if (bezug == null) return;
    emit(state.copyWith(bezuege: {...state.bezuege, eintrag.id: bezug}));
  }

  /// Merkt sich die aktuell offenen Zentralruf-Antworten (aus
  /// `MailboxInboxCubit`, das nur unquittierte lädt). Ein Schlüssel, der
  /// vorher offen war und jetzt fehlt, gilt fortan als übernommen — siehe
  /// `PosteingangState.zentralrufOffen`.
  void merkeZentralruf(Iterable<String> messageIds) {
    final offen = messageIds
        .map(normalisiereMailSchluessel)
        .whereType<String>()
        .toSet();
    emit(
      state.copyWith(
        zentralrufOffen: offen,
        zentralrufSchluessel: {...state.zentralrufSchluessel, ...offen},
      ),
    );
  }

  /// Holt einen Anhang ins Zwischenlager und gibt seinen Pfad zurück, oder
  /// `null` bei Fehlschlag (dann steht die Meldung in `state.anhangFehler`).
  /// [anhang.id] merkt sich der Zustand als `ladenderAnhangId` (Befund 7) —
  /// nur die eigene Zeile in `PosteingangAnhangZeile` zeigt dann den Ring.
  Future<String?> anhangLaden(String eintragId, PosteingangAnhang anhang) =>
      _ladeInsZwischenlager(
        () => _repository.ladeAnhang(eintragId, anhang.id),
        anhangId: anhang.id,
      );

  /// Legt die ganze Nachricht als `.eml` ab, sonst wie [anhangLaden] — ohne
  /// eigene Anhang-Id, denn die `.eml` gehört zu keiner Zeile der Anhangliste.
  Future<String?> emlLaden(String eintragId) =>
      _ladeInsZwischenlager(() => _repository.ladeEml(eintragId));

  /// Nur ein Download gleichzeitig (der Dienst serialisiert die
  /// Postfachverbindung ohnehin, R10) — ein zweiter Aufruf während eines
  /// laufenden liefert sofort `null`, ohne den ersten zu stören.
  Future<String?> _ladeInsZwischenlager(
    Future<PosteingangAnhangAblage> Function() laden, {
    String? anhangId,
  }) async {
    if (state.anhangLaedt) return null;
    emit(
      state.copyWith(
        anhangLaedt: true,
        ladenderAnhangId: anhangId,
        leereFehler: true,
        leereAnhangFehler: true,
      ),
    );
    try {
      final ablage = await laden();
      return ablage.pfad;
    } catch (error) {
      if (!isClosed) emit(state.copyWith(anhangFehler: _meldung(error)));
      return null;
    } finally {
      if (!isClosed) {
        emit(state.copyWith(anhangLaedt: false, leereLadenderAnhangId: true));
      }
    }
  }

  String _meldung(Object error) => error is PosteingangFehler
      ? error.meldung
      : 'Die Nachrichten konnten nicht geladen werden. Bitte erneut versuchen.';

  @override
  Future<void> close() {
    _entprellung?.cancel();
    _push?.cancel();
    _repository.abbrechen();
    return super.close();
  }
}
