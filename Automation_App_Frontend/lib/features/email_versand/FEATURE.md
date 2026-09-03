# email_versand — Mail zum Vorgang verfassen und senden

**Zweck:** Der letzte Schritt des Ablaufs: Anspruchsschreiben per E-Mail an Mandant und gegnerische
Versicherung. Empfänger, Betreff und Anrede aus dem Vorgang vorbelegt, Anhänge wählbar; gesendet
wird über das Postfach der Kanzlei.
**Anforderung:** `REQUIREMENTS.md` §4.7
**Einstieg:** `presentation/widgets/email_versand_button.dart` (`EmailVersandButton`) — der Knopf
für alle Stellen; er öffnet `EmailVersandDialog`.
**Zustand:** `EmailEntwurfCubit` (`presentation/blocs/email_entwurf_cubit/`) — Factory, je Dialog
ein eigener Entwurf; die Griffe liegen in `OutlookAnhaengeGriff`, `VersandGriff`, `AnredeGriff`,
`VorgangGriff`.
**Domain:** Entities `EmailEntwurf`, `EmailEmpfaengerVorschlag`, `EmpfaengerArt`, `EmailVersandBereitschaft`,
`EmailVersandErgebnis`, `OutlookAnhaenge`, `OutlookStand`, `VersandPruefung`, `VersandEintrag`, `MailVorlage`,
`Grussformel`, `Anredebaustein`, `AnredeNeutralGrund`, `AnredeartWirkung`, `Beugung`, `PlatzhalterBefund`,
`VorlagenMangel`; Dienste
`EmailEntwurfErzeuger`, `VersandVoraussetzungen`, `MailVorlagenFueller`, `EntwurfAbleitung`,
`EmpfaengerAbgleich`, `PlatzhalterFehlstelle`, `VorlagenPruefung`, `TextNachtrag`; Schnittstellen
`EmailVersandRepository`, `MailVorlagenRepository`, `GrussformelnRepository`,
`AnredebausteineRepository`. Keine UseCases.
**Backend:** `Features/EmailVersand/` · `bereitschaft` · `senden` · `entwurf`
(+ `entwurf/vorwaermen`) · `outlook/anhaenge` · `outlook/stand` · `protokoll` (+ `/letzte`) ·
`signaturen` (+ `/stand`, `/uebernehmen`, `/format`, `/bild`)
· CRUD: `api/MailVorlagen`, `api/Grussformeln`, `api/Anredebausteine`
(`signaturen` auch `/vorschau`: lesen ohne zu speichern)
**Tests:** `test/features/email_versand/`

**Fallstricke**

- Der lange Rest steht in `FALLSTRICKE.md` daneben: Vorbelegung, Anrede, Beugung, warum neutral,
  Signatur, Anhänge, Outlook-Entwurf, Versandprotokoll, Oberfläche.
- Der Dialog liest **nichts** aus dem Kontext — er wird aus zwei Tabs und aus einem anderen
  Dialog heraus geöffnet; Kanzleidaten, Mandant und Versicherer holt der **Cubit** selbst
  (`EntwurfQuellen`, jede Quelle mit Rückfallwert).
- Zwei Wege hinaus: Direktversand **oder** Entwurf in Outlook — die Rückfalltür, ohne
  Postfach-Zugang. Danach bleibt die Phase auf `verfassen` und `ergebnis` null: Ob dort gesendet
  wurde, weiß die App nicht (§4.8), der Dialog schließt sich **nicht**.
- Entwurf, Anhang-Griff und Signatur-Übernahme brauchen alle drei das **klassische** Outlook; das
  neue (Store-App) hat kein COM und liesse sie wortlos leer ausgehen. `OutlookStand` (Dienst
  prüft beim Start, `outlook/stand`) trägt den Grund, jede der drei Stellen schreibt ihn hin
  (`OutlookHinweisZeile`) — der Direktversand ist davon **nicht** betroffen.
