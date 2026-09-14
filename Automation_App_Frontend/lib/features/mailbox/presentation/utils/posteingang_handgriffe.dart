import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_dialog.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/utils/antwort_betreff.dart';
import 'package:automation_app/features/mailbox/presentation/utils/datei_oeffnen.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_akten_ablage_dialog.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';

/// Was an einer geöffneten Nachricht tatsächlich geschieht (§4.3) — die
/// Verdrahtung zwischen [PosteingangCubit] (holt Anhang bzw. `.eml` ins
/// Zwischenlager), dem Versanddialog, dem Ablagedialog und dem Öffnen im
/// Betriebssystem.
///
/// Eigene Datei statt Methoden in `posteingang_detail_bereich.dart`: Die sechs
/// Handgriffe sind für sich genommen mechanisch, machen aber den Großteil der
/// Zeilen aus — zusammen mit der Fallunterscheidung Zentralruf/Mail und dem
/// Aufbau der Detailansicht wäre die Ansicht deutlich über der Dateigrenze.
/// Die Widgets selbst (`PosteingangAktionsleiste`, `PosteingangAnhangListe`)
/// kennen davon nichts; sie bekommen nur Rückrufe.
class PosteingangHandgriffe {
  const PosteingangHandgriffe(this.cubit);

  final PosteingangCubit cubit;

  /// „Antworten": öffnet den Versanddialog mit dem Absender als Empfänger und
  /// „AW: …" als Betreff. **Kein Zitieren, kein Weiterleiten** (REQUIREMENTS
  /// §8) — die Nachricht selbst geht nicht mit.
  Future<void> antworten(
    BuildContext context,
    PosteingangEintrag eintrag, {
    PosteingangInhalt? inhalt,
    Vorgang? vorgang,
  }) async {
    final adresse =
        inhalt?.absenderAdresse ?? eintrag.absenderAdresse ?? eintrag.absender;
    await EmailVersandDialog.zeigen(
      context,
      vorgang: vorgang,
      empfaengerVorauswahl: [if (adresse.trim().isNotEmpty) adresse.trim()],
      betreffVorgabe: antwortBetreff(eintrag.betreff),
    );
  }

  /// Legt die ganze Nachricht als `.eml` in der Akte ab.
  Future<void> mailInDieAkte(
    BuildContext context,
    PosteingangEintrag eintrag, {
    Vorgang? vorgang,
  }) async {
    final pfad = await _hole(context, () => cubit.emlLaden(eintrag.id));
    if (pfad == null || !context.mounted) return;
    await PosteingangAktenAblageDialog.zeigen(
      context,
      pfade: [pfad],
      vorgang: vorgang,
    );
  }

  /// Hängt die Nachricht als `.eml` an den nächsten Versand — über denselben
  /// `ausDerAkte`-Weg, den der Versanddialog schon für die Dateien aus dem
  /// Fall-Ordner geht: zum Anklicken bereit, aber nicht von selbst dran.
  Future<void> mailBeimVersand(
    BuildContext context,
    PosteingangEintrag eintrag, {
    Vorgang? vorgang,
  }) async {
    final pfad = await _hole(context, () => cubit.emlLaden(eintrag.id));
    if (pfad == null || !context.mounted) return;
    await EmailVersandDialog.zeigen(
      context,
      vorgang: vorgang,
      ausDerAkte: [pfad],
    );
  }

  Future<void> anhangOeffnen(
    BuildContext context,
    String eintragId,
    PosteingangAnhang anhang,
  ) async {
    final pfad = await _hole(
      context,
      () => cubit.anhangLaden(eintragId, anhang),
    );
    if (pfad == null || !context.mounted) return;
    await PosteingangDateiOeffnen.oeffne(context, pfad, name: anhang.dateiname);
  }

  Future<void> anhangInDieAkte(
    BuildContext context,
    String eintragId,
    PosteingangAnhang anhang, {
    Vorgang? vorgang,
  }) async {
    final pfad = await _hole(
      context,
      () => cubit.anhangLaden(eintragId, anhang),
    );
    if (pfad == null || !context.mounted) return;
    await PosteingangAktenAblageDialog.zeigen(
      context,
      pfade: [pfad],
      vorgang: vorgang,
    );
  }

  Future<void> anhangBeimVersand(
    BuildContext context,
    String eintragId,
    PosteingangAnhang anhang, {
    Vorgang? vorgang,
  }) async {
    final pfad = await _hole(
      context,
      () => cubit.anhangLaden(eintragId, anhang),
    );
    if (pfad == null || !context.mounted) return;
    await EmailVersandDialog.zeigen(
      context,
      vorgang: vorgang,
      ausDerAkte: [pfad],
    );
  }

  /// Holt die Datei und meldet einen Fehlschlag — der Cubit legt die Meldung
  /// in `state.anhangFehler`, liefert aber nur `null` zurück.
  /// **`anhangFehler`, nicht `state.fehler`** (Review #134, Befund 8): Der
  /// teilt sich Seitenlade- und Downloadfehler — ein alter Listenfehler
  /// zeigte sich sonst hier als vermeintlicher Downloadfehler.
  /// [Rueckmeldung.von] **vor** dem `await`: Danach kann die Seite weg sein.
  Future<String?> _hole(
    BuildContext context,
    Future<String?> Function() laden,
  ) async {
    final melder = Rueckmeldung.von(context);
    final pfad = await laden();
    if (pfad == null) {
      melder.fehler(
        cubit.state.anhangFehler ??
            'Die Datei wird gerade schon geholt — bitte einen Augenblick '
                'warten.',
      );
    }
    return pfad;
  }
}
