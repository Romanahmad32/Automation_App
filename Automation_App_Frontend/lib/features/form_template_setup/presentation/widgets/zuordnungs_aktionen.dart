import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_uebernahme.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/zuordnungs_dialog.dart';
import 'package:flutter/material.dart';

/// Die beiden Wege in den [ZuordnungsDialog] (#36) — aus der Detailseite
/// herausgezogen, weil sie dort das Zeilenbudget sprengten und weil sie
/// zusammengehören: Sie arbeiten auf denselben Namen und benennen nach
/// derselben Regel um.
///
/// Der Name eines Feldes steht **im Formular-Control**, nicht in
/// `FieldData.label` (das hält auf der offenen Seite nur den Control-Schlüssel,
/// siehe FEATURE.md). Deshalb reicht zum Umbenennen ein `updateValue`: Typ,
/// Datenquelle, Pflicht und Reihenfolge des Feldes bleiben unberührt.
class ZuordnungsAktionen {
  /// Der veränderliche Stand des Editors — Feldliste, Formular und die
  /// Auflösung der Feldnamen kommen von dort.
  final VorlagenBearbeitung bearbeitung;

  /// Die Platzhalter beider verknüpfter Word-Dateien, so weit gelesen.
  final List<String> allePlatzhalter;

  const ZuordnungsAktionen({
    required this.bearbeitung,
    required this.allePlatzhalter,
  });

  /// Aus dem Zustand des [TemplatePlaceholdersBloc]: Beide Slots zu einer
  /// Menge zusammengezogen. Was noch lädt oder fehlschlug, zählt als „nicht
  /// vorhanden" — dann fällt der Abgleich weg, statt falsch zu melden.
  factory ZuordnungsAktionen.ausZustand(
    TemplatePlaceholdersState zustand, {
    required VorlagenBearbeitung bearbeitung,
  }) {
    return ZuordnungsAktionen(
      bearbeitung: bearbeitung,
      allePlatzhalter: [
        for (final slot in TemplateFileSlot.values)
          if (zustand.forSlot(slot) case SlotPlaceholdersLoaded(
            placeholders: final erkannt,
          ))
            ...erkannt,
      ],
    );
  }

  /// Die aktuell eingetragenen Feldnamen.
  List<String?> get feldnamen => bearbeitung.feldnamen;

  /// Klick auf einen offenen Chip: Der Platzhalter hat kein Feld. Ist ein
  /// vorhandenes Feld gemeint, wird es umbenannt; sonst legt [onNeuesFeld] es
  /// an. Ohne Kandidaten fragt der Dialog nicht.
  Future<void> vomPlatzhalter(
    BuildContext context,
    String platzhalter, {
    required VoidCallback onNeuesFeld,
  }) async {
    final grund = PlatzhalterUebernahme.ablehnungsgrund(platzhalter, feldnamen);
    if (grund != null) {
      Rueckmeldung.zeigeHinweis(context, grund);
      return;
    }
    final wahl = await ZuordnungsDialog.fuerPlatzhalter(
      context,
      platzhalter: platzhalter,
      feldnamen: feldnamen,
      allePlatzhalter: allePlatzhalter,
    );
    if (!context.mounted) return;
    switch (wahl) {
      case NeuesFeldAnlegen():
        onNeuesFeld();
      case NamenUebernehmen(name: final alterName):
        umbenennen(alterName, platzhalter);
      case null:
        break;
    }
  }

  /// Klick auf das Kennzeichen „in keiner Datei" an einer Feldzeile: Der Wert
  /// dieses Feldes wird beim Erzeugen verworfen. Zur Wahl stehen die
  /// Platzhalter, die heute kein Feld haben.
  Future<void> vomFeld(BuildContext context, FieldData feld) async {
    final control = bearbeitung.formGroup.control(feld.label);
    final offene = PlatzhalterUebernahme.uebernehmbare(
      allePlatzhalter,
      feldnamen,
    );
    if (offene.isEmpty) {
      Rueckmeldung.zeigeHinweis(
        context,
        'In den verknüpften Word-Dateien ist kein Platzhalter mehr frei.',
      );
      return;
    }
    final wahl = await ZuordnungsDialog.fuerFeld(
      context,
      feldname: (control.value as String?)?.trim() ?? '',
      offenePlatzhalter: offene,
    );
    if (wahl case NamenUebernehmen(name: final platzhalter)) {
      control.updateValue(platzhalter);
    }
  }

  /// Benennt das Feld mit dem Namen [alt] in [neu] um.
  void umbenennen(String alt, String neu) {
    final gesucht = alt.trim().toLowerCase();
    for (final field in bearbeitung.fields) {
      final control = bearbeitung.formGroup.control(field.label);
      if ((control.value as String?)?.trim().toLowerCase() != gesucht) {
        continue;
      }
      control.updateValue(neu);
      return;
    }
  }
}
