# mailbox — Postfach-Überwachung und Posteingang

**Zweck:** Verbindungsstand der Postfach-Überwachung und die vom Backend selbsttätig erfassten
Zentralruf-Antworten; von hier wird ein Treffer geprüft und übernommen — und geschrieben
(`MailboxVersandLeiste` öffnet den Entwurf aus `email_versand`, §4.7). Der Zugang wird über
`MailboxAccessView` im Reiter „E-Mail" der `settings` gepflegt — dort haengt auch die Signatur des Direktversands
(`MailSignaturSektion`). Auswerten und Zuordnen liegt in `zentralruf_reply`.
**Anforderung:** `REQUIREMENTS.md` §4.3, §4.7, §7.1
**Einstieg:** `presentation/views/mailbox_inbox_view.dart`
**Zustand:** `MailboxInboxCubit` (`presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart`),
`MailboxConfigBloc` (`presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart`),
`MailboxAuswahlSignal` (`presentation/blocs/mailbox_auswahl_signal.dart`, Sprung vom Dashboard)
**Domain:** Entities `ReceivedReply`, `MailboxStatus`, `MailboxConfig`/`MailboxConfigUpdate`;
Schnittstellen `MailboxRepository`, `MailboxPushNotifier`. Keine UseCases — Bloc/Cubit rufen das
Repository direkt.
**Backend:** `Features/MailboxMonitor/` · `GET|PUT /api/mailbox/config` ·
`POST /api/mailbox/microsoft/signin` · `POST /api/mailbox/microsoft/signout` ·
`GET /api/mailbox/status` · `GET /api/mailbox/replies` ·
`POST /api/mailbox/replies/{id}/acknowledge` · SignalR-Hub `/hubs/mailbox`
**Tests:** —

**Fallstricke**

- Der Hub überträgt keine Nutzdaten: `replyReceived`/`statusChanged` lösen nur
  `MailboxInboxCubit.refresh()` aus, der Stand kommt danach per REST. Neue Angaben gehören ins
  `ReceivedReplyDto`, nicht ins Signal.
- `MailboxHub.ensureConnected()` schluckt einen fehlgeschlagenen Verbindungsaufbau still (`catch (_)`) — die Oberfläche meldet
  nichts. `withAutomaticReconnect()` lädt nichts nach: Treffer aus der Trennung erscheinen erst beim nächsten Signal.
- Geladen wird ausschließlich mit `includeAcknowledged: false`. Nach dem Übernehmen ruft
  `MailboxInboxView` `acknowledge` auf, und der Treffer ist aus der App verschwunden (bleibt in der
  Datenbank). Der Parameter existiert, wird aber nirgends mit `true` benutzt.
- `acknowledge` sendet kein SignalR-Signal, und `MailboxInboxCubit` ist `@injectable` (Factory):
  Dashboard und Postfach halten je eine eigene Instanz mit eigenem Abo. Quittiert man im Postfach,
  zeigt die Dashboard-Kachel den Treffer bis zu deren nächstem `refresh()`.
- `ReceivedReply.zuordnungVermutet` kommt vom Backend, wird aber nirgends gelesen — `MailboxVorgangZuordnung`
  rechnet sie lokal über `findeWahrscheinlichenVorgang` neu aus.
- Der Microsoft-Anmeldeaufruf braucht `receiveTimeout: 6 Minuten` — das Backend wartet, bis der
  Nutzer sich im Browser angemeldet hat (Zeitfenster 5 Minuten).
- `MailboxVersandLeiste` gibt Vorgang **und** `reply.data` mit: Der Treffer ist hier noch nicht
  übernommen, die Versichereradresse steht nur in der Antwort, nicht am Vorgang.
