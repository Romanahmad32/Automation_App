# email_versand — Mail zum Vorgang verfassen und senden

**Zweck:** Der letzte Schritt des Ablaufs: Anspruchsschreiben per E-Mail an Mandant und gegnerische Versicherung. Empfänger, Betreff und Anrede sind aus dem Vorgang vorbelegt, Anhänge wählbar; gesendet wird über das Postfach der Kanzlei.
**Anforderung:** `REQUIREMENTS.md` §4.7
**Einstieg:** `presentation/widgets/email_versand_button.dart` (`EmailVersandButton`) — der Knopf für alle Stellen; er öffnet `EmailVersandDialog`.
**Zustand:** `EmailEntwurfCubit` (`presentation/blocs/email_entwurf_cubit/`) — Factory, je Dialog ein eigener Entwurf.
**Domain:** Entities `EmailEntwurf`, `EmailEmpfaengerVorschlag`, `EmpfaengerArt`, `EmailVersandBereitschaft`, `EmailVersandErgebnis`;
Dienst `EmailEntwurfErzeuger` (Vorbelegung aus Vorgang/Mandant/Versicherer); Schnittstelle `EmailVersandRepository`. Keine UseCases.
**Backend:** `Features/EmailVersand/` · `GET /api/EmailVersand/bereitschaft` · `POST /api/EmailVersand/senden` ·
`POST /api/EmailVersand/entwurf` (in Outlook öffnen) · `GET /api/EmailVersand/signaturen`
**Tests:** `test/features/email_versand/`

**Fallstricke**

- `EmailEntwurfErzeuger` ist **die** Stelle für die späteren pflegbaren Mail-Textvorlagen (§4.7, §5.3):
  Betreff und Text kommen dann aus der Vorlage statt aus `betreff`/`textFuer`. Nichts anderswo verdoppeln.
- Die Anrede folgt dem Empfängerkreis: „Sehr geehrter Herr Müller" nur, wenn **ausschließlich** der Mandant
  angeschrieben wird. Der Bezugssatz steht nur bei Anhängen (`mitSchreiben`). Nach `setzeText` wird beides
  nicht mehr nachgezogen (`textSelbstGeschrieben`).
- Der Dialog liest **nichts** aus dem Kontext — er wird aus zwei Tabs und aus einem anderen Dialog heraus
  geöffnet. Kanzleidaten, Mandant (aus `vorgang.mandantId`) und Versicherer holt sich der **Cubit** selbst.
- Die Adressen kommen aus `_antwort` = mitgegebene Antwort **vor** `vorgang.antwort`. Im Postfach ist der
  Treffer noch nicht übernommen (§4.3) — ohne den `antwort`-Parameter stünde dort kein Vorschlag.
- Anhänge gehen als **Pfade** ans Backend, nicht als Inhalt (wie bei der Ablage). `anhangNamen` benennt nur
  **für die Mail** um; die Datei in der Akte behält ihren Namen. Für Outlook legt das Backend dafür eine
  Kopie unter dem gewünschten Namen an, weil COM nach Pfad anhängt.
- Der Versand braucht ein `receiveTimeout` von 120 s in der Datasource; global stehen im `NetworkModule` 3 s.
- Ein Versandfehler lässt den Entwurf **vollständig** stehen (Phase zurück auf `verfassen`).
- Zwei Wege hinaus: Direktversand **oder** Entwurf in Outlook. Der Entwurf braucht **keinen**
  Postfach-Zugang (`kannEntwurfOeffnen` prüft ihn nicht) — er ist die Rückfalltür. Danach bleibt die Phase
  auf `verfassen` und `ergebnis` null: Ob dort gesendet wurde, weiß die App nicht (§4.8). Der Dialog
  schließt sich dabei **nicht**; `entwurfErgebnis` bleibt stehen und der Knopf heißt „Erneut … öffnen".
- Die **Signatur** hängt das Backend an (`KanzleiSignatur`), nur beim Direktversand — beim Outlook-Entwurf
  setzt Outlook seine eigene. Ins Frontend kommt sie über `bereitschaft.signatur` **nur zum Anzeigen**.
- Empfängerzeilen übernehmen die Eingabe auch beim Verlassen des Feldes und bei `,`/`;`. Was offen bleibt,
  meldet `onOffeneEingabe` nach oben; `VersandVoraussetzungen.fehlend` erklärt daraus, warum „Senden" grau ist.
