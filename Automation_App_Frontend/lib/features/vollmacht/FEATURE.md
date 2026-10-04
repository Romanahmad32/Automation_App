# vollmacht — Vollmacht je Vorgang drucken

**Zweck:** Füllt die Vollmacht zum Vorgang aus Mandant und Vorgang vor, lässt die Kopfzeilen
korrigieren, druckt sie über Word und vermerkt den Druck am Vorgang. Nichts wird abgelegt oder
versendet — die Kanzlei archiviert die unterschriebene Vollmacht auf Papier.
**Anforderung:** `REQUIREMENTS.md` §4.11, §8
**Einstieg:** `presentation/widgets/vollmacht_dialog.dart` (`VollmachtDialog.zeige`/`zeigeZuReferenz`)
**Zustand:** `VollmachtCubit` (`@injectable`, je Dialog neu) mit `VollmachtStand` und `VollmachtPhase`;
den Vermerk schreibt er über den app-weiten `VorgangCubit.vermerkeVollmacht`
**Domain:** Entities `VollmachtArt`, `VollmachtKopfdaten`, `VollmachtAuftrag`, `VollmachtErgebnis`,
`VollmachtVorlagenStand`; Dienste `VollmachtArtAbleitung` (Rechtsgebiet → Vorlage über den
Katalog, sonst Abteilung), `VollmachtVorbelegung` (Kopf je Art, `nachziehen`); UseCases
`LadeVollmachtVorlagen`, `LadeVollmachtMandant`, `DruckeVollmacht`, `FuelleVollmachtAus`;
Port `VollmachtRepository` → `VollmachtRepositoryImpl` → `ApiVollmachtDatasource`
**Backend:** `Features/Vollmacht/` · `GET /api/Vollmacht/vorlagen`, `POST /api/Vollmacht/drucken|oeffnen`,
dazu `GET /api/Mandanten/{id}` und `PUT|DELETE /api/Vorgaenge/vollmacht`
**Tests:** `test/features/vollmacht/` (Ableitung aller Katalogzeilen, Vorbelegung, Ablauf im
Cubit, Standzeile und Dialog ohne Mandant)

**Fallstricke**

- Eingestiegen wird von außen: Knopf in `WeiterAktionen` (vorgang_starten), Aktion und
  `VollmachtStandZeile` in `VorgangVerwaltungTile` (vorgaenge), `VollmachtVorlagenSektion` in der
  `OrdnerSektion` (settings), Zähler in `DashboardUebersicht` (dashboard).
- Vermerkt wird nur nach einem Druck, den Word angenommen hat, oder nach „In Word öffnen" auf
  ausdrückliche Bestätigung. Ein gescheiterter Druck (`druckFehlgeschlagen`) öffnet die Datei über
  `DateiOeffner.oeffne` und vermerkt **nichts** — die App weiß nicht, ob Papier herauskam.
- „in Sachen" und „wegen" folgen Art und Name nur, solange sie noch genau der Vorbelegung
  entsprechen (`VollmachtVorbelegung.nachziehen`). Ein von Hand geänderter Text bleibt stehen.
- Die Vorlagen sind feste Dateien im Unterordner `Vollmacht` des Vorlagenordners, ohne Pflege in
  Tab 4. Muster sät der Dienst nur in den App-eigenen Ordner; im Ordner der Kanzlei heißt eine
  fehlende Datei „fehlt", nie „Muster gedruckt".
- Drucken wartet bis 90 s (`ApiVollmachtDatasource`): Word öffnet, druckt und schließt — die
  Vorgabe von drei Sekunden meldete sonst einen Fehler, während das Papier schon kommt.
- Die Bankverbindung wird weder vorbelegt noch gespeichert; `VollmachtKopfdaten` hat kein Feld dafür.
