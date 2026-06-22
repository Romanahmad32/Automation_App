import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  /// Wird mit den (ggf. korrigierten) Daten aufgerufen, wenn der Anwalt
  /// übernimmt.
  final void Function(ZentralrufReplyData bearbeitet) onUebernehmen;

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
  late final Map<_Feld, TextEditingController> _controllers;

  ZentralrufReplyData get _data => widget.data;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final feld in _Feld.values)
        feld: TextEditingController(text: feld.wert(_data) ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _wertVon(_Feld feld) {
    final text = _controllers[feld]!.text.trim();
    return text.isEmpty ? null : text;
  }

  ZentralrufReplyData _bearbeiteteDaten() {
    final referenz = _wertVon(_Feld.referenz);
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
      anfrageDatum: _wertVon(_Feld.anfrageDatum),
      kennzeichen: _wertVon(_Feld.kennzeichen),
      unfallDatum: _wertVon(_Feld.unfallDatum),
      versichererName: _wertVon(_Feld.versichererName),
      versichererStrasse: _wertVon(_Feld.versichererStrasse),
      versichererPlz: _wertVon(_Feld.versichererPlz),
      versichererOrt: _wertVon(_Feld.versichererOrt),
      versichererTelefon: _wertVon(_Feld.versichererTelefon),
      versichererFax: _wertVon(_Feld.versichererFax),
      versichererEmail: _wertVon(_Feld.versichererEmail),
      versicherungsscheinNr: _wertVon(_Feld.versicherungsscheinNr),
      versicherungsbeginn: _wertVon(_Feld.versicherungsbeginn),
      keinVersichererErmittelt: _data.keinVersichererErmittelt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keinVersicherer = _data.keinVersichererErmittelt;

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
          ZuordnungHinweis(referenz: _data.referenz),
          if (keinVersicherer)
            _ToneCard(
              accent: theme.colorScheme.error,
              text:
                  'Der Zentralruf konnte zu dieser Anfrage keinen Versicherer '
                  'ermitteln. Bitte Kennzeichen und Unfalldatum prüfen und die '
                  'Anfrage ggf. wiederholen.',
            ),
          for (final warnung in widget.warnings)
            if (!keinVersicherer || !warnung.contains('keinen Versicherer'))
              _ToneCard(
                accent: theme.colorScheme.tertiary,
                icon: Icons.warning_amber,
                text: warnung,
              ),
          const SizedBox(height: 8),
          for (final feld in _Feld.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: TextField(
                controller: _controllers[feld],
                decoration: InputDecoration(
                  labelText: feld.label,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  // Nicht erkannte Angaben deutlich markieren.
                  helperText: feld.wert(_data) == null
                      ? 'nicht gefunden'
                      : null,
                  helperStyle: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(widget.submitLabel),
            onPressed: keinVersicherer
                ? null
                : () => widget.onUebernehmen(_bearbeiteteDaten()),
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

/// Zeigt, ob die Antwort über ihre Referenz einer zuvor gestarteten
/// Zentralruf-Anfrage zugeordnet werden konnte (Req. 3.3).
class ZuordnungHinweis extends StatelessWidget {
  final String? referenz;

  const ZuordnungHinweis({super.key, required this.referenz});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<VorgangCubit, List<Vorgang>>(
      bloc: getIt<VorgangCubit>(),
      builder: (context, vorgaenge) {
        final vorgang = getIt<VorgangCubit>().findeZuReferenz(referenz);
        if (vorgang != null) {
          final datum = vorgang.angefragtAm;
          final datumText =
              '${datum.day.toString().padLeft(2, '0')}.'
              '${datum.month.toString().padLeft(2, '0')}.${datum.year}';
          final mandant = vorgang.mandantName?.trim();
          return _ToneCard(
            accent: theme.colorScheme.primary,
            icon: Icons.link,
            text:
                'Zugeordnet zum Vorgang vom $datumText '
                '(Referenz ${vorgang.referenz})'
                '${mandant != null && mandant.isNotEmpty ? ' — $mandant' : ''}.',
          );
        }

        if (vorgaenge.isEmpty || referenz == null) {
          return const SizedBox.shrink();
        }

        return _ToneCard(
          accent: theme.colorScheme.tertiary,
          text:
              'Zur Referenz "$referenz" ist kein offener Vorgang '
              'bekannt — bitte prüfen, ob die Antwort zum richtigen Vorgang gehört.',
        );
      },
    );
  }
}

class _ToneCard extends StatelessWidget {
  final Color accent;
  final IconData? icon;
  final String text;

  const _ToneCard({required this.accent, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    final tone = SoftTone.fromAccent(accent, Theme.of(context).colorScheme);
    return Card(
      color: tone.background,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (icon case final icon?) ...[
              Icon(icon, color: tone.foreground),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(text, style: TextStyle(color: tone.foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Die editierbaren Felder in Anzeigereihenfolge.
enum _Feld {
  referenz('Referenz (Ihr Zeichen)'),
  anfrageDatum('Anfrage vom'),
  kennzeichen('Gegnerisches Kennzeichen'),
  unfallDatum('Unfalldatum'),
  versichererName('Versicherer'),
  versichererStrasse('Straße'),
  versichererPlz('PLZ'),
  versichererOrt('Ort'),
  versichererTelefon('Telefon'),
  versichererFax('Fax'),
  versichererEmail('E-Mail'),
  versicherungsscheinNr('Versicherungsschein-Nr.'),
  versicherungsbeginn('Versicherungsbeginn');

  final String label;

  const _Feld(this.label);

  String? wert(ZentralrufReplyData data) => switch (this) {
    _Feld.referenz => data.referenz,
    _Feld.anfrageDatum => data.anfrageDatum,
    _Feld.kennzeichen => data.kennzeichen,
    _Feld.unfallDatum => data.unfallDatum,
    _Feld.versichererName => data.versichererName,
    _Feld.versichererStrasse => data.versichererStrasse,
    _Feld.versichererPlz => data.versichererPlz,
    _Feld.versichererOrt => data.versichererOrt,
    _Feld.versichererTelefon => data.versichererTelefon,
    _Feld.versichererFax => data.versichererFax,
    _Feld.versichererEmail => data.versichererEmail,
    _Feld.versicherungsscheinNr => data.versicherungsscheinNr,
    _Feld.versicherungsbeginn => data.versicherungsbeginn,
  };
}
