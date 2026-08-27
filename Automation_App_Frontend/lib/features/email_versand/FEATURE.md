# email_versand — Mail zum Vorgang verfassen und senden

**Zweck:** Der letzte Schritt des Ablaufs: Anspruchsschreiben per E-Mail an Mandant und gegnerische Versicherung. Empfänger, Betreff und Anrede sind aus dem Vorgang vorbelegt, Anhänge wählbar; gesendet wird über das Postfach der Kanzlei.
**Anforderung:** `REQUIREMENTS.md` §4.7
**Einstieg:** `presentation/widgets/email_versand_button.dart` (`EmailVersandButton`) — der Knopf für alle Stellen; er öffnet `EmailVersandDialog`.
**Zustand:** `EmailEntwurfCubit` (`presentation/blocs/email_entwurf_cubit/`) — Factory, je Dialog ein eigener Entwurf.
**Domain:** Entities `EmailEntwurf`, `EmailEmpfaengerVorschlag`, `EmpfaengerArt`, `EmailVersandBereitschaft`, `EmailVersandErgebnis`;
Dienst `EmailEntwurfErzeuger` (Vorbelegung aus Vorgang/Mandant/Versicherer); Schnittstelle `EmailVersandRepository`. Keine UseCases.
**Backend:** `Features/EmailVersand/` · `bereitschaft` · `senden` · `entwurf` (+ `entwurf/vorwaermen`) ·
`outlook/anhaenge` · `signaturen` — alle unter `/api/EmailVersand/`
**Tests:** `test/features/email_versand/`

**Fallstricke**

- `EmailEntwurfErzeuger` ist **die** Stelle für die späteren pflegbaren Mail-Textvorlagen (§4.7, §5.3):
  Betreff und Text kommen dann aus der Vorlage statt aus `betreff`/`textFuer`. Nichts anderswo verdoppeln.
- Die Anrede folgt dem Empfängerkreis: „Sehr geehrter Herr Müller" nur, wenn **ausschließlich** der Mandant angeschrieben wird;
  der Bezugssatz nur bei Anhängen (`mitSchreiben`). Nach `setzeText` zieht beides nicht mehr nach (`textSelbstGeschrieben`).
- Der Dialog liest **nichts** aus dem Kontext — er wird aus zwei Tabs und aus einem anderen Dialog heraus
  geöffnet. Kanzleidaten, Mandant (aus `vorgang.mandantId`) und Versicherer holt sich der **Cubit** selbst.
- Die Adressen kommen aus `_antwort` = mitgegebene Antwort **vor** `vorgang.antwort`. Im Postfach ist der
  Treffer noch nicht übernommen (§4.3) — ohne den `antwort`-Parameter stünde dort kein Vorschlag.
- Anhänge gehen als **Pfade** ans Backend, nicht als Inhalt. `anhangNamen` benennt nur **für die Mail** um; die Datei in der
  Akte behält ihren Namen — für Outlook legt das Backend dafür eine Kopie an, weil COM nach Pfad anhängt.
- Versand, Entwurf und Outlook-Anhänge brauchen `receiveTimeout: 120 s`; global stehen 3 s. Ein
  Versandfehler lässt den Entwurf **vollständig** stehen (Phase zurück auf `verfassen`).
- Zwei Wege hinaus: Direktversand **oder** Entwurf in Outlook. Der Entwurf braucht **keinen** Postfach-Zugang
  (`kannEntwurfOeffnen` prüft ihn nicht) — er ist die Rückfalltür. Danach bleibt die Phase auf `verfassen` und `ergebnis` null:
  Ob dort gesendet wurde, weiß die App nicht (§4.8). Der Dialog schließt sich **nicht**, der Knopf heißt „Erneut … öffnen".
- Die **Signatur** hängt das Backend an (`KanzleiSignatur`), nur beim Direktversand — beim Outlook-Entwurf
  setzt Outlook seine eigene. Ins Frontend kommt sie über `bereitschaft.signatur` **nur zum Anzeigen**.
- Empfängerzeilen übernehmen die Eingabe auch beim Verlassen des Feldes und bei `,`/`;`; was offen bleibt,
  meldet `onOffeneEingabe`, und `VersandVoraussetzungen.fehlend` erklärt, warum „Senden" grau ist.
- Die Vorschau laeuft ab 1180 px Fensterbreite als Seitenspalte mit (`EmailVersandInhalt.zweispaltig`),
  darunter bleibt sie hinter dem Knopf. Anhaenge kommen auch per Ziehen aus dem Explorer herein
  (`DateiAblageBereich`; Ordner werden abgelehnt statt still verschluckt).
- `OutlookVerbindung` haelt die Outlook-Instanz; der Dialog laesst sie beim Oeffnen vorwaermen
  (`waermeEntwurfVor`). Ohne das kostet der erste Entwurf den Kaltstart von Outlook.
- Vorschlaege aus zwei Quellen, **nicht** vermischt: `ausDerAkte` ist Bestand, `ausOutlook` ein Griff, der
  danebengehen darf — nur der traegt ein Kreuz (`outlookAnhangVerwerfen` loescht auch die Datei).
