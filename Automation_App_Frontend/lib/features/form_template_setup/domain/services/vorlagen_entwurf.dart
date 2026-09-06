import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:equatable/equatable.dart';

/// Ein Feld im Schnappschuss [VorlagenEntwurf] — genau die fünf Angaben, die
/// der Anwalt an einer Feldzeile einstellen kann.
///
/// [name] ist der **aufgelöste** Feldname, nicht der Control-Schlüssel: Solange
/// die Detailseite offen ist, hält `FieldData.label` nur `field_0`, `field_1`,
/// … (siehe `FALLSTRICKE.md`). Ein Vergleich über die Schlüssel wäre wertlos —
/// sie ändern sich beim Umbenennen nie.
class VorlagenEntwurfFeld extends Equatable {
  final String name;
  final InputType inputType;
  final FeldDatenquelle datenquelle;
  final bool pflicht;
  final DatumsVorbelegung? vorbelegung;

  const VorlagenEntwurfFeld({
    required this.name,
    required this.inputType,
    required this.datenquelle,
    required this.pflicht,
    required this.vorbelegung,
  });

  @override
  List<Object?> get props => [
    name,
    inputType,
    datenquelle,
    pflicht,
    vorbelegung,
  ];
}

/// Der Bearbeitungsstand des Vorlageneditors als unveränderlicher
/// Schnappschuss: Vorlagenname, beide Word-Pfade und die Felder **in ihrer
/// Reihenfolge**.
///
/// Damit beantwortet `aktuell != beimOeffnen` die Frage, ob es ungespeicherte
/// Änderungen gibt (§1.3, „Erfasste Daten gehen nicht verloren"). Der
/// naheliegende `formGroup.dirty` kann das nicht: Er kennt nur den
/// Vorlagennamen und die Feldnamen. Feldtyp, Datenquelle, Pflichthaken,
/// Datums-Vorbelegung, Reihenfolge und die beiden Dateipfade liegen im Zustand
/// der Seite und laufen komplett an ihm vorbei — wer nur den Pflichthaken
/// setzt und die Seite verlässt, verlöre seine Änderung wortlos.
///
/// Verglichen wird **exakt**: Ein versehentliches Leerzeichen am Namensende ist
/// eine Änderung, denn es landet genauso in der gespeicherten Vorlage. Einzige
/// Zusammenfassung ist `null` gegen `''` — ein nie befülltes und ein wieder
/// geleertes Textfeld sind derselbe leere Stand, und der Unterschied entsteht
/// allein daraus, ob reactive_forms schon einmal einen Wert gesehen hat.
class VorlagenEntwurf extends Equatable {
  final String vorlagenname;
  final String pfadOhneAuflistung;
  final String pfadMitAuflistung;
  final List<VorlagenEntwurfFeld> felder;

  const VorlagenEntwurf({
    required this.vorlagenname,
    required this.pfadOhneAuflistung,
    required this.pfadMitAuflistung,
    required this.felder,
  });

  /// Nimmt den Stand aus den Rohdaten der Detailseite auf.
  ///
  /// [feldname] löst den Control-Schlüssel aus `FieldData.label` zum
  /// eingetippten Namen auf. Die Auflösung bleibt bewusst beim Aufrufer: Die
  /// Namen liegen in einer reactive_forms-`FormGroup`, und die gehört in die
  /// Präsentation — hier zählt nur, dass verglichen wird, was der Anwalt sieht.
  factory VorlagenEntwurf.aufnehmen({
    required String? vorlagenname,
    required String? pfadOhneAuflistung,
    required String? pfadMitAuflistung,
    required List<FieldData> fields,
    required String? Function(String controlKey) feldname,
  }) {
    return VorlagenEntwurf(
      vorlagenname: leerstelle(vorlagenname),
      pfadOhneAuflistung: leerstelle(pfadOhneAuflistung),
      pfadMitAuflistung: leerstelle(pfadMitAuflistung),
      felder: [
        for (final feld in fields)
          VorlagenEntwurfFeld(
            name: leerstelle(feldname(feld.label)),
            inputType: feld.inputType,
            datenquelle: feld.datenquelle,
            pflicht: feld.required,
            vorbelegung: feld.vorbelegung,
          ),
      ],
    );
  }

  /// `null` und `''` sind derselbe leere Stand (siehe Klassenkommentar).
  static String leerstelle(String? wert) => wert ?? '';

  @override
  List<Object?> get props => [
    vorlagenname,
    pfadOhneAuflistung,
    pfadMitAuflistung,
    felder,
  ];
}
