# backup — Fallstricke

Was im Steckbrief (`FEATURE.md`) nicht mehr in vierzig Zeilen passt. Hier steht das *Warum*; das
*Was* steht dort.

## Die Sicherungsdatei ist ein ZIP, der Öffnen-Dialog lässt trotzdem `.db` zu

Seit die Word-Vorlagen unter `%APPDATA%` liegen, enthält die Sicherung nicht nur die Datenbank,
sondern auch die `.docx`-Dateien, auf die sie verweist. Der Öffnen-Dialog lässt `db`/`bak` weiterhin
zu, damit ältere Sicherungen aus der Zeit davor einspielbar bleiben — das ist Absicht, kein
vergessener Filter. Das Backend erkennt das Format an der Datei selbst, nicht an ihrer Endung.

## Eigene 5-Minuten-Timeouts, und das Multipart-Feld heißt `datei`

Die Dio-Vorgaben (3 s) reichen für einen größeren Bestand nicht: Export baut ein Archiv, Import
tauscht die Datenbank und migriert sie. Das Feld beim Upload muss `datei` heißen, sonst bindet der
`IFormFile`-Parameter des Controllers nicht.

## Die Übergabe hat keinen Bloc — und darf keinen bekommen

`ArbeitsplatzUebergabeGate` steht **vor** der Anwendung, also vor Router, Theme und sämtlichen
`BlocProvider`n. Es gibt zu diesem Zeitpunkt keinen Baum, in den ein Bloc gehörte. Genau dort muss
die Frage aber stehen: Eine Übernahme tauscht die Datenbank aus, und jede Ansicht, die vorher Daten
geladen hat, blickt danach auf einen Bestand, den es nicht mehr gibt.

Deshalb bringt der Bildschirm auch seine eigene `MaterialApp` mit (dasselbe Muster wie
`BackendStartScreen`), und deshalb ist der Weg über den Reiter „Datensicherung" — derselbe Schritt
im laufenden Betrieb — mit dem Hinweis „App bitte neu starten" versehen.

## Der Start hängt nie an der Übergabe

Kommt die Auskunft nicht (Dienst zickt, synchronisierter Ordner offline), geht der Start weiter, als
gäbe es nichts zu entscheiden. Ein Arbeitsplatz, den man nicht mehr öffnen kann, weil der andere
unerreichbar ist, wäre die schlechteste Antwort auf ein Problem, das im Zweifel gar keines ist.

## Warum die Meldung über eine misslungene Sicherung *hier* steht

Gesichert wird beim Beenden, wenn das Fenster schon zu ist — in dem Moment gibt es niemanden, dem
man etwas sagen könnte. Das Backend merkt sich das Ergebnis lokal, und die App zeigt einen
Fehlschlag beim nächsten Start. Ohne das wäre eine Sicherung, die seit Wochen an einem umbenannten
Ordner scheitert, nicht von einer heilen zu unterscheiden — bis der Anwalt sie braucht.

Die Meldung wird beim Wegklicken quittiert (`POST sicherungsstand/quittieren`), sonst stünde sie bei
jedem Start wieder da. Der Zeitpunkt bleibt: Die Zeile „zuletzt gesichert …" im Reiter
„Datensicherung" soll die Quittung überleben.

## Zwei Zeitpunkte, und warum sie nicht zusammengelegt werden dürfen

`UebergabeAngebot` trägt `zuletztGearbeitet` **und** `gesichertAm`. Der erste steht im Satz auf dem
Bildschirm, der zweite entscheidet, ob überhaupt ein Angebot zustande kommt. Wer beide zusammenlegt,
macht aus einem Rechner, der heute nur kurz auf war, den „neueren" Stand — obwohl sein Archiv von
vorgestern ist. Die Gegenprobe steht im Backend (`ArbeitsplatzUebergabeTests`).

## Übernehmen ist Ersetzen, nicht Verschmelzen

Es gibt kein Zusammenführen zweier Stände. Was davor schützt: Die Frage nennt Rechner, Zeitpunkt und
den eigenen Stand daneben; das Backend legt vor dem Einspielen eine vollständige Kopie des
bisherigen Standes an; und die Frage kommt, bevor irgendeine Ansicht Daten geladen hat. Scheitert
die Übernahme, bleibt der Bildschirm stehen — das Backend spielt alles oder nichts ein, der eigene
Stand ist dann unberührt.
