import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/vorgaenge/domain/services/antwort_konflikte.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/antwort_konflikt_dialog.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';

/// Übernimmt eine ausgewertete Zentralruf-Antwort in den Zielvorgang (§4.3).
/// Liefert false, wenn der Anwalt im Konfliktdialog abgebrochen hat — dann ist
/// **nichts** geschrieben.
///
/// Wortgleich aus dem abgelösten `mailbox_inbox_view.dart` übernommen, damit
/// der automatische Weg (erfasste Antwort im Posteingang) und der manuelle
/// (eingefügte Mail) weiterhin durch denselben Code laufen. Eigene Datei statt
/// einer Methode in einer der beiden Ansichten: Beide brauchen sie, und die
/// zweite hätte sie sonst abgeschrieben.
///
/// **Ohne** den Tab-Wechsel nach Word: Er gehört an die aufrufende Stelle. Ein
/// `AutoTabsRouter.of(context)` aus einem Dialog heraus sucht oberhalb des
/// Dialog-Overlays weiter — je nachdem, an welchem Navigator der Dialog hängt,
/// findet es den Tab-Router oder nicht. Die Ansichten haben ihn dagegen
/// sicher über sich.
Future<bool> uebernimmZentralrufDaten(
  BuildContext context,
  ZentralrufReplyData daten, {
  String? zielReferenz,
}) async {
  // Antwort dem im Formular gewählten Vorgang zuordnen (Vorauswahl: der über
  // die Referenz gefundene Vorgang, §4.3) und ihn auf „Beantwortet" schalten —
  // so bleiben mehrere offene Vorgänge sauber unterscheidbar, und eine
  // fehlgeschlagene Auto-Zuordnung lässt sich von Hand korrigieren.
  // [zielReferenz] == null bedeutet „Neuen Vorgang anlegen". Der Word-Assistent
  // wählt diesen Vorgang beim Wechsel auf den Tab automatisch vor und belegt
  // die Felder daraus.
  final vorgaenge = getIt<VorgangCubit>();

  // Widerspricht die Antwort bereits erfassten Vorgangsdaten, entscheidet der
  // Anwalt je Feld — statt den Antwortwert still zu verwerfen.
  var antwortGewinnt = const <AntwortKonfliktFeld>{};
  final ziel = vorgaenge.zielVorgangFuer(daten, zielReferenz: zielReferenz);
  if (ziel != null) {
    final konflikte = AntwortKonflikte.finde(ziel, daten);
    if (konflikte.isNotEmpty) {
      final entscheidung = await AntwortKonfliktDialog.zeige(
        context,
        konflikte,
      );
      if (entscheidung == null || !context.mounted) return false;
      antwortGewinnt = entscheidung;
    }
  }

  vorgaenge.uebernehmeAntwort(
    daten,
    zielReferenz: zielReferenz,
    antwortGewinnt: antwortGewinnt,
  );
  // Die Meldung liegt im Wurzel-Overlay (Rueckmeldung) und übersteht den
  // Tab-Wechsel der aufrufenden Stelle deshalb unbeschadet.
  Rueckmeldung.zeigeErfolg(
    context,
    'Vorgangsdaten übernommen. Passende Felder werden beim Ausfüllen der '
    'Vorlage automatisch vorbelegt.',
  );
  return true;
}
