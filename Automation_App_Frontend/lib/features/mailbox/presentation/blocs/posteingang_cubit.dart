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

@injectable
class PosteingangCubit extends Cubit<PosteingangState> {
  final PosteingangRepository _repository;
  final List<String?> _verlauf = [];
  String? _cursor;
  int _seitenAnfrage = 0;
  int _inhaltAnfrage = 0;
  StreamSubscription<void>? _push;
  Timer? _entprellung;

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
        leereAuswahl: true,
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
    emit(state.copyWith(filter: filter));
  }

  /// „Nicht zuordnen" (§4.5) — nur für die Sitzung, ändert nichts am Vorgang.
  void nichtZuordnen(String eintragId) {
    if (state.nichtZuordnen.contains(eintragId)) return;
    emit(state.copyWith(nichtZuordnen: {...state.nichtZuordnen, eintragId}));
  }

  /// Berechnet den Vorgangsbezug jeder geladenen Zeile neu — nach jeder
  /// Seitenladung und wann immer sich der Vorgangsbestand ändert (§4.3). Der
  /// Erkenner selbst ändert nie etwas; er wird hier nur ausgewertet.
  void bezuegeNeuRechnen(VorgangsbezugErkenner erkenner) {
    final bezuege = <String, Vorgangsbezug>{};
    for (final eintrag in state.eintraege) {
      final bezug = erkenner.fuer(eintrag);
      if (bezug != null) bezuege[eintrag.id] = bezug;
    }
    emit(state.copyWith(bezuege: bezuege));
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
  /// `null` bei Fehlschlag (dann steht die Meldung in `state.fehler`).
  Future<String?> anhangLaden(String eintragId, PosteingangAnhang anhang) =>
      _ladeInsZwischenlager(() => _repository.ladeAnhang(eintragId, anhang.id));

  /// Legt die ganze Nachricht als `.eml` ab, sonst wie [anhangLaden].
  Future<String?> emlLaden(String eintragId) =>
      _ladeInsZwischenlager(() => _repository.ladeEml(eintragId));

  /// Nur ein Download gleichzeitig (der Dienst serialisiert die
  /// Postfachverbindung ohnehin, R10) — ein zweiter Aufruf während eines
  /// laufenden liefert sofort `null`, ohne den ersten zu stören.
  Future<String?> _ladeInsZwischenlager(
    Future<PosteingangAnhangAblage> Function() laden,
  ) async {
    if (state.anhangLaedt) return null;
    emit(state.copyWith(anhangLaedt: true, leereFehler: true));
    try {
      final ablage = await laden();
      return ablage.pfad;
    } catch (error) {
      if (!isClosed) emit(state.copyWith(fehler: _meldung(error)));
      return null;
    } finally {
      if (!isClosed) emit(state.copyWith(anhangLaedt: false));
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
