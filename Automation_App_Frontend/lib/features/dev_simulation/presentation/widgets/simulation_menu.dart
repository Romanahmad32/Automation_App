import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/dev_simulation/domain/entities/zentralruf_antwort_typ.dart';
import 'package:automation_app/features/dev_simulation/domain/repositories/simulation_repository.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Die im Simulations-Menü wählbaren Aktionen — jeder Schritt des
/// Vorgangs-Lebenszyklus lässt sich damit einzeln auslösen.
enum SimulationAktion {
  antwort,
  antwortNegativ,
  antwortZwischennachricht,
  schreibenErstellt,
  abgelegt,
  abschliessen,
}

/// Entwickler-Menü an einem Vorgang (nur im Debug-Build sichtbar): simuliert
/// jeden Schritt des Lebenszyklus in der App. Die Zentralruf-Antwort geht den
/// **echten** Weg (Backend-Parser → Postfach-Inbox → Übernahme durch den
/// Nutzer); die Status-Schritte „erstellt"/„abgelegt" werden direkt am Vorgang
/// gesetzt, der Abschluss nutzt die echte Backend-Transaktion (zählt die
/// Auftragsnummer hoch).
class SimulationMenu extends StatelessWidget {
  final Vorgang vorgang;

  const SimulationMenu({super.key, required this.vorgang});

  Future<void> _antwortSimulieren(
    BuildContext context, {
    required ZentralrufAntwortTyp typ,
  }) async {
    String meldung;
    try {
      await getIt<SimulationRepository>().simuliereZentralrufAntwort(
        referenz: vorgang.referenz,
        kennzeichen: vorgang.kennzeichen,
        unfallDatum: vorgang.unfallDatum,
        antwortTyp: typ,
      );
      meldung =
          'Simulierte Zentralruf-Antwort eingespeist — im Postfach prüfen '
          'und übernehmen (echter Weg).';
    } catch (_) {
      meldung =
          'Simulation fehlgeschlagen. Läuft das Backend im Development-Profil '
          '(Simulation:Enabled)?';
    }
    if (!context.mounted) return;
    _melde(context, meldung);
  }

  Future<void> _schreibenErstelltSimulieren(BuildContext context) async {
    await getIt<VorgangCubit>().aktualisiere(
      vorgang.copyWith(
        status: VorgangStatus.erstellt,
        dokumentPfad:
            vorgang.dokumentPfad ??
            r'C:\Demo\Anspruchsschreiben (simuliert).docx',
      ),
    );
    if (!context.mounted) return;
    _melde(context, 'Status auf „Erstellt" gesetzt (simuliertes Dokument).');
  }

  Future<void> _abgelegtSimulieren(BuildContext context) async {
    await getIt<VorgangCubit>().aktualisiere(
      vorgang.copyWith(
        status: VorgangStatus.abgelegt,
        aktenOrdner: vorgang.aktenOrdner ?? 'Mustermann, Max (Demo)',
      ),
    );
    if (!context.mounted) return;
    _melde(context, 'Status auf „Abgelegt" gesetzt (simulierte Akte).');
  }

  Future<void> _abschliessen(BuildContext context) async {
    final erfolgreich = await getIt<VorgangCubit>().abschliessen(vorgang);
    if (!context.mounted) return;
    _melde(
      context,
      erfolgreich
          ? 'Vorgang abgeschlossen — Auftragsnummer wurde hochgezählt '
                '(echte Backend-Transaktion).'
          : 'Abschließen fehlgeschlagen. Läuft der Hintergrunddienst?',
    );
  }

  void _melde(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _ausfuehren(BuildContext context, SimulationAktion aktion) {
    return switch (aktion) {
      SimulationAktion.antwort => _antwortSimulieren(
        context,
        typ: ZentralrufAntwortTyp.versicherer,
      ),
      SimulationAktion.antwortNegativ => _antwortSimulieren(
        context,
        typ: ZentralrufAntwortTyp.keinVersicherer,
      ),
      SimulationAktion.antwortZwischennachricht => _antwortSimulieren(
        context,
        typ: ZentralrufAntwortTyp.zwischennachricht,
      ),
      SimulationAktion.schreibenErstellt => _schreibenErstelltSimulieren(
        context,
      ),
      SimulationAktion.abgelegt => _abgelegtSimulieren(context),
      SimulationAktion.abschliessen => _abschliessen(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return PopupMenuButton<SimulationAktion>(
      icon: const Icon(Icons.science_outlined),
      tooltip: 'Simulation (nur Entwicklung)',
      onSelected: (aktion) => _ausfuehren(context, aktion),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: SimulationAktion.antwort,
          child: Text('Zentralruf-Antwort simulieren (→ Postfach)'),
        ),
        PopupMenuItem(
          value: SimulationAktion.antwortNegativ,
          child: Text('Negativ-Antwort simulieren (kein Versicherer)'),
        ),
        PopupMenuItem(
          value: SimulationAktion.antwortZwischennachricht,
          child: Text('Zwischennachricht simulieren (Antwort folgt)'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: SimulationAktion.schreibenErstellt,
          child: Text('Status: Schreiben erstellt (simuliert)'),
        ),
        PopupMenuItem(
          value: SimulationAktion.abgelegt,
          child: Text('Status: Abgelegt (simuliert)'),
        ),
        PopupMenuItem(
          value: SimulationAktion.abschliessen,
          child: Text('Abschließen — zählt Auftragsnummer hoch'),
        ),
      ],
    );
  }
}
