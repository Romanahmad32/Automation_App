# settings — Fallstricke

Was im Steckbrief (`FEATURE.md`) nicht mehr in vierzig Zeilen passt. Hier steht das *Warum*; das
*Was* steht dort.

## Die Ordnerpfade werden relativ abgelegt — und der Anker gehört dazu

Ein Ordner unterhalb von OneDrive wird nicht als `C:\Users\anwalt\OneDrive - Kanzlei\Kanzlei App Daten`
gespeichert, sondern als `%OneDriveCommercial%\Kanzlei App Daten`. Der Grund ist der zweite
Arbeitsplatz: Absolute Pfade sind maschinenabhängig, werden bei der Übernahme einer Sicherung
ausdrücklich **nicht** mitgenommen, und der Anwalt richtet dieselben vier Ordner ein zweites Mal ein.
Ein relativer Pfad ist maschinenunabhängig und kommt deshalb mit.

Der Variablenname in den Prozentzeichen ist der **Anker**, und er ist kein Schmuck. Es gibt drei
mögliche Wurzeln — `OneDriveCommercial`, `OneDriveConsumer`, `OneDrive` —, und ein Rechner mit
Geschäftskonto hat eine andere als einer mit privatem. Ohne festgehaltenen Anker löste derselbe
relative Pfad auf dem zweiten Rechner still in einen anderen Baum auf: kein Fehler, keine Meldung,
nur Dateien an einer Stelle, an der niemand sie sucht. Deshalb weicht die Auflösung **nie** auf eine
andere Variable aus. Ist die angegebene auf diesem Rechner nicht gesetzt, gilt der Ordner als nicht
auflösbar — Zustand `ankerFehlt`, und der Reiter sagt es in einem ganzen Satz.

**Das Frontend rechnet dabei nie um.** Es zeigt an, was `GET /api/Settings` liefert (den aufgelösten
Pfad, sonst die Speicherform), und schickt beim Speichern den vollen Pfad, den der Ordnerdialog
geliefert hat. Aus absolut wird relativ im Dienst, beim Schreiben. Dieselbe Arbeitsteilung wie bei
den Vorlagenpfaden — und derselbe Grund: Pfadmathematik an zwei Stellen ist Pfadmathematik in zwei
Fassungen.

## Warum der Zustand aus einem eigenen Endpunkt kommt

`GET /api/Settings/ordner` liefert je Ordner die Speicherform, den wirksamen Ordner und den Grund
(`OrdnerZustand`). Das steht bewusst **nicht** in `KanzleiSettingsDto`: Die Auskunft löst
Umgebungsvariablen auf, sieht auf der Platte nach, ob der Ordner existiert, und kennt die Ableitungen
(`Vorlagen`, `Register`, `Sicherungen` unter dem Ordner für die App-Daten). Das gehört nicht in jeden
Aufruf, der bloß den Kanzleinamen für ein Anschreiben braucht — und die Einstellungen sind die
einzige Stelle, an der es jemanden interessiert.

Die Anzeige (`OrdnerZustandListe`) lädt selbst und hat keinen Bloc, wie die `SicherungsStandZeile`
im Reiter „Datensicherung": eine nur-lesende Auskunft ohne Folgeschritt. Sie lädt aber **nach jedem
Speichern der Kanzleidaten neu** — der wirksame Ordner ändert sich genau dann, und eine Zeile, die
nach dem Speichern den alten Stand zeigt, ist schlechter als keine. Fehler bleiben stumm: Steht der
Dienst nicht, bleibt die Stelle leer, statt eine Fehlermeldung über etwas zu zeigen, das der Anwalt
gar nicht angefasst hat.

Ordner werden **nicht beim Speichern angelegt**, sondern beim ersten Schreiben. Der Zustand
`ordnerFehlt` ist deshalb kein Fehler, sondern die Normalform direkt nach der Wahl — und der Satz
dazu sagt genau das.

## Der Ordner wird vorgeschlagen, nie gesetzt

`SynchronisierterOrdner` liest die Umgebungsvariablen, die der OneDrive-Client selbst setzt, und
prüft, ob der Ordner dahinter wirklich auf der Platte liegt. Mehr passiert nicht: keine Anmeldung,
kein Konto, kein Cloud-Zugang. Der gefundene Pfad steht als Knopf da (§1.3), und wer woanders
ablegen will, wählt woanders.

Findet die Suche nichts, steht statt des Knopfes ein stiller Hinweis — kein leerer Fleck. Für die
Register- und die Sicherungsablage ist der Vorschlag eine Bequemlichkeit und darf ausbleiben; für
den Ordner der App-Daten ist er der Regelweg, und sein Ausbleiben braucht eine Erklärung, sonst
sieht es nach einem Fehler der App aus.

Die Suche ist asynchron, und das ist keine Vorsicht auf Verdacht: Zeigt die Variable auf einen
OneDrive-Bereich, der getrennt ist oder auf „Dateien bei Bedarf" steht, dauert schon das Nachsehen.
Im `build` stünde sie bei jedem Tastendruck im Feld daneben.

## Der Aufklapper klappt nur auf, nie zu

`AbweichendeOrdnerAufklapper` beginnt zugeklappt, solange alle drei Einzelfelder leer sind, und
aufgeklappt, sobald eines gefüllt ist. Das Formular wird aber erst gefüllt, **nachdem** das Widget
zum ersten Mal aufgebaut wurde (`AppSettingsView` patcht, wenn der Bloc geladen hat) — ein einmal im
`initState` gelesener Stand wäre immer leer und der Aufklapper immer zu. Deshalb hängt er am
`valueChanges` der `FormGroup` und tauscht über einen `ValueKey` das `ExpansionTile` aus:
`initiallyExpanded` wird nur beim ersten Aufbau gelesen.

Der Zustand ist absichtlich **einbahnig**. Wer das letzte der drei Felder leert, stünde sonst mitten
im Arbeiten vor einer Fläche, die sich unter ihm zuklappt.

## Die Mail-Signatur speichert für sich

Sie steht im Reiter „E-Mail" (`MailSignaturSektion`) und schreibt über `SaveMailSignaturEvent`
**für sich**; `…Loaded.gespeichert` sagt, welcher Reiter gespeichert hat. Deshalb setzt
`AppSettingsView._save` per `copyWith` auf dem geladenen Stand auf — sonst löscht jedes Speichern
der Kanzleidaten die Felder der Nachbarreiter still mit. Dasselbe gilt für jedes künftige Feld
daneben, den Ordner für die App-Daten eingeschlossen.

Einen **eigenen Knopf** hat sie trotzdem nicht: Den einen des Reiters ruft `MailboxAccessView._save`,
er schreibt beides (`speichereWennGeaendert`) — zwei Knöpfe „Speichern" sahen aus wie zwei
Formulare. Daneben stehen `MailVorlagenSektion`, `AnredebausteineSektion` und `GrussformelnSektion`;
alle gehören `email_versand`, und jeder Eintrag dort ist ein eigener Satz im Bestand, sofort
geschrieben.

`mailSignaturHtml` wird **nur durchgereicht**: gelesen, übernommen und verworfen wird sie im Dienst
(`GET/POST/DELETE api/EmailVersand/signaturen/…`). Der Import **schreibt nicht** — er füllt das Feld
und merkt den Namen vor, erst `speichereWennGeaendert` übernimmt; Entfernen nimmt Text **und**
Formatierung. Warum, steht bei `email_versand`.

## Ein neues Feld hier heißt: sechs Stellen, zwei Tests, ein Steckbrief

`KanzleiSettings` ist von Hand geschrieben, nicht generiert. Ein neues Feld gehört an **sechs**
Stellen: Feld, Konstruktor, `copyWith`, `fromJson`, `toJson`, `props`. Vergessenes `copyWith` löscht
das Feld beim nächsten Speichern eines Nachbarreiters, vergessenes `props` macht zwei verschiedene
Stände gleich, und beides fällt in keinem Test auf, der nicht genau danach sucht.

Dazu kommt `test/architecture/http_vertrag_test.dart`: Jede Datei mit `json['…']`-Zugriffen muss dort
einem Backend-DTO aus `docs/openapi.json` zugeordnet sein, und es dürfen nur dessen Feldnamen
vorkommen. Ein Tippfehler im Schlüssel ist sonst zur Laufzeit ein stilles `null` — kein Compilerfehler
und keine rote Prüfkette.

Und der Steckbrief nebenan hat **40 Zeilen, keine über 130 Zeichen**, beides erzwungen von
`test/architecture/dokumentation_test.dart`. Was nicht hineinpasst, gehört hierher — nie in kürzere
Sätze: Absätze zusammenzuziehen, um unter das Budget zu kommen, hat schon einmal lesbare Doku
unlesbar gemacht. Der Verweis wird in **beide** Richtungen geprüft: Steckbrief ohne diese Datei ist
so rot wie diese Datei ohne Verweis im Steckbrief.
