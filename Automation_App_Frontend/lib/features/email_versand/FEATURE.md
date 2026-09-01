# email_versand — Mail zum Vorgang verfassen und senden

**Zweck:** Der letzte Schritt des Ablaufs: Anspruchsschreiben per E-Mail an Mandant und gegnerische
Versicherung. Empfänger, Betreff und Anrede aus dem Vorgang vorbelegt, Anhänge wählbar; gesendet
wird über das Postfach der Kanzlei.
**Anforderung:** `REQUIREMENTS.md` §4.7
**Einstieg:** `presentation/widgets/email_versand_button.dart` (`EmailVersandButton`) — der Knopf
für alle Stellen; er öffnet `EmailVersandDialog`.
**Zustand:** `EmailEntwurfCubit` (`presentation/blocs/email_entwurf_cubit/`) — Factory, je Dialog
ein eigener Entwurf; der Griff nach Outlook liegt im Mixin `OutlookAnhaengeGriff` daneben.
**Domain:** Entities `EmailEntwurf`, `EmailEmpfaengerVorschlag`, `EmpfaengerArt`, `EmailVersandBereitschaft`,
`EmailVersandErgebnis`, `OutlookAnhaenge`, `OutlookStand`, `VersandPruefung`, `VersandEintrag`, `MailVorlage`;
Dienste `EmailEntwurfErzeuger` (Vorbelegung), `VersandVoraussetzungen`, `MailPlatzhalter`; Schnittstellen
`EmailVersandRepository`, `MailVorlagenRepository`. Keine UseCases.
**Backend:** `Features/EmailVersand/` · `bereitschaft` · `senden` · `entwurf`
(+ `entwurf/vorwaermen`) · `outlook/anhaenge` · `outlook/stand` · `protokoll` (+ `/letzte`) ·
`signaturen` (+ `/stand`, `/uebernehmen`, `/format`, `/bild`) · `api/MailVorlagen` (CRUD)
**Tests:** `test/features/email_versand/`

**Fallstricke**

- Der lange Rest steht in `FALLSTRICKE.md` daneben: Vorbelegung, Anrede, Signatur, Oberfläche.
- Der Dialog liest **nichts** aus dem Kontext — er wird aus zwei Tabs und aus einem anderen
  Dialog heraus geöffnet; Kanzleidaten, Mandant und Versicherer holt der **Cubit** selbst
  (`EntwurfQuellen`, jede Quelle mit Rückfallwert).
- Zwei Wege hinaus: Direktversand **oder** Entwurf in Outlook — die Rückfalltür, ohne
  Postfach-Zugang. Danach bleibt die Phase auf `verfassen` und `ergebnis` null: Ob dort gesendet
  wurde, weiß die App nicht (§4.8), der Dialog schließt sich **nicht**.
- Anhänge gehen als **Pfade** ans Backend. `anhangNamen` benennt nur **für die Mail** um; die
  Datei in der Akte behält ihren Namen — für Outlook legt das Backend eine Kopie an, weil COM
  nach Pfad anhängt. Versand, Entwurf und Outlook-Anhänge brauchen `receiveTimeout: 120 s`
  (global 3 s); ein Versandfehler lässt den Entwurf **vollständig** stehen.
- Entwurf, Anhang-Griff und Signatur-Übernahme brauchen alle drei das **klassische** Outlook; das
  neue (Store-App) hat kein COM und liesse sie wortlos leer ausgehen. `OutlookStand` (Dienst
  prüft beim Start, `outlook/stand`) trägt den Grund, jede der drei Stellen schreibt ihn hin
  (`OutlookHinweisZeile`) — der Direktversand ist davon **nicht** betroffen.
- **Versandprotokoll** (`protokoll`): geschrieben **nach** erfolgreicher Einlieferung, nie davor,
  und nie den Versand aufhaltend. Sichtbar in der Vorgangsliste (`VorgangVersandZeile`, ein Abruf
  via `LetzteVersaendeCubit`) und im Abschlussdialog, wo nur ein **Direktversand** das Häkchen
  belegt — eine Outlook-Übergabe nicht (§4.8: die App weiß dort nichts).
