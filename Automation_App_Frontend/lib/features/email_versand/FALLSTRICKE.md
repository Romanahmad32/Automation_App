# email_versand — Fallstricke

Der lange Rest zu `FEATURE.md`. Der Steckbrief hat ein Zeilenbudget, diese Datei nicht: was
hier steht, musste nicht in vierzig Zeilen passen und ist deshalb ausgeschrieben. Die vier,
fünf Punkte, die man **vor** dem ersten Griff in das Feature kennen muss, stehen weiter im
Steckbrief — hier steht, was einen beim zweiten Griff erwischt.

## Vorbelegung und Anrede

- `EmailEntwurfErzeuger` belegt vor, **solange keine Vorlage gewählt ist** (§4.7). Wird eine
  gewählt, ersetzt `MailVorlagenFueller` Betreff und Text — die Vorbelegung bleibt der Rückfall
  und wird nicht abgeschafft: Ohne Vorlage im Bestand ist sie das Einzige, was dasteht.
- **Die Vorlage errät die App nicht.** Standardmäßig gehen Mandant und Versicherung eine
  gemeinsame Mail (§4.7); ein Mandantenanschreiben passt dort nicht hinein, und automatisch
  gesetzt stünde es vor der Gegenseite. `MailVorlagenAuswahl` blendet sich ganz aus, solange der
  Bestand leer ist — ein leeres Auswahlfeld sähe aus wie eine Einstellung, die es nicht gibt.
- **Betreff und Text sind abgeleitet, nicht eingefügt.** Solange eine Vorlage gewählt ist und der
  Anwalt nicht selbst getippt hat (`textSelbstGeschrieben`), erzeugt `_abgeleitet` sie bei jeder
  Änderung neu — Empfänger dazu, Gruß gewechselt, Vorlage getauscht. Erst `setzeText` löst die
  Bindung. Wer hier eine einmalige Einfügung daraus macht, bricht genau die Zusage, dass die
  Anrede dem Empfängerkreis folgt.
  **Der Betreff ist die Ausnahme:** Er entsteht nur bei einer *ausdrücklichen* Handlung neu
  (Vorlage oder Gruß gewählt, `betreffAuch: true`). Ein hinzugefügter Empfänger ist keine Ansage,
  die Betreffzeile neu zu schreiben — so war es vor den Vorlagen schon.
- **„Keine Vorlage" ist ein echter Eintrag** mit `null` als Wert, kein Sonderfall daneben. Deshalb
  nimmt `copyWith` die Vorlage als **Funktion** (`gewaehlteVorlage: () => null`), wie `fehler`:
  Mit `?? this.` liesse sie sich nie zurücknehmen.
- Der **Zusatzgruß** wird je Mail gewählt (`setzeZusatzgruss`), vorbelegt aus dem Mandanten. Der
  Wert liegt im Zustand, die **Regel** bleibt im `MailVorlagenFueller`: `nurAnDenMandanten`
  entscheidet, ob er eingesetzt wird. `grussMoeglich` steht daneben im Zustand, damit die Chips
  und der erzeugte Text dieselbe Rechnung benutzen — zwei davon liefen auseinander.
- **Anrede und Grußformel sind Platzhalter der Vorlage**, keine Vorspann-Zeilen: So bestimmt
  jede Vorlage selbst, ob und wie angeredet wird. Ein Platzhalter ohne Wert nimmt **seine ganze
  Zeile** mit (`MailVorlagenFueller`), und wo dadurch zwei Leerzeilen aufeinanderträfen, bleibt
  eine — sonst hätte jede Mail an einen Mandanten ohne Grußformel eine Lücke unter der Anrede.
- Beide Werte hängen am Feld „An" **im Augenblick der Wahl**: `nurAnDenMandanten` entscheidet über
  den Zusatzgruß (§5.1), `anredeFuer` über die Anrede. Wer danach die Versicherung hinzunimmt, hat
  eine Mandantenanrede vor einem Mitleser stehen — sichtbar im Text, und die App schreibt ihm
  nicht hinein. Nachziehen ginge nicht, ohne das zu überschreiben, was er inzwischen getippt hat.
- Alle übrigen Platzhalter laufen über `VorgangPrefillMatcher.wertFuerNamen` — **dieselbe** Kette
  wie beim Ausfüllen einer Word-Vorlage. Deshalb gilt dort auch deren Eigenheit: `{{Aktenzeichen}}`
  liefert wie `{{Referenz}}` die **volle** Referenz mit Kennzeichen. Im Ausgangsbestand steht
  darum `{{Referenz}}`.
- Die Anrede folgt dem Empfängerkreis: „Sehr geehrter Herr Müller" nur, wenn **ausschließlich**
  der Mandant angeschrieben wird; der Bezugssatz nur bei Anhängen (`mitSchreiben`). Nach
  `setzeText` zieht beides nicht mehr nach (`textSelbstGeschrieben`).
- Die Adressen kommen aus `_antwort` = mitgegebene Antwort **vor** `vorgang.antwort`: Im
  Postfach ist der Treffer noch nicht übernommen (§4.3) — ohne den `antwort`-Parameter stünde
  dort kein Vorschlag.

## Signatur

- Die **Signatur** hängt das Backend an (`KanzleiSignatur`), nur beim Direktversand — beim
  Outlook-Entwurf setzt Outlook seine eigene. Outlook führt sie **doppelt**: `signatur` ist
  seine Nur-Text-Übersetzung, `signaturHtml` die formatierte Fassung, die beim Empfänger
  ankommt. Die Vorschau rendert **die HTML-Fassung** (`SignaturAnsicht`,
  `flutter_widget_from_html_core`); ihre Bildverweise zeigt `SignaturHtmlAufbereitung` auf
  `signaturen/bild` um.
- **Outlook schreibt jedes Bild zweimal** (VML-Form *und* `<img>`) — beim Abwählen müssen beide
  fallen, ein Zellenhintergrund (`background=`) verliert nur sein Attribut; pixelgleich wird die
  Ansicht nie (Word-Modul).
- Ein Bild, das **nicht** mitgenommen werden kann (>25 MB, leer, unlesbar), verliert seine ganze
  Marke statt einen toten Verweis zu hinterlassen — beim Übernehmen
  (`OutlookSignaturFormat.Uebergangen`, gemeldet in den Einstellungen) und als Netz beim Versand
  (`KanzleiSignatur`, `OertlicheQuellen`).
- Signaturbilder sind je Mail abwählbar (`ohneSignaturBilder`) und **wiegen mit**:
  `state.gesamtBytes` = Anhänge + mitgehende Bilder gegen `bereitschaft.maxAnhangMb`. Das
  Backend rechnet nach (`AnhangPruefung`) — die Oberfläche warnt, sie prüft nicht.

## Outlook-Entwurf

- `OutlookVerbindung` hält die Outlook-Instanz am Leben, der Dialog wärmt sie beim Öffnen vor
  (`waermeEntwurfVor`) — ohne das bezahlt der erste Entwurf den Outlook-Kaltstart, während der
  Anwalt wartet statt tippt.

## Oberfläche

- **„Senden" ist immer anfassbar**, solange ein Postfach-Zugang da ist; geprüft wird beim
  Drücken (`istVersandbereit`), was fehlt steht danach am Feld (`state.markiert`). Daher
  `offenAn`/`offenKopie` im Zustand: eine getippte, nicht übernommene Adresse ginge sonst
  verloren.
- Ein **Klick** auf eine Empfängerkachel holt sie zum Berichtigen zurück ins Feld (übernimmt
  vorher die angefangene Eingabe); das Kreuz löscht.
- Die Vorschau läuft ab 1180 px als Seitenspalte mit (`EmailVersandInhalt.zweispaltig`) und
  scrollt **als Ganzes**, damit die Leiste am Rand sitzt.
- Ein **aus Outlook** gezogener Anhang kommt als *leeres* Ablegen an (Windows reicht ihn als
  virtuelle Datei durch, `desktop_drop` liest nur `CF_HDROP`) — `onNichtsErkannt` fragt dann
  Outlook nach derselben Nachricht.
