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

## Das Kennzeichen: ein Baustein, und **keine** Sperre

Beide Kennzeichenfelder dieser Seite — Gegner (`UnfallSection`) und Mandant (`MandantSection`) —
sind `KennzeichenField` aus `core/general_widgets/form/`. Am Control hängt seit #130 **kein
Formatvalidator** mehr, nur noch die Pflicht am Gegnerfeld, und die auch nur bei Verkehrsrecht
(`_applyUnfallValidators`). Eine eigene Kennzeichen-Prüfung gehört hier erst recht nicht hin.

Der Grund steht in §4.1: Welche Fahrzeuge in die Kanzlei kommen, entscheidet nicht die App. Ein
E-Scooter trägt ein Versicherungskennzeichen (`123 ABC`), ein Behördenwagen `THW-12345`, der
Unfallgegner womöglich ein französisches `AB-123-CD` — nichts davon passt ins Pkw-Schema. Die
frühere Prüfung liess alles davon durchfallen und sperrte damit „Vorgang speichern" **und**
„Zentralruf-Formular ausfüllen"; ein E-Scooter-Mandat blieb schlicht liegen.

Das Feld stellt die Konvention `HG-E 1427` beim **Verlassen** her. `leseVorgangDaten` normalisiert
trotzdem ein zweites Mal (`kennzeichenAusFormular`) — ein eingefügter Wert muss das Feld nie
verlassen haben, und wer `hg-e1427` einfügt und sofort speichert, hätte den Rohwert in Referenz,
Vorgang und Registereintrag stehen.

**Mehrdeutige Kennzeichen werden nicht geraten — aber auch nicht gesperrt.** `HGE1427` kann
`HG-E 1427` oder `H-GE 1427` heißen, zwei verschiedene Fahrzeuge. Solche Werte lässt
`normalizeKennzeichen` stehen, statt eine Aufteilung zu wählen, und `KennzeichenField`
**beanstandet** sie unter dem Feld („Mehrdeutig, bitte mit Bindestrich: …"). Gesperrt wird dadurch
nichts: Die Sperre sollte verhindern, dass die App rät — das tut aber schon der Normalisierer. Ohne
sie bleibt `HGE1427` einfach stehen, wie es getippt wurde, und niemand steht vor einem toten Knopf.
Die ganze Regel steht in `word_automation/FALLSTRICKE.md`.

**Warum der Knopf gesperrt ist, steht jetzt darüber.** `VorgangAktionsleiste` trägt seit #130 einen
`FormularFehlerHinweis` — diese Seite hatte eine solche Zeile gar nicht. Sie nennt jedes ungültige
Feld mit Grund und springt beim Anklicken hin; die Anzeigenamen dazu stehen in
`vorgangFeldBeschriftungen` (`vorgang_form_group.dart`), die beiden Sonderfälle von
`ValidationMessage.pattern` (Uhrzeit, Vorgangsnummer) in der Leiste selbst. Nötig ist das, weil
reactive_forms einen Fehler am Feld erst nach `touched` zeigt — ein vorbelegter Wert wird das nie,
und ein gesperrter Knopf nimmt keinen Fokus.

**Ausserhalb des Verkehrsrechts trägt der ganze Unfallteil keine Prüfung mehr.** Nicht nur die
Pflicht fällt weg, auch die Formatprüfungen von Unfalltag, Uhrzeit und Vorgangsnummer
(`setzeUnfallPruefungen` in `vorgang_form_group.dart`, aufgerufen aus `_applyUnfallValidators`).
Der Grund ist derselbe wie beim eingeklappten Vorlagenfeld (#82): Ihre beiden Abschnitte stehen dann
gar nicht mehr auf der Seite, die Controls aber weiter in der Gruppe. Eine `25:99`, die aus dem
vorherigen Rechtsgebiet stehengeblieben ist, sperrte sonst „Vorgang speichern", ohne dass irgendwo
ein Feld zu sehen wäre, das man berichtigen könnte — und die Zeile darüber verwiese auf ein Feld,
zu dem kein Widget mehr gehört, der Sprung dorthin liefe ins Leere. Die **Werte** bleiben stehen und
gelten beim Zurückwechseln samt ihrer Beanstandung wieder.

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

## Auftragsnummer-Vorschlag und Belegt-Warnung (§6.3)

`_onLadeDefaults` lädt seit §6.3 zusätzlich den Nummernstand des laufenden Jahrgangs über
`RegisterNummernRepository` (Feature `vorgaenge`, wie hier schon die Einstellungen eines anderen
Features gelesen werden). Vorgeschlagen wird `naechsteNummer` — die höchste im Jahrgang belegte
Nummer + 1, quellenübergreifend über Vorgänge der App und übernommene Historie (§6.2) —, nicht mehr
`settings.laufendeAuftragsnummer`. Der Zähler bleibt trotzdem bestehen: Er ist weiterhin die
Korrektur von Hand (§7.1) und wird unverändert erst beim Abschluss des Vorgangs erhöht (`POST
/api/Vorgaenge/abschliessen`, atomar im Backend, §4.8) — mit dem Vorschlag des nächsten Vorgangs hat
das seit §6.3 nichts mehr zu tun.

**Scheitert der Abruf, bleibt es beim Zähler.** `_ladeNummernstand()` fängt den Fehler ab und gibt
`null` zurück; `_onLadeDefaults` fällt dann auf `settings.laufendeAuftragsnummer` zurück und lässt
`belegteNummern`/`nummernJahr` leer bzw. `null`. Ein nicht erreichbarer Endpunkt darf das Anlegen
eines Vorgangs nicht aufhalten — deshalb hier **kein** Fehlerdialog und keine `Rueckmeldung`.

**Die Belegt-Warnung sitzt bewusst nicht am `FormControl`.** `AuftragsnummerBelegtHinweis`
(`presentation/widgets/`) hört über `ReactiveValueListenableBuilder` live auf das Feld
`auftragsnummer` und vergleicht gegen `belegteNummern` — sie setzt **keinen** Validator. Ein
Validator würde `formGroup.valid` mitbestimmen und über `VorgangAktionsleiste` den
„Speichern"-Knopf sperren, so wie es die RVG-Wert-Prüfung in `word_automation` mit absichtlich
unlesbaren Werten tut. §6.3 verlangt das Gegenteil: „Eine doppelte Nummer warnt, sperrt nicht" — das
gewachsene Register der Kanzlei enthält echte Doubletten (`1/26 C03` und `5/26 C03` doppelt, siehe
Begründung der Anforderung), und was im Bestand steht, muss eintragbar bleiben. Der Hinweistext
selbst ist `FehlerHinweis` (`core/general_widgets/`) — dieselbe Fehlerfarbe wie eine Validierung,
aber ohne ihre Wirkung; das Muster stammt von `FeldNameHinweis` in `form_template_setup`.

Der Bestand (`belegteNummern`, `nummernJahr`) liegt als lokaler State in
`_VorgangStartenFormViewState`, gesetzt über `onNummernstandGeladen` — den Rückkanal von
`VorgangDefaultsBeobachter` (`presentation/widgets/`, seit #109-D1 die eigenständige Auslagerung von
`_patchDefaults` und dem Öffnen-schon-geladen-Check aus der View, wegen des 250-Zeilen-Budgets). Es
ist kein erneuter Bloc-Zugriff aus `AuftragSection` nötig: Die Sektionen-Widgets sind reine
`StatelessWidget`s, die ihre Werte von der View bekommen, wie auch `referenzManuallyEdited` und die
Mandantenliste. Ändert der Anwalt den Jahrgang im Feld `auftragsjahr`, wird der Bestand **nicht** neu
geladen — er gilt für den beim Öffnen der Seite aktuellen Jahrgang. Das deckt den Normalfall (ein
neuer Vorgang trägt praktisch immer das laufende Jahr); ein Nachladen je Tastenanschlag im Jahr-Feld
war für diesen Zuschnitt bewusst nicht Teil der Aufgabe.

## Die Referenz-Vorschau friert ein, sobald jemand sie anfasst

Die Referenz baut sich aus Auftragsnummer, Jahr, Abteilung und dem Kennzeichen des Gegners und
wird bei jeder Änderung dieser vier Felder neu gesetzt (`_syncReferenzVorschau`). Ändert der Anwalt
sie einmal von Hand, ist Schluss damit: `_referenzManuallyEdited` friert die Automatik ein, bis
„zurücksetzen" gedrückt wird. Erkannt wird die Handänderung über einen **Wertvergleich** im
Listener, nicht über ein Unterdrücken der Ereignisse — das eigene `updateValue` löst denselben
Strom aus wie eine Tastatureingabe, und wer stattdessen ein Flag um den Schreibvorgang legt,
verpasst jede Änderung, die währenddessen eintrifft. Dasselbe Muster trägt das Rechtsgebiet
(`_rechtsgebietManuell`, §7.1): vorschlagen statt entscheiden, mit sichtbarem Weg zurück.

## `registriereAnfrage` ist ein Upsert über die Referenz

Dieselbe Referenz ein zweites Mal zu speichern legt keinen zweiten Vorgang an, sondern
aktualisiert **nur die hier erfassten Felder** des vorhandenen. Antwort- und Dokumentdaten, die
später aus Postfach (§4.4) und Word-Automation (§4.6) dazugekommen sind, bleiben stehen. Das ist
der Grund, warum der Anwalt einen Vorgang gefahrlos noch einmal über dieses Formular schicken darf
— etwa wenn der Zentralruf-Prefill beim ersten Versuch am Captcha gescheitert ist.
