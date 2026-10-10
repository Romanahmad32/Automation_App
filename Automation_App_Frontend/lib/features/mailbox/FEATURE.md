# mailbox — Postfach-Überwachung und Posteingang

**Zweck:** Alle Nachrichten des eingerichteten Posteingangs seitenweise lesen — mit vorgeschlagenem
Vorgangsbezug (Zeichen oder Schadennummer im Betreff, sonst Absenderadresse) und vier Handgriffen
an einer geöffneten Nachricht: Anhang öffnen, Anhang oder `.eml` in die Akte legen, beim Versand
weiterverwenden, antworten (§4.3). Eine erfasste Zentralruf-Antwort erscheint als markierte Zeile
(Chip, Filterchip „Zentralruf") mit eigenem Detail (`PosteingangZentralrufDetail`) statt eines
eigenen Bereichs. Ein zweiter Bereich „Gesendet" (`GesendetView`) zeigt daneben, in Tagesgruppen
wie der Posteingang (`GesendetListe`, dreizeilige `GesendetZeile` — bewusst nicht das
verdichtende `VersandEintragZeile` aus `email_versand`), das Versandprotokoll über alle Vorgänge
(§4.7).
**Anforderung:** `REQUIREMENTS.md` §4.3, §4.7, §7.1
**Einstieg:** `presentation/views/mailbox_bereiche.dart` (`SegmentedButton` Posteingang | Gesendet);
`MailboxStatusPille` zeigt den Postfachstatus in der Kopfzeile. Der Zugang wird über
`MailboxAccessView` im Reiter „E-Mail" der `settings` gepflegt — dort auch die Signatur des
Direktversands (`MailSignaturSektion`). Auswerten und Zuordnen einer Zentralruf-Antwort liegt in
`zentralruf_reply`.
**Zustand:** `PosteingangCubit` (`presentation/blocs/posteingang_cubit.dart` — hängt Seiten an,
Deckel 500, Filter `PosteingangFilter`, lädt Anhänge/`.eml` ins Zwischenlager), `GesendetCubit`
(`presentation/blocs/gesendet_cubit.dart`, lädt `EmailVersandRepository.ladeAlleVersaende`),
`MailboxInboxCubit` (liefert die offenen Zentralruf-Treffer an
`PosteingangCubit.merkeZentralruf`), `MailboxConfigBloc`, `MailboxAuswahlSignal`.
**Domain:** Entities `PosteingangEintrag`/`PosteingangSeite`/`PosteingangInhalt`,
`PosteingangAnhang`/`PosteingangAnhangAblage`, `Vorgangsbezug`/`BezugSicherheit`, `ReceivedReply`
(`mailSchluessel` als Brücke zum Posteingang), `MailboxStatus`, `MailboxConfig`/
`MailboxConfigUpdate`. Dienst `VorgangsbezugErkenner` — reine Regel ohne Flutter, ändert nie den
Vorgang. Repositories `PosteingangRepository`, `MailboxRepository`, `MailboxPushNotifier`. Keine
UseCases — Bloc/Cubit rufen das Repository direkt.
**Backend:** `Features/MailboxMonitor/` · `GET|PUT /api/mailbox/config` ·
`POST /api/mailbox/microsoft/signin` · `POST /api/mailbox/microsoft/signout` ·
`GET /api/mailbox/status` · `GET /api/mailbox/replies` ·
`POST /api/mailbox/replies/{id}/acknowledge` · `GET /api/mailbox/nachrichten` (+ `/{id}`,
`/{id}/anhaenge/{anhangId}`, `/{id}/eml`) · Hub `/hubs/mailbox`; für „Gesendet" zusätzlich
`Features/EmailVersand/` · `GET /api/EmailVersand/protokoll/alle`
**Tests:** `test/features/mailbox/` (Zugang, Posteingang, Vorgangsbezug, Gesendet, Layout);
Backend `PosteingangTests`

**Fallstricke**

- Der lange Rest steht in [`FALLSTRICKE.md`](FALLSTRICKE.md) daneben: Anhängen statt Seitentausch,
  die Message-Id-Brücke zur erfassten Antwort, das Zwischenlager samt Grenzen, die
  HTML-Entschärfung und die Erkennungsregeln des Vorgangsbezugs.
- Der Betreff-Filter gilt nur für die Zentralruf-Auswertung, nie für die allgemeine Nachrichtenliste.
- Der allgemeine Posteingang liest direkt vom IMAP-Server und benötigt eine Internetverbindung.
- Je Abruf höchstens 50 Kopfdatensätze; Mailtext, HTML und Anhänge lädt die App erst bei Bedarf.
- Kennungen sind an Konto, Ordner und UIDVALIDITY gebunden. Keine Mail wird als gelesen markiert.
- Der Vorgangsbezug ist ein Vorschlag ohne eigenen Speicher — „Nicht zuordnen" gilt nur für die
  laufende Sitzung.
