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

## Bei der Übernahme kommt mit, was relativ gespeichert ist — nicht, was absolut ist

Seit #103 unterscheidet `DatabaseBackupService.SchuetzeMaschinenPfadeAsync` nicht mehr nach Feld,
sondern nach **Speicherform** (`AppOrdnerPfad`): Ein Ordnerpfad, der relativ zum
OneDrive-Wurzelordner mit festgehaltenem Anker steht (`%OneDriveCommercial%\Kanzlei App Daten`),
kommt aus der eingespielten Sicherung mit — er trägt keinen Benutzernamen und kein Laufwerk, nur
den Namen der Variable, die der OneDrive-Client auf jedem Rechner selbst setzt. Ein absoluter Pfad
bleibt dagegen beim Wert *dieses* Rechners: Beide Rechner meinen zwar denselben synchronisierten
Ordner, aber unter verschiedenen Pfaden — der fremde Sicherungsordner wäre der schlimmste, weil
dieser Rechner seine Sicherungen danach woanders ablegte, als er sein eigenes Übernahme-Angebot
liest. Betroffen sind alle fünf Ordnerfelder gleich (App-Daten-, Akten-, Vorlagen-, Register- und
Sicherungsordner), nicht nur die Sicherungsablage.

Fehlt der Anker eines übernommenen relativen Pfads auf diesem Rechner (kein passendes
OneDrive-Konto eingerichtet), wird er **trotzdem** übernommen, nicht verworfen: Der Pfad wird
richtig, sobald das Konto eingerichtet ist, und bis dahin sagt `GET api/Settings/ordner` (Zustand
`ankerFehlt`), was fehlt. Ihn zu verwerfen wäre stiller Datenverlust an einer Lage, die sich von
selbst behebt, sobald der Anwalt das zweite Konto einrichtet.

## Aufbewahrung nach Alter statt nach Anzahl — und der Zeitpunkt kommt aus dem Dateinamen

„Die letzten 10" (#39) und „alle 30 Minuten sichern" (#112) passen nicht zusammen: Sichert die App
öfter, deckt eine feste Anzahl nur noch wenige Stunden ab — der Fall, für den man eine Sicherung
eigentlich braucht („vorgestern war der Bestand noch in Ordnung"), wäre gerade nicht mehr abgedeckt.
`Aufbewahrungsregel` staffelt deshalb nach Alter (heute alles, dann je Kalendertag, dann je Woche,
dann je Monat, dort begrenzt), damit die Anzahl beschränkt bleibt, während die Historie Monate
zurückreicht.

Die Regel rechnet dabei mit dem Zeitpunkt **im Dateinamen** (`SicherungsDateiname`), nicht mit dem
Änderungsdatum der Datei: Ein Synchronisierer (OneDrive) setzt `LastWriteTime` beim Herunterladen
auf dem zweiten Rechner neu — dann sähe jedes übernommene Archiv aus, als wäre es gerade eben
entstanden, und die Staffel würfe alte Archive für neue.

## Warum der Fingerabdruck über Dateien läuft, nicht über `PRAGMA data_version` oder `GeaendertAm`

Zwei naheliegende Änderungsmerkmale scheiden aus. `PRAGMA data_version` bräuchte eine offene
Verbindung, die über die Laufzeit eines einzelnen Zeitgeber-Ticks hinaus bestehen bliebe — genau das
bricht `DatabaseBackupService.ErsetzeDatenbankdatei` (Zeilen 186–194): Der Import löscht alle
gepoolten Verbindungen (`SqliteConnection.ClearAllPools()`) und tauscht die Datei aus; eine
dauerhaft offene Verbindung stünde dem im Weg. Einen `GeaendertAm`-Zeitstempel je Datensatz gibt es
nicht: §7.2 „Nachvollziehbarer Änderungsstand" ist als **[S]** noch offen, nicht gebaut. Was bleibt
und tatsächlich für jede Änderung mitzieht: ein Datei-Fingerabdruck aus `(Length,
LastWriteTimeUtc)` von `automation.db`, `-wal` und `-shm` (`AenderungsMerkmal`) — SQLite schreibt im
WAL-Modus in diese drei Dateien, nicht nur in die Hauptdatei.

## Die Schleuse — Zeitgeber und Beenden dürfen nicht gleichzeitig schreiben

Ein Semaphor um `AutomatischeSicherung.SchreibeAsync` verhindert, dass der 30-Minuten-Zeitgeber und
das Beenden der App gleichzeitig ein Archiv bauen. Beenden wartet dadurch notfalls auf einen
laufenden Zeitgeber-Lauf und schreibt danach selbst — zwei Archive mit unterschiedlichem Zeitstempel
sind dabei in Kauf genommen, ein halb geschriebenes nicht. Damit der Zeitgeber beim Beenden nicht
noch einen neuen Lauf anstößt, prüft er `stoppingToken`, bevor er startet. Der Dateiname löst nur
Sekunden auf: fallen zwei Läufe in dieselbe Sekunde, ersetzt der zweite das Archiv des ersten
(`AtomareAblage.Ersetze`). Das ist kein Verlust — beide tragen denselben Stand — und der Test prüft
deshalb, dass jedes vorhandene Archiv vollständig ist, nicht wie viele es sind.

## Warum das neueste Archiv nie gelöscht wird

`Aufbewahrungsregel.ZuLoeschen` nimmt das global neueste Archiv immer aus, unabhängig davon, was die
Staffel sonst sagt. Ohne diese Ausnahme könnte ein Rechner, der seit Monaten nicht mehr lief, beim
nächsten Aufräumen sein einziges Archiv verlieren, weil es rechnerisch längst in die Monats-Stufe
gerutscht ist und dort die Obergrenze reißt.

## Der Zeitgeber sichert mit `CancellationToken.None`, nicht mit seinem `stoppingToken`

`SicherungsZeitgeber` ruft `SchreibeAsync` bewusst mit `CancellationToken.None`: Ein laufender
Sicherungslauf, der beim Herunterfahren mitten im Schreiben abgebrochen wird, hinterließe im
schlimmsten Fall eine unvollständige Datei. Bricht nichts ab, kostet ein Fehlschlag höchstens eine
Meldung beim nächsten Start (`LetzteSicherungAkte`) — nie einen beschädigten Bestand.

## Lokale Zeit im Dateinamen, und die Sommerzeit-Kante

`SicherungsDateiname` schreibt und liest lokale Zeit, nicht UTC — der Anwalt vergleicht Zeitpunkte
im Reiter „Datensicherung" gegen seine Wanduhr, nicht gegen UTC. An der Umstellung selbst kann
dadurch rechnerisch eine Stunde fehlen oder doppelt vorkommen; das ist hingenommen, weil die Staffel
ohnehin nur den *jüngsten* Zeitpunkt je Tag/Woche/Monat behält — eine verschobene Stunde ändert
nichts daran, welches Archiv das ist.

## Der Rechnername kann selbst einen Bindestrich tragen — deshalb wird vom Ende gelesen

Windows vergibt Rechnernamen häufig nach einem Schema mit Bindestrich (`DESKTOP-AB12CD3`), und der
Dateiname selbst trennt Rechnername und Zeitstempel ebenfalls mit einem Bindestrich
(`automation-<Rechner>-<yyyyMMdd-HHmmss>.zip`). `SicherungsDateiname.Zeitpunkt` liest deshalb **vom
Ende her**: `.zip` abschneiden, die letzten 15 Zeichen als Zeitstempel parsen, erst danach prüfen,
ob der Rest mit `automation-<Rechner>-` beginnt. Ein Parser, der stattdessen am ersten Bindestrich
nach `automation-` trennte, zerlegte einen bindestrichhaltigen Rechnernamen selbst und läse nie
einen gültigen Zeitpunkt.
