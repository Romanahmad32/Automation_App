import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/mandanten/domain/services/arbeitspaket_bauen.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// „Arbeitspaket holen" in der `SeitenAppBar` des Zuordnungsstapels (Issue
/// #108). Ein Druck löst der Reihe nach aus, ohne Zwischenfrage: Paket bauen,
/// Speichern-Dialog, schreiben und verbuchen, Rückmeldung.
///
/// **Reihenfolge ist der Zweck.** Der Speichern-Dialog steht zwischen Bauen
/// und Verbuchen — bricht der Anwalt ihn ab, wird gar nicht erst verbucht.
/// [speichernUnter] macht das ohne den echten Dialog testbar (Vorgabe: der
/// wirkliche `FilePicker.saveFile`).
class PaketHolenButton extends StatefulWidget {
  const PaketHolenButton({
    super.key,
    this.speichernUnter = _standardSpeichernUnter,
  });

  /// Zeigt den Speichern-Dialog und liefert den gewählten Pfad — `null`, wenn
  /// abgebrochen wurde.
  final Future<String?> Function(String vorgeschlagenerDateiname)
  speichernUnter;

  static Future<String?> _standardSpeichernUnter(String dateiname) {
    return FilePicker.saveFile(
      dialogTitle: 'Arbeitspaket speichern',
      fileName: dateiname,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
  }

  @override
  State<PaketHolenButton> createState() => _PaketHolenButtonState();
}

class _PaketHolenButtonState extends State<PaketHolenButton> {
  static const List<int> _stufen = [50, 100, 200, 500];

  int _anzahl = ArbeitspaketBauen.vorgabeAnzahl;

  /// Sperrt den Knopf für die Dauer eines Laufs (Befund aus dem Code Review
  /// zu Issue #108): [_holen] macht vor dem Speichern-Dialog mehrere
  /// nacheinander laufende Netzaufrufe, und die Paketnummer im Dateinamen ist
  /// nur eine **Vorhersage** — vergeben wird sie erst später vom Backend
  /// (`max+1`). Zwei überlappende Läufe schrieben sonst beide dieselbe
  /// vorhergesagte Nummer, während das Backend real zwei verschiedene
  /// vergibt. Dasselbe Muster wie `MandantenImportCubit.laufend` und
  /// `DokumentManuellSpeichern._laeuft`.
  bool _laeuft = false;

  @override
  Widget build(BuildContext context) {
    final aktiv =
        context.watch<MandantenOverviewBloc>().state
            is MandantenOverviewLoaded &&
        !_laeuft;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: aktiv ? () => _holen(context) : null,
          icon: _laeuft
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.move_to_inbox_outlined, size: 18),
          label: const Text('Arbeitspaket holen'),
        ),
        MenuAnchor(
          menuChildren: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Text('Wie viele Mandanten ins Paket?'),
            ),
            for (final stufe in _stufen) _stufenEintrag(stufe),
          ],
          builder: (context, controller, child) => IconButton(
            onPressed: aktiv
                ? () =>
                      controller.isOpen ? controller.close() : controller.open()
                : null,
            icon: const Icon(Icons.arrow_drop_down),
            tooltip: 'Paketgröße wählen',
          ),
        ),
      ],
    );
  }

  Widget _stufenEintrag(int stufe) {
    final gewaehlt = stufe == _anzahl;
    return MenuItemButton(
      onPressed: () => setState(() => _anzahl = stufe),
      leadingIcon: gewaehlt
          ? const Icon(Icons.check, size: 18)
          : const SizedBox(width: 18),
      trailingIcon: stufe == ArbeitspaketBauen.vorgabeAnzahl
          ? const Text('Vorgabe')
          : null,
      child: Text('$stufe Mandanten'),
    );
  }

  Future<void> _holen(BuildContext context) async {
    if (_laeuft) return;
    setState(() => _laeuft = true);
    try {
      final bloc = context.read<MandantenOverviewBloc>();
      final rueckmeldung = Rueckmeldung.von(context);

      final paket = await bloc.baueArbeitspaket(_anzahl);
      if (paket.ordner.isEmpty) {
        rueckmeldung.hinweis(
          'Alle Ordner sind zugeordnet oder vermerkt — kein Paket nötig.',
        );
        return;
      }

      final zielPfad = await widget.speichernUnter(paket.dateiname);
      if (zielPfad == null) return; // Abgebrochen — nichts wird verbucht.

      final ergebnis = await bloc.schreibeUndVerbucheArbeitspaket(
        paket: paket,
        pfad: zielPfad,
      );
      switch (ergebnis) {
        case Right():
          final mandanten = ArbeitspaketBauen.mandantenAnzahl(paket.ordner);
          rueckmeldung.erfolg(
            'Paket ${paket.paket} mit $mandanten Mandanten und '
            '${paket.ordner.length} Ordnern gespeichert. Die Anleitung liegt '
            'in der Zwischenablage.',
          );
        case Left(value: final failure):
          rueckmeldung.fehler(failure.message);
      }
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }
}
