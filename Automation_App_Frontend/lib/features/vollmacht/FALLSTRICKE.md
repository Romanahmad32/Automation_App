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

## „In Word öffnen" ist eine Nebenhandlung

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
