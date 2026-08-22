# mailbox — Postfach-Überwachung und Posteingang

**Zweck:** Verbindungsstand der Postfach-Überwachung und die vom Backend selbsttätig erfassten
Zentralruf-Antworten; von hier wird ein Treffer geprüft und übernommen. Der Zugang (Gmail-App-Passwort
oder Microsoft-Anmeldung) wird über `MailboxAccessView` in `settings` gepflegt. Nicht hier: Auswerten
der Mail und Zuordnung zum Vorgang — das liegt in `zentralruf_reply`.
**Anforderung:** `REQUIREMENTS.md` §4.3, §7.1
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
- `MailboxHub.ensureConnected()` schluckt einen fehlgeschlagenen Verbindungsaufbau still
  (`catch (_)`) — die Oberfläche meldet nichts, es bleibt nur „Aktualisieren". Und
  `withAutomaticReconnect()` löst nach dem Wiederverbinden kein Nachladen aus: während der
  Trennung eingegangene Treffer erscheinen erst beim nächsten Signal oder manuellen Aktualisieren.
- Geladen wird ausschließlich mit `includeAcknowledged: false`. Nach dem Übernehmen ruft
  `MailboxInboxView` `acknowledge` auf, und der Treffer ist aus der App verschwunden (er bleibt
  nur in der Datenbank). Der Parameter existiert, wird aber nirgends mit `true` benutzt.
- `acknowledge` sendet kein SignalR-Signal, und `MailboxInboxCubit` ist `@injectable` (Factory):
  Dashboard und Postfach halten je eine eigene Instanz mit eigenem Abo. Quittiert man im Postfach,
  zeigt die Dashboard-Kachel den Treffer bis zu deren nächstem `refresh()`.
- `ReceivedReply.zuordnungVermutet` kommt zwar vom Backend, wird in der Oberfläche aber nirgends
  gelesen: `MailboxVorgangZuordnung` rechnet die Vermutung lokal über
  `findeWahrscheinlichenVorgang` neu aus. Zwei Quellen für dieselbe Aussage.
- Der Microsoft-Anmeldeaufruf braucht `receiveTimeout: 6 Minuten` — das Backend wartet, bis der
  Nutzer sich im Browser angemeldet hat (Zeitfenster 5 Minuten).
