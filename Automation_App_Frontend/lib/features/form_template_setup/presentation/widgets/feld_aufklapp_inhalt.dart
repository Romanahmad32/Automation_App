import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/datums_vorbelegung_editor.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_name_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Was unter einer aufgeklappten Feldzeile steht: die Datums-Vorbelegung
/// (nur an einem Datumsfeld, §5.3) und der Hinweis zu einem mehrdeutigen
/// Namen.
///
/// Beides stand vorher **immer** unter der Zeile. Bei achtzehn Feldern hiess
/// das achtzehn verschieden hohe Zeilen, von denen die meisten nichts zu sagen
/// hatten — und die eine Zeile mit dem Hinweis ging darin unter. Seltenes
/// gehört in den Aufklapper, damit die Tabelle eine Tabelle bleibt.
class FeldAufklappInhalt extends StatelessWidget {
  final FieldData fieldData;

  /// Null nimmt die Einstellung zurück, sodass wieder die Namensregel greift.
  final ValueChanged<DatumsVorbelegung?> onVorbelegungChanged;

  const FeldAufklappInhalt({
    super.key,
    required this.fieldData,
    required this.onVorbelegungChanged,
  });

  /// Ob es überhaupt etwas aufzuklappen gibt. Ohne Inhalt bleibt das Chevron
  /// in der Zeile stehen (die Spalten sollen untereinander bleiben), aber
  /// abgeschaltet — ein Knopf, der eine leere Fläche öffnet, ist eine
  /// Enttäuschung.
  static bool hatInhalt(FieldData feld, {required bool nameMehrdeutig}) =>
      feld.inputType == InputType.date || nameMehrdeutig;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          if (fieldData.inputType == InputType.date) _vorbelegung(),
          FeldNameHinweis(
            formControlName: fieldData.label,
            datenquelleGesetzt: fieldData.datenquelle.istGesetzt,
          ),
        ],
      ),
    );
  }

  /// Der Vorbelegungs-Einsteller.
  ///
  /// Er hängt am **Wert** des Controls, nicht an `fieldData.label`: Solange
  /// die Detailseite offen ist, hält das Label nur den Control-Schlüssel
  /// (`field_0`, …, siehe FEATURE.md). Ohne den Umweg leitete die Namensregel
  /// aus „field_0" ab statt aus „Zahlungsfrist" — und der Anwalt sähe beim
  /// Umbenennen nie, dass sich die Ableitung mitändert.
  ///
  /// Der [ValueKey] ist der Preis des Aufklappers: Der Einsteller ist ein
  /// `StatefulWidget` mit vier `TextEditingController`n. Beim Zu- und
  /// Aufklappen wechselt seine Stelle im Baum, und ohne eigenen Schlüssel
  /// könnte Flutter ihn gegen ein anderes Widget derselben Art abgleichen —
  /// die Eingabe des Anwalts stünde dann in der falschen Zeile.
  Widget _vorbelegung() {
    return ReactiveValueListenableBuilder<String>(
      formControlName: fieldData.label,
      builder: (context, control, _) => DatumsVorbelegungEditor(
        key: ValueKey('vorbelegung_${fieldData.label}'),
        vorbelegung: fieldData.vorbelegung,
        feldname: control.value ?? '',
        onChanged: onVorbelegungChanged,
      ),
    );
  }
}
