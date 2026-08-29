# vorgang_starten — Fallstricke

Der lange Teil des Steckbriefs `FEATURE.md`. Hier steht, was am Speicherpfad regelmäßig schiefgeht —
die kurzen Merksätze bleiben drüben.

## Die Reihenfolge in `_onSpeichereVorgang`

Erst den Mandanten anlegen bzw. aktualisieren, dann den Zentralruf-Prefill, zuletzt
`VorgangCubit.registriereAnfrage`. Scheitert einer der ersten beiden Schritte, entsteht **kein**
Vorgang — der Bloc meldet `VorgangStartenError` und kehrt um.

Die vom Prefill zurückgegebene Referenz schlägt die im Formular eingetippte: das Backend
normalisiert sie, und was am Zentralruf steht, muss auch im Register stehen.

## Zwei Wege, einen Mandanten anzulegen — ein Aufräumpfad

Es gibt zwei Knöpfe, die einen Mandanten ins Register schreiben:

| Weg | Event | Erfolgszustand |
|---|---|---|
| Karten-Knopf „Neuen Mandanten speichern" | `SpeichereMandantEvent` | `MandantGespeichert` |
| Aktionsleiste „Speichern" / „Zentralruf-Formular ausfüllen" | `SpeichereVorgangEvent` | `VorgangGespeichert` |

Beide müssen in der View durch `_uebernehmeGespeicherten` laufen — Mandantenliste neu laden **und**
`_selectedMandantId` setzen. Deshalb trägt `VorgangGespeichert` den angelegten bzw. aktualisierten
Mandanten in `gespeicherterMandant` mit.

Was passiert, wenn er fehlt, war einmal echter Datenschaden und ist der Grund für
`mandant_uebernahme_test.dart`: Ohne die Verknüpfung liefert `mandantAenderungsart` weiterhin `neu`,
die Karte hält den gerade angelegten Mandanten für unbekannt, er lässt sich unter „Aus Mandanten
übernehmen" nicht auswählen — und der nächste Klick auf „Speichern" legt **denselben Menschen ein
zweites Mal** an. Eine Dublette im Mandantenregister ist kein Anzeigefehler.

Der Zustand `VorgangStartenLoading` bleibt dabei bis zum Schluss stehen. Das ist Absicht: Er sperrt
die Knöpfe in `VorgangAktionsleiste` und `MandantSpeichernButton`. Wer die Mandanten-Übernahme
stattdessen als eigenes `MandantGespeichert` mitten in den Ablauf einschöbe, gäbe die Knöpfe frei,
während der Prefill noch läuft — und handelte sich denselben Doppelklick auf anderem Weg wieder ein.

## Warum Tests hier zweimal pumpen müssen

`MandantUebersichtDialog.zeige` gibt sein Ergebnis erst frei, wenn die Ausblende-Animation durch ist.
Die Speicherkette startet also erst **nach** dem letzten Frame, den ein einzelnes `pumpAndSettle`
sieht. Ein Widget-Test, der direkt danach misst, sieht `VorgangStartenLoading` und hält die
Übernahme fälschlich für kaputt. `mandant_uebernahme_test.dart` wartet deshalb auf
`VorgangGespeichert`, statt eine feste Anzahl Frames zu raten.
