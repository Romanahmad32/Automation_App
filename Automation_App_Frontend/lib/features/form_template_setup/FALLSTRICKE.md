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
- **„In Word öffnen" läuft über `DateiOeffner` (`lib/core/dateien/`)** — an der Auswahlkachel und an
  der Dateikarte des Editors, mit derselben Aufschrift und demselben `Icons.edit_document` wie in
  `WizardStepReview`. Wer beim Einrichten einen falsch geschriebenen Platzhalter findet, muss ihn in
  Word reparieren; bisher hieß das, die Datei im Explorer zu suchen. Die Mechanik ist
  `Process.start('rundll32', ['url.dll,FileProtocolHandler', pfad])` und **nicht** `cmd /c start`:
  Der Pfad geht dann nicht durch die Shell, und ein `&` im Ordnernamen zerlegt den Aufruf nicht. Und
  **nicht** `url_launcher`: `wizard_step_review.dart` hält fest, dass `launchUrl` die Datei erst beim
  zweiten Klick öffnete. Die Klasse lag bis Stufe 5 als `AnhangOeffner` in
  `email_versand/presentation/utils/`; sie steht jetzt in `core/`, weil die Mechanik nichts mit
  Mailversand zu tun hat und der Vorlageneditor sich sonst quer über eine fremde `presentation`-Schicht
  bedient hätte. `oeffne` und `zeigeImOrdner` sind **veränderliche Felder** — dieselbe Naht wie
  `VorlagenDateiwahl.waehle`: Ein Widget-Test darf keinen Prozess starten, und `zuruecksetzen()` gehört
  in ein `addTearDown`. Schlägt das Öffnen fehl, meldet `VorlagenDateiOeffnen.inWord` „Die Datei wurde
  nicht gefunden: <Dateiname>" samt Aktion „Im Ordner zeigen" — der **Dateiname**, nicht der Pfad,
  denn daran erkennt der Anwalt, welche der beiden Dateien gemeint ist.
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
- **`VorlagenStandKarte` (`presentation/widgets/`) zeigt diese Rechnung jetzt an einer Stelle** unter den
  Datei-Slots (#104 Stufe 2) und ersetzt die zwei Zählzeilen, die bis dahin unter jeder `PlatzhalterChips`-Liste
  standen: eine rote Warnzeile und ein „14 von 18 übernommen", je Word-Datei getrennt gezählt. Bei zwei
  verknüpften Dateien las der Anwalt vier Zahlen, von denen keine für die Vorlage als Ganzes galt — derselbe
  Platzhalter in beiden Dateien zählte doppelt. Die Karte liest dieselbe `VorlagenStand`-Rechnung wie die
  Feldertabelle und zählt ihn einmal; „Alle übernehmen" lebt seither nur noch hier, nicht mehr unter den Chips.

## Feldzeile und Tabelle

`FelderSpalten` (`presentation/widgets/`) ist **die eine** Spaltenbeschreibung der Feldertabelle (#104 Stufe 2):
Tabellenkopf (`TemplateFieldsTableHeader`) und Feldzeile (`TemplateFieldItem`) bauen beide über
`FelderSpalten.zeile(...)` aus derselben Liste. Vorher stand die Aufteilung zweimal da — eine Flex-Liste im
Tabellenkopf, eine zweite in der Feldzeile, dazu je eigene Platzhalter für Ziehgriff und Löschen-Knopf. Die beiden
liefen bei jeder Änderung auseinander: Der Kopf „ANFORDERUNG" stand irgendwann über der Datenquelle, weil nur eine
der beiden Listen angepasst wurde. `FelderSpalten.zeile` besteht per `assert` darauf, dass Kopf und Zeile gleich
viele Zellen liefern.

- **Alles Seltene liegt im Aufklapper** (`FeldAufklappInhalt`): die Datums-Vorbelegung und `FeldNameHinweis`.
  Zugeklappt ist jede Zeile gleich hoch (`FelderSpalten.zeilenHoehe`, Mindest- nicht Festhöhe wegen der
  Schriftskala, Issue #57). Vorher stand beides **immer** unter der Zeile — bei achtzehn Feldern verschwand die
  eine Zeile mit dem Hinweis in siebzehn ohne Inhalt.
- **Der Chevron schaltet ab, wenn `FeldAufklappInhalt.hatInhalt` `false` liefert** — ein Knopf, der eine leere
  Fläche öffnet, ist eine Enttäuschung. Eine Zeile geht **offen** auf, wenn ihr Name mehrdeutig ist (dieselbe
  Regel wie bei „Zu prüfen" unten): Das ist ein Befund, den der Anwalt sehen muss, kein Angebot, das er suchen
  muss. Klappt er sie zu, gewinnt seine Entscheidung über den Vorschlag, bis die Zeile neu aufgebaut wird.
- **`DatumsVorbelegungEditor` braucht einen `ValueKey`, der am Feld hängt, nicht an der Position.** Er ist ein
  `StatefulWidget` mit vier `TextEditingController`n, und beim Zu-/Aufklappen wechselt seine Stelle im Baum. Ohne
  eigenen Schlüssel gliche Flutter ihn gegen ein anderes Widget derselben Art ab — die Eingabe des Anwalts stünde
  dann in der falschen Zeile.
- **Alle vier Vorkommens-Kennzeichen an jeder Zeile, auf Wunsch des Anwalts** (`FeldVorkommenPille` in
  `feld_bezeichnung_zelle.dart`, ausgelöst über `FeldVorkommenBeobachter`). Stufe 2 hatte die drei Auskunftsfälle
  *beide · nur HGn · nur Auflistung* abgeschafft, weil sie an jeder Zeile standen, ohne dass der Anwalt je etwas
  damit tat. Der Anwalt wollte sie zurück: Die beiden Word-Dateien sind gleichwertig, und er will an **jeder**
  Zeile sehen, welches Feld welche Datei bedient — nicht erst im Fehlerfall danach suchen.
  Das alte Argument („achtzehn Kennzeichen verstecken das eine, das zählt") trägt eine Hierarchie aus, statt die
  drei Fälle wegzulassen: Die Auskunftsfälle bleiben **ruhig** (`AuflistungBadge` mit
  `colorScheme.onSurfaceVariant` — `outline` als Schrift käme auf der Tönung nur auf 1,9:1 Kontrast; kein Klickweg), nur „in keiner Datei" trägt die Fehlerfarbe und bleibt der einzige Fall, der auf einen Klick
  reagiert (Zuordnung, #36). Je Fall ein eigenes Icon (`FeldVorkommenIcon`-Extension), damit die Zeile auch ohne
  Text unterscheidbar bleibt. `FeldVorkommen` selbst blieb über beide Entscheidungen hinweg vierwertig.
- **`FelderFilter`** (`domain/services/`) sagt, welche Feldzeilen sichtbar sind — *Alle · Nur offene · Zu
  prüfen*. Die Regeln stehen bewusst dort und nicht im Widget: „offen" ist `VorlagenStand.felderOhneVorkommen`
  (siehe oben), „zu prüfen" ist **dieselbe Bedingung wie `FeldNameHinweis`** — ein mehrdeutiger Name
  (`FeldDatenquelleErkennung.erkenne(name).hinweis` ist gesetzt) **und** keine Datenquelle gewählt. Eine zweite
  Regel danebenzustellen hieße, dass der Filter etwas anderes zählt, als die Zeile darunter zeigt.
  `FelderFilter.start` öffnet die Karte auf „Nur offene", solange die Vorlage unvollständig ist, sonst auf „Alle".
- **Bei aktivem Filter ist Umsortieren gesperrt** (`umsortierenMoeglich` an `TemplateFieldItem`, gesetzt aus
  `_filter == FelderFilter.alle` in `TemplateFieldsCard`): Die Liste zeigt dann eine Auswahl, und der Index, den
  der Ziehgriff der `ReorderableListView` meldet, ist der Index in dieser Auswahl, nicht im Feldbestand — ein Zug
  verschöbe das Feld an eine Stelle, die der Anwalt gar nicht sieht. Der Griff bleibt sichtbar, nur grau und mit
  erklärendem Tooltip, statt zu verschwinden.
- **Das Häkchen vor der gewählten Filter-Aufschrift bleibt an** (`SegmentedButton.selected`, bewacht von
  `auswahl_sichtbar_test.dart`): Es ist die einzige Markierung, die auch bei geringem Farbkontrast trägt. Den
  Platz bei der größten Schriftstufe (Issue #57) löst das `Flexible` um den Knopf, nicht das Abschalten des
  Häkchens.

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

## Zweispaltiges Layout

`VorlagenEditorLayout` (`presentation/widgets/`) ist die einzige Stelle, die die Breite der
Detailseite kennt, und entscheidet allein über zwei Spalten oder einen Stapel (#104 Stufe 3a).

- **Die Schwelle ist eine Inhaltsbreite, keine Fensterbreite** — `zweiSpaltenAb` (1180) vergleicht
  gegen die Breite *nach* Abzug von `VorlagenEditorLayout.seitenrand`. Wer stattdessen die
  Fensterbreite hineinreicht, misst zu großzügig und schaltet auf zwei Spalten um, bevor tatsächlich
  Platz dafür ist.
- **Warum 1180**: Die Zahl folgt aus der rechten Spalte, nicht aus der linken. Die Felderkarte ist
  bei `Schriftstufe.amGroessten` bis 700 px hinunter überlauffrei (`felder_karte_schmal_test.dart`,
  tiefer ist es nicht geprüft). 1180 − 400 (linke Spalte) − 16 (Spalt) lässt ihr 764 px, also noch
  Luft über dem geprüften Rand.
- **Kein gemeinsamer Baustein in `core/general_widgets/layout/`, obwohl `EmailVersandInhalt`
  dieselbe Zahl 1180 verwendet.** Das ist ein Zufall aus derselben Rechnung (schmale linke Spalte +
  geprüfte Kartenbreite), kein gemeinsamer Beschluss — `KartenSpalten` rechnet mit 1080, einer
  dritten Zahl aus einer dritten Rechnung. Eine geteilte Schwelle wäre eine Zahl, um die sich drei
  Seiten streiten, sobald eine von ihnen ihre Kartenbreite ändert.
- **Zweispaltig braucht eine begrenzte Höhe**, wie `EmailVersandInhalt`: Zwei für sich scrollende
  Spalten brauchen einen Rahmen, in dem sie sich ausdehnen können. Unter einem `Scaffold`-Rumpf ist
  das gegeben; wer das Layout in einen Scrollbereich hängt, bekommt zu Recht einen Fehler.
- **`TemplateFieldsCard` kennt zwei Anordnungen über `eigenerScrollbereich`**, nicht zwei Karten:
  Zweispaltig (`true`) füllt die Karte die Höhe, die ihr das Layout gibt, Kartenkopf und
  Tabellenkopf bleiben beim Scrollen stehen, und nur die Zeilen laufen — echt virtualisiert,
  `shrinkWrap: false`. Gestapelt (`false`, Vorgabe) wächst die Karte mit ihrem Inhalt und scrollt mit
  der Seite, `shrinkWrap: true`. Eine `ReorderableListView` mit `shrinkWrap: true` baut **alle**
  Zeilen auf einmal — in der schmalen Fassung hinnehmbar, in der breiten mit eigenem Scrollbereich
  nicht mehr nötig.
- **Die Chips der `PlatzhalterAbschnitt` sind zugeklappt, mit einer Zählzeile über beide Dateien** —
  derselbe Griff wie bei `AppEigenePlatzhalterListe`. Gezählt wird über beide Word-Dateien zusammen
  und jeder Name nur einmal, dieselbe Regel wie in `VorlagenStand` (siehe oben): Ein Platzhalter, der
  in beiden Dateien steht, ist ein Platzhalter, nicht zwei. `TemplateFileSlotCard` zeigt seit
  Stufe 3a nur noch die Datei selbst — die Chips zu ihr stehen jetzt im Abschnitt darunter, nicht
  mehr in der Karte.

## Datei zuerst und Abgleich

Der Ablauf, mit dem eine **neue** Vorlage anfängt (#104 Stufe 3b/3c): erst eine Word-Datei wählen,
danach leitet die App Name und erste Felder daraus ab. `VorlagenLeerzustand`,
`VorlagennameVorschlag`, `EinleseReaktion` und `FeldAbgleich` (`presentation/widgets/` bzw.
`domain/services/`) tragen die Stücke.

- **Die Auswahlseite steht, bis „Weiter" gedrückt ist** (`VorlagenBearbeitung.auswahlAbgeschlossen`,
  #104 Stufe 5) — nicht mehr nur, bis der erste Pfad gesetzt ist. Der Grund ist die Gleichwertigkeit
  der beiden Word-Dateien: Der Anwalt will sie an **einer** Stelle verknüpfen, und die alte Ableitung
  aus `ohneDatei` sprang nach der ersten Datei in den Editor, wo die zweite nur noch in einer Karte
  der linken Spalte zu finden war. `zeigtLeerzustand` ist deshalb `istNeu && !auswahlAbgeschlossen`;
  `weiter()` ist die einzige Stelle, die den Zustand setzt. Jede Fläche (`VorlagenDateiKachel`) trägt
  bis dahin ihren eigenen Stand — Dateiname, „14 Platzhalter erkannt", „In Word öffnen", „Andere Datei
  wählen", „Verknüpfung entfernen". Nicht bei einer bestehenden Vorlage ohne Datei: Das ist ein
  Mangel, den `VorlagenStandBereich` benennt, und ihren Namen samt Feldern wegzublenden nähme dem
  Anwalt genau das, was er reparieren will.
- **„Weiter" ist grau, solange keine Datei verknüpft ist oder ein Lesevorgang läuft**
  (`weiterMoeglich`): Die Felder entstehen erst, wenn die Platzhalter gelesen sind, und wer
  währenddessen weiterklickt, sähe einen leeren Editor und gleich darauf eine Meldung über Felder,
  die er nicht angelegt hat. Ein Lesefehler hält dagegen nicht auf — er steht in der Kachel, und die
  Vorlage lässt sich trotzdem einrichten. Grau statt weg, anders als beim Speichern-Knopf: „Weiter" ist
  der nächste Schritt dieser Seite, und einen Schritt, der zeitweise nicht geht, muss man trotzdem
  sehen. **Kein Rückweg:** Ist die Auswahl abgeschlossen, kommt sie auch dann nicht wieder, wenn beide
  Dateien wieder entfernt werden — dann stehen schon Name und Felder da, und „Womit fängt diese
  Vorlage an?" wäre eine Lüge über den Stand. Ein Abgleich-Dialog geht während der Auswahl nur bei
  einem echten Dateiwechsel auf: Beide Dateien nacheinander zu wählen verliert nichts, weil
  `FeldAbgleich` über **beide** Slots rechnet und die Felder der ersten Datei in ihr weiter vorkommen.
- **Namensvorschlag**: `VorlagennameVorschlag.ausPfad` schneidet das Präfix „VORLAGE" (nur als
  ganzes Wort) und die Suffixe „ohne/mit Auflistung", „ohne/mit Schadensaufstellung", „SA" ab —
  wiederholt, bis keines mehr passt, weil eine Datei mehrere davon tragen kann (`… SA ohne
  Auflistung`). Beide Word-Dateien einer Vorlage ergeben denselben Vorschlag, weil die Suffixliste
  beide Seiten kennt — das ist Absicht: welche der beiden Dateien der Anwalt zuerst wählt, darf den
  Namen nicht bestimmen. Vorgeschlagen wird **nur in ein leeres Namensfeld**
  (`VorlagenBearbeitung.nameVorschlagen`); was der Anwalt tippt, gewinnt immer, auch gegen einen
  späteren Dateiwechsel. Der Hinweis unter dem Namensfeld (`TemplateNameCard.hinweis`) steht nur,
  solange das Feld noch unverändert den Vorschlag trägt (`nameZeigtVorschlag`) — ein geändertes
  Zeichen, und er ist weg.
- **Automatische Übernahme nur beim Anlegen, und je Slot nur einmal pro Datei**:
  `sollAutomatischUebernehmen` prüft `istNeu` und ob für den Slot schon **dieser Pfad** in
  `automatischUebernommen` (Slot → Pfad) vorgemerkt ist; `automatischUebernehmen` merkt den Pfad
  **auch dann**, wenn keine Felder entstanden sind — sonst brächte ein zweiter Lesevorgang derselben
  Datei zurück, was der Anwalt inzwischen gelöscht hat. Ein **echter Dateiwechsel** (anderer Pfad)
  gibt den Slot wieder frei: „Zuerst die falsche Datei gewählt" ist beim Anlegen der häufige Weg, und
  „Datei zuerst → Felder von selbst" soll dann weiter gelten. Bewusst eine Map statt eines Löschens
  in `setzePfad`: Datei entfernen und dieselbe wieder verknüpfen ist kein Wechsel und darf gelöschte
  Felder nicht zurückbringen. In einer bestehenden Vorlage passiert die Übernahme nie: Dort stünde
  sie gegen Handarbeit, die schon da ist.
- **Der Abgleich-Dialog fragt nur bei einem echten Loading→Loaded-Übergang**, nicht bei jedem
  Bloc-Zustand: `EinleseReaktion._geradeFertig` führt ein eigenes Set `_ladend` mit und meldet einen
  Slot erst als „fertig", wenn er vorher darin stand. Ohne diese Fortschreibung liefe die Rückfrage
  bei jedem `TemplatePlaceholdersState` erneut an, auch beim blossen Aufgehen der Seite.
- **`_letzterStand` merkt sich nur bekannte Stände** (`!platzhalterUnbekannt`) — ein
  `SlotPlaceholdersLoading`-Zwischenstand darf ihn nicht überschreiben, sonst wäre beim nächsten
  `Loaded` das „vorher" weg, gegen das verglichen werden müsste, und der Abgleich käme nie zustande.
  Aus demselben Grund gibt es beim allerersten Aufbau der Seite kein „vorher" und also keine Frage.
- **Der Dialog steht nie, wenn die Seite gesperrt ist** (`EinleseReaktion.gesperrt`, gespeist aus
  `SubmittingFormTemplateData`) oder schon einer offen ist (`_dialogOffen`) — dieselbe Wache wie bei
  `VorlagenVerlassenWache.gesperrt`: Ein offener Dialog beim Eintreffen des Speichern-Erfolgs finge
  den `pop(true)` der Seite ab, und die Seite meldete fälschlich `false`.
- **Im Leerzustand fehlt der Speichern-Knopf, statt grau zu sein**
  (`FormTemplateActionButtons.nurAbbrechen`): Ein grauer Knopf über einer Seite mit genau einer
  Handlung liest sich wie ein kaputtes Formular; Abbrechen bleibt, sonst gäbe es keinen Weg zurück.
- **Die Dateiwahl ist eine Test-Naht**: `VorlagenDateiwahl.waehle` ist ein statisches
  **veränderliches** Feld, kein fester Verweis — der Dateidialog ist ein Plattformkanal, den ein
  Widget-Test nicht bedienen kann, und ein zusätzlicher Konstruktorparameter an der Detailseite hätte
  die generierte `auto_route`-Route (`app_router.gr.dart`) verändert und bei jeder Anpassung einen
  build_runner-Lauf verlangt. Ein Test setzt das Feld und stellt es über
  `VorlagenDateiwahl.zuruecksetzen()` in einem `addTearDown` zurück.

## VorlagenBearbeitung

`VorlagenBearbeitung` (`presentation/widgets/`) hält den veränderlichen Stand des Editors — `FormGroup`,
Feldliste, beide Word-Pfade, `nextFieldIndex` — und jede Mutation darauf. Aus `form_template_details_page.dart`
herausgezogen (#104 Stufe 2), wie zuvor schon `FeldAenderungen` und `ZuordnungsAktionen`: Die Seite stand mit der
neuen Feldzeile am Zeilenbudget.

- **Grund ist das Zeilenbudget** (`file_length_test.dart`, 250 Anweisungszeilen handgeschrieben): Ohne die
  Auslagerung hätte die Detailseite es gerissen. `FeldAenderungen`, `ZuordnungsAktionen`, `TemplateFileSlots` und
  `VorlagenVerlassenWache` nehmen jetzt eine `VorlagenBearbeitung`-Instanz statt einzelner Parameter — was die
  Seite zusammensetzt, bleibt auf der Seite; was sich am Stand ändert, liegt hier.
- **`feldname(controlKey)` ist die eine Stelle, die `field_n` zum echten Namen auflöst** — sie liest den **Wert**
  des Controls, nicht `FieldData.label` (siehe oben, „Vom Namen zur Datenquelle"). `FelderFilter`,
  `TemplateFieldItem` und `VorlagenStand` (über `feldnamen`) rufen alle dieselbe Methode; ohne sie baute sich
  jede Stelle die Auflösung einzeln, mit dem Risiko, dass eine davon `FieldData.label` direkt läse und wieder auf
  `field_0` statt auf den echten Namen liefe.
- **Keine Widget-Abhängigkeit**: Die Methoden ändern nur `fields`, `formGroup` und die Pfade und geben nichts
  Anzeigbares zurück — die Seite ruft sie und baut danach mit `setState` neu auf. Deshalb kommt
  `vorlagen_bearbeitung_test.dart` ohne `WidgetTester` aus und prüft jede Mutation für sich.
- **Die Objekte sind veränderlich und geteilt, nicht kopiert**: `fields` ist dieselbe Liste, die die Karten zu
  sehen bekommen, `formGroup` dasselbe Formular. `VorlagenVerlassenWache` und die Chips bauen genau darauf — eine
  Kopie hier hieße, dass sie auf einem veralteten Stand verglichen.
- **Stufe 3 legt den Zustand für „Datei zuerst" dazu**: `istNeu` (aus `.fuer`, wenn keine Vorlage übergeben
  wurde), `zeigtLeerzustand`, die drei Namensvorschlag-Leser `nameVorschlag`/`nameVorschlagQuelle`/
  `nameZeigtVorschlag` neben der Mutation `nameVorschlagen`, dazu `automatischUebernehmen`/
  `sollAutomatischUebernehmen` (merkt den Slot in `automatischUebernommen`) und `felderEntfernen` für den
  Abgleich (siehe oben, „Datei zuerst und Abgleich"). **Löschen liegt jetzt nur noch hier** (`feldLoeschen`):
  `FeldAenderungen.loeschen` ruft ihn nur noch auf und meldet danach weiter — zwei Fassungen desselben
  Entfernens liefen sonst auseinander, sobald der Abgleich seinen eigenen Löschweg gebraucht hätte.

## Übersicht und Duplizieren

Stufe 4 von #104 arbeitet an der Tabelle statt am Editor: Sie bekommt ein Kennzeichen
„unvollständig", und jede Vorlage lässt sich duplizieren.

- **Der Stand in der Übersicht ist gespeichert, nicht gerechnet.** `VorlagenStand` braucht die
  Platzhalter der verknüpften Word-Dateien; die Übersicht hat sie nicht und dürfte sie sich auch
  nicht holen — sie müsste beim Öffnen des Tabs für jede Vorlage ein Word-Dokument einlesen lassen.
  Der Editor kennt sie ohnehin und schreibt sein Ergebnis deshalb beim Speichern mit
  (`GespeicherterStand`, `domain/services/`). Die Übersicht liest nur. **Eine zweite Rechnung wäre
  genau die Sache, die Stufe 1 beseitigt hat** — `GespeicherterStand.aus` nimmt den fertigen
  `VorlagenStand` entgegen und rechnet nichts nach.
- **Wo der Stand steht: in der opaken `fields`-Spalte.** Das Backend reicht sie als `JsonElement`
  verlustfrei durch (`FormTemplateDto.Fields`), und die Datenbank hält sie als Textspalte
  (`FormTemplateEntity.FieldsJson`). Stufe 4 kommt damit ohne Änderung am HTTP-Vertrag
  (`docs/openapi.json`), an der Datenbank und am Dienst aus. Die Spalte trägt seither zwei Formen,
  und beide werden gelesen: die **nackte Liste** `[ {Feld}, … ]` (Bestand vor Stufe 4) und das
  **Objekt** `{"felder": [ … ], "stand": {"version": 1, …}}`. Geschrieben wird die zweite Form nur,
  wenn wirklich ein Stand vorliegt — `GespeicherterStand.verpacke(felder, null)` gibt die nackte
  Liste zurück, das JSON bleibt dann byteidentisch zu vorher.
- **„Noch nicht geprüft" ist nicht „unvollständig".** Fehlt der Eintrag, ist über die Vorlage
  nichts bekannt — sie deshalb anzumahnen hiesse, jedem Bestand ohne Not einen Mangel anzuhängen.
  Dasselbe gilt für einen Eintrag mit fremder `version`: Er wird nicht ausgelegt, sondern als
  unbekannt behandelt. Der Fall steht namentlich in `gespeicherter_stand_test.dart`.
- **`FormTemplate.copyWith` gibt den Stand auf, sobald sich seine Grundlage ändert** — sowie
  `fields` oder ein Word-Pfad mitgegeben wird. Das trifft die beiden Griffe aus „Word Automation"
  (`WizardCubit.aktualisiereFeld`, `.linkWordFileToTemplate`): Sie schreiben die Vorlage fort, ohne
  die Platzhalter beider Dateien zu kennen. Den alten Stand mitzuschleppen hiesse, eine Zusage
  weiterzugeben, für die niemand mehr geradesteht; „Noch nicht geprüft" ist ehrlich und heilt beim
  nächsten Speichern im Editor. Wer den neuen Stand kennt, gibt ihn ausdrücklich mit.
- **Gerechnet wird beim Klick, nicht beim Aufbau** (`FormTemplateActionButtons.standErmitteln` als
  Rückruf): Der Stand hängt an den gelesenen Platzhaltern **und** an den Feldnamen, und die stehen
  bis zuletzt nur in den Controls der `FormGroup` (siehe FEATURE.md). Ein beim Aufbau übergebener
  Wert wäre veraltet, sobald jemand ein Feld umbenennt.
- **Duplizieren geht über den vorhandenen Anlege-Weg** (`CreateFormTemplate` →
  `POST /api/FormTemplates`) — kein neuer Endpunkt. Damit gilt für die Kopie dieselbe
  Fehlerbehandlung wie fürs Anlegen, einschließlich der Namens-Dublette: `ApiFormTemplateDatasource`
  übersetzt 409 in eine `FormTemplateException` mit dem Text des Dienstes, und der landet als
  `Rueckmeldung.zeigeFehler` auf der Verwaltungsseite.
- **Die Kopie bekommt die Felder, nicht die Word-Dateien.** Zwei Vorlagen auf derselben Datei wären
  zwei Beschreibungen desselben Dokuments; wer dupliziert, will die Feldarbeit wiederverwenden. Die
  Kopie ist damit unvollständig, und genau das steht in ihrem Stand: `vollstaendig: false`,
  `offen: 0` — ohne Datei sind keine Platzhalter bekannt, es ist also nichts zu zählen
  (`GespeicherterStand.ohneDatei`).
- **`KopieName` (`domain/services/`) vergleicht schärfer als das Backend**: ohne
  Groß-/Kleinschreibung und ohne Randleerzeichen. SQLite vergleicht `TemplateName` binär, `Brief
  (Kopie)` und `brief (kopie)` dürften also nebeneinander stehen — für den Anwalt wären sie
  dieselbe Vorlage. Heisst das Original schon `… (Kopie)` oder `… (Kopie 7)`, wird am **Stamm**
  weitergezählt statt ein zweites `(Kopie)` anzuhängen; nur *ein* Anhängsel wird abgeschnitten,
  weil ein von Hand vergebener Name sonst zerlegt würde. Der Vorschlag ist die Bequemlichkeit, die
  Sicherung bleibt der 409 des Dienstes.
- **Die Zeile kann nicht melden, was sie auslöst.** Nach einer erfolgreichen Kopie lädt die
  Übersicht neu — die Zeile, die den Knopf trug, ist dann abgebaut. Erfolg und Fehler hängen
  deshalb an einem `BlocListener` in `FormTemplateManagementPage`, nicht in `FormTemplateRow`.
- **Kein Überlauf bei 700 px und größter Schrift** (Issue #57): Die Zeile trägt seit Stufe 4 eine
  Spalte und eine Aktion mehr. Das Kennzeichen steht wie die Dateibadges in einem `Wrap` — der
  bindet seine Kinder an die Spaltenbreite, statt sie darüber hinauslaufen zu lassen —, und
  `AuflistungBadge` kürzt seinen Text einzeilig mit Auslassung, damit die Zeilenhöhe nicht springt.
  `actionsWidth` ist von 112 auf 160 px gewachsen: Ein `IconButton` misst 48 px unabhängig von der
  Schriftstufe, drei also 144. Bewacht von `vorlagen_tabelle_schmal_test.dart` (mit 100 px dort
  meldet der Test 44 px Überlauf — die Grenze ist gemessen, nicht geschätzt).

## Zustand

- `FormTemplateOverviewBloc` ist bewusst `@lazySingleton` (Verwaltung und Wizard-Dropdown teilen
  ihn): per `BlocProvider.value` einbinden, sonst schließt ihn die Seite beim Verlassen; nach der
  Rückkehr aus der Detailseite braucht es ein `LoadFormTemplatesEvent`.
- **Duplizieren liegt bewusst *nicht* in diesem Bloc**, sondern in `VorlagenKopieCubit`
  (`presentation/blocs/vorlagen_kopie_cubit/`, `@injectable`, an die Verwaltungsseite gebunden).
  Zwei Gründe: Sein Fehlerzustand `FormTemplateOverviewError` **ersetzt** die geladene Liste — ein
  Namenskonflikt beim Duplizieren nähme dem Wizard mitten im Ausfüllen die Vorlagenwahl weg. Und
  eine dritte Abhängigkeit im Konstruktor eines Singletons, den zwei Features anfassen, ist eine
  Änderung, die beide zu tragen hätten. Der Overview-Bloc bleibt lesen und löschen; nach einer
  Kopie lädt er neu, wie nach dem Anlegen auch.
