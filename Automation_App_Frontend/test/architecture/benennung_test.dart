import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Erzwingt eine einheitliche Benennung der beiden Bausteine, die es in jedem
/// Feature genau einmal gibt: der Datasource und der Repository-Umsetzung.
///
/// Hintergrund: derselbe Baustein hiess in diesem Projekt einmal
/// `api_vorgaenge_datasource.dart`, einmal `mandant_datasource.dart`, einmal
/// `remote_word_template_datasource.dart` und einmal
/// `local_theme_preferences_datasource.dart` — vier Schreibweisen fuer eine
/// Rolle. Wer die Datasource zu einer Sache sucht, muss dann raten statt zu
/// tippen, und das kostet bei jeder einzelnen Suche Zeit.
///
/// Die Regel trennt Sache und Technik sauber auf:
///
/// * **Der Dateiname nennt die Sache**: `<sache>_datasource.dart`. Kein
///   `api_`, `remote_`, `local_`. So ist der Pfad aus dem Fachbegriff
///   ableitbar, ohne die Umsetzung zu kennen.
/// * **Der Klassenname nennt die Technik**: `Api…` fuer den HTTP-Zugriff auf
///   das Backend, `Filesystem…`/`Local…` fuer alles andere. So ist an der
///   Klasse sofort erkennbar, woher die Daten kommen — und `Api` findet mit
///   einer Suche jede Stelle, die den Dienst anspricht.
/// * **Die Schnittstelle traegt keine Technik**: `<Sache>Datasource`. Sie
///   beschreibt, was zu holen ist, nicht wie.
///
/// Kein `Impl`-Suffix: es benennt keine Eigenschaft, sondern nur die Tatsache,
/// dass es sich um eine Umsetzung handelt — die sieht man am `implements`.
///
/// Bei der **Repository-Umsetzung** unter `data/repositories/` ist es genau
/// umgekehrt: sie heisst `<Sache>RepositoryImpl`. Kein `Api…`, denn sie spricht
/// kein HTTP — sie ruft die Datasource und uebersetzt deren Ergebnis in
/// Domain-Typen und `Failure`s. Ein `Api`-Praefix dort behauptet eine Technik,
/// die eine Schicht tiefer liegt, und laesst die Frage offen, was die Datasource
/// dann noch tut. Hier gibt es keine zweite Umsetzung, von der zu unterscheiden
/// waere, also bleibt das neutrale `Impl`.
///
/// Braucht ein Feature gar keine Uebersetzung, entfaellt die Schicht ganz: dann
/// setzt die Datasource das Repository direkt um
/// (`@Injectable(as: VorgangRepository)`) und es gibt kein `…RepositoryImpl`.
/// Beides ist erlaubt — nur nicht dieselbe Rolle unter zwei Namen.
void main() {
  // Technik-Begriffe, die im Dateinamen nichts zu suchen haben. Geprueft wird
  // je Unterstrich-Abschnitt, damit ein fachliches Wort, das eine Marke
  // enthaelt, nicht faelschlich anschlaegt.
  const technikMarken = {
    'api',
    'rest',
    'http',
    'dio',
    'remote',
    'local',
    'db',
    'sqlite',
    'filesystem',
    'memory',
  };

  // Praefixe, mit denen eine konkrete Datasource ihre Herkunft benennen darf.
  const erlaubtePraefixe = ['Api', 'Local', 'Filesystem', 'InMemory'];

  final klassenkopf = RegExp(r'^(abstract\s+)?class\s+(\w+)', multiLine: true);

  List<Quelldatei> datasourceDateien() => dartQuelldateien('lib')
      .map((datei) => Quelldatei(relPfad(datei), datei.readAsStringSync()))
      .where((datei) => datei.pfad.endsWith('_datasource.dart'))
      .toList();

  test('Dateinamen von Datasources nennen die Sache, nicht die Technik', () {
    final verstoesse = <String>[];

    for (final datei in datasourceDateien()) {
      final name = datei.pfad.split('/').last;
      final sache = name.substring(0, name.length - '_datasource.dart'.length);
      final marken = sache.split('_').where(technikMarken.contains).toList();
      if (marken.isNotEmpty) {
        verstoesse.add('${datei.pfad}: "${marken.join('", "')}" im Dateinamen');
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Die Technik gehoert in den Klassennamen, nicht in den Dateinamen. '
          'Aus api_vorgaenge_datasource.dart wird vorgaenge_datasource.dart '
          'mit der Klasse ApiVorgaengeDatasource.\n${verstoesse.join('\n')}',
    );
  });

  test('konkrete Datasource-Klassen tragen ihre Technik als Praefix', () {
    final verstoesse = <String>[];

    for (final datei in datasourceDateien()) {
      for (final treffer in klassenkopf.allMatches(datei.inhalt)) {
        final istAbstrakt = treffer.group(1) != null;
        final name = treffer.group(2)!;
        if (!name.endsWith('Datasource') && !name.endsWith('DatasourceImpl')) {
          continue;
        }
        if (name.endsWith('DatasourceImpl')) {
          verstoesse.add('${datei.pfad}: $name — Impl-Suffix');
          continue;
        }
        if (istAbstrakt) {
          final technik = erlaubtePraefixe.where(name.startsWith).toList();
          if (technik.isNotEmpty) {
            verstoesse.add(
              '${datei.pfad}: $name — Schnittstelle mit Technik-Praefix '
              '"${technik.first}"',
            );
          }
          continue;
        }
        if (!erlaubtePraefixe.any(name.startsWith)) {
          verstoesse.add(
            '${datei.pfad}: $name — ohne Herkunfts-Praefix '
            '(${erlaubtePraefixe.join(", ")})',
          );
        }
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Eine konkrete Datasource sagt im Namen, woher die Daten kommen; '
          'die Schnittstelle sagt nur, was zu holen ist.\n'
          '${verstoesse.join('\n')}',
    );
  });

  test('Repository-Umsetzungen heissen <Sache>RepositoryImpl', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      final pfad = relPfad(datei);
      if (!pfad.contains('/data/repositories/')) continue;

      if (!pfad.endsWith('_repository_impl.dart')) {
        verstoesse.add('$pfad — Datei nicht auf _repository_impl.dart');
      }
      for (final treffer in klassenkopf.allMatches(datei.readAsStringSync())) {
        final name = treffer.group(2)!;
        if (name.endsWith('Repository')) {
          verstoesse.add('$pfad: $name — Klasse nicht auf RepositoryImpl');
        }
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Schicht spricht kein HTTP, sie uebersetzt nur — das Api-Praefix '
          'gehoert an die Datasource. Aus api_zentralruf_repository.dart wird '
          'zentralruf_repository_impl.dart mit ZentralrufRepositoryImpl.\n'
          '${verstoesse.join('\n')}',
    );
  });

  // Bis 09.2026 stand hier ein vierter Teiltest: "unter data/datasources/
  // liegen nur Datasources". Er prueft keine Benennung mehr, sondern
  // Ordnerhygiene — welche Datei in einem Ordner liegen darf — und ist damit
  // Geschmack: Ein `mailbox_hub.dart` neben den Datasources findet, wer den
  // Ordner oeffnet, und die Regel oben (Sache im Dateinamen) gilt fuer ihn
  // ohnehin nicht. Was er einbrachte, war eine dritte Ausnahmeliste, die bei
  // jedem neuen Hub gepflegt werden musste; gefangen hat er nie etwas.
}

/// Pfad und Inhalt einer eingelesenen Datei — damit jede Datei genau einmal
/// von der Platte kommt, auch wenn mehrere Pruefungen sie brauchen.
class Quelldatei {
  final String pfad;
  final String inhalt;

  const Quelldatei(this.pfad, this.inhalt);
}
