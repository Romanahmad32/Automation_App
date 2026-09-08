import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:flutter/material.dart';

/// Der zweite Chip an einer historischen Zeile: Es gibt einen Befund, oder der
/// Erzeuger der Importdatei war sich seiner Zerlegung nicht sicher.
///
/// Nur dann — sonst stünde an jeder der tausenden Zeilen ein Hinweis, und
/// „auffällig" hieße nichts mehr. Die Befundsätze selbst stehen im Tooltip:
/// Sie sind ganze Sätze („Spalte 1 „12" widerspricht der Nummer im
/// Aktenzeichen „13/22".") und sprengten jede Tabellenzelle.
class RegisterBefundChip extends StatelessWidget {
  final RegisterZeile zeile;

  const RegisterBefundChip({super.key, required this.zeile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final befunde = zeile.befunde;
    final text = befunde.isEmpty
        ? zeile.sicherheitText
        : '${befunde.length} ${befunde.length == 1 ? 'Befund' : 'Befunde'}';

    return StatusPille(
      text: text,
      // Ein Befund ist ein Widerspruch im Bestand, eine niedrige Sicherheit nur
      // eine Selbsteinschätzung — dieselbe Farbe machte aus beidem dasselbe.
      farbe: befunde.isEmpty ? scheme.tertiary : scheme.error,
      tooltip: [...befunde, 'Übernahme: ${zeile.sicherheitText}.'].join('\n'),
    );
  }
}
