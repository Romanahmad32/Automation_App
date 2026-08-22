# dashboard — Startseite mit Absprüngen

**Zweck:** Was der Anwalt beim Öffnen der App sieht (Tab 0): offene Vorgänge in der Reihenfolge,
in der er sie anfassen sollte, unbearbeitete Postfach-Antworten und die letzten Registerzeilen.
Rein lesend — jede Karte springt in den Tab, der den Bereich vollständig zeigt.
**Anforderung:** `REQUIREMENTS.md` §3
**Einstieg:** `presentation/views/dashboard_view.dart`
**Zustand:** Kein eigener. `DashboardPage` stellt als `AutoRouteWrapper` eine eigene
`MailboxInboxCubit`-Instanz bereit; die Vorgänge kommen aus dem Singleton `VorgangCubit`
(`features/vorgaenge/presentation/blocs/vorgang_cubit.dart`), im `BlocBuilder` per `bloc:` gesetzt.
**Domain:** `DashboardUebersicht` (`domain/services/dashboard_uebersicht.dart`) — reine Auswertung
des Vorgangsbestands: Dringlichkeitsrang der offenen Vorgänge, Ausschnitt der letzten
Registerzeilen. Keine Entities, keine UseCases, kein Repository, keine Datasource.
**Backend:** — (kein eigener Slice; über die fremden Cubits `GET /api/Vorgaenge` sowie
`GET /api/mailbox/status` und `GET /api/mailbox/replies?includeAcknowledged=false`)
**Tests:** `test/features/dashboard/dashboard_uebersicht_test.dart`,
`test/features/dashboard/dashboard_karte_test.dart`

**Fallstricke**

- Der „Aktualisieren"-Knopf ruft `VorgangCubit.ladeErneut()`, das bei nicht leerem Zustand nichts
  emittiert — tatsächlich neu geladen wird nur der Postfach-Teil.
- Absprünge laufen über `AutoTabsRouter.of(context).setActiveIndex(...)` mit Konstanten aus
  `core/router/app_tab_index.dart`. Das setzt den Tab-Baum von `AppShellPage` voraus: außerhalb
  (eigene Route, Widget-Test) wirft es. Nie eine Tab-Zahl hart schreiben.
- Beim Öffnen eines Postfach-Treffers wird erst `MailboxAuswahlSignal.setze(id)` gesetzt, dann der
  Tab gewechselt. Der Postfach-Tab lebt unter `AutoTabsRouter` weiter und wird nicht neu gebaut —
  ohne das Signal käme die Auswahl dort nicht an.
- `MailboxInboxCubit` ist `@injectable`, also je Seite eine eigene Instanz mit eigenem SignalR-Abo.
  Neue Treffer erscheinen dadurch überall live, ein „Erledigt" im Postfach-Tab aber nicht: das
  Quittieren löst keinen Push aus, die Startseite zeigt die Zeile bis zu ihrem nächsten Refresh.
- Eine leere Antwortliste heißt nicht „nichts zu tun": Steht die Überwachung auf „ausgeschaltet",
  sagt das nur der `MailboxStatusBanner` über der Liste — er gehört nicht wegoptimiert.
- `DashboardUebersicht` sortiert Registerzeilen ohne laufende Nummer nach vorn, `RegisterPage`
  dagegen ans Ende. Absicht: Die Karte zeigt das Listenende, dort sollen die Ausreißer nicht stehen.
