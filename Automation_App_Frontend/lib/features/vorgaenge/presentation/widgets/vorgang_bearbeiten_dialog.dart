import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/sachgebiet_katalog_builder.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:flutter/material.dart';

/// Führt die Referenzänderung aus (konfliktgeprüft im Backend, siehe
/// `VorgangCubit.aendereReferenz`). Liefert bei Erfolg den umbenannten
/// Vorgang, sonst eine anzeigbare Fehlermeldung.
typedef ReferenzAendernCallback =
    Future<({Vorgang? vorgang, String? fehler})> Function(
      Vorgang vorgang,
      String neueReferenz,
    );

/// Dialog zum Bearbeiten der Daten eines [Vorgang]. Auch die
/// [Vorgang.referenz] (der fachliche Schlüssel) lässt sich korrigieren —
/// z. B. bei einem Tippfehler im Kennzeichen; die Umbenennung läuft über
/// [onReferenzAendern] als eigener, konfliktgeprüfter Schritt. Die übrigen
/// Felder gehen beim Speichern als aktualisierter Vorgang an [onSave].
class VorgangBearbeitenDialog extends StatefulWidget {
  final Vorgang vorgang;
  final ValueChanged<Vorgang> onSave;
  final ReferenzAendernCallback onReferenzAendern;

  const VorgangBearbeitenDialog({
    super.key,
    required this.vorgang,
    required this.onSave,
    required this.onReferenzAendern,
  });

  @override
  State<VorgangBearbeitenDialog> createState() =>
      _VorgangBearbeitenDialogState();
}

class _VorgangBearbeitenDialogState extends State<VorgangBearbeitenDialog> {
  late final TextEditingController _referenz;
  late final TextEditingController _mandantName;
  late final TextEditingController _gegner;
  late final TextEditingController _geschaedigtenKennzeichen;
  late final TextEditingController _unfallDatum;
  late final TextEditingController _unfallort;
  late final TextEditingController _unfalluhrzeit;
  late final TextEditingController _polizei;

  late VorgangStatus _status;

  /// Der gespeicherte Rohwert; geändert nur durch eine aktive Auswahl aus dem
  /// Katalog — lädt der nicht, bleibt der Wert beim Speichern unangetastet.
  late String _rechtsgebiet;

  /// Fehlermeldung einer abgewiesenen Referenzänderung (z. B. schon vergeben).
  String? _referenzFehler;
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vorgang;
    _referenz = TextEditingController(text: v.referenz);
    _mandantName = TextEditingController(text: v.mandantName ?? '');
    _gegner = TextEditingController(text: v.gegner ?? '');
    _geschaedigtenKennzeichen = TextEditingController(
      text: v.geschaedigtenKennzeichen ?? '',
    );
    _unfallDatum = TextEditingController(text: v.unfallDatum ?? '');
    _unfallort = TextEditingController(text: v.unfallort ?? '');
    _unfalluhrzeit = TextEditingController(text: v.unfalluhrzeit ?? '');
    _polizei = TextEditingController(text: v.polizeiVorgangsnummer ?? '');
    _status = v.status;
    _rechtsgebiet = v.rechtsgebiet;
  }

  @override
  void dispose() {
    _referenz.dispose();
    _mandantName.dispose();
    _gegner.dispose();
    _geschaedigtenKennzeichen.dispose();
    _unfallDatum.dispose();
    _unfallort.dispose();
    _unfalluhrzeit.dispose();
    _polizei.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    setState(() {
      _referenzFehler = null;
      _speichert = true;
    });

    // Eine geänderte Referenz zuerst umbenennen (eigener, konfliktgeprüfter
    // Schritt); die übrigen Felder gehen danach auf den umbenannten Stand.
    var basis = widget.vorgang;
    final neueReferenz = _referenz.text.trim();
    if (!Vorgang.gleicheReferenz(neueReferenz, basis.referenz) ||
        neueReferenz.isEmpty) {
      final ergebnis = await widget.onReferenzAendern(basis, neueReferenz);
      if (ergebnis.fehler != null || ergebnis.vorgang == null) {
        if (!mounted) return;
        setState(() {
          _referenzFehler =
              ergebnis.fehler ?? 'Die Referenz konnte nicht geändert werden.';
          _speichert = false;
        });
        return;
      }
      basis = ergebnis.vorgang!;
    }

    final aktualisiert = basis.copyWith(
      status: _status,
      rechtsgebiet: _rechtsgebiet,
      mandantName: _mandantName.text.trim(),
      gegner: _gegner.text.trim(),
      geschaedigtenKennzeichen: _geschaedigtenKennzeichen.text.trim(),
      unfallDatum: _unfallDatum.text.trim(),
      unfallort: _unfallort.text.trim(),
      unfalluhrzeit: _unfalluhrzeit.text.trim(),
      polizeiVorgangsnummer: _polizei.text.trim(),
    );
    widget.onSave(aktualisiert);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Vorgang ${widget.vorgang.zeichen} bearbeiten'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                  controller: _referenz,
                  decoration: InputDecoration(
                    labelText: 'Referenz (Nr/Jahr Abteilung_Kennzeichen)',
                    helperText:
                        'Verknüpft Anfrage und Antwort — nur bei Tippfehlern '
                        'ändern.',
                    helperMaxLines: 2,
                    errorText: _referenzFehler,
                    errorMaxLines: 3,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              VorgangDialogField(
                controller: _mandantName,
                label: 'Mandant (Name)',
              ),
              VorgangDialogField(
                controller: _gegner,
                label: 'Gegner / gegnerische Versicherung',
              ),
              VorgangDialogField(
                controller: _geschaedigtenKennzeichen,
                label: 'Kennzeichen Mandant (z. B. HG-E 1427)',
              ),
              VorgangDialogField(
                controller: _unfallDatum,
                label: 'Unfalldatum (TT.MM.JJJJ)',
              ),
              VorgangDialogField(controller: _unfallort, label: 'Unfallort'),
              VorgangDialogField(
                controller: _unfalluhrzeit,
                label: 'Unfalluhrzeit',
              ),
              VorgangDialogField(
                controller: _polizei,
                label: 'Polizei-Vorgangsnummer',
              ),
              const SizedBox(height: 8),
              SearchableDropdown<VorgangStatus>(
                value: _status,
                labelText: 'Status',
                hintText: 'Status wählen',
                entries: [
                  for (final s in VorgangStatus.values)
                    SearchableDropdownEntry(value: s, label: s.displayName),
                ],
                onChanged: (s) => setState(() => _status = s ?? _status),
              ),
              const SizedBox(height: 16),
              // Auswahl aus dem Sachgebietskatalog (§7.1); ein gespeicherter
              // Wert ausserhalb des Katalogs (Altbestand) bleibt als eigener
              // Eintrag wählbar. Lädt der Katalog nicht, steht hier der
              // Fehlerhinweis mit „Erneut versuchen" statt der Auswahl.
              SachgebietKatalogBuilder(
                builder: (context, katalog) {
                  final entries = [
                    for (final sachgebiet in katalog)
                      SearchableDropdownEntry(
                        value: sachgebiet.rechtsgebietVorschlag,
                        label: sachgebiet.rechtsgebietVorschlag,
                      ),
                  ];
                  // Den gespeicherten Wert auf den Katalogeintrag abbilden
                  // ('verkehrsrecht' → 'Verkehrsrecht'), damit die Auswahl ihn
                  // anzeigt; ohne Deckung kommt er als eigener Eintrag dazu.
                  String? wert;
                  for (final eintrag in entries) {
                    if (RechtsgebietWert.gleich(eintrag.value, _rechtsgebiet)) {
                      wert = eintrag.value;
                      break;
                    }
                  }
                  if (wert == null && _rechtsgebiet.trim().isNotEmpty) {
                    wert = _rechtsgebiet;
                    entries.add(
                      SearchableDropdownEntry(
                        value: _rechtsgebiet,
                        label: RechtsgebietWert.anzeige(_rechtsgebiet),
                      ),
                    );
                  }
                  return SearchableDropdown<String>(
                    value: wert,
                    labelText: 'Rechtsgebiet',
                    hintText: 'Rechtsgebiet wählen',
                    entries: entries,
                    onChanged: (r) =>
                        setState(() => _rechtsgebiet = r ?? _rechtsgebiet),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _speichert ? null : _speichern,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Ein beschriftetes Textfeld im Bearbeiten-Dialog — eigenständig, damit kein
/// privates Hilfs-Widget nötig ist und es wiederverwendbar bleibt.
class VorgangDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const VorgangDialogField({
    super.key,
    required this.controller,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
