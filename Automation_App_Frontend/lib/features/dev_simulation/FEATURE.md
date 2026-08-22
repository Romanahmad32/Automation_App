# dev_simulation — Entwickler-Simulation des Vorgangs

**Zweck:** Spielt den gesamten Vorgangs-Lebenszyklus in der App durch, ohne das Zentralruf-Formular
auszufüllen oder auf eine echte Antwortmail zu warten. Kein Feature für den Anwalt — im
Release-Build unsichtbar.
**Anforderung:** —
**Einstieg:** `presentation/widgets/simulation_menu.dart`
**Zustand:** kein eigener; die Widgets greifen auf `VorgangCubit`
(`features/vorgaenge/presentation/blocs/vorgang_cubit.dart`) zu
**Domain:** `ZentralrufAntwortTyp` (`domain/entities/zentralruf_antwort_typ.dart`) · kein UseCase,
nur der Port `SimulationRepository`
**Backend:** `Features/DevSimulation/` · `POST /api/Simulation/zentralruf-antwort`
**Tests:** —

**Fallstricke**

- Über die Sichtbarkeit entscheiden die Widgets selbst: `DemoVorgangButton.build` und
  `SimulationMenu.build` geben ohne `kDebugMode` ein `SizedBox.shrink()` zurück. Die Aufrufstellen in
  `vorgaenge` (`vorgaenge_verwalten_page.dart`, `vorgang_verwaltung_tile.dart`) binden sie
  **unbedingt** ein — die Prüfung dort nicht duplizieren und beim Verschieben nicht verlieren.
- Der Backend-Gegenpart ist zusätzlich per Konfiguration verriegelt: `SimulationOptions.Enabled` ist
  standardmäßig `false` und nur in `appsettings.Development.json` gesetzt; sonst antwortet der
  Controller mit `NotFound()`. Im Release ist der Endpunkt also 404 — genau darauf zielt der
  Fehlerzweig im Menü („Läuft das Backend im Development-Profil?").
- Die simulierte Antwort nimmt den **echten** Weg (Backend-Parser → `DbReceivedReplyStore` →
  SignalR-Push) und muss im Postfach wie eine echte übernommen werden. Sie landet damit in der realen
  Datenbank, und das Backend lernt daraus auch einen realen Versicherer-Eintrag.
- „Abschließen" ruft die echte Backend-Transaktion (`POST /api/Vorgaenge/abschliessen`) und **zählt
  die laufende Auftragsnummer hoch**; die Status-Schritte „erstellt"/„abgelegt" schreiben direkt am
  Vorgang. Keiner dieser Menüpunkte ist ein Trockenlauf.
- `ZentralrufAntwortTyp.wireName` muss zeichengleich zu den Membernamen des Backend-Enums
  `SimulationAntwortTyp` bleiben (String-Serialisierung über die Leitung).
