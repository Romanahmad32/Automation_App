import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/wahrscheinlicher_vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/tone_card.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/versicherer_auswahl.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/versicherer_ergaenzung.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgang_zuordnung_auswahl.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_feld.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_felder_liste.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/zwischennachricht_hinweis_card.dart';
import 'package:flutter/material.dart';

/// Editierbares Formular mit den ausgewerteten Vorgangsdaten: der Anwalt kann
/// fehlende oder falsch erkannte Angaben direkt korrigieren, bevor sie in den
/// Vorgang übernommen werden (statt später in der Vorlage abzutippen).
///
/// Gemeinsam genutzt vom manuellen Weg (eingefügte/geladene Antwortmail) und von
/// der automatisch per Postfach erfassten Antwort — beide Eingangskanäle landen
/// so im selben Mapping-/Korrektur-Codepfad.
class VorgangsdatenForm extends StatefulWidget {
  /// Die ausgewerteten Daten, mit denen die Felder vorbelegt werden. Bei einem
  /// Wechsel der Daten das Widget mit `key: ObjectKey(data)` neu aufbauen.
  final ZentralrufReplyData data;

  /// Hinweise auf mögliche Falschzuordnungen (Kennzeichen passt nicht zur
  /// Referenz, Negativ-Antwort …).
  final List<String> warnings;

  /// Wird mit den (ggf. korrigierten) Daten und dem gewählten Zielvorgang
  /// aufgerufen, wenn der Anwalt übernimmt. [zielReferenz] ist die Referenz des
  /// Vorgangs, dem die Antwort zugeordnet werden soll, oder null für „Neuen
  /// Vorgang anlegen".
  final void Function(ZentralrufReplyData bearbeitet, String? zielReferenz)
  onUebernehmen;

  /// Optionaler Kopfbereich oberhalb der Hinweise (z. B. Betreff der Mail).
  final Widget? kopf;

  /// Optionaler Fußbereich unterhalb des Übernehmen-Knopfs (z. B. der
  /// Originaltext der Mail zum Nachlesen/Kopieren).
  final Widget? fuss;

  final String submitLabel;

  const VorgangsdatenForm({
    super.key,
    required this.data,
    required this.onUebernehmen,
    this.warnings = const [],
    this.kopf,
    this.fuss,
    this.submitLabel = 'Übernehmen und Vorlage ausfüllen',
  });

  @override
  State<VorgangsdatenForm> createState() => _VorgangsdatenFormState();
}

class _VorgangsdatenFormState extends State<VorgangsdatenForm> {
  late final Map<VorgangsdatenFeld, TextEditingController> _controllers;

  /// Gewählter Zielvorgang: normalisierte Referenz oder der Sentinel „Neuen
  /// Vorgang anlegen". Vorbelegt mit dem über die Referenz automatisch
  /// gefundenen Vorgang, sonst mit dem Fallback-Treffer (Kennzeichen +
  /// Unfalldatum, als „wahrscheinliche Zuordnung"), sonst „Neuen Vorgang anlegen".
  late String _zielAuswahl;

  /// Referenz des Fallback-Treffers (für den Bestätigungs-Hinweis).
  String? _vermuteteReferenz;

  /// Aus der Versicherer-Wissensbasis ergänzte Felder (Lückenfüllung).
  VersichererErgaenzung _ergaenzung = VersichererErgaenzung.leer;

  /// Bei Negativ-Antworten manuell gewählter Versicherer aus dem Register.
  int? _gewaehlterVersichererId;

  ZentralrufReplyData get _data => widget.data;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final feld in VorgangsdatenFeld.values)
        feld: TextEditingController(text: feld.wert(_data) ?? ''),
    };

    // Lücken der Antwort aus der Versicherer-Wissensbasis füllen (mit
    // Herkunftshinweis in der Feldliste; der Anwalt kann weiterhin editieren).
    // Das Register kann während der Sitzung dazugelernt haben — nachladen und
    // dann noch leere Felder nachträglich füllen.
    final versichererCubit = getIt<VersichererCubit>();
    _fuelleAusRegister(versichererCubit);
    versichererCubit.ladeErneut().then((_) {
      if (mounted) setState(() => _fuelleAusRegister(versichererCubit));
    });

    // Zielvorgang: exakter Referenz-Treffer vor dem Fallback über
    // Kennzeichen + Unfalldatum (Letzterer nur als vorgeschlagene, vom Anwalt
    // zu bestätigende Auswahl).
    final vorgangCubit = getIt<VorgangCubit>();
    final auto = vorgangCubit.findeZuReferenz(_data.referenz);
    final vermutet = auto == null
        ? findeWahrscheinlichenVorgang(vorgangCubit.state, _data)
        : null;
    _vermuteteReferenz = vermutet?.referenz;
    final ziel = auto ?? vermutet;
    _zielAuswahl = ziel != null
        ? Vorgang.normalizeReferenz(ziel.referenz)
        : VorgangZuordnungAuswahl.neuerVorgangWert;

    if (_data.keinVersichererErmittelt || _data.zwischennachricht) {
      // Übernehmen wird erst mit einem Versicherernamen möglich — auf
      // Eingaben/Registerauswahl reagieren.
      _controllers[VorgangsdatenFeld.versichererName]!.addListener(
        () => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _wertVon(VorgangsdatenFeld feld) {
    final text = _controllers[feld]!.text.trim();
    return text.isEmpty ? null : text;
  }

  /// Füllt noch leere Versicherer-Felder aus dem Register (Lückenfüllung);
  /// bereits Eingetipptes bleibt unberührt.
  void _fuelleAusRegister(VersichererCubit versichererCubit) {
    final bekannt = versichererCubit.findeZuName(_data.versichererName);
    final ergaenzung = VersichererErgaenzung.ermittle(_data, bekannt);
    for (final MapEntry(key: feld, value: wert) in ergaenzung.werte.entries) {
      if (_controllers[feld]!.text.trim().isEmpty) {
        _controllers[feld]!.text = wert;
      }
    }
    if (ergaenzung.werte.isNotEmpty) _ergaenzung = ergaenzung;
  }

  /// Übernimmt einen aus dem Register gewählten Versicherer in die Felder
  /// (nur belegte Registerwerte, bereits Getipptes wird nicht geleert).
  void _uebernehmeVersicherer(Versicherer gewaehlt) {
    final werte = <VorgangsdatenFeld, String?>{
      VorgangsdatenFeld.versichererName: gewaehlt.name,
      VorgangsdatenFeld.versichererStrasse: gewaehlt.strasse,
      VorgangsdatenFeld.versichererPlz: gewaehlt.plz,
      VorgangsdatenFeld.versichererOrt: gewaehlt.ort,
      VorgangsdatenFeld.versichererTelefon: gewaehlt.telefon,
      VorgangsdatenFeld.versichererFax: gewaehlt.fax,
      VorgangsdatenFeld.versichererEmail: gewaehlt.email,
    };
    setState(() {
      _gewaehlterVersichererId = gewaehlt.id;
      for (final MapEntry(key: feld, value: wert) in werte.entries) {
        if ((wert ?? '').trim().isNotEmpty) {
          _controllers[feld]!.text = wert!.trim();
        }
      }
    });
  }

  ZentralrufReplyData _bearbeiteteDaten() {
    final referenz = _wertVon(VorgangsdatenFeld.referenz);
    // Die zerlegten Referenz-Bestandteile stammen aus dem Parser; wurde die
    // Referenz von Hand geändert, passen sie nicht mehr und entfallen.
    final referenzUnveraendert = referenz == _data.referenz;
    return ZentralrufReplyData(
      referenz: referenz,
      referenzAuftragsnummer: referenzUnveraendert
          ? _data.referenzAuftragsnummer
          : null,
      referenzJahr: referenzUnveraendert ? _data.referenzJahr : null,
      referenzAbteilung: referenzUnveraendert ? _data.referenzAbteilung : null,
      referenzKennzeichen: referenzUnveraendert
          ? _data.referenzKennzeichen
          : null,
      anfrageDatum: _wertVon(VorgangsdatenFeld.anfrageDatum),
      kennzeichen: _wertVon(VorgangsdatenFeld.kennzeichen),
      unfallDatum: _wertVon(VorgangsdatenFeld.unfallDatum),
      versichererName: _wertVon(VorgangsdatenFeld.versichererName),
      versichererStrasse: _wertVon(VorgangsdatenFeld.versichererStrasse),
      versichererPlz: _wertVon(VorgangsdatenFeld.versichererPlz),
      versichererOrt: _wertVon(VorgangsdatenFeld.versichererOrt),
      versichererTelefon: _wertVon(VorgangsdatenFeld.versichererTelefon),
      versichererFax: _wertVon(VorgangsdatenFeld.versichererFax),
      versichererEmail: _wertVon(VorgangsdatenFeld.versichererEmail),
      versicherungsscheinNr: _wertVon(VorgangsdatenFeld.versicherungsscheinNr),
      versicherungsbeginn: _wertVon(VorgangsdatenFeld.versicherungsbeginn),
      keinVersichererErmittelt: _data.keinVersichererErmittelt,
      zwischennachricht: _data.zwischennachricht,
    );
  }

  /// Bei Negativ-Antworten und Zwischennachrichten wird Übernehmen erst mit
  /// einem Versicherernamen möglich (aus dem Register gewählt oder von Hand
  /// eingetragen) — bei der Zwischennachricht ist das Abwarten der Folgemail
  /// der Normalweg.
  bool get _uebernehmenMoeglich =>
      (!_data.keinVersichererErmittelt && !_data.zwischennachricht) ||
      _wertVon(VorgangsdatenFeld.versichererName) != null;

  void _uebernehmen() {
    final ziel = _zielAuswahl == VorgangZuordnungAuswahl.neuerVorgangWert
        ? null
        : _zielAuswahl;
    widget.onUebernehmen(_bearbeiteteDaten(), ziel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keinVersicherer = _data.keinVersichererErmittelt;
    final zwischennachricht = _data.zwischennachricht;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.kopf case final kopf?) ...[
            kopf,
            const SizedBox(height: 12),
          ],
          Text('Vorgangsdaten', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Bitte prüfen und bei Bedarf direkt hier korrigieren.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          VorgangZuordnungAuswahl(
            antwortReferenz: _data.referenz,
            vermuteteReferenz: _vermuteteReferenz,
            value: _zielAuswahl,
            onChanged: (wert) => setState(() => _zielAuswahl = wert),
          ),
          const SizedBox(height: 8),
          if (zwischennachricht) ...[
            const ZwischennachrichtHinweisCard(),
            const SizedBox(height: 8),
          ],
          if (keinVersicherer) ...[
            ToneCard(
              accent: theme.colorScheme.error,
              text:
                  'Der Zentralruf konnte zu dieser Anfrage keinen Versicherer '
                  'ermitteln. Bitte Kennzeichen und Unfalldatum prüfen und die '
                  'Anfrage ggf. wiederholen — oder den Versicherer unten aus '
                  'der Liste bekannter Versicherer wählen bzw. eintragen.',
            ),
            const SizedBox(height: 8),
            VersichererAuswahl(
              value: _gewaehlterVersichererId,
              onGewaehlt: _uebernehmeVersicherer,
            ),
          ],
          // Warnungen anzeigen; die vom Backend mitgeschickten Texte zu
          // Negativ-Antwort/Zwischennachricht entfallen, wenn oben schon die
          // ausführliche Hinweiskarte steht (sonst doppelt).
          for (final warnung in widget.warnings)
            if ((!keinVersicherer || !warnung.contains('keinen Versicherer')) &&
                (!zwischennachricht ||
                    !warnung.contains('Zwischennachricht')))
              ToneCard(
                accent: theme.colorScheme.tertiary,
                icon: Icons.warning_amber,
                text: warnung,
              ),
          const SizedBox(height: 8),
          VorgangsdatenFelderListe(
            controllers: _controllers,
            data: _data,
            ergaenzung: _ergaenzung,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(widget.submitLabel),
            onPressed: _uebernehmenMoeglich ? _uebernehmen : null,
          ),
          if (widget.fuss case final fuss?) ...[
            const SizedBox(height: 16),
            fuss,
          ],
        ],
      ),
    );
  }
}
