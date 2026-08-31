# sachgebiete — Sachgebietskatalog der Kanzlei

**Zweck:** Hält den Sachgebietskatalog (§7.1, zwölf Abteilungskürzel mit Sachgebiet) als Stammdaten
bereit — die Quelle der Auswahllisten für Rechtsgebiet (Register-Filter, Vorgang bearbeiten, Vorgang
starten) und für die Abteilung als Haupt-/Nebensachgebiet-Auswahl (Einstellungen, Vorgang starten).
**Anforderung:** `REQUIREMENTS.md` §7.1 (Katalog, Überschneidungen, Normalisierung)
**Einstieg:** `presentation/blocs/sachgebiet_cubit.dart`
**Zustand:** `SachgebietCubit` (`presentation/blocs/sachgebiet_cubit.dart`) — `@lazySingleton`,
Zustände `SachgebietKatalogLaedt`/`Geladen`/`Fehler` (`sachgebiet_katalog_stand.dart`)
**Domain:** `Sachgebiet` (`domain/entities/sachgebiet.dart`, spiegelt `SachgebietDto`) ·
`AbteilungKuerzel` (`domain/services/abteilung_kuerzel.dart`: Überschneidungen `C05/3`,
Normalisierung) · Port `SachgebietRepository`
**Backend:** `Features/Sachgebiete/` · `GET /api/Sachgebiete` (der einzige Endpunkt — nur lesend)
**Tests:** `test/features/sachgebiete/` (DTO-Abbild, Kürzel-Regeln) · aus Sicht des Aufrufers
`test/features/vorgaenge/register_filter_test.dart` (Katalog ∪ Bestand)

**Fallstricke**

- Kein eigener Tab. Benutzt aus `vorgaenge` (Register-Filter, Bearbeiten-Dialog), `vorgang_starten`
  (`auftrag_section.dart`) und `settings` (`kanzlei_settings_form_body.dart`).
- Ein Ladefehler wird **nicht** still geschluckt (anders als beim `VersichererCubit`): Die
  Auswahllisten zeigen über `SachgebietKatalogBuilder` einen Hinweis mit „Erneut versuchen" und
  bleiben aus — eine stillschweigend unvollständige Auswahl ist die Fehlerklasse, die der Katalog
  beseitigt (#70). Nur der Register-Filter filtert weiter über die Bestandswerte, sichtbar gemacht.
- Das Rechtsgebiet am Vorgang bleibt ein **freier String** (`RechtsgebietWert` in `vorgaenge`):
  Altbestand kleingeschrieben (`verkehrsrecht`), Katalog liefert Anzeigenamen (`Verkehrsrecht`) —
  Vergleiche laufen immer über `RechtsgebietWert.gleich`, nie über `==`.
- `@lazySingleton`: `SachgebietKatalogBuilder` holt den Cubit per `getIt`, kein `BlocProvider` —
  ein Provider würde den app-weiten Cubit beim Verlassen der Seite schließen.
