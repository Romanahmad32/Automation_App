part of 'edited_document_bloc.dart';

sealed class EditedDocumentEvent extends Equatable {
  const EditedDocumentEvent();
}

final class EditDocumentEvent extends EditedDocumentEvent {
  final String path;
  final Map<String, String> data;
  final DamageListing? damageListing;
  final bool? vorsteuerabzugsberechtigt;
  final String? outputFileName;

  /// Referenz des Vorgangs — bestimmt den Arbeitsordner im Backend.
  final String? vorgangSchluessel;

  const EditDocumentEvent({
    required this.data,
    required this.path,
    this.damageListing,
    this.vorsteuerabzugsberechtigt,
    this.outputFileName,
    this.vorgangSchluessel,
  });

  @override
  List<Object?> get props => [
    path,
    data,
    damageListing,
    vorsteuerabzugsberechtigt,
    outputFileName,
    vorgangSchluessel,
  ];
}

/// Das Schreiben, das am gewählten Vorgang hängt (§3: Wiederaufnahme) — sein
/// [Vorgang.dokumentPfad], oder `null`, wenn dort keins steht.
///
/// Ohne dieses Ereignis kannte der Wizard nur Dokumente, die er in **dieser
/// Sitzung** erzeugt hat: Nach einem Neustart waren „Dokument begutachten" und
/// „Speichern & weiter" gesperrt, und der Absprung „Versenden & abschließen"
/// eines abgelegten Vorgangs endete in „Es wurde noch kein Dokument erstellt".
/// Der einzige Weg zu Versand und Abschluss (§4.7, §4.8) wäre gewesen, das
/// Schreiben neu zu erzeugen — für einen Schritt, der die Auftragsnummer
/// hochzählt, ein Umweg, den man nicht gehen will.
///
/// Ein `null`-Pfad räumt einen zuvor **wiederhergestellten** Stand ab; ein in
/// dieser Sitzung erzeugter bleibt stehen (siehe Bloc).
final class DokumentAusVorgangEvent extends EditedDocumentEvent {
  final String? pfad;

  const DokumentAusVorgangEvent(this.pfad);

  @override
  List<Object?> get props => [pfad];
}

/// Das Dokument liegt jetzt in der Akte: ab hier arbeitet der Wizard mit der
/// abgelegten Datei weiter, nicht mehr mit der Arbeitskopie — die wird nach der
/// Ablage gelöscht (§4.6), und ein Pfad, hinter dem nichts mehr liegt, ließe
/// „In Word öffnen" und „An anderen Ort speichern" ins Leere laufen.
final class DokumentAbgelegtEvent extends EditedDocumentEvent {
  final String zielpfad;

  const DokumentAbgelegtEvent(this.zielpfad);

  @override
  List<Object?> get props => [zielpfad];
}
