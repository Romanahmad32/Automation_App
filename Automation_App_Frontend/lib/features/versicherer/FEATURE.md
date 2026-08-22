# versicherer — Gelernte Versicherer-Wissensbasis

**Zweck:** Hält die aus Zentralruf-Antworten gelernten Versicherer samt Anschrift und Kontaktdaten
bereit, damit fehlende Angaben einer Antwort ergänzt und bei einer Negativ-Antwort ein bekannter
Versicherer ausgewählt werden kann.
**Anforderung:** `REQUIREMENTS.md` §5.2
**Einstieg:** `presentation/blocs/versicherer_cubit.dart`
**Zustand:** `VersichererCubit` (`presentation/blocs/versicherer_cubit.dart`) — `@lazySingleton`,
Zustand ist schlicht `List<Versicherer>`, lädt sich im Konstruktor selbst
**Domain:** `Versicherer` (`domain/entities/versicherer.dart`, spiegelt das Backend-DTO
`VersichererDto`) · kein UseCase, nur der Port `VersichererRepository`
**Backend:** `Features/Versicherer/` · `GET /api/Versicherer` (der einzige Endpunkt — nur lesend)
**Tests:** `test/features/zentralruf_reply/versicherer_ergaenzung_test.dart`

**Fallstricke**

- Kein eigener Tab und keine eigene Seite. Benutzt wird das Feature aus `zentralruf_reply`:
  `versicherer_ergaenzung.dart` (Lückenfüllung mit Herkunftshinweis je Feld),
  `versicherer_auswahl.dart` (Auswahl bei Negativ-Antworten) — beide in `vorgangsdaten_form.dart`.
- Geschrieben wird **nicht** über das Frontend: das Register füllt das Backend selbst, sobald eine
  Antwort geparst wird (`VersichererWissen.MerkeAusAntwortAsync`, gerufen aus `DbReceivedReplyStore`
  und `ZentralrufController`). Dass POST/PUT fehlen, ist Absicht.
- Weil das Backend erst beim Parsen lernt, ruft `vorgangsdaten_form.dart` nach dem Öffnen
  `ladeErneut()` und berechnet die Ergänzung danach ein zweites Mal — der erste, synchrone Durchlauf
  kennt den soeben gelernten Eintrag noch nicht. Diese Doppelberechnung nicht „aufräumen".
- Ladefehler schluckt der Cubit **still** (leere Liste), anders als der `VorgangCubit` mit seiner
  Fehlermeldung: die Wissensbasis ist Komfort, kein Pflichtbestandteil.
- `@lazySingleton`: `VersichererAuswahl` reicht die Instanz per `bloc: getIt<VersichererCubit>()`
  durch, statt einen `BlocProvider` aufzumachen — ein Provider würde den app-weiten Cubit beim
  Verlassen der Seite schließen.
