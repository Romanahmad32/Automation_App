# email_versand — Mail zum Vorgang verfassen und senden

**Zweck:** Der letzte Schritt des Ablaufs: Anspruchsschreiben per E-Mail an Mandant und gegnerische Versicherung. Empfänger, Betreff und Anrede sind aus dem Vorgang vorbelegt, Anhänge wählbar; gesendet wird über das Postfach der Kanzlei.
**Anforderung:** `REQUIREMENTS.md` §4.7
**Einstieg:** `presentation/widgets/email_versand_button.dart` (`EmailVersandButton`) — der Knopf für alle Stellen; er öffnet `EmailVersandDialog`.
**Zustand:** `EmailEntwurfCubit` (`presentation/blocs/email_entwurf_cubit/`) — Factory, je Dialog ein eigener Entwurf.
**Domain:** Entities `EmailEntwurf`, `EmailEmpfaengerVorschlag`, `EmpfaengerArt`, `EmailVersandBereitschaft`, `EmailVersandErgebnis`;
Dienst `EmailEntwurfErzeuger` (Vorbelegung aus Vorgang/Mandant/Versicherer); Schnittstelle `EmailVersandRepository`. Keine UseCases.
**Backend:** `Features/EmailVersand/` · `bereitschaft` · `senden` · `entwurf` (+ `entwurf/vorwaermen`) ·
`outlook/anhaenge` · `signaturen` (+ `/stand`, `/uebernehmen`, `/format`) — alle unter `/api/EmailVersand/`
**Tests:** `test/features/email_versand/`

**Fallstricke**

- `EmailEntwurfErzeuger` ist **die** Stelle für die späteren pflegbaren Mail-Textvorlagen (§4.7, §5.3):
  Betreff und Text kommen dann aus der Vorlage statt aus `betreff`/`textFuer`. Nichts anderswo verdoppeln.
- Die Anrede folgt dem Empfängerkreis: „Sehr geehrter Herr Müller" nur, wenn **ausschließlich** der Mandant angeschrieben wird;
  der Bezugssatz nur bei Anhängen (`mitSchreiben`). Nach `setzeText` zieht beides nicht mehr nach (`textSelbstGeschrieben`).
- Der Dialog liest **nichts** aus dem Kontext — er wird aus zwei Tabs und aus einem anderen Dialog heraus geöffnet;
  Kanzleidaten, Mandant und Versicherer holt der **Cubit** selbst (`EntwurfQuellen`, jede Quelle mit Rückfallwert).
- Die Adressen kommen aus `_antwort` = mitgegebene Antwort **vor** `vorgang.antwort`: Im Postfach ist der Treffer noch nicht übernommen (§4.3) — ohne den `antwort`-Parameter stünde dort kein Vorschlag.
- Anhänge gehen als **Pfade** ans Backend, nicht als Inhalt. `anhangNamen` benennt nur **für die Mail** um; die Datei in der Akte
  behält ihren Namen — für Outlook legt das Backend eine Kopie an, weil COM nach Pfad anhängt. Versand, Entwurf und
  Outlook-Anhänge brauchen `receiveTimeout: 120 s` (global 3 s); ein Versandfehler lässt den Entwurf **vollständig** stehen.
- Zwei Wege hinaus: Direktversand **oder** Entwurf in Outlook. Der Entwurf braucht **keinen** Postfach-Zugang
  (`kannEntwurfOeffnen` prüft ihn nicht) — er ist die Rückfalltür. Danach bleibt die Phase auf `verfassen` und `ergebnis` null:
  Ob dort gesendet wurde, weiß die App nicht (§4.8). Der Dialog schließt sich **nicht**, der Knopf heißt „Erneut … öffnen".
  `OutlookVerbindung` hält die Instanz, der Dialog wärmt sie beim Öffnen vor (`waermeEntwurfVor`) — sonst Kaltstart.
- Die **Signatur** hängt das Backend an (`KanzleiSignatur`), nur beim Direktversand — beim Outlook-Entwurf setzt Outlook seine
  eigene. Mit formatierter Fassung wird die Mail HTML **und** Text, ihre Bilder gehen als `cid:` mit (`MailRumpf`). Die
  HTML-Fassung kommt **nie** ins Frontend: übernommen wird im Dienst (`signaturen/uebernehmen`, legt die Bilder ab),
  angezeigt nur `bereitschaft.signatur` (Text) und `signaturen/stand` (Bildliste mit Größe).
- Signaturbilder sind je Mail abwählbar (`ohneSignaturBilder`) und **wiegen mit**: `state.gesamtBytes` = Anhänge + mitgehende
  Bilder gegen `bereitschaft.maxAnhangMb`. Das Backend rechnet nach (`AnhangPruefung`) — die Oberfläche warnt, sie prüft nicht.
- Empfängerzeilen übernehmen die Eingabe auch beim Verlassen des Feldes und bei `,`/`;`; was offen bleibt, meldet
  `onOffeneEingabe`, und `VersandVoraussetzungen.fehlend` erklärt jeden Grund, aus dem „Senden" grau ist.
- Die Vorschau läuft ab 1180 px Fensterbreite als Seitenspalte mit (`EmailVersandInhalt.zweispaltig`), darunter bleibt sie
  hinter dem Knopf. Anhänge kommen auch per Ziehen aus dem Explorer herein (`DateiAblageBereich`, Ordner abgelehnt).
- Vorschläge aus zwei Quellen, **nicht** vermischt: `ausDerAkte` ist Bestand, `ausOutlook` ein Griff, der danebengehen
  darf — nur der trägt ein Kreuz (`outlookAnhangVerwerfen` löscht auch die Datei).
