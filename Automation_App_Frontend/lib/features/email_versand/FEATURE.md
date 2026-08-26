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
  Betreff und Text kommen dann aus der Vorlage statt aus `betreff`/`textFuer`. Nichts davon anderswo verdoppeln.
- Die Anrede folgt dem Empfängerkreis: „Sehr geehrter Herr Müller" nur, wenn **ausschließlich** der Mandant
  angeschrieben wird — sonst die neutrale Form. Der Bezugssatz („übersende ich anbei …") steht nur bei
  Anhängen (`mitSchreiben`). Nach `setzeText` wird beides nicht mehr nachgezogen (`textSelbstGeschrieben`).
- Der Dialog liest **nichts** aus dem Kontext — er wird aus zwei Tabs (Word, Postfach) und aus einem
  anderen Dialog heraus geöffnet, dessen Kontext am Navigator-Overlay hängt. Kanzleidaten, Mandant
  (aus `vorgang.mandantId`) und Versicherer holt sich der **Cubit** selbst; Aufrufer geben nur den
  Vorgang und die Anhänge mit.
- Die Adressen kommen aus `_antwort` = mitgegebene Antwort **vor** `vorgang.antwort`. Im Postfach
  ist der Treffer noch nicht übernommen (§4.3) — ohne den `antwort`-Parameter stünde dort kein
  einziger Vorschlag, obwohl die Adresse auf dem Schirm ist.
- Anhänge gehen als **Pfade** ans Backend, nicht als Inhalt — Dienst und Oberfläche laufen auf einem
  Rechner (wie bei der Ablage). Das Backend liest sie und lehnt ab, wenn eine fehlt: alles oder nichts.
- Der Versand braucht ein `receiveTimeout` von 120 s in der Datasource; global stehen im `NetworkModule` 3 s.
- Ein Versandfehler lässt den Entwurf **vollständig** stehen (Phase zurück auf `verfassen`): Nach dem
  Schließen des Anhangs in Word genügt ein zweiter Klick auf „Senden".
- Zwei Wege hinaus: Direktversand (`senden`) **oder** Entwurf in Outlook (`entwurfOeffnen`). Der
  Entwurf braucht **keinen** Postfach-Zugang (`kannEntwurfOeffnen` prüft ihn nicht) — er ist die
  Rückfalltür. Danach bleibt die Phase auf `verfassen` und `ergebnis` null: Ob dort gesendet wurde,
  weiß die App nicht und darf es im Abschlussdialog nicht behaupten (§4.8).
- Die **Signatur** hängt das Backend an, nicht das Formular (`KanzleiSignatur`, aus den
  Einstellungen) — und nur beim Direktversand. Beim Outlook-Entwurf setzt Outlook seine eigene;
  beide zusammen stünden doppelt unter der Mail.
