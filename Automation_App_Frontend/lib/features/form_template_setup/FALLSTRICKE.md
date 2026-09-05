# form_template_setup — Fallstricke

Der lange Teil des Steckbriefs `FEATURE.md`. Hier steht, was beim Einrichten einer Vorlage
regelmäßig schiefgeht — die kurzen Merksätze bleiben drüben.

## Vom Namen zur Datenquelle

`FeldDatenquelleErkennung` (`domain/services/`) löst einen Platzhalternamen zu einer
`FeldDatenquelle` auf. Sie wird an **zwei** Stellen gebraucht, und das ist der Grund, warum es sie
gibt: hier beim Übernehmen eines Platzhalters (Vorauswahl im Dropdown, sichtbar und änderbar) und
zur Laufzeit im `VorgangPrefillMatcher` für Bestandsfelder, an denen nie eine Quelle gesetzt wurde.

Vorher lagen dieselben Stichwörter in drei Listen mit je eigener Prüfreihenfolge: eine für die
Mandantenfelder, der inzwischen abgeschaffte `VorgangsdatenFieldMatcher` für die Antwortfelder,
und das Dropdown. Was der Anwalt sah, war deshalb etwas anderes als das, was beim Ausfüllen
passierte.

- **Die Reihenfolge der Prüfungen ist die Regel** — spezifisch vor allgemein. Wer eine Zeile
  verschiebt, ändert das Verhalten; die Tests halten jede Regel einzeln fest.
- Ganz vorn stehen die Unfallangaben, erst danach die Beteiligten: `{{Unfallort des
  Geschädigten}}` meint den Ort des Unfalls. Andersherum fischte das „ort" der Mandantengruppe
  den Namen ab, und das Schreiben trüge still den Wohnort. Wörter wie „unfallort", „unfalltag"
  oder „polizei" benennen nie eine Stammdatenangabe — nur deshalb dürfen sie vorne stehen.
- **Das Kennzeichen heißt „Gegnerkennzeichen", und das blosse „Kennzeichen" trifft trotzdem.** An
  einem Unfall sind zwei Fahrzeuge beteiligt, deshalb nennt der angebotene Name seinen Halter
  (§4.1): **Gegnerkennzeichen** und **Mandantenkennzeichen**. Gefunden werden beide über einen
  *Teilstring*-Test — `hat('kennzeichen')`, beim Mandanten hinter dem Sprung in die
  Mandantengruppe. Das ist keine Bequemlichkeit, sondern die Zusage aus dem Umbenennen: Die
  Kanzleivorlagen tragen `{{Kennzeichen}}` und `{{Mandant Kennzeichen}}`, und wer die Regel zu
  einem exakten Vergleich „aufräumt", nimmt jedem dieser Felder still seinen Wert. Kein Fehler,
  keine Meldung — auffallen würde es am leeren Platz im nächsten Schreiben.
- **„Zeichen" und „Aktenzeichen" meinen dasselbe, „Referenz" nicht.** Die ersten beiden liefern
  `216/26 C03` — den Bezeichner, der in den Brief gehört. Nur wer sein Feld „Referenz" nennt,
  bekommt die volle Zeichenkette samt Kennzeichen; die trägt allein die Zentralruf-Zuordnung
  (§4.2). „Ihr Zeichen" bleibt ungebunden: das meint die Gegenseite, nicht die eigene Kanzlei.
- Nennt ein Name zwei einzeln gespeicherte Angaben (`{{VersicherungPlzOrt}}`,
  `{{MandantVornameNachname}}`), bindet die Erkennung ihn **nicht**, und `FeldNameHinweis` sagt
  unter dem Feld, warum. Grund: Solche Namen lieferten früher still nur die erste der beiden
  Angaben — der Fehler steckte damit in jedem erzeugten Brief, statt einmal hier aufzufallen.
- Die Abgrenzung dahinter: **einzeln gespeichert → eigene Datenquelle; Zusammensetzung → zwei
  Platzhalter nebeneinander in der Word-Datei.** Ausnahme sind die Anschriften
  (`mandantAnschrift`, `versichererAnschrift`): Sie lassen fehlende Teile weg, was zwei
  Platzhalter nebeneinander nicht können — dort bliebe eine Leerstelle samt wanderndem Komma.
- Der Hinweis schweigt, sobald am Feld eine Datenquelle gewählt ist: Dann hat der Anwalt
  entschieden, und eine gesetzte Quelle gewinnt immer über die Erkennung.
- **Dieselbe Erkennung schlägt auch den Feldtyp vor** (`_feldtypFuer`) — und dort steht das
  Kennzeichen **vor** der Datumsprüfung. Sonst fischte deren Wortliste („datum", „tag", „frist",
  „beginn") einen Namen wie `{{KennzeichenAmUnfalltag}}` ab, und das Feld verlangte ein Datum auf
  einem Wert wie `HG-E 1427`. Umgekehrt geht nichts verloren: Kein Datumsfeld heißt „Kennzeichen".
- **`InputType.kennzeichen` (#17) steht in keiner Bestandsvorlage** und wird erst geschrieben, wenn
  ihn jemand am Feld auswählt — bis dahin bleibt dort `text`. Das Backend hält `fields` als opakes
  JSON und reicht den Wert durch; das Schema lebt nur in Dart. Die Kehrseite steht weiter unten:
  `InputType.fromValue` wirft bei Unbekanntem, eine Vorlage mit dem neuen Wert lässt sich also von
  einer **älteren** App-Fassung nicht mehr laden. Was das Feld im Ausfüllschritt daraus macht
  (Formatprüfung, Auswahlhilfe), steht in `word_automation/FALLSTRICKE.md`.

## Platzhalter und Dateien

- Erlaubte Zeichen im Platzhalternamen prüft erst das Backend beim Erzeugen
  (`^[\p{L}\p{N} _-]+$`, sonst 400): ein Label mit Punkt oder Doppelpunkt lässt sich hier speichern
  und scheitert erst im Wizard.
- Die Datei im Slot „mit Auflistung“ muss `{{Schadensaufstellung}}` enthalten, sonst schlägt die
  Erzeugung fehl; die Karte warnt nur, sie blockiert das Speichern nicht. Der Chip zu diesem
  Platzhalter wird trotzdem angeboten — als Eingabefeld übernehmen wäre falsch, die Tabelle setzt
  ihn selbst ein.
- **Zuordnen heißt umbenennen, nicht die `.docx` anfassen** (#36): `PlatzhalterZuordnung` schlägt
  zu einem Namen ohne Gegenstück Kandidaten der anderen Seite vor — gleich nach
  `FeldDatenquelleErkennung.normalisiere` (`Versicherungsschein-Nr` ↔ `{{VersicherungsscheinNr}}`,
  der stille Killer: das Backend ersetzt nur `IgnoreCase`) oder ineinander steckend
  (`Unfalldatum` ↔ `{{Verkehrsunfalldatum}}`, ab fünf Zeichen). Vorgeschlagen wird nur, was **kein**
  Feld wegnimmt: Ein Feld, das schon irgendwo ankommt, steht als Befund da statt als Angebot —
  es umzubenennen tauschte nur den einen Waisen gegen den anderen. Genau das ist der Produktivfall,
  in dem die beiden Word-Dateien dieselbe Angabe verschieden nennen; dort hilft nur Word.
  `{{VersScheinNr}}` erkennt keine Regel — deshalb hat der Dialog die aufklappbare Handauswahl.
- Der Word-Pfad läuft im Frontend absolut und wird auch aus `word_automation` überschrieben
  (`WizardCubit.linkWordFileToTemplate`). Gespeichert wird er seit #33 im **Backend** relativ zum
  eingestellten Vorlagenordner, sofern die Datei darin liegt (`FormTemplatesController`) — das
  Frontend rechnet nie um. Eine Datei außerhalb bietet `_pickFile` zum Hineinkopieren an
  (`VorlagenHineinholen`); abgelehnt bleibt sie absolut verknüpft und fehlt in der Sicherung.
  `fields` liegt im Backend als opakes JSON — das Schema
  lebt nur in Dart, ein unbekannter `inputType` wirft beim Laden (`InputType.fromValue`). Tot:
  `FormTemplateField` (gemeint ist `FieldData`) und `getFormTemplateByName`.

## Vollständigkeitsrechnung über beide Dateien

`VorlagenStand` (`domain/services/`) sagt in **einer** Rechnung über **beide** Word-Dateien, was einer
Vorlage noch fehlt (#104). Vorher zählten zwei Dienste dieselbe Sache aus zwei Richtungen und je Datei
getrennt: `PlatzhalterUebernahme.uebernehmbare` (Platzhalter ohne Feld) und `FeldVorkommen` (Feld ohne
Platzhalter).

- **Eine Rechnung statt zwei, weil sonst über die Dateigrenze hinweg doppelt gezählt wird.** Wer je
  Datei getrennt fragte, zählte einen Platzhalter, der in der Datei ohne **und** der Datei mit
  Auflistung steht, zweimal — und bekam nie eine Aussage über die Vorlage als Ganzes.
- **Ein Feld ohne Vorkommen ist nur eine Warnung, kein Mangel.** Es bleibt wirkungslos, aber das
  erzeugte Dokument sieht deswegen nicht falsch aus — anders als ein Platzhalter ohne Feld: Der bliebe
  als rohes `{{…}}` im Brief stehen und macht die Vorlage unvollständig.
- **App-eigene Platzhalter zählen nie als offen** — `PlatzhalterUebernahme` filtert sie aus der Liste
  „Platzhalter ohne Feld" heraus, denn die füllt das Backend beim Erzeugen selbst, ohne dass der
  Anwalt ihnen ein Feld gibt.
- **Auslegung: Das gilt nicht umgekehrt.** Trägt ein Feld den Namen eines app-eigenen Platzhalters, der
  Platzhalter kommt in keiner Datei vor, warnt `VorlagenStand` trotzdem — die Ausnahme betrifft nur den
  Platzhalter (er braucht kein Feld), nicht ein Feld, das wirkungslos bleibt.

## Vorbelegung der Datumsfelder

`DatumsVorbelegung` (`domain/entities/`) sagt je Datumsfeld, um wie viel es beim Ausfüllen in die
Zukunft vorbelegt wird — eingestellt im Vorlageneditor, eingesetzt im `FormTemplateBuilder`. Vorher
war das ein Sonderfall im Ausfüllschritt: „zahlungsfrist" im Namen bekam heute + 35 Tage, alles
andere heute; eine andere Frist ging nur über den Quellcode.

- **`null` und „lauter Nullen" sind nicht dasselbe** — das ist der Fallstrick. `null` heißt „an
  diesem Feld wurde nie eine Vorbelegung eingestellt", und dann greift die Namensregel
  (`DatumsVorbelegung.ausFeldname`). Lauter Nullen heißt „bewusst heute" und schaltet die
  Namensregel ab. Ohne diese Unterscheidung liesse sich die Ableitung an einem Feld namens
  „Zahlungsfrist" nie loswerden: Jedes Zurücksetzen auf 0 fiele sofort wieder auf 5 Wochen.
  Deshalb hat `FieldData` neben `copyWith` (das die Vorbelegung nur durchreicht) die Methode
  `mitVorbelegung`, und `toJson` schreibt den Schlüssel `vorbelegung` **nur, wenn er gesetzt ist**
  — eine Bestandsvorlage bleibt damit byteidentisch, und ein vorhandener Schlüssel heißt umgekehrt
  immer „bewusst eingestellt".
- Die Namensregel prüft **„zahlungsfrist" vor „frist"** (5 bzw. 4 Wochen, Entscheidung vom
  29.08.2026): „frist" steckt in „zahlungsfrist". Wer die beiden Zeilen tauscht, gibt jedem
  Zahlungsfrist-Feld still eine Woche weniger. Verglichen wird über
  `FeldDatenquelleErkennung.normalisiere`, damit `{{Zahlungs-Frist}}` derselbe Name ist.
- **Gerechnet wird über den `DateTime`-Konstruktor, nicht mit `Duration`.** Ein „Jahr" als 365 Tage
  wäre im Schaltjahr falsch, und eine Sommerzeitumstellung verschöbe das Ergebnis über Mitternacht
  um einen Tag. Die Überläufe der Kalenderrechnung sind gewollt und in
  `datums_vorbelegung_test.dart` festgehalten: 29.02.2028 + 1 Jahr → 01.03.2029, 31.01.2027 +
  1 Monat → 03.03.2027, im Schaltjahr 31.01.2028 + 1 Monat → 02.03.2028.
- **Das ist keine Fristenlogik (§8):** keine Werktagsverschiebung, keine Feiertage, keine
  Wiedervorlage. 4 Wochen sind 28 Kalendertage. Der Wert landet als sichtbarer Vorschlag im
  Datumsfeld des Ausfüllschritts und ist dort überschreibbar — die Vorschauzeile des Editors
  („ergibt heute: …") zeigt darum das gerechnete Datum und nicht bloß die Zahlen.
- Der Editor steht in der Feldzeile der Detailseite und liest den Feldnamen aus dem **Control**,
  nicht aus `FieldData.label` (siehe oben, `field_0`). Sonst leitete er aus `field_0` ab.
- **Ein Feld wird fortgeschrieben, nie neu gebaut** — an beiden Enden des Editors. Zweimal
  wechselt ein `FieldData` unterwegs das Label: `InitialTemplateForm.fromTemplate` tauscht beim
  Öffnen den Namen gegen den Control-Schlüssel, `FormTemplateActionButtons` beim Speichern zurück.
  Beide Stellen bauten dafür ein neues `FieldData` aus fünf Feldern zusammen und liessen die
  Vorbelegung als sechstes stillschweigend liegen (#105). Sichtbar war das nicht: `toJson` schreibt
  den Schlüssel bei `null` gar nicht, der Verlust sah also aus wie „nie eingestellt", und
  aufgefallen wäre er erst am falschen Datum im nächsten Schreiben. Beide Stellen gehen deshalb
  über `element.copyWith(order: …, label: …)`; jedes neue Feld an `FieldData` kommt damit von
  selbst mit, statt an zwei Stellen nachgetragen werden zu müssen. Bewacht von
  `datums_vorbelegung_speicherweg_test.dart`, das den Weg hinein und heraus am Knopf prüft — samt
  der Gegenprobe, dass ein Feld ohne Einstellung den Schlüssel weiterhin nicht schreibt.

## Verlassen mit ungespeicherten Änderungen

`VorlagenVerlassenWache` (`presentation/widgets/`) umschließt den Inhalt der Detailseite und fragt
über ein `PopScope` nach, bevor der Editor mit ungespeicherten Änderungen zugeht (#104, §1.3).
Verglichen wird ein Schnappschuss: `VorlagenEntwurf` (`domain/services/`) beim Aufgehen gegen den
jeweils aktuellen Stand.

- **`formGroup.dirty` reicht dafür nicht** — er kennt nur den Vorlagennamen und die Feldnamen.
  Feldtyp, Datenquelle, Pflichthaken, Datums-Vorbelegung, Reihenfolge und die beiden Word-Pfade
  liegen im Zustand der Seite und laufen komplett an ihm vorbei. Wer nur den Pflichthaken setzt und
  die Seite verlässt, verlöre seine Änderung wortlos. Deshalb der Schnappschuss über *alles*.
- **Der Vergleich muss die Feldnamen auflösen.** Solange die Seite offen ist, hält `FieldData.label`
  den Control-Schlüssel (`field_0`, siehe oben) — und der ändert sich beim Umbenennen nie. Ein
  Vergleich über die Schlüssel wäre also blind für genau die Änderung, die der Anwalt am häufigsten
  macht. `VorlagenEntwurf.aufnehmen` bekommt deshalb eine Auflösungsfunktion und nimmt den Wert des
  Controls auf. Verglichen wird exakt (ein Leerzeichen am Namensende ist eine Änderung, es landet
  ja auch so in der Vorlage); nur `null` und `''` gelten als derselbe leere Stand.
- **Abbrechen liefert jetzt `false`, nicht mehr `true`.** Der Rückgabewert der Detailseite heißt
  „es hat sich etwas geändert" und lässt die Übersicht neu laden (`form_template_row.dart`,
  `form_template_management_page.dart`). Abbrechen hat nichts geändert — das frühere `true` liess
  die Liste bei jedem Blick in eine Vorlage grundlos neu laden. Nur der Erfolgsweg gibt `true`.
- **Speichern geht über `Navigator.pop`, Abbrechen über `Navigator.maybePop`.** Das ist der
  Unterschied, an dem die Wache hängt: `maybePop` fragt `PopScope`, `pop` nicht. Nach erfolgreichem
  Speichern gibt es nichts mehr zu verwerfen, also darf der Pop durchgehen. Wer den Erfolgsweg auf
  `maybePop` umstellt, bekommt die Verwerfen-Frage nach dem Speichern zu sehen;
  `test/features/form_template_setup/vorlagen_verlassen_test.dart` hält beide Wege fest.
- Die Wache **belauscht die `FormGroup`**: Tippen im Namensfeld baut die Seite nicht neu auf. Ohne
  den Horcher stünde `canPop` auf dem Stand des letzten Aufbaus, und die frische Umbenennung ginge
  beim Verlassen ohne Rückfrage verloren.
- **Während des Speicherns ist die Wache gesperrt** (`gesperrt: true`, aus dem Bloc-Zustand
  `SubmittingFormTemplateData`), und Abbrechen wie Speichern sind aus. Sonst könnte der Anwalt
  während der laufenden Anfrage Abbrechen drücken, die Verwerfen-Frage stünde offen, und der
  Erfolgs-`pop(true)` träfe den Dialog statt der Seite — die Seite meldete dann `false`, obwohl
  gespeichert wurde. Gesperrt kann kein Dialog offen sein, wenn der Erfolg eintrifft.

## Zustand

- `FormTemplateOverviewBloc` ist bewusst `@lazySingleton` (Verwaltung und Wizard-Dropdown teilen
  ihn): per `BlocProvider.value` einbinden, sonst schließt ihn die Seite beim Verlassen; nach der
  Rückkehr aus der Detailseite braucht es ein `LoadFormTemplatesEvent`.
