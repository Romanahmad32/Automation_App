/// Welches Backend-DTO eine Dart-Datei spiegelt — abgeleitet statt gepflegt.
///
/// Bis 09.2026 stand die Zuordnung als Handliste in `http_vertrag_test.dart`:
/// Pfad → DTO-Namen. Sie wuchs in drei Wochen von einem auf 44 Eintraege, in
/// 20 Commits, und jeder davon trug denselben Satz zweimal — einmal als
/// Klassenname in `lib/`, einmal als Zeile in der Liste. Eine Liste, die bei
/// jeder neuen Entity nachgepflegt werden muss, wird irgendwann nicht
/// nachgepflegt: Dann faellt die Datei aus der Pruefung, und der Test bleibt
/// gruen.
///
/// **Das Muster**, dem der Bestand folgt: Zur Dart-Klasse `Sache` gehoert das
/// Schema `SacheDto` (oder `Sache`, wo das Backend keinen Zusatz setzt); die
/// Anlege- und Speicher-Varianten heissen `CreateSacheDto` bzw.
/// `SpeichereSacheDto` und gehoeren derselben Datei. Zwei Abweichungen sind
/// haeufig genug, um sie mitzunehmen statt sie einzeln aufzulisten:
///
/// * **Dart-Zusaetze am Klassennamen.** `RegisterNummernStand` traegt das
///   `Stand` fuer die Dart-Seite, das DTO heisst `RegisterNummernDto`.
///   Dasselbe bei `…Datei`, `…Ergebnis` und `…Eintrag`. Die vier Woerter
///   beschreiben die Huelle, nicht die Nutzlast.
/// * **Mehrzahl.** `RegisterZeile` ↔ `RegisterZeilenDto`.
///
/// Was danach uebrig bleibt, steht in [abweichendeDtos] — vier Dateien, jede
/// mit ihrem Grund. Wer eine fuenfte eintraegt, sollte zuerst pruefen, ob sich
/// nicht der Klassenname anpassen laesst: Die Ableitung ist der Regelfall.
library;

/// Anlege-/Speicher-Varianten: Praefixe, mit denen ein DTO dieselbe Sache
/// beschreibt wie das Haupt-DTO.
const List<String> dtoPraefixe = ['Create', 'Speichere'];

/// Woerter, die nur die Dart-Huelle benennen und im DTO-Namen fehlen duerfen.
const List<String> dartZusaetze = ['Datei', 'Stand', 'Ergebnis', 'Eintrag'];

/// Dateien, deren DTO sich nicht aus dem Klassennamen ergibt — mit Grund.
///
/// Der Grund ist wichtiger als der Eintrag: Er sagt der naechsten Aenderung,
/// ob die Abweichung noch besteht oder ob inzwischen umbenannt wurde.
const Map<String, List<String>> abweichendeDtos = {
  // Die Dart-Klasse traegt das Feature im Namen (`Email…`), das DTO nicht.
  'lib/features/email_versand/domain/entities/email_entwurf_ergebnis.dart': [
    'EntwurfErgebnisDto',
  ],
  // Vertauschte Wortfolge: `RegisterImportZeile` gegen `ImportRegisterZeile`.
  'lib/features/register_import/domain/entities/register_import_zeile.dart': [
    'ImportRegisterZeileDto',
  ],
  // Die Datei enthaelt gar keine Klasse, sondern die Uebersetzung eines
  // Vorgangs in JSON als freie Funktionen — es gibt keinen Namen abzuleiten.
  'lib/features/vorgaenge/domain/entities/vorgang_json.dart': ['VorgangDto'],
  // Partizip statt Substantiv: `ArbeitsordnerAufraeumung` gegen
  // `ArbeitsordnerAufgeraeumtDto`, dazu das mitgelieferte `ArbeitsordnerDto`.
  'lib/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart':
      ['ArbeitsordnerAufgeraeumtDto', 'ArbeitsordnerDto'],
};

/// Dateien mit `json['…']`-Zugriffen, die bewusst kein Backend-DTO spiegeln —
/// mit dem Grund, damit die naechste Aenderung ihn nachpruefen kann statt ihn
/// zu glauben.
const Map<String, String> ohneDto = {
  'lib/core/backend/backend_health_probe.dart':
      'liest GET /health — die Bereitschaftsabfrage vor dem DI-Aufbau, '
      'bewusst kein Teil des OpenAPI-Vertrags',
  'lib/core/theme/domain/theme_preferences.dart':
      'geraetelokale Darstellungs-Einstellung, geht nie ueber HTTP',
  'lib/features/form_template_setup/domain/entities/datums_vorbelegung.dart':
      'steckt als Unterobjekt in field_data.dart und damit in derselben '
      'opaken fields-Spalte — dasselbe Schema, dieselbe Begruendung',
  'lib/features/form_template_setup/domain/entities/field_data.dart':
      'Inhalt der opaken fields-Spalte von FormTemplateDto — das Schema '
      'lebt nur in Dart (FALLSTRICKE.md des Features)',
  'lib/features/vorgaenge/domain/entities/vorgang_entwurf.dart':
      'Inhalt des opaken entwurf-Felds von VorgangDto — das Backend reicht '
      'den angefangenen Ausfuellstand durch, ohne ihn zu kennen, das Schema '
      'lebt nur in Dart (FALLSTRICKE.md von word_automation)',
};

/// Ordnet einer Dart-Quelle die Schemata zu, die sie spiegeln darf.
class DtoZuordnung {
  DtoZuordnung(this.schemata);

  /// Alle Schemanamen aus `docs/openapi.json`.
  final Set<String> schemata;

  static final RegExp _kopf = RegExp(
    r'^(?:abstract\s+|base\s+|final\s+|sealed\s+)*class\s+(\w+)',
    multiLine: true,
  );

  /// Die Schemata, deren Name zu einer Klasse in [quelle] passt. Leere Liste,
  /// wenn keines passt — dann meldet der Test die Datei als unzugeordnet,
  /// statt sie stillschweigend durchzuwinken.
  List<String> dtosFuer(String quelle) {
    final ruempfe = <String>{
      for (final treffer in _kopf.allMatches(quelle))
        ...klassenRuempfe(treffer.group(1)!),
    };
    if (ruempfe.isEmpty) return const [];

    return [
      for (final schema in schemata)
        if (ruempfe.contains(schemaRumpf(schema)) ||
            ruempfe.contains(ohneMehrzahl(schemaRumpf(schema))))
          schema,
    ]..sort();
  }

  /// Ein angehaengtes `n` weg — die Mehrzahl, in der ein Sammel-DTO steht.
  static String ohneMehrzahl(String name) =>
      name.endsWith('n') ? name.substring(0, name.length - 1) : name;

  /// Der Rumpf eines Schemanamens: klein, ohne `Dto`-Endung und ohne einen
  /// der [dtoPraefixe].
  static String schemaRumpf(String schema) {
    var rumpf = schema.toLowerCase();
    if (rumpf.endsWith('dto')) {
      rumpf = rumpf.substring(0, rumpf.length - 'dto'.length);
    }
    for (final praefix in dtoPraefixe) {
      final klein = praefix.toLowerCase();
      if (rumpf.startsWith(klein) && rumpf.length > klein.length) {
        return rumpf.substring(klein.length);
      }
    }
    return rumpf;
  }

  /// Die Namen, unter denen eine Dart-Klasse ihr Schema suchen darf: der
  /// eigene, der ohne Dart-Zusatz und beide ohne Mehrzahl-`n`.
  static Set<String> klassenRuempfe(String klasse) {
    final klein = klasse.toLowerCase();
    final formen = <String>{klein};
    for (final zusatz in dartZusaetze) {
      final k = zusatz.toLowerCase();
      if (klein.endsWith(k) && klein.length > k.length) {
        formen.add(klein.substring(0, klein.length - k.length));
      }
    }
    return {...formen, ...formen.map(ohneMehrzahl)};
  }
}
