# vollmacht — Vollmacht je Vorgang drucken

**Zweck:** Füllt die Vollmacht zum Vorgang aus Mandant und Vorgang vor, lässt die Kopfzeilen
korrigieren, zeigt die Seite vorab und den Drucker, druckt über Word, vermerkt den Druck am Vorgang
und lässt das Ergebnis zum Nachsteuern stehen (#164). Nichts wird abgelegt oder versendet — die
Kanzlei archiviert die unterschriebene Vollmacht auf Papier.
**Anforderung:** `REQUIREMENTS.md` §4.11, §8
**Einstieg:** `presentation/widgets/vollmacht_dialog.dart` (`VollmachtDialog.zeige`/`zeigeZuReferenz`)
**Zustand:** `VollmachtCubit` (`@injectable`, je Dialog neu) mit `VollmachtStand`, `VollmachtPhase`,
`VollmachtWordFassung` (in Word geöffnet) und `VollmachtAbschluss` (das Ergebnis nach dem Druck);
den Vermerk schreibt er über den app-weiten `VorgangCubit.vermerkeVollmacht`
**Domain:** Entities `VollmachtArt`, `VollmachtKopfdaten`, `VollmachtFeld`, `VollmachtAuftrag`,
`VollmachtErgebnis`, `VollmachtVorlagenStand`, `VollmachtDrucker`, `VollmachtVorschau`; Dienste
`VollmachtArtAbleitung` (Rechtsgebiet → Vorlage über den Katalog, sonst Abteilung),
`VollmachtVorbelegung` (Kopf je Art, `nachziehen`), `VollmachtFeldauswahl` (Felder nach den
Platzhaltern der Vorlage, was frei bleibt), `VollmachtSchreiblinie`; UseCases
`LadeVollmachtVorlagen`, `LadeVollmachtMandant`, `LadeVollmachtDrucker`,
`ErstelleVollmachtVorschau`, `DruckeVollmacht`, `FuelleVollmachtAus`, `RaeumeVollmachtAuf`;
Port `VollmachtRepository` → `VollmachtRepositoryImpl` → `ApiVollmachtDatasource`
**Backend:** `Features/Vollmacht/` · `GET /api/Vollmacht/vorlagen|drucker`,
`POST /api/Vollmacht/drucken|oeffnen|vorschau|aufraeumen`, dazu `GET /api/Mandanten/{id}` und
`PUT|DELETE /api/Vorgaenge/vollmacht`
**Tests:** `test/features/vollmacht/` (Ableitung aller Katalogzeilen, Vorbelegung, Ablauf im
Cubit, Vorschau je Art, Word-Leiste und Aufräumen, Drucker und Ergebnis, Standzeile, Feldauswahl
und Schreiblinie, Dialog ohne Mandant und bei „Am größten")

**Fallstricke** — Vorschau, „In Word öffnen“, Aufräumen, Schreiblinie, Vorlagenordner,
Druckdauer und Dialogbreite ausführlich in `FALLSTRICKE.md`.

- Eingestiegen wird von außen: Knopf in `WeiterAktionen` (vorgang_starten), Aktion und
  `VollmachtStandZeile` in `VorgangVerwaltungTile` (vorgaenge), `VollmachtVorlagenSektion` in der
  `OrdnerSektion` (settings), Zähler in `DashboardUebersicht` (dashboard).
- Vermerkt wird nur nach einem Druck, den Word angenommen hat, oder nach „In Word öffnen" auf
  ausdrückliche Bestätigung. Ein gescheiterter Druck (`druckFehlgeschlagen`) öffnet die Datei über
  `DateiOeffner.oeffne` und vermerkt **nichts** — die App weiß nicht, ob Papier herauskam.
- „in Sachen" und „wegen" folgen Art und Name nur, solange sie noch genau der Vorbelegung
  entsprechen (`VollmachtVorbelegung.nachziehen`). Ein von Hand geänderter Text bleibt stehen.
- Leer heißt Schreiblinie (#171): Leere Mandantenfelder gehen leer hinaus, die Linie setzt der
  Dienst; ein fehlendes Datum oder ein fehlender Name steht als Linie schon in der Vorbelegung.
  Gezeigt werden nur Felder, deren Platzhalter in der Vorlage steht (`VollmachtFeldauswahl`).
- Die Bankverbindung wird weder vorbelegt noch gespeichert; `VollmachtKopfdaten` hat kein Feld dafür.
- Drucker und erste Vorschau stößt der Dialog an (`druckerFaellig`, `vorschauFaellig`, nach dem
  Bild), nicht `starte`: Das Öffnen wartet nicht auf einen Drucker, der nicht antwortet, und jede
  weitere Ausgabe löschte die Meldung des Öffnens (etwa „Mandant nicht ladbar"). Danach folgt die
  Vorschau der Art, nicht jeder Eingabe.
