import 'package:automation_app/features/register_import/domain/entities/register_zeilen_befund.dart';
import 'package:automation_app/features/register_import/presentation/blocs/register_import_cubit/register_import_cubit.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_zeile_kachel.dart';
import 'package:flutter/material.dart';

/// Die Zeilen eines Jahrgangs unter seiner Befundkarte.
///
/// `ListView.builder`, nicht `Column`: Ein Jahrgang bringt rund zweihundert
/// Zeilen mit. Sie hängt in der Liste der Jahrgänge und rollt deshalb nicht
/// selbst ([shrinkWrap]); gerollt wird eine Ebene darüber, und lazy gebaut
/// werden dort die Jahrgänge.
class RegisterImportZeilenListe extends StatelessWidget {
  final List<RegisterZeilenBefund> zeilen;

  /// Der Zustand, aus dem die Kachel ihren Datensatz zieht — sie braucht
  /// beides: das Urteil des Dienstes und die Zeile aus der Datei.
  final RegisterImportState stand;

  const RegisterImportZeilenListe({
    super.key,
    required this.zeilen,
    required this.stand,
  });

  @override
  Widget build(BuildContext context) {
    if (zeilen.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          stand.nurZuPruefen
              ? 'Keine Zeile dieses Jahrgangs ist zu prüfen. Über den Schalter '
                    'oben sehen Sie alle.'
              : 'Dieser Jahrgang enthält keine Zeile mehr.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: zeilen.length,
      itemBuilder: (_, i) => RegisterImportZeileKachel(
        befund: zeilen[i],
        datensatz: stand.zeileAus(zeilen[i].jahrgang, zeilen[i].zeile),
        bearbeitbar: stand.kannJahrgangBearbeiten(zeilen[i].jahrgang),
      ),
    );
  }
}
