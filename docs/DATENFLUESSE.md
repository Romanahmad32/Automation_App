# Datenflüsse — was durch mehrere Features läuft

Die Steckbriefe (`FEATURE.md`) enden am Feature-Rand, die Fachlogik nicht. Vier Ketten laufen
quer durch den Baum, und in keiner steht an der Nahtstelle, dass es eine gibt. Wer eine davon
ändert, ohne sie zu kennen, ändert sie an einer Stelle und lässt die anderen stehen.

Diese Datei ist **kein** Ersatz für die Steckbriefe: Sie sagt nur, welche Features zusammenhängen
und wo die Naht liegt. Was ein einzelnes Feature tut, steht weiter in seinem `FEATURE.md`.

## 1. Vom Platzhalter zum ausgefüllten Feld

Der Weg, den ein `{{Platzhalter}}` aus der Word-Vorlage bis zum fertigen Wert nimmt.

```
form_template_setup ──▶ vorgaenge ──▶ mandanten / zentralruf_reply ──▶ word_automation
```

- **Einrichten:** `FeldDatenquelleErkennung` (`form_template_setup/domain/services/`) löst den
  Platzhalternamen zu einer `FeldDatenquelle` auf und schlägt sie im Editor vor. Der Anwalt sieht
  und ändert den Vorschlag; gewählt wird er auf `FieldData.datenquelle`.
- **Ausfüllen:** `VorgangPrefillMatcher` (`vorgaenge/domain/services/`) löst dieselbe
  `FeldDatenquelle` zum Wert auf — und greift auf die Erkennung zurück, wo an einem Bestandsfeld
  nie eine Quelle gesetzt wurde.
- **Quellen:** `Vorgang` (vorgaenge), `Mandant` (mandanten, zusammengesetzt in
  `mandant_anschrift.dart`) und die übernommene `ZentralrufReplyData` (zentralruf_reply).

**Die Naht:** Die `FeldDatenquelle` ist die einzige Verbindung zwischen Einrichten und Ausfüllen.
Ein neuer Wert dort braucht **beide** Seiten — ohne den Zweig im Matcher steht die Quelle im
Dropdown und liefert zur Laufzeit nichts. Einzelheiten in der `FALLSTRICKE.md` von
`form_template_setup`.

## 2. Von der Antwortmail zum Vorgang

```
Postfach ──▶ ZentralrufReplyParser ──▶ mailbox ──▶ vorgaenge ──▶ versicherer
```

- **Backend:** Der Monitor hängt per IMAP IDLE am Postfach, schickt den Treffer durch
  `ZentralrufReplyParser`, legt ihn im `DbReceivedReplyStore` ab und meldet ihn über den
  SignalR-Hub `MailboxHub`. `VersichererWissen` lernt dabei den Versicherer mit.
- **Frontend:** `mailbox_inbox_view.dart` ruft `VorgangCubit.uebernehmeAntwort` — die Übernahme
  legt einen Vorgang an oder ergänzt einen vorhandenen.
- **Ergänzung:** `versicherer_ergaenzung.dart` (in `zentralruf_reply`) füllt aus dem Register, was
  die Antwort offengelassen hat, je Feld mit Herkunftshinweis.

**Die Naht:** Derselbe Parser bedient zwei Eingänge — das Postfach und das Einfügen von Hand
(`POST api/Zentralruf/antwort/parse`). Wer am Parsen etwas ändert, ändert beide Wege. Und weil das
Backend den Versicherer erst **beim Parsen** lernt, lädt die Oberfläche danach ein zweites Mal
(`ladeErneut`); diese Doppelberechnung ist Absicht.

## 3. Vorgang abschließen

```
word_automation ──▶ vorgaenge ──▶ settings
```

`wizard_step_save.dart` schließt den Vorgang ab; im Backend erledigt `VorgangAbschlussService`
Status, Abschlusszeitpunkt und das Hochzählen der laufenden Auftragsnummer in **einer**
Transaktion, idempotent (§4.8, §7.1).

**Die Naht:** Die Auftragsnummer gehört fachlich zu `settings`, wird aber hier weitergezählt. Sie
von außen zu setzen (`POST api/Settings/auftragsnummer/erhoehe`) und den Abschluss zu trennen,
zerlegt genau die Transaktion, die dieser Dienst zusammenhält.

## 4. Kanzleidaten

```
settings ──▶ vorgang_starten ──▶ zentralruf_request
        └──▶ word_automation (Briefkopf)   └──▶ email_versand (Signatur)
```

`KanzleiSettings` ist der Einzelsatz mit Anschrift, Auftragsnummer und Mail-Signatur. Drei
Verbraucher: `vorgang_starten_bloc.dart` baut daraus den **Anfrager** für das
Zentralruf-Formular, `word_automation` füllt Briefkopf-Platzhalter, `email_versand` hängt die
Signatur an.

**Die Naht:** Der Anfrager wird **immer** vom Frontend mitgeschickt
(`ZentralrufAutomationService.ResolveAnfrager` nimmt ihn bevorzugt). Der Rückfall aus
`appsettings.json` ist deshalb toter Boden — dort standen bis zuletzt leere Felder für Name,
Anschrift und Telefon des Anwalts, ohne je zu wirken. Sie sind entfernt; wer sie wieder einträgt,
schreibt personenbezogene Daten in ein öffentliches Repository, ohne etwas zu bewirken.

## Wo eine Kette anfängt zu lügen

Alle vier haben dieselbe Bruchstelle: **eine Seite geändert, die andere nicht.** Kein Test fängt
das von allein — die Architektur-Tests prüfen Schichten und Verträge, nicht Fachwege. Was hilft,
ist die Naht mitzulesen, bevor man eine Seite anfasst.

Kommt eine Kette hinzu oder fällt eine weg, gehört sie hier hinein — sonst steht in dieser Datei
bald dasselbe wie in einem Steckbrief, der auf Tests zeigt, die es nicht mehr gibt.
