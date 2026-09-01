import 'package:automation_app/features/vorgaenge/domain/entities/referenz_teile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';

/// Zeigt das **Zeichen** eines Vorgangs — „216/26 C03", nicht die volle
/// Referenz „216/26 C03_EU-FE 1111".
///
/// Der Baustein existiert, damit die Entscheidung „welcher der beiden
/// Bezeichner steht hier?" einmal fällt und nicht an jeder Anzeigestelle neu.
/// Sie war vorher verstreut, und das Ergebnis war einheitlich falsch: Die
/// Oberfläche zeigte durchweg die Referenz, obwohl das Kennzeichen daran nur
/// die Zentralruf-Zuordnung trägt (§4.2).
///
/// Die volle Referenz gehört an genau drei Stellen — ins Zentralruf-Formular,
/// in die Zuordnung einer Antwort und als Nebenzeile auf die Vorgangskachel.
/// Dort steht sie bewusst als `Text(vorgang.referenz)` und nicht über diesen
/// Baustein; `test/architecture/zeichen_anzeige_test.dart` führt die Liste.
class ZeichenText extends StatelessWidget {
  /// Der Vorgang, dessen Zeichen gezeigt wird. Null bei [ZeichenText.ausReferenz].
  final Vorgang? vorgang;

  /// Die rohe Referenz, wenn kein Vorgang vorliegt. Null beim Standardweg.
  final String? referenz;

  final TextStyle? style;
  final TextOverflow? overflow;

  const ZeichenText(
    Vorgang this.vorgang, {
    super.key,
    this.style,
    this.overflow,
  }) : referenz = null;

  /// Für Anzeigestellen, die nur die Referenz in der Hand haben und keinen
  /// Vorgang — etwa ein Protokolldialog zu einem inzwischen gelöschten
  /// Vorgang.
  const ZeichenText.ausReferenz(
    String this.referenz, {
    super.key,
    this.style,
    this.overflow,
  }) : vorgang = null;

  String get zeichen =>
      vorgang?.zeichen ?? ReferenzTeile.zeichenAus(referenz ?? '');

  @override
  Widget build(BuildContext context) =>
      Text(zeichen, style: style, overflow: overflow);
}
