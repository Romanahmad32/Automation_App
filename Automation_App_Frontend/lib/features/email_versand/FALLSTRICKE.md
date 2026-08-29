# email_versand — Fallstricke

Der lange Rest zu `FEATURE.md`. Der Steckbrief hat ein Zeilenbudget, diese Datei nicht: was
hier steht, musste nicht in vierzig Zeilen passen und ist deshalb ausgeschrieben. Die vier,
fünf Punkte, die man **vor** dem ersten Griff in das Feature kennen muss, stehen weiter im
Steckbrief — hier steht, was einen beim zweiten Griff erwischt.

## Vorbelegung und Anrede

- `EmailEntwurfErzeuger` ist **die** Stelle für die späteren pflegbaren Mail-Textvorlagen
  (§4.7, §5.3): Betreff und Text kommen dann aus der Vorlage statt aus `betreff`/`textFuer`.
  Nichts anderswo verdoppeln.
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
