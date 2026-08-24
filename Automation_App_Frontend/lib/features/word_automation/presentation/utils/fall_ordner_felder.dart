import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:flutter/widgets.dart';

/// Die drei Eingaben, aus denen der Name des Fall-Unterordners entsteht
/// (§6.1): Stichwort, Ursachendatum und Kennzeichen, zusammengesetzt zu
/// „Unfall v. 12.06.2026 HG-E 1427".
///
/// Bündelt Controller, Vorbelegung und Namensbildung an einer Stelle, damit
/// der Speicherschritt sich um die Ablage kümmern kann und nicht um drei
/// Textfelder. Wer die Instanz hält, ruft [dispose].
class FallOrdnerFelder {
  final stichwort = TextEditingController(text: 'Unfall');
  final datum = TextEditingController();
  final kennzeichen = TextEditingController();

  bool _vorbelegt = false;

  /// Belegt Datum und Kennzeichen aus den Eingaben des ersten Schritts vor —
  /// nur beim ersten Mal, damit eine bewusste Korrektur des Anwalts beim
  /// nächsten Aufruf nicht wieder überschrieben wird.
  void vorbelegen(List<FieldData> fields, Map<String, String> data) {
    if (_vorbelegt) return;
    _vorbelegt = true;
    datum.text = ursachendatumAusFormular(fields, data) ?? '';
    kennzeichen.text = kennzeichenAusFormular(data) ?? '';
  }

  /// Der zusammengesetzte Ordnername. Ohne Stichwort bleibt es bei „Unfall":
  /// ein leerer Name wäre kein gültiger Ordner.
  String get ordnername {
    final wort = stichwort.text.trim();
    final tag = datum.text.trim();
    final zeichen = kennzeichen.text.trim();
    var name = wort.isEmpty ? 'Unfall' : wort;
    if (tag.isNotEmpty) name += ' v. $tag';
    if (zeichen.isNotEmpty) name += ' $zeichen';
    return name;
  }

  void dispose() {
    stichwort.dispose();
    datum.dispose();
    kennzeichen.dispose();
  }
}
