# email_versand — Fallstricke

Der lange Rest zu `FEATURE.md`. Der Steckbrief hat ein Zeilenbudget, diese Datei nicht: was
hier steht, musste nicht in vierzig Zeilen passen und ist deshalb ausgeschrieben. Die vier,
fünf Punkte, die man **vor** dem ersten Griff in das Feature kennen muss, stehen weiter im
Steckbrief — hier steht, was einen beim zweiten Griff erwischt.

## Vorbelegung und Anrede

- **Der Vorgang ist im Dialog wählbar** (`VorgangAuswahl` → `EmailEntwurfCubit.waehleVorgang`) und
  nicht bloß ein Parameter des Dialogs. Der Grund steht im Postfach: Dort geht der Entwurf auch
  dann auf, wenn sich die Antwort keinem Vorgang zuordnen ließ (§4.3) — vorher war die Vorbelegung
  nur durch Schließen und Neuöffnen zu erreichen, und der Eintrag „Keine Vorlage (Vorbelegung aus
  dem Vorgang)" versprach eine, die es nicht gab.
  Ein Wechsel baut den `EmailEntwurfErzeuger` neu (der Mandant kommt aus dem Register, also ein
  Zugriff — währenddessen ist `wechseltVorgang` und damit `beschaeftigt` wahr) und leitet Betreff
  **und** Text neu ab: Der Wechsel ist eine ausdrückliche Handlung, wie die Vorlagenwahl.
  **Was der Anwalt selbst eingetragen hat, bleibt:** `EmpfaengerAbgleich.nachWechsel` nimmt die
  Adressen heraus, die die App zum *alten* Vorgang **vorbelegt** hatte, und nimmt die des neuen
  herein; getippte bleiben stehen. Andersherum — alle ersetzen — verlöre genau die Adresse, die im
  Postfach zuerst eingetippt und der Vorgang danach zugeordnet wird.
  **Verglichen wird gegen die Vorbelegung, nicht gegen die Vorschlagsliste** (behoben am
  03.09.2026): Beides sah gleich aus, ist es aber nicht. Tippt der Anwalt die Mandantenadresse und
  ordnet den Vorgang danach zu, steht dieselbe Adresse auch in dessen Vorschlägen — über die
  Vorschlagsliste verglichen verschwand sie beim nächsten Wechsel wortlos. Der Cubit führt dazu
  `vorbelegteEmpfaenger` mit (kein Zustandsfeld: auf dem Schirm steht davon nichts, gelesen wird es
  nur beim Wechsel), und `nachWechsel` gibt die neue Vorbelegung gleich mit zurück — ohne die
  Adressen, die der Anwalt schon selbst dastehen hatte.
  **Auch „neutral anreden" endet mit dem Vorgang** (behoben am 03.09.2026), wie der Gruß und die
  Anredeart: Die Entscheidung galt für *diesen* Empfängerkreis. Blieb sie stehen, wurde der nächste
  Mandant namentlich angeredet, obwohl die Mail an die Versicherung ging. Und die zwei Flags
  (`mitleserImAn`, `anredePersoenlichMoeglich`) rechnen über `alleEmpfaenger` — wer in **Kopie**
  steht, liest mit; aus der `an`-Liste allein gerechnet widersprachen sie der Anredezeile im Text.
  Der **Zusatzgruß** folgt dagegen dem neuen Mandanten: Ein Gruß, der für jemand anderen gedacht
  war, darf den Wechsel nicht überleben.
  Die mitgegebene `ZentralrufReplyData` überlebt ihn hingegen (`_antwort` im Cubit) — sie gehört
  zu der Nachricht, die beantwortet wird, nicht zum Vorgang.
- `EmailEntwurfErzeuger` belegt vor, **solange keine Vorlage gewählt ist** (§4.7). Wird eine
  gewählt, ersetzt `MailVorlagenFueller` Betreff und Text — die Vorbelegung bleibt der Rückfall
  und wird nicht abgeschafft: Ohne Vorlage im Bestand ist sie das Einzige, was dasteht.
- **Die Vorlage errät die App nicht.** Standardmäßig gehen Mandant und Versicherung eine
  gemeinsame Mail (§4.7); ein Mandantenanschreiben passt dort nicht hinein, und automatisch
  gesetzt stünde es vor der Gegenseite. `MailVorlagenAuswahl` blendet sich ganz aus, solange der
  Bestand leer ist — ein leeres Auswahlfeld sähe aus wie eine Einstellung, die es nicht gibt.
- **Ab dem ersten eigenen Anschlag im Text laufen die Chips nicht mehr durch die Ableitung —
  aber auch nicht leer.** `textSelbstGeschrieben` sperrt `_leiteAb`; dort greift stattdessen
  `_zieheNach`, und der tauscht über `TextNachtrag` **wörtlich** die Anredezeile und den
  Zusatzgruß, die die App zuletzt selbst eingesetzt hat. Dafür führt der Zustand zwei Merker mit
  (`anredeImText`, `zusatzgrussImText`) — ohne sie wüsste niemand, welche Zeichenfolge im Text
  der App gehört.
  **Die Merker gehören zu jedem abgeleiteten Text** (behoben am 03.09.2026): `starte` setzt sie
  gleich mit — sonst suchte der erste Klick nach der leeren Zeichenkette und tat nichts, wenn der
  Anwalt *zuerst* getippt hatte —, und `_setzeEntwurf` zieht sie nach, wenn es den Text neu
  ableitet: Ein hinzugefügter Empfänger macht aus „Sehr geehrter Herr Müller" „Sehr geehrte Damen
  und Herren", und der Merker zeigte danach auf einen Wortlaut, der nicht mehr im Text stand.
  **Nur diese zwei, und das ist die Grenze:** Eine andere Vorlage schreibt den ganzen Text, eine
  andere Anredeart beugt Wörter mitten im Satz — beides wäre in einem selbst geschriebenen Text
  geraten. Dass sie nicht mehr wirken, sagt `HandarbeitHinweis`, und `erzeugeTextNeu` ist die
  Rückfahrkarte. Vorher blieben alle Chips anfassbar und taten wortlos nichts (§4.7, behoben am
  02.09.2026).
  Der Merker zieht **nur bei Erfolg** mit: Fand sich die alte Fassung nicht, hat der Anwalt sie
  selbst umgeschrieben, und dann gehört die Stelle ihm.
  **`_setzeEntwurf` zieht bewusst nicht nach.** Ein hinzugefügter Empfänger ist eine beiläufige
  Handlung, und in einen selbst geschriebenen Text greift nur ein Klick ein, der genau das sagt.
  Folge: Kommt die Versicherung nachträglich ins Feld „An", bleibt die namentliche Anrede stehen —
  sichtbar gemacht vom Hinweis an der Anredereihe (`mitleserImAn`), und ein Klick auf „neutral
  anreden" tauscht sie dann.
- **Betreff und Text sind abgeleitet, nicht eingefügt.** Solange eine Vorlage gewählt ist und der
  Anwalt nicht selbst getippt hat (`textSelbstGeschrieben`), erzeugt `_abgeleitet` sie bei jeder
  Änderung neu — Empfänger dazu, Gruß gewechselt, Vorlage getauscht. Erst `setzeText` löst die
  Bindung. Wer hier eine einmalige Einfügung daraus macht, bricht genau die Zusage, dass die
  Anrede dem Empfängerkreis folgt.
  **Der Betreff ist die Ausnahme:** Er entsteht nur bei einer *ausdrücklichen* Handlung neu
  (Vorlage oder Gruß gewählt, `betreffAuch: true`). Ein hinzugefügter Empfänger ist keine Ansage,
  die Betreffzeile neu zu schreiben — so war es vor den Vorlagen schon.
- **„Keine Vorlage" ist ein echter Eintrag** mit `null` als Wert, kein Sonderfall daneben. Deshalb
  nimmt `copyWith` die Vorlage als **Funktion** (`gewaehlteVorlage: () => null`), wie `fehler`:
  Mit `?? this.` liesse sie sich nie zurücknehmen.
- Der **Zusatzgruß** wird je Mail gewählt (`setzeZusatzgruss`), vorbelegt aus dem Mandanten. Der
  Wert liegt im Zustand; **wo** er landet, entscheidet allein die Vorlage: Trägt sie
  `{{Zusatzgruß}}`, wird er eingesetzt — der Empfängerkreis spielt keine Rolle mehr (geändert am
  02.09.2026, §4.7). Bis dahin sperrte `nurAnDenMandanten` ihn, sobald eine zweite Adresse im
  Feld „An" stand; damit verlor jedes Mandantenanschreiben mit einer Adresse in Kopie den Gruß,
  obwohl die Vorlagenwahl die Absicht schon ausgedrückt hatte.
  `grussMoeglich` heißt seitdem etwas anderes: **ob die Vorlage überhaupt eine Stelle dafür hat**
  (`MailPlatzhalter.stehtIn`). Es ist ein *abgeleiteter* Wert im Zustand und kein Feld — als Feld
  liefe es hinter jeder Vorlagenwahl her, und genau dabei ändert es sich. `mitleserImAn` daneben
  ist nur der **Hinweis** an der Auswahl und sperrt nichts; ohne bekannte Mandantenadresse bleibt
  es falsch, statt auf Verdacht zu warnen.
- **Anrede und Zusatzgruß sind Platzhalter der Vorlage**, keine Vorspann-Zeilen: So bestimmt
  jede Vorlage selbst, ob und wie angeredet wird. Ein Platzhalter ohne Wert nimmt **seine ganze
  Zeile** mit (`MailVorlagenFueller`), und wo dadurch zwei Leerzeilen aufeinanderträfen, bleibt
  eine — sonst hätte jede Mail ohne gewählten Gruß eine Lücke unter der Anrede.
  Damit die Zeile nicht **wortlos** verschwindet, trägt jeder `PlatzhalterBefund` seine Stelle
  (Betreff = Zeile 0, sonst die Zeilennummer), `zeileEntfaellt` und die **Fehlstelle**
  (`PlatzhalterFehlstelle`): warum leer, und wo die Angabe gepflegt wird. Der Unterschied zwischen
  „Zeile entfällt" und „Zeile bleibt, ohne diesen Wert" hängt an der **ganzen** Zeile: Ein
  einziger gefüllter Platzhalter hält sie am Leben.
  Der wertvollste Fall der Fehlstelle ist **„kein Feld dieses Namens"**: `{{Adresse}}` löst auf
  keine Datenquelle auf und bleibt darum immer leer. Vorher war das von einer wirklich fehlenden
  Angabe nicht zu unterscheiden — und die eine Aufgabe ist „Schreibweise berichtigen", die andere
  „Daten nachpflegen" (§4.7, ergänzt am 02.09.2026).
- **Die Anrede ist wählbar, aber nur ihr Anfang** (`AnredeAuswahl` → `waehleAnrede`, §7.1).
  `Anredebaustein.zeileFuer` setzt daraus die Zeile zusammen: Anfang + „Herr"/„Frau" + Nachname,
  und die Beugung folgt `Mandant.anrede`. Ein Baustein, der die ganze Zeile trüge, stünde für
  genau einen Mandanten.
  **Ohne Bestand gilt der Rückfall** auf `Mandant.briefanrede` — die Umstellung von „fest" auf
  „wählbar" darf keine Mail ohne Anrede hinterlassen; deshalb ist der Seed „Sehr geehrter / Sehr
  geehrte / Sehr geehrte" nicht Zierde, sondern der alte Zustand.
  `anredeNeutral` ist **`bool?`, und null ist der Vorgabewert**: „wie der Empfängerkreis es
  ergibt". Erst true/false ist die Entscheidung des Anwalts, und die schlägt dann den
  Empfängerkreis — „änderbar" heisst änderbar (§4.7). Mit einem `bool` daneben bräuchte es ein
  zweites Feld „hat er selbst gesetzt"; mit `bool?` ist es eines.
- Alle übrigen Platzhalter laufen über `VorgangPrefillMatcher.wertFuerNamen` — **dieselbe** Kette
  wie beim Ausfüllen einer Word-Vorlage. Deshalb gilt dort auch deren Eigenheit: `{{Aktenzeichen}}`
  liefert wie `{{Referenz}}` die **volle** Referenz mit Kennzeichen. Im Ausgangsbestand steht
  darum `{{Referenz}}`, und `FeldDatenquelle.aktenzeichen` wird gar **nicht** zur Auswahl
  angeboten: Sie verspricht die kurze Form und ist über einen Namen nicht erreichbar — ein
  offener Restposten aus #38, namentlich festgehalten in `feld_datenquelle_test.dart`.
- Ohne eigene Entscheidung folgt die Anrede dem Empfängerkreis: namentlich nur, wenn
  **ausschließlich** der Mandant angeschrieben wird; der Bezugssatz nur bei Anhängen
  (`mitSchreiben`). Nach `setzeText` zieht beides nicht mehr nach (`textSelbstGeschrieben`).
  Namentlich angeredet wird ausserdem nur, wenn Geschlecht **und** Nachname hinterlegt sind
  (`anredePersoenlichMoeglich`) — bei `Anrede.keine` wird nicht geraten (§1.3).
- Die Adressen kommen aus `_antwort` = mitgegebene Antwort **vor** `vorgang.antwort`: Im
  Postfach ist der Treffer noch nicht übernommen (§4.3) — ohne den `antwort`-Parameter stünde
  dort kein Vorschlag.

## Beugung: Anredeart ist nicht „neutral anreden"

- **Die zwei Angaben werden verwechselt, und die Verwechslung ist teuer.** `anredeNeutral`
  beantwortet „wird **namentlich** angeredet?" und hängt am Empfängerkreis; `anredeGeschlecht`
  beantwortet „welche **Form** nimmt ein Wort an?" und hängt am Mandanten. Der Regelfall trennt
  sie: Die Mail an die gegnerische Versicherung beginnt mit „Sehr geehrte Damen und Herren" —
  nicht namentlich — und schreibt im Text von „unserer Mandantin". Wer beides zu einem Feld
  zusammenzieht, schickt genau diese Mail falsch hinaus (§4.7).
- **Die geltende Anredeart wird an *einer* Stelle gerechnet:**
  `EmailEntwurfErzeuger.geschlechtFuer` (gewählte **vor** der am Mandanten hinterlegten). Sie
  speist die Anredezeile (`Anredebaustein.zeileFuer`) **und** die Beugung im Vorlagentext
  (`MailVorlagenFueller.geschlecht`). Zwei Rechnungen daneben liefen auseinander — dann redet
  eine Mail „Frau Meier" an und schreibt im Text von „unserem Mandanten".
- Der Zustand führt beides mit: `anredeGeschlecht` (die Wahl, null = keine) und `mandantAnrede`
  (was das Register sagt). Zwei Felder, weil `null` unterscheidbar bleiben muss — nur so kann
  `waehleVorgang` die Wahl **zurücksetzen**, und sie muss zurückgesetzt werden: Eine für diesen
  Mandanten gewählte Beugung darf den Wechsel nicht überleben, genau wie der Zusatzgruß.
- **`waehleGeschlecht` muss `anredePersoenlichMoeglich` mitziehen.** Stand am Register „keine
  Angabe", war eine namentliche Anrede unmöglich und `anredeGehtNeutral` fest wahr; mit der
  gewählten Anredeart ist sie möglich. Ohne das Nachziehen bliebe „Sehr geehrte Damen und Herren"
  stehen, obwohl der Anwalt gerade gesagt hat, wen er anschreibt.
- **Zwei verschiedene Sätze unter der Chipreihe, und die Bedingungen dürfen sich nicht
  überschneiden.** `anredeartWeichtAb` gilt nur, wenn am Register **etwas** steht und die Wahl es
  übergeht — dann heißt die Auskunft „gilt nur für diese Mail". Steht dort **nichts**, wird nichts
  übergangen; dann ist es eine Lücke, und `anredeartNachtragbar` bietet den Klick an. Ohne die
  Einschränkung `mandantAnrede != keine` wäre der erste Satz auch im zweiten Fall wahr, und der
  Anwalt bekäme beides gleichzeitig.
- **Nachgetragen wird nur die Lücke, nie eine Korrektur** (§1.3, §5.1). Eine bereits hinterlegte
  Anredeart aus dem Versanddialog zu überschreiben wäre eine Änderung an Stammdaten im
  Vorbeigehen — dafür gibt es das Register. Der Grund für den Klick ist der andere Fall: Steht dort
  „keine Angabe", wählt der Anwalt sonst bei **jeder** Mail an denselben Mandanten von Hand.
- **Nach dem Nachtrag muss der Erzeuger mitziehen.** `merkeAnredeart` setzt `anredeGeschlecht` auf
  null zurück (es gibt nichts mehr zu übersteuern) — ab da fragt die Ableitung den Mandanten am
  `EmailEntwurfErzeuger`. Stünde dort weiter „keine Angabe", fiele die nächste Ableitung auf die
  neutrale Form zurück, obwohl im Register nun „Frau" steht. Deshalb baut `anredeartNachtragen` den
  Erzeuger mit dem geänderten Mandanten neu; ein Test hält genau das fest.
- **Misslingt das Schreiben, bleibt der Entwurf unberührt** — die Wahl für diese Mail gilt weiter,
  und der Dialog meldet es nur. Ein Registerfehler darf eine fertige Mail nicht anfassen.
- **Die neutrale Form ist meist errechnet, und die Regel dafür ist eng gefasst**
  (`Beugung.neutralAus`): Ist die eine Form der Anfang der anderen, kommt der Unterschied in
  Klammern — „Mandant(in)", „Geschädigte(r)", die Schreibweise des Rechtsdeutschen. Sonst bleiben
  es beide mit Schrägstrich: „der/die", „er/sie", „sein/ihr". Dort wäre eine Klammer falsch, denn
  die Formen teilen keinen Stamm — „d(er/ie)" wäre Unsinn, und „Zeug(e/in)" die Cleverness, die
  danebengreift. Die Regel greift also nur, wo sie nachweislich hinkommt.
  Eine **geschriebene** dritte Form schlägt sie immer, und `neutralGeschrieben` unterscheidet
  beides — nur eine errechnete Form markiert der Editor als solche, denn nur sie kann der Anwalt
  noch verbessern.
- **Der Schrägstrich im Platzhalter ist die Beugung** (`Beugung.aus`), und er ist als Kennzeichen
  sicher: `FeldDatenquelleErkennung.normalisiere` wirft ihn weg, `{{Mandant/Mandantin}}` löste
  also auf `mandantmandantin` auf und traf nie eine Datenquelle — solche Vorlagen verloren ihre
  Zeile stillschweigend. Dieselbe Schreibweise, die jetzt gemeint ist, war vorher ein
  unsichtbarer Fehler.
  `istGemeint` erkennt die **Absicht** (nur am Schrägstrich), `aus` das **Gelingen** (zwei oder
  drei nicht-leere Formen). Die Trennung ist der Punkt: `{{Mandant/}}` fiele sonst auf die
  Namenserkennung zurück und bekäme dort „kein Feld dieses Namens" — eine Auskunft, die am
  Fehler vorbeigeht. So sagt `PlatzhalterFehlstelle` stattdessen „Beugung unvollständig".
  **Der Preis der Schreibweise:** Ein Platzhalter mit Schrägstrich, der *keine* Beugung sein
  sollte, wird trotzdem als eine gelesen — `{{PLZ/Ort}}` setzt jetzt das Wort „PLZ" ein, statt
  wie vorher seine Zeile stillschweigend zu verlieren. Sichtbar bleibt es: Die Übersicht führt
  den Befund mit dem Wert „PLZ" und der Bezeichnung „Beugung nach der Anredeart". Zwei Felder in
  einem Platzhalter waren nie vorgesehen (siehe `_mehrdeutigkeit` in `FeldDatenquelleErkennung`),
  und dieser Weg macht den Irrtum erstmals lesbar.
- **Die Prüfung im Editor darf `FeldDatenquelleErkennung` nicht fragen, ob eine Form ein Feldname
  ist.** Die Erkennung ist eine Heuristik über Teilzeichenketten und löst `Mandant`, `Mandantin`
  und sogar `Geschädigter` **alle** auf „Mandant · Name" auf — ein erster Entwurf von
  `VorlagenPruefung` beanstandete damit ausgerechnet die zwei häufigsten Beugungen und das
  Beispiel aus der eigenen Auswahlliste. Der Fehlgriff, der zu fangen ist, sieht anders aus: Da
  stehen zwei Namen **aus dem Katalog** (`{{MandantOrt/MandantPlz}}`), und die sind wörtlich zu
  erkennen — `_alsKatalogname` vergleicht deshalb gegen `FeldDatenquelle.waehlbare`, exakt und
  über die Normalisierung. Ein Test hält beide Seiten fest.
- **Nur Mail-Textvorlagen beugen.** Die Ersetzung sitzt im Frontend (`MailVorlagenFueller`); die
  Word-Vorlagen füllt das Backend über `FieldData.label` → `replacePatterns`. Ein
  `{{Mandant/Mandantin}}` in einer Word-Vorlage bleibt dort als `{{…}}` im Dokument stehen und
  kommt als Warnung zurück — sichtbar, aber ungebeugt. Wer die Beugung dorthin will, baut sie im
  Dienst nach; ein zweites Verfahren daneben wäre der Zustand, den der gemeinsame
  Platzhalter-Katalog gerade aufräumt.

## Warum die Anrede neutral ist — sechs Lagen, eine Auskunft

- **Der Bericht aus der Kanzlei war zweiteilig, und beide Teile waren richtig:** „Sehr geehrte
  Damen und Herren" stand über Mails, ohne dass jemand diese Anrede angelegt hatte, und ein Klick
  auf die Anredeart bewegte sie nicht. Das Wortlaut-Rätsel löst der Seed (`AnredeBausteineVorgabe`
  legt „Sehr geehrter / Sehr geehrte / Sehr geehrte" an) samt dem festen Anhängsel „Damen und
  Herren" in `Anredebaustein.zeileFuer`; das Beugungs-Rätsel löst sich von selbst — die neutrale
  Zeile hat kein Geschlecht. **Der Mangel war keins von beidem, sondern das Schweigen:** Die App
  kannte den Grund und sagte ihn nicht (behoben am 02.09.2026, `AnredeNeutralGrund`).
- **`EmailEntwurfErzeuger.neutralGrund` rechnet dieselben Bedingungen wie `anredeFuer`, nur nach
  ihrem Grund befragt.** Zwei Rechnungen nebeneinander liefen auseinander, und ein Satz, der den
  falschen Grund nennt, ist schlechter als keiner. Deshalb steht der Grund auch **nicht** im
  Zustand: Er wird beim Bauen geholt, wie `anredeVorschau` — als Feld liefe er jeder
  Empfängeränderung hinterher.
- **Die Reihenfolge der Gründe ist die eigentliche Entscheidung.** Erst der Empfängerkreis (dann
  ist die neutrale Anrede *richtig*), dann die Lücken im Register (dann ist sie eine *Aufgabe*) —
  `istLuecke` trennt beides, und nur die Lücke bekommt ein Zeichen. Umgekehrt bekäme der Anwalt bei
  jeder Mail an die Versicherung einen Hinweis auf den fehlenden Nachnamen seines Mandanten, obwohl
  die Mail stimmt.
- **Innerhalb des Empfängerkreises steht die Ursache vor dem Symptom:** Ohne hinterlegte
  E-Mail-Adresse erkennt `nurAnDenMandanten` den Mandanten **nie** — auch dann nicht, wenn genau
  seine Adresse von Hand im Feld „An" steht. Das ist die teuerste der sechs Lagen, weil sie wie ein
  Mitleser aussieht. Und ein **leeres** Feld „An" ist kein Mitleser, sondern der Anfang: „neben dem
  Mandanten steht noch jemand" wäre am Einstieg aus dem Postfach schlicht falsch.
- **Der Umschalter „neutral anreden" hängt an `anredeNamentlichMachbar`, nicht an
  `anredePersoenlichMoeglich`** (geändert am 02.09.2026). Der Unterschied ist der Empfängerkreis:
  Vorher erschien der Umschalter nur, wenn die namentliche Anrede **schon** galt — also nie bei der
  häufigsten Mail dieser Kanzlei. „Änderbar" heisst änderbar (§4.7); was ohne Nachname und ohne
  Anredeart fehlt, kann er dagegen wirklich nicht herstellen, und dort bleibt er weg.
- **Zwei Sätze unter der Reihe dürfen sich nie überschneiden.** Der Grund für die neutrale Anrede
  und die Warnung „die namentliche Anrede liest er mit" behaupten Gegenteiliges. Maßgeblich ist
  `grund == null && anredeNeutral != true` — nur dann ist die Zeile namentlich. Über
  `anredeGehtNeutral` allein ging es nicht: Erzwingt der Anwalt `neutral: false` an einem Mandanten
  ohne Nachnamen, ist die Zeile trotzdem neutral, und beide Sätze hätten gleichzeitig gestanden.
- **Der Rückfall geht über `Anredebaustein.rueckfall`, nicht über `Mandant.briefanrede`** (behoben
  am 02.09.2026). Der alte Weg las allein das Register: Wer für eine Mail „Frau" wählte, bekam
  „unserer Mandantin" im Text und „Sehr geehrte Damen und Herren" darüber — genau der
  Auseinanderlauf, den `geschlechtFuer` verhindern soll. `Anrede.briefanrede` bleibt trotzdem
  bestehen, weil sie `{{Anrede}}` in den **Word**-Vorlagen füllt; dass beide Wortlaute gleich
  bleiben, hält `anredebaustein_test.dart` fest.
- **Was der Anwalt selbst gewählt hat, ist kein Grund.** `Anrede.keine` entsteht auf **zwei**
  Wegen: Am Mandanten steht nichts (Lücke) — oder er hat „Keine Angabe" angeklickt (Entscheidung).
  `neutralGrund` fragt darum `geschlecht == Anrede.keine` **vor** dem Ergebnis von
  `geschlechtFuer`; sonst hält die App ihm seine eigene Wahl als Mangel vor. Dieselbe Ausnahme gilt
  für `neutral == true`, und dort war sie von Anfang an drin — bei der Anredeart wurde sie
  nachgezogen (02.09.2026), weil sie beim ersten Wurf fehlte.
- **Der Satz über der Anredeart sagt, was *jetzt* gilt** (`AnredeartWirkung`, geändert am
  02.09.2026). Vorher stand dort fest „Beugt die Anrede und die Wortformen im Text" — in der
  häufigsten Mail dieser Kanzlei eine Behauptung ohne Deckung: Die Anrede ist neutral, und die
  mitgelieferte Vorlage trägt kein gebeugtes Wort. Die zwei Wirkungen werden **getrennt**
  festgestellt, weil sie einzeln wegfallen, und die Wörter kommen aus derselben Prüfung wie im
  Editor (`VorlagenPruefung.beugungen`) — die zählt jede Beugung einmal, auch bei mehrfachem
  Vorkommen: Die Zahl beantwortet „wie viele Angaben beugen sich", nicht „wie oft".
- **„Keine Anredezeile" ist nicht „neutrale Anredezeile", und beide brauchen eigene Sätze.**
  Fehlt `{{Anrede}}`, ist „die Anrede ist neutral" falsch — es gibt keine. Deshalb trägt
  `AnredeartWirkung` neben `anredezeile` auch `ohneAnredezeile`; ein einziges Bit hätte an dieser
  Stelle einen Satz erzeugt, der genau die Art Fehlauskunft ist, die dieser Abschnitt abschafft.
  Aus demselben Grund unterdrückt die Anredereihe bei fehlender Stelle den Grund für die neutrale
  Anrede **und** den Umschalter: Wo keine Zeile ist, gibt es nichts zu erklären und nichts zu
  schalten.
- **Der Hinweis auf die fehlende Stelle folgt dem Muster des Zusatzgrußes** — `AnredeChips
  .hinweisFuer` neben `GrussformelChips.hinweisFuer`, gleicher Aufbau, gleicher Wortlaut, gleicher
  Weg zur Behebung. Zwei verschiedene Sätze für denselben Sachverhalt (Platzhalter fehlt in der
  Vorlage) wären für den Anwalt zwei Dinge, die er auseinanderhalten muss.
- **Ein Ladefehler ist kein leerer Bestand.** Beides endete in `bausteine.isEmpty`, die Chipreihe
  verschwand ohne ein Wort, und jede Mail nahm den Rückfall — wer den Dienst gerade aktualisiert
  hatte (die Tabelle ist eine Migration von heute), suchte die Anredewahl in den Einstellungen.
  `AnredeBestandFehler` meldet den Fehler und lässt es erneut versuchen.
- **Ohne Nachnamen trägt die Anredeart die Zeile allein** (geändert am 03.09.2026, auf Bericht aus
  der Kanzlei: „wenn man Herr auswählt, soll auch Herr stehen"). `Anredebaustein.zeileFuer` fiel
  vorher bei leerem Nachnamen immer auf „Damen und Herren" zurück — bei einem Vorgang **ohne
  Mandanten im Register** zeigten damit alle Chips dieselbe Zeile, und die Anredeart darüber
  bewegte nichts. Jetzt gilt: `Anrede.keine` → neutral; nicht persönlich **und ein Nachname
  vorhanden** → neutral (der Name soll der Gegenseite nicht vor die Nase gesetzt werden); sonst
  folgt die Zeile der Anredeart, ohne Namen eben als „Sehr geehrter Herr".
  Der Empfängerkreis entscheidet dort **nicht** mehr mit: Ohne Namen gibt es nichts zu verraten.
  `EmailEntwurfErzeuger.neutralGrund` musste mitziehen — sonst hätte darunter „Neutral, weil kein
  Mandant" gestanden, während die Zeile längst „Sehr geehrter Herr" lautete.
- **Und der leere Bestand ist auch keine leere Anrede** (behoben am 03.09.2026). „Wer alle Anreden
  gelöscht hat, weiß es" war der Gedanke — er stimmte nicht: Gelöscht ist der *Bestand*, nicht die
  Anredezeile. `Anredebaustein.rueckfall` schreibt weiter „Sehr geehrter Herr Müller", während die
  Reihe verschwunden ist. Genau die Lage, aus der die Frage kam, warum über den Mails eine Anrede
  steht, die niemand angelegt hat. `AnredeBestandLeer` sagt jetzt, was gilt und wo man es ändert;
  ein Sprung in die Einstellungen steht bewusst nicht da — der Dialog ist modal, ihn zu verlassen
  hiesse den Entwurf verwerfen.

## Signatur

- **Der Import schreibt nicht selbst** (§4.7, behoben am 02.09.2026). `GET signaturen/vorschau`
  liest die gewählte Outlook-Signatur, ohne etwas zu speichern; der Abschnitt füllt damit das Feld
  und merkt den **Namen** vor (`vorgemerkt`, ein `ValueNotifier` der *Seite* — ihr Speichern-Knopf
  muss die Übernahme auslösen und kennt den Abschnitt nur über das, was ihm mitgegeben wird).
  Erst `speichereWennGeaendert` ruft `signaturen/uebernehmen`, und zwar **vor** dem Schreiben des
  Feldtextes: Die Übernahme schreibt Outlooks Nur-Text-Fassung mit, und was der Anwalt danach von
  Hand geändert hat, muss darüber gewinnen.
  Vorher schrieb schon der Klick auf einen Namen in der Auswahlliste — Text, HTML und Bilder in
  der Datenbank, die bisherigen Bilder unwiederbringlich gelöscht, ohne dass „Speichern" gedrückt
  war.
  **`mailSignaturHtml` gehört dem Dienst** (behoben am 03.09.2026). Es ist das einzige Feld des
  Einstellungssatzes, das nicht über den PUT entsteht — die Übernahme schreibt es. Der Bloc kannte
  nach dem Laden noch den alten Stand und schrieb ihn beim Speichern mitsamt leerem HTML zurück:
  Die eben übernommene Signatur war weg, die Bilder verwaist, und gemeldet wurde „Die Signatur ist
  gespeichert." `KanzleiSettingsBloc._speichere` holt deshalb **vor jedem** Schreiben den frischen
  Stand und übernimmt das Feld daraus; scheitert das Nachladen, wird nicht geschrieben, sondern
  gemeldet. Und `speichereWennGeaendert` prüft nach dem `await` auf `context.mounted` — der
  Aufrufer schickt es ohne `await` los, und der `ValueNotifier` dahinter gehört der Seite.
  **Die Bilder gehen nicht über die Leitung** (bis 25 MB je Bild, `SignaturAblage.MaxBildBytes`) —
  sie liegen erst nach der Übernahme im Dienst. Bis dahin zeigt die Vorschau Schrift und Farben,
  aber kein Logo; `SignaturVorgemerktZeile` sagt das, sonst liest sich das fehlende Logo wie ein
  Fehler. Welche Bilder die Übernahme ablegen wird, entscheidet `SignaturAblage.Brauchbare` für
  **Lesen und Schreiben gemeinsam** — zwei Filter nebeneinander versprächen der Vorschau ein Bild,
  das die Übernahme übergeht.
- **Das Feld zu leeren entfernt die Signatur nicht.** `SaveMailSignaturEvent` schreibt nur
  `MailSignatur`; `MailSignaturHtml` bleibt stehen, und weil `KanzleiSignatur` die HTML-Fassung
  bevorzugt, ging die Signatur samt Logo weiter unter jeder Mail hinaus — in der Vorschau
  ebenfalls sichtbar, was aussah wie ein Anzeigefehler und keiner war. Dafür gibt es
  `SignaturEntfernenButton`: `verwirfSignaturFormat()` **und** ein leerer Feldtext, mit Rückfrage.
  „Formatierung verwerfen" daneben ist etwas anderes und bleibt — es behält den Text (§4.7,
  behoben am 02.09.2026).
- Die **Signatur** hängt das Backend an (`KanzleiSignatur`), nur beim Direktversand — beim
  Outlook-Entwurf setzt Outlook seine eigene. Outlook führt sie **doppelt**: `signatur` ist
  seine Nur-Text-Übersetzung, `signaturHtml` die formatierte Fassung, die beim Empfänger
  ankommt. Die Vorschau rendert **die HTML-Fassung** (`SignaturAnsicht`,
  `flutter_widget_from_html_core`); ihre Bildverweise zeigt `SignaturHtmlAufbereitung` auf
  `signaturen/bild` um.
- **Outlook schreibt jedes Bild zweimal** (VML-Form *und* `<img>`) — beim Abwählen müssen beide
  fallen, ein Zellenhintergrund (`background=`) verliert nur sein Attribut; pixelgleich wird die
  Ansicht nie (Word-Modul).
- Ein Bild, das **nicht** mitgenommen werden kann (>25 MB, leer, unlesbar), verliert seine ganze
  Marke statt einen toten Verweis zu hinterlassen — beim Übernehmen
  (`OutlookSignaturFormat.Uebergangen`, gemeldet in den Einstellungen) und als Netz beim Versand
  (`KanzleiSignatur`, `OertlicheQuellen`).
- Signaturbilder sind je Mail abwählbar (`ohneSignaturBilder`) und **wiegen mit**:
  `state.gesamtBytes` = Anhänge + mitgehende Bilder gegen `bereitschaft.maxAnhangMb`. Das
  Backend rechnet nach (`AnhangPruefung`) — die Oberfläche warnt, sie prüft nicht.

## Anhänge

- Anhänge gehen als **Pfade** ans Backend. `anhangNamen` benennt nur **für die Mail** um; die
  Datei in der Akte behält ihren Namen — für Outlook legt das Backend eine Kopie an, weil COM
  nach Pfad anhängt. Versand, Entwurf und Outlook-Anhänge brauchen `receiveTimeout: 120 s`
  (global 3 s); ein Versandfehler lässt den Entwurf **vollständig** stehen.
  *(Stand hier bis zum 02.09.2026 im Steckbrief — der ist auf 40 Zeilen begrenzt, diese Datei
  nicht.)*

## Outlook-Entwurf

- `OutlookVerbindung` hält die Outlook-Instanz am Leben, der Dialog wärmt sie beim Öffnen vor
  (`waermeEntwurfVor`) — ohne das bezahlt der erste Entwurf den Outlook-Kaltstart, während der
  Anwalt wartet statt tippt.

## Versandprotokoll

- Geschrieben **nach** erfolgreicher Einlieferung, nie davor, und nie den Versand aufhaltend
  (`protokoll`). Sichtbar in der Vorgangsliste (`VorgangVersandZeile`, ein Abruf via
  `LetzteVersaendeCubit`) und im Abschlussdialog, wo nur ein **Direktversand** das Häkchen belegt
  — eine Outlook-Übergabe nicht (§4.8: die App weiß dort nichts).

## Oberfläche

- **„Senden" ist immer anfassbar**, solange ein Postfach-Zugang da ist; geprüft wird beim
  Drücken (`istVersandbereit`), was fehlt steht danach am Feld (`state.markiert`). Daher
  `offenAn`/`offenKopie` im Zustand: eine getippte, nicht übernommene Adresse ginge sonst
  verloren.
- Ein **Klick** auf eine Empfängerkachel holt sie zum Berichtigen zurück ins Feld (übernimmt
  vorher die angefangene Eingabe); das Kreuz löscht.
- Die Vorschau läuft ab 1180 px als Seitenspalte mit (`EmailVersandInhalt.zweispaltig`) und
  scrollt **als Ganzes**, damit die Leiste am Rand sitzt.
- Ein **aus Outlook** gezogener Anhang kommt als *leeres* Ablegen an (Windows reicht ihn als
  virtuelle Datei durch, `desktop_drop` liest nur `CF_HDROP`) — `onNichtsErkannt` fragt dann
  Outlook nach derselben Nachricht.
