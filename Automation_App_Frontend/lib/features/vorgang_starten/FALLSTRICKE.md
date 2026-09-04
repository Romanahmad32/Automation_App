# vorgang_starten — Fallstricke

Der lange Teil des Steckbriefs `FEATURE.md`. Hier steht, was am Speicherpfad regelmäßig schiefgeht —
die kurzen Merksätze bleiben drüben.

## Die Reihenfolge in `_onSpeichereVorgang`

Erst den Mandanten anlegen bzw. aktualisieren, dann den Zentralruf-Prefill, zuletzt
`VorgangCubit.registriereAnfrage`. Scheitert einer der ersten beiden Schritte, entsteht **kein**
Vorgang — der Bloc meldet `VorgangStartenError` und kehrt um.

Der Mandant ist an dieser Stelle aber schon geschrieben. Deshalb trägt auch `VorgangStartenError`
den `gespeicherterMandant` mit: Ein Fehler beim Prefill darf ihn nicht verschlucken (siehe unten).

Die vom Prefill zurückgegebene Referenz schlägt die im Formular eingetippte: das Backend
normalisiert sie, und was am Zentralruf steht, muss auch im Register stehen.

## Zwei Wege, einen Mandanten anzulegen — ein Aufräumpfad

Es gibt zwei Knöpfe, die einen Mandanten ins Register schreiben:

| Weg | Event | Zustand mit dem Mandanten |
|---|---|---|
| Karten-Knopf „Neuen Mandanten speichern" | `SpeichereMandantEvent` | `MandantGespeichert` |
| Aktionsleiste „Speichern" / „Zentralruf-Formular ausfüllen" | `SpeichereVorgangEvent` | `VorgangGespeichert`, im Fehlerfall `VorgangStartenError` |

Alle drei laufen in der View durch `_verknuepfeGespeicherten`.

### Was passiert, wenn der Mandant nicht ankommt

Nicht das, was hier lange stand. Ohne die Verknüpfung liefert `mandantAenderungsart` weiterhin
`neu`, die Karte hält den gerade angelegten Mandanten für unbekannt, und der nächste Klick auf
„Speichern" versucht ihn ein zweites Mal anzulegen. Das lässt das Backend nicht zu:
`MandantenRepository.EnsureNameUniqueAsync` vergleicht Vor- und Nachnamen normalisiert und wirft
`MandantNameConflictException`, der Controller antwortet **409**, `MandantDatasource._mapError`
macht daraus eine `MandantException`.

Es entsteht also **keine Dublette, sondern eine Sackgasse**: Der Vorgang lässt sich ab da überhaupt
nicht mehr speichern — jeder weitere Klick bringt dieselbe rote Meldung —, bis der Anwalt merkt,
dass er den Mandanten von Hand aus dem Register wählen muss, oder die Seite neu lädt. Wer das für
Anzeigeärger hält, unterschätzt es: Bis dahin ist der Vorgang selbst nirgends gespeichert.

Die frühere Fassung dieses Absatzes behauptete eine Dublette. Das war falsch und hat einen Prüfer
in die Irre geführt, der die Annahme ungeprüft übernahm — deshalb bildet
`MandantenRegisterDouble` den Konflikt inzwischen nach. Ein Double, das jede Anlage klaglos
hinnimmt, lässt die Tests eine Welt beschreiben, die es nicht gibt.

### Warum die Verknüpfung synchron passiert

`_verknuepfeGespeicherten` setzt `_selectedMandantId` und ergänzt die Liste **im selben
Listener-Aufruf**, bevor es das Nachladen anstößt. Der Grund ist dasselbe Zeitfenster:
`VorgangStartenLoading` endet mit dem Zustand, der den Mandanten trägt — ab da sind die Knöpfe in
`VorgangAktionsleiste` und `MandantSpeichernButton` wieder frei. Liefe die Übernahme erst über ein
`await` auf `GET /api/Mandanten`, fiele ein Klick in genau dieses Loch und stünde wieder vor dem
Namenskonflikt. Aus demselben Grund wird die Liste hier ergänzt statt abgewartet: `_ladeMandanten`
verschluckt seinen Fehlerfall, und eine Id ohne passenden Eintrag ist so gut wie keine.

Aus demselben Zeitfenster folgt auch, dass die Übernahme **keine Formularfelder schreibt**. Auf dem
Zentralruf-Weg vergehen zwischen Klick und Rückkehr bis zu drei Minuten (Captcha); gesperrt sind
dabei nur die Knöpfe, die Felder bleiben bedienbar. Was der Anwalt in dieser Zeit korrigiert, würde
sonst kommentarlos auf den Stand vom Speicherzeitpunkt zurückfallen — gegen §1.3, „überschreibt
nichts stillschweigend". Felder füllt nur `_uebernehmeMandant`, und das hängt allein am Dropdown
„Aus Mandanten übernehmen".

## Ein geänderter Name benennt den Registereintrag um

Ist ein Mandant über das Dropdown verknüpft und wird sein Name überschrieben, geht daraus ein
`PUT /api/Mandanten/{id}` hervor: Derselbe Eintrag behält seine Id und trägt fortan den neuen
Namen. Jeder Vorgang, der über `mandantId` daran hängt, zeigt danach auf diesen Namen — der
Mensch, der vorher so hieß, steht nirgends mehr im Register.

**Das ist gewollt** (§5.1): Ein Tippfehler im Namen soll sich dort berichtigen lassen, wo er
auffällt, und nicht erst im Mandanten-Tab. Falsch war bis #50 nur die Ansage. Die Karte versprach
im Hinweistext des Dropdowns das Gegenteil („Änderungen am Namen lösen die Verknüpfung" — nie
gebaut), und die Rückfrage nannte den Fall „Mandantendaten aktualisieren" und zeigte den Namen
als eine Zeile unter sieben, in derselben Aufmachung wie eine geänderte Hausnummer.

Wer hier etwas ändert, hält die drei Stellen zusammen:

- `VorgangStartenDaten.nameWeichtAbVon` ist der **einzige** Eingang für die Frage; `weichtAbVon`
  ruft ihn mit auf, damit die Namensprüfung nicht in zwei Fassungen auseinanderläuft.
- `mandantUmbenennung` (`mandant_aenderung.dart`) macht daraus alten Namen, neuen Namen und die
  Zahl der betroffenen Vorgänge — oder `null`, wenn der Name bleibt. `null` heißt: gewöhnliche
  Aktualisierung, keine Warnung. Eine Warnung, die immer dasteht, warnt vor nichts mehr.
- Die Zahl kommt aus dem `VorgangCubit` und wird **in der View** gezählt
  (`_vorgaengeAmMandanten`), nicht in der Karte: Die Karte kennt die Vorgänge nicht. Steht der
  Cubit noch leer, warnt der Dialog ohne Zahl statt mit einer falschen. Deshalb registrieren die
  Widget-Tests, die das ganze Formular aufbauen, einen `VorgangCubit` in `getIt`.

Was der Anwalt stattdessen tun soll, wenn ein **anderer** Mensch gemeint ist, steht in der Warnung
selbst: oben „(neuer Mandant)" wählen. Ein automatisches Lösen der Verknüpfung wäre der andere
Weg gewesen und ist bewusst nicht gewählt worden — er nimmt die Korrektur eines Vertippers mit.

## Das Kennzeichen: ein Baustein, keine zweite Prüfung

Beide Kennzeichenfelder dieser Seite — Gegner (`UnfallSection`) und Mandant (`MandantSection`) —
sind `KennzeichenField` aus `core/general_widgets/form/`. Am Control hängt
`KennzeichenField.validator` (`vorgang_form_group.dart`, und in
`_applyUnfallValidators` noch einmal, weil das Gegner-Feld je nach Rechtsgebiet zusätzlich Pflicht
wird). Eine eigene Kennzeichen-Prüfung gehört hier nicht mehr hin: Die frühere strenge Fassung
verlangte den Bindestrich vom Anwalt und beanstandete damit Werte, die die App selbst aus dem
Register angeboten hatte.

Das Feld stellt die Konvention `HG-E 1427` beim **Verlassen** her. `leseVorgangDaten` normalisiert
trotzdem ein zweites Mal (`kennzeichenAusFormular`) — ein eingefügter Wert muss das Feld nie
verlassen haben, und wer `hge1427` einfügt und sofort speichert, hätte den Rohwert in Referenz,
Vorgang und Registereintrag stehen.

Die gespeicherten Kennzeichen des verknüpften Mandanten sind seit #17/#18 **Kandidaten des
Auswahldialogs** am Feld, nicht mehr eine eigene Chipreihe darüber (`MandantKennzeichenAuswahl` ist
weg, samt der Callback-Kette `onKennzeichenGewaehlt` durch `VorgangStartenSektionen` und die View).
Damit sieht die Auswahlhilfe hier aus wie im Ausfüllschritt, und die freie Eingabe bleibt der
Normalfall statt einer Ausnahme neben den Chips.

## Warum Widget-Tests hier nicht `pumpAndSettle` benutzen dürfen

Zwei Fallen übereinander, beide in `mandant_uebernahme_test.dart` beschrieben:

`MandantUebersichtDialog.zeige` gibt sein Ergebnis erst frei, wenn die Ausblende-Animation durch
ist. Die Speicherkette startet also erst **nach** dem letzten Frame, den ein einzelnes
`pumpAndSettle` sieht. Wer direkt danach misst, sieht den Ladezustand und hält die Übernahme
fälschlich für kaputt.

Wer daraufhin `pumpAndSettle` nachschiebt, hängt: Solange der Bloc lädt, dreht sich der Ladekringel
in der Aktionsleiste, „bis nichts mehr animiert" tritt nie ein, und der Lauf läuft erst nach zehn
Minuten Testuhr in seinen Timeout. Der Test pumpt deshalb in einer Schleife und bricht ab, sobald
der Bloc den Lauf abgeschlossen hat — Erfolg **oder** Fehler; die Framezahl ist nur die Obergrenze.

Mitgezählt wird über einen `BlocListener` im Widgetbaum. Ein von Hand geöffnetes
`bloc.stream.listen(…)` überlebt den Testkörper und blockiert das Aufräumen; dasselbe gilt für
`await bloc.close()` im Test. Der Bloc wird hier bewusst nicht geschlossen — mit dem Testprozess ist
er ohnehin weg.
