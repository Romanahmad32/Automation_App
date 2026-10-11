# vollmacht — Fallstricke

## Die Vorschau folgt der Art, nicht jeder Eingabe

Die erste Vorschau bestellt der Dialog, sobald sie fällig ist (`VollmachtStand.vorschauFaellig`).
Danach entsteht sie beim Wechsel der Art (`VollmachtCubit.waehleArt`, #174) und auf „Aktualisieren",
nie bei einer Feldeingabe: Jede Umwandlung belegt den Word-Thread, auf dem auch gedruckt wird. Eine
andere Art ist ein anderes Formular, ein geänderter Feldwert nur ein veralteter Stand — dafür
reicht der Hinweis über der Seite.

Läuft schon eine Vorschau, wird nicht verworfen, sondern nachbestellt (`erstelleVorschau`): Nach
ihrem Ende läuft genau eine weitere für den **dann** aktuellen Auftrag. Nie zwei gleichzeitig, und
keine für eine Art, die inzwischen wieder abgewählt ist — wer hin- und zurückschaltet, bekommt keine
zweite Umwandlung. Bis #174 ging ein Wechsel während einer laufenden Vorschau still verloren.

## Leer heißt Schreiblinie (#171)

Ein leeres Feld hält nichts auf (§4.11 „vorbelegt, nicht vorgeschrieben“), druckt aber nicht mehr
als Lücke, sondern als Linie aus Unterstrichen, auf der der Mandant von Hand ergänzt. Die Linie
zeichnen zwei Seiten, und das ist Absicht:

- Die Mandantenfelder (Vorname, Nachname, Straße, PLZ, Ort, Telefon, E-Mail) gehen **leer** an den
  Dienst; der setzt je Feld eine Linie eigener Länge ein, für einen ganz leeren Namen eine einzige
  lange (`VollmachtSchreiblinie` im Dienst). Das Frontend füllt hier nichts auf — sonst stünden die
  Unterstriche im Auftrag, und der Dienst hielte sie für einen Wert.
- „in Sachen“ und „wegen“ schreibt die Vorbelegung, also auch deren Linien: ein fehlendes Unfall-
  oder Tatdatum hinter „vom“ bzw. „am“, ein fehlender Name hinter „Bußgeldsache“ bzw.
  „Strafverfahren gegen“ (`VollmachtSchreiblinie` hier, die Namenslinie so lang wie im Dienst). So
  zeigen Feld, Vorschau und Papier dasselbe, und keine Zeile hängt auf „vom“ aus.

`VollmachtVorbelegung.nachziehen` erkennt eine unberührte Zeile weiter am genauen Text — samt Linie.
Wer das Datum statt ins eigene Feld direkt über die Linie in „wegen“ tippt, hat „wegen“ geändert;
das bleibt stehen, und das Datumsfeld speist danach nichts mehr.

Der Dialog sagt, was frei bleibt: unter jedem leeren Mandantenfeld als Hinweis (`helperText` in der
Tertiärfarbe, nie `errorText` — der läse sich wie eine Sperre) und gesammelt in
`VollmachtFreiZeile` direkt über den Knöpfen, außerhalb der scrollenden Felder und nur in der
Eingabe. Ein leeres Datum zählt nur, solange „wegen“ noch die Vorbelegung ist. „in Sachen“ und
„wegen“ selbst bekommen keinen Hinweis: Leer drucken sie keine Linie, und sie sind Sache des
Anwalts, nicht des Mandanten. Felder und Zeile fragen dieselbe Stelle (`VollmachtStandFelder`),
damit sie nie Verschiedenes sagen.

Gezeigt werden nur Felder, deren Platzhalter in der gewählten Vorlage steht (`VollmachtFeldauswahl`;
`GET /api/Vollmacht/vorlagen` liefert sie je Vorlage). Vorname und Nachname zählen auch bei
`MandantName`, Straße, PLZ und Ort auch bei `MandantAnschrift`, Unfall- und Tatdatum bei `Wegen`.
Mit den Vorlagen der Kanzlei stehen Telefon und E-Mail damit nur bei Unfallsachen, deren Fußblock
sie trägt. Ist die Liste unbekannt (`null`: Datei fehlt, Dienst älter, kein Vorlagenstand), zeigt
der Dialog alle Felder — ein Feld zu viel kostet einen Blick, eines zu wenig einen Wert, den niemand
eintragen konnte. Ein ausgeblendetes Feld behält seinen Wert und geht weiter mit in den Auftrag;
die Vorlage druckt ihn nur nicht.

Das Tatdatum hat ein eigenes Feld, geht aber **nicht** an den Dienst: Aufs Papier kommt es nur über
„wegen“. Beide Datumsfelder sind ein `GermanDateTextField` — dieselbe Prüfung und derselbe Kalender
wie `GermanDateField`, aber ohne reactive_forms, und ein Formatfehler ist nur ein Hinweis.

Wird die Zeile über den Knöpfen höher, bleibt der Arbeitsfläche weniger: Bei 1200 × 700 mit
Word-Leiste trägt die Vorschau keine 200 Pixel mehr. Ihr Platzhalter scrollt deshalb, statt
überzulaufen — der Test „niedriges Fenster“ in `vollmacht_dialog_darstellung_test.dart` fiel hier.

## Die Vorlagen sind feste Dateien

Die Vorlagen sind feste Dateien im Unterordner `Vollmacht` des Vorlagenordners, ohne Pflege in
Tab 4. Muster sät der Dienst nur in den App-eigenen Ordner; im Ordner der Kanzlei heißt eine
fehlende Datei „fehlt", nie „Muster gedruckt".

## Drucken wartet bis 90 s

Drucken wartet bis 90 s (`ApiVollmachtDatasource`): Word öffnet, druckt und schließt — die
Vorgabe von drei Sekunden meldete sonst einen Fehler, während das Papier schon kommt.

## Kein `LayoutBuilder` im Dialog

Kein `LayoutBuilder` im Dialog: `AlertDialog` legt den Inhalt in eine `IntrinsicWidth`. Ob Felder
und Vorschau nebeneinander passen, entscheidet die Fensterbreite (`VollmachtArbeitsflaeche`).

## „In Word öffnen“ ist eine Nebenhandlung

Der Dialog bleibt nach dem Öffnen in der Eingabe; eine eigene Word-Phase gibt es nicht mehr.
`VollmachtWordLeiste` zwischen Arbeitsfläche und Knöpfen nennt Datei und Uhrzeit, fragt „Ist sie
gedruckt?" und bietet „Im Explorer zeigen". Ließ sich Word nicht anstoßen, sagt die Leiste das.
Ab dann heißt „Abbrechen" „Schließen" — zurückgelassen wird eine Datei ohne Vermerk.

Derselbe Knopf öffnet erneut. Ist der Auftrag (Art und Kopfdaten) seit dem letzten Öffnen gleich
(`VollmachtWordFassung.auftrag`), öffnet er dieselbe Datei über `DateiOeffner.oeffne`, ohne neu
auszufüllen — hält Word sie offen, scheiterte ein neues Ausfüllen ohnehin. Liefert das Öffnen
false (meist: Datei weg), füllt er neu aus. Nach einer Änderung füllt er immer neu aus; hält Word
die alte Fassung, kommt die Meldung aus `ZieldateiGesperrtException` als Fehler, die Leiste bleibt.

Denselben Weg gehen der Rückfall nach gescheitertem Druck (`druckFehlgeschlagen`: Fehler, Word,
Eingabe mit Leiste) und „In Word öffnen" aus dem Ergebnis (`oeffneInWordErneut`: erst den Vermerk
zurück, dann Eingabe mit Leiste). Ein gelungener Druck schreibt dieselbe Datei neu und löscht sie —
die Word-Fassung ist danach leer.

## Aufräumen beim Schließen

Schließt der Dialog, schließt `BlocProvider` den Cubit, und `VollmachtCubit.close` lässt den Dienst
die Vollmachtdateien des Vorgangs löschen (`RaeumeVollmachtAuf` → `POST /api/Vollmacht/aufraeumen`)
— nur, wenn in diesem Dialog eine Word-Fassung entstand (`wordFassungEntstanden`), und ohne zu
warten. Der Dienst nimmt nur die drei festen Namen `Vollmacht <Art>.docx`; ein Anspruchsschreiben
daneben bleibt, ein danach leerer Ordner geht mit. Hält Word eine Datei noch, bleibt sie still bis
zur Startaufräumung liegen. `POST /api/WordAutomation/arbeitsordner/aufraeumen` ist **nicht** der
Weg: Er löschte den ganzen Arbeitsordner samt angefangenem Schreiben.
