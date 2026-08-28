# email_versand — Mail zum Vorgang verfassen und senden

**Zweck:** Der letzte Schritt des Ablaufs: Anspruchsschreiben per E-Mail an Mandant und gegnerische Versicherung. Empfänger, Betreff und Anrede sind aus dem Vorgang vorbelegt, Anhänge wählbar; gesendet wird über das Postfach der Kanzlei.
**Anforderung:** `REQUIREMENTS.md` §4.7
**Einstieg:** `presentation/widgets/email_versand_button.dart` (`EmailVersandButton`) — der Knopf für alle Stellen; er öffnet `EmailVersandDialog`.
**Zustand:** `EmailEntwurfCubit` (`presentation/blocs/email_entwurf_cubit/`) — Factory, je Dialog ein eigener Entwurf; der Griff nach Outlook liegt im Mixin `OutlookAnhaengeGriff` daneben.
**Domain:** Entities `EmailEntwurf`, `EmailEmpfaengerVorschlag`, `EmpfaengerArt`, `EmailVersandBereitschaft`, `EmailVersandErgebnis`, `OutlookAnhaenge`, `OutlookStand`, `VersandPruefung`, `VersandEintrag`;
Dienste `EmailEntwurfErzeuger` (Vorbelegung), `VersandVoraussetzungen` (Prüfung je Feld); Schnittstelle `EmailVersandRepository`. Keine UseCases.
**Backend:** `Features/EmailVersand/` · `bereitschaft` · `senden` · `entwurf` (+ `entwurf/vorwaermen`) ·
`outlook/anhaenge` · `outlook/stand` · `protokoll` (+ `/letzte`) · `signaturen` (+ `/stand`, `/uebernehmen`, `/format`, `/bild`)
**Tests:** `test/features/email_versand/`

**Fallstricke**

- `EmailEntwurfErzeuger` ist **die** Stelle für die späteren pflegbaren Mail-Textvorlagen (§4.7, §5.3): Betreff und Text kommen dann aus der Vorlage statt aus `betreff`/`textFuer`. Nichts anderswo verdoppeln.
- Die Anrede folgt dem Empfängerkreis: „Sehr geehrter Herr Müller" nur, wenn **ausschließlich** der Mandant angeschrieben wird; der Bezugssatz nur bei Anhängen (`mitSchreiben`). Nach `setzeText` zieht beides nicht mehr nach (`textSelbstGeschrieben`).
- Der Dialog liest **nichts** aus dem Kontext — er wird aus zwei Tabs und aus einem anderen Dialog heraus geöffnet; Kanzleidaten, Mandant und Versicherer holt der **Cubit** selbst (`EntwurfQuellen`, jede Quelle mit Rückfallwert).
- Die Adressen kommen aus `_antwort` = mitgegebene Antwort **vor** `vorgang.antwort`: Im Postfach ist der Treffer noch nicht übernommen (§4.3) — ohne den `antwort`-Parameter stünde dort kein Vorschlag.
- Anhänge gehen als **Pfade** ans Backend. `anhangNamen` benennt nur **für die Mail** um; die Datei in der Akte behält ihren
  Namen — für Outlook legt das Backend eine Kopie an, weil COM nach Pfad anhängt. Versand, Entwurf und Outlook-Anhänge brauchen
  `receiveTimeout: 120 s` (global 3 s); ein Versandfehler lässt den Entwurf **vollständig** stehen.
- Zwei Wege hinaus: Direktversand **oder** Entwurf in Outlook — die Rückfalltür, ohne Postfach-Zugang. Danach bleibt die Phase auf `verfassen` und `ergebnis` null: Ob dort gesendet wurde, weiß die App nicht (§4.8), der Dialog schließt sich **nicht**.
  `OutlookVerbindung` hält die Instanz, der Dialog wärmt vor (`waermeEntwurfVor`) — sonst Kaltstart.
- Die **Signatur** hängt das Backend an (`KanzleiSignatur`), nur beim Direktversand — beim Outlook-Entwurf setzt Outlook seine eigene. Outlook führt sie **doppelt**: `signatur` ist seine Nur-Text-Übersetzung, `signaturHtml` die formatierte Fassung, die beim Empfänger ankommt. Die Vorschau rendert **die HTML-Fassung** (`SignaturAnsicht`, `flutter_widget_from_html_core`); ihre Bildverweise zeigt `SignaturHtmlAufbereitung` auf `signaturen/bild` um.
  **Outlook schreibt jedes Bild zweimal** (VML-Form *und* `<img>`) — beim Abwählen müssen beide fallen; pixelgleich wird die Ansicht nie (Word-Modul).
  Ein Bild, das **nicht** mitgenommen werden kann (>25 MB, leer, unlesbar), verliert seine ganze Marke statt einen toten Verweis zu hinterlassen —
  beim Übernehmen (`OutlookSignaturFormat.Uebergangen`, gemeldet in den Einstellungen) und als Netz beim Versand (`KanzleiSignatur`, `OertlicheQuellen`).
- Signaturbilder sind je Mail abwählbar (`ohneSignaturBilder`) und **wiegen mit**: `state.gesamtBytes` = Anhänge + mitgehende
  Bilder gegen `bereitschaft.maxAnhangMb`. Das Backend rechnet nach (`AnhangPruefung`) — die Oberfläche warnt, sie prüft nicht.
- **„Senden" ist immer anfassbar**, solange ein Postfach-Zugang da ist; geprüft wird beim Drücken (`istVersandbereit`), was fehlt
  steht danach am Feld (`state.markiert`). Daher `offenAn`/`offenKopie` im Zustand: eine getippte, nicht übernommene Adresse ginge sonst verloren.
  Ein **Klick** auf eine Empfängerkachel holt sie zum Berichtigen zurück ins Feld (`_bearbeiten`, übernimmt vorher die angefangene Eingabe); das Kreuz löscht.
- Die Vorschau läuft ab 1180 px als Seitenspalte mit (`EmailVersandInhalt.zweispaltig`) und scrollt **als Ganzes**, damit die Leiste am Rand sitzt.
  Ein **aus Outlook** gezogener Anhang kommt als *leeres* Ablegen an (Windows reicht ihn als virtuelle Datei durch, `desktop_drop` liest nur `CF_HDROP`) — `onNichtsErkannt` fragt dann Outlook nach derselben Nachricht.
- Entwurf, Anhang-Griff und Signatur-Übernahme brauchen alle drei das **klassische** Outlook; das neue (Store-App) hat kein COM
  und liesse sie wortlos leer ausgehen. `OutlookStand` (Dienst prüft beim Start, `outlook/stand`) trägt den Grund, jede der drei
  Stellen schreibt ihn hin (`OutlookHinweisZeile`) — der Direktversand ist davon **nicht** betroffen.
- **Versandprotokoll** (`protokoll`): geschrieben **nach** erfolgreicher Einlieferung, nie davor, und nie den Versand aufhaltend.
  Sichtbar in der Vorgangsliste (`VorgangVersandZeile`, ein Abruf via `LetzteVersaendeCubit`) und im Abschlussdialog, wo nur ein
  **Direktversand** das Häkchen belegt — eine Outlook-Übergabe nicht (§4.8: die App weiß dort nichts).
