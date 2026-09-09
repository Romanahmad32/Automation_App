# mailbox — Postfach-Überwachung und Posteingang

**Zweck:** Alle Nachrichten des eingerichteten Posteingangs seitenweise lesen; daneben erfasste
Zentralruf-Antworten prüfen und übernehmen — und schreiben
(`MailboxVersandLeiste` öffnet den Entwurf aus `email_versand`, §4.7). Der Zugang wird über
`MailboxAccessView` im Reiter „E-Mail" der `settings` gepflegt — dort haengt auch die Signatur des Direktversands
(`MailSignaturSektion`). Auswerten und Zuordnen liegt in `zentralruf_reply`.
**Anforderung:** `REQUIREMENTS.md` §4.3, §4.7, §7.1
**Einstieg:** `presentation/views/mailbox_bereiche.dart` (Posteingang / Zentralruf-Antworten)
**Zustand:** `MailboxInboxCubit` (`presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart`),
`MailboxConfigBloc` (`presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart`),
`PosteingangCubit` (`presentation/blocs/posteingang_cubit.dart`), `MailboxAuswahlSignal` (Sprung vom Dashboard)
**Domain:** Entities `ReceivedReply`, `MailboxStatus`, `MailboxConfig`/`MailboxConfigUpdate`;
`PosteingangEintrag`/`PosteingangSeite`/`PosteingangInhalt`, `PosteingangRepository`, `MailboxRepository`, `MailboxPushNotifier`.
Keine UseCases — Bloc/Cubit rufen das
Repository direkt.
**Backend:** `Features/MailboxMonitor/` · `GET|PUT /api/mailbox/config` ·
`POST /api/mailbox/microsoft/signin` · `POST /api/mailbox/microsoft/signout` ·
`GET /api/mailbox/status` · `GET /api/mailbox/replies` ·
`POST /api/mailbox/replies/{id}/acknowledge` · `GET /api/mailbox/nachrichten` (+ `/{id}`) · Hub `/hubs/mailbox`
**Tests:** `test/features/mailbox/` (Zugang, Posteingang, Layout); Backend `PosteingangTests`

**Fallstricke**

- Der lange Rest steht in [`FALLSTRICKE.md`](FALLSTRICKE.md) daneben: Seitengrenzen, Blätter-Cursor,
  Vorschau und die Besonderheiten der Zentralruf-Auswertung.
- Der Betreff-Filter gilt nur für die Zentralruf-Auswertung, nie für die allgemeine Nachrichtenliste.
- Der allgemeine Posteingang liest direkt vom IMAP-Server und benötigt eine Internetverbindung.
- Je Abruf höchstens 50 Kopfdatensätze; die vorige Seite und der vorige Text werden ersetzt.
- Kennungen sind an Konto, Ordner und UIDVALIDITY gebunden. Keine Mail wird als gelesen markiert.
