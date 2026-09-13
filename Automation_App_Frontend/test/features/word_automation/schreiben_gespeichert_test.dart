import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/word_automation/presentation/utils/speicher_vermerk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

/// §4.9 nach #133: Die laufende Nummer eines Schreibens entsteht im
/// **Speicherschritt**, nicht beim Erzeugen. Wer zehnmal auf „Dokument
/// erstellen" drückt und einmal ablegt, hat ein Schreiben und nicht zehn — die
/// Nummer darf deshalb nur dort steigen, wo eine Fassung liegen bleibt.
///
/// Geprüft wird an [vermerkeGespeichertesSchreiben], der einen Stelle, die
/// beide Speicherwege gehen: die Ablage in der Akte und das freie „an anderem
/// Ort speichern".
void main() {
  const referenz = '84/26 C03_HG-E 1427';

  Vorgang vorgang({
    VorgangStatus status = VorgangStatus.erstellt,
    int? schreibenNummer,
    String? dokumentPfad,
    String? aktenOrdner,
  }) => Vorgang(
    referenz: referenz,
    angefragtAm: DateTime(2026, 6, 12),
    status: status,
    schreibenNummer: schreibenNummer,
    dokumentPfad: dokumentPfad,
    aktenOrdner: aktenOrdner,
  );

  /// Eine Wizard-Umgebung mit gewähltem Vorgang und getroffener Wahl.
  Future<WizardUmgebung> umgebungMit(
    Vorgang gewaehlt, {
    bool? neuesSchreiben,
  }) async {
    final umgebung = WizardUmgebung();
    umgebung.ablage.vorgaenge = [gewaehlt];
    await umgebung.wizard.selectVorgang(gewaehlt);
    umgebung.wizard.setNeuesSchreiben(neuesSchreiben);
    return umgebung;
  }

  /// Der Stand, wie ihn die Ablage geschrieben hat.
  Vorgang abgelegt(WizardUmgebung umgebung) => umgebung.ablage.vorgaenge
      .firstWhere((v) => Vorgang.gleicheReferenz(v.referenz, referenz));

  test('die Ablage schreibt Pfad, Aktenordner und die Nummer an den '
      'Vorgang', () async {
    final umgebung = await umgebungMit(vorgang(), neuesSchreiben: false);

    vermerkeGespeichertesSchreiben(
      vorgaenge: umgebung.vorgaenge,
      wizard: umgebung.wizard,
      vorgang: vorgang(),
      dokumentPfad: r'C:\Akten\Mustermann\Anspruchsschreiben an Allianz 1.docx',
      aktenOrdner: 'Mustermann',
      status: VorgangStatus.abgelegt,
    );

    final stand = abgelegt(umgebung);
    expect(stand.schreibenNummer, 1);
    expect(stand.aktenOrdner, 'Mustermann');
    expect(stand.dokumentPfad, contains('Anspruchsschreiben an Allianz 1'));
    expect(stand.status, VorgangStatus.abgelegt);
    await umgebung.schliesse();
  });

  /// Der Folgefehler aus #133: Die frühere Status-Sperre liess die **zweite**
  /// Ablage am Vorgang vorbeilaufen. `dokumentPfad` zeigte danach auf die
  /// Arbeitskopie, die gleich darauf gelöscht wurde (§4.6, §3).
  test('auch das zweite Schreiben wird am Vorgang festgehalten', () async {
    final erste = vorgang(
      status: VorgangStatus.versendet,
      schreibenNummer: 1,
      dokumentPfad: r'C:\Akten\Mustermann\Anspruchsschreiben an Allianz 1.docx',
      aktenOrdner: 'Mustermann',
    );
    final umgebung = await umgebungMit(erste, neuesSchreiben: true);

    vermerkeGespeichertesSchreiben(
      vorgaenge: umgebung.vorgaenge,
      wizard: umgebung.wizard,
      vorgang: erste,
      dokumentPfad: r'C:\Akten\Mustermann\Anspruchsschreiben an Allianz 2.docx',
      aktenOrdner: 'Mustermann',
      status: VorgangStatus.abgelegt,
    );

    final stand = abgelegt(umgebung);
    expect(stand.schreibenNummer, 2);
    expect(stand.dokumentPfad, contains('Allianz 2'));
    // Der Status läuft nur vorwärts: „versendet" fällt nicht auf „abgelegt".
    expect(stand.status, VorgangStatus.versendet);
    await umgebung.schliesse();
  });

  test('eine Korrektur behält die Nummer', () async {
    final umgebung = await umgebungMit(
      vorgang(status: VorgangStatus.abgelegt, schreibenNummer: 2),
      neuesSchreiben: false,
    );

    vermerkeGespeichertesSchreiben(
      vorgaenge: umgebung.vorgaenge,
      wizard: umgebung.wizard,
      vorgang: vorgang(status: VorgangStatus.abgelegt, schreibenNummer: 2),
      dokumentPfad: r'C:\Akten\Mustermann\Anspruchsschreiben an Allianz 2.docx',
      aktenOrdner: 'Mustermann',
      status: VorgangStatus.abgelegt,
    );

    expect(abgelegt(umgebung).schreibenNummer, 2);
    await umgebung.schliesse();
  });

  /// Der Kern von Teil A: Zwischen zwei Speicherschritten darf beliebig oft
  /// erzeugt werden. Das Erzeugen rührt die Nummer nicht an — sichtbar daran,
  /// dass der zweite Speicherschritt ohne neue Wahl dieselbe Nummer schreibt.
  test('mehrfaches Erzeugen vor dem Speichern zählt nicht weiter', () async {
    final start = vorgang(status: VorgangStatus.abgelegt, schreibenNummer: 1);
    final umgebung = await umgebungMit(start, neuesSchreiben: true);

    // Erzeugt, erzeugt, erzeugt — dann einmal gespeichert.
    vermerkeGespeichertesSchreiben(
      vorgaenge: umgebung.vorgaenge,
      wizard: umgebung.wizard,
      vorgang: start,
      dokumentPfad: r'C:\Akten\Mustermann\zwei.docx',
      aktenOrdner: 'Mustermann',
      status: VorgangStatus.abgelegt,
    );
    expect(abgelegt(umgebung).schreibenNummer, 2);

    // Mit dem gespeicherten Schreiben ist die Wahl verbraucht: Wer jetzt noch
    // einmal speichert, ohne neu zu wählen, korrigiert genau dieses Schreiben.
    expect(umgebung.wizard.state.neuesSchreiben, isNull);
    vermerkeGespeichertesSchreiben(
      vorgaenge: umgebung.vorgaenge,
      wizard: umgebung.wizard,
      vorgang: abgelegt(umgebung),
      dokumentPfad: r'C:\Akten\Mustermann\zwei.docx',
      aktenOrdner: 'Mustermann',
      status: VorgangStatus.abgelegt,
    );
    expect(abgelegt(umgebung).schreibenNummer, 2);
    await umgebung.schliesse();
  });

  /// „Gespeichert ist gespeichert": Das freie Speichern an anderem Ort belegt
  /// die Nummer ebenso — es ändert nur weder Status noch Aktenordner, weil die
  /// Datei nicht in der Akte liegt.
  test('freies Speichern belegt die Nummer, ohne Status und Akte zu '
      'berühren', () async {
    final start = vorgang(schreibenNummer: null);
    final umgebung = await umgebungMit(start, neuesSchreiben: false);

    vermerkeGespeichertesSchreiben(
      vorgaenge: umgebung.vorgaenge,
      wizard: umgebung.wizard,
      vorgang: start,
    );

    final stand = abgelegt(umgebung);
    expect(stand.schreibenNummer, 1);
    expect(stand.status, VorgangStatus.erstellt);
    expect(stand.aktenOrdner, isNull);
    await umgebung.schliesse();
  });

  /// Der gewählte Vorgang im Wizard zieht mit — sonst zeigte die Leiste über
  /// dem Formular weiter den Stand von vor dem Speichern.
  test('der gewählte Vorgang kennt die gespeicherte Nummer sofort', () async {
    final start = vorgang();
    final umgebung = await umgebungMit(start, neuesSchreiben: false);

    vermerkeGespeichertesSchreiben(
      vorgaenge: umgebung.vorgaenge,
      wizard: umgebung.wizard,
      vorgang: start,
      dokumentPfad: r'C:\Akten\Mustermann\eins.docx',
      aktenOrdner: 'Mustermann',
      status: VorgangStatus.abgelegt,
    );

    expect(umgebung.wizard.state.selectedVorgang?.schreibenNummer, 1);
    await umgebung.schliesse();
  });
}
