import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:flutter/material.dart';

/// Die Filterleiste über dem Register (§6.2): Jahrgang, Status, Rechtsgebiet.
///
/// Nötig, seit das Register **alle** Vorgänge führt und nicht mehr nur die
/// abgeschlossenen — bei ein paar hundert Zeilen ist „alles zeigen" ohne
/// Einschränkung keine Ansicht mehr.
///
/// Die Auswahl wirkt nur auf den Bildschirm. Was in der Spiegeldatei landet,
/// steht in den Einstellungen; der Hinweis darauf steht in der
/// `RegisterSpiegelLeiste` darunter, damit niemand vom Bildschirm auf die Datei
/// schließt.
class RegisterFilterLeiste extends StatelessWidget {
  final RegisterFilter filter;
  final List<Vorgang> alle;
  final ValueChanged<RegisterFilter> onGeaendert;

  const RegisterFilterLeiste({
    super.key,
    required this.filter,
    required this.alle,
    required this.onGeaendert,
  });

  @override
  Widget build(BuildContext context) {
    final jahre = RegisterFilter.jahrgaenge(alle);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final jahr in jahre)
          FilterChip(
            label: Text(jahr),
            selected: filter.jahr == jahr,
            onSelected: (gewaehlt) => onGeaendert(
              filter.mit(jahr: gewaehlt ? jahr : null, jahrLoeschen: !gewaehlt),
            ),
          ),
        if (jahre.isNotEmpty) const SizedBox(width: 8),
        _auswahl<VorgangStatus>(
          context,
          hinweis: 'Status',
          wert: filter.status,
          werte: VorgangStatus.values,
          beschriftung: (status) => status.displayName,
          onGewaehlt: (status) => onGeaendert(
            filter.mit(status: status, statusLoeschen: status == null),
          ),
        ),
        _auswahl<Rechtsgebiet>(
          context,
          hinweis: 'Rechtsgebiet',
          wert: filter.rechtsgebiet,
          werte: Rechtsgebiet.values,
          beschriftung: (gebiet) => gebiet.displayName,
          onGewaehlt: (gebiet) => onGeaendert(
            filter.mit(
              rechtsgebiet: gebiet,
              rechtsgebietLoeschen: gebiet == null,
            ),
          ),
        ),
        if (!filter.istLeer)
          TextButton.icon(
            onPressed: () => onGeaendert(RegisterFilter.alle),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Filter zurücksetzen'),
          ),
      ],
    );
  }

  /// Ein Auswahlfeld, dessen erster Eintrag „alle" ist. Bewusst kein Chip je
  /// Wert: Status und Rechtsgebiet haben zusammen vierzehn Ausprägungen, und
  /// vierzehn Chips wären die Leiste selbst, nicht mehr ihr Inhalt.
  Widget _auswahl<T>(
    BuildContext context, {
    required String hinweis,
    required T? wert,
    required List<T> werte,
    required String Function(T) beschriftung,
    required ValueChanged<T?> onGewaehlt,
  }) => SizedBox(
    width: 200,
    child: DropdownButtonFormField<T?>(
      initialValue: wert,
      isDense: true,
      decoration: InputDecoration(
        labelText: hinweis,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<T?>(
          value: null,
          child: Text('Alle ${hinweis.toLowerCase()}'),
        ),
        for (final eintrag in werte)
          DropdownMenuItem<T?>(
            value: eintrag,
            child: Text(beschriftung(eintrag)),
          ),
      ],
      onChanged: onGewaehlt,
    ),
  );
}
