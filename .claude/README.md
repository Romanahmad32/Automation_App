# Agent-Setup (`.claude/`)

Alles in diesem Ordner ist versioniert, damit jeder Agent dieselbe Umgebung vorfindet — hier, im
Worktree, in der Cloud. Maschinenlokales gehört in `.claude/settings.local.json`; die bleibt
ignoriert.

Diese Datei lag bis Ende August 2026 als Abschnitt in der Wurzel-`CLAUDE.md`. Sie ist hierher
gezogen, weil die Wurzel-Datei in *jeder* Sitzung vollständig geladen wird und ihr Wortbudget
aufgebraucht war: Wer selten Gebrauchtes dort stehen lässt, bezahlt es bei jedem Start mit.

## `settings.json` — Rechte und Hooks

Die Routinebefehle der Toolchain (`flutter`, `dart`, `dotnet`, `git`) laufen ohne Rückfrage. Die
auswärts wirkenden bzw. schwer umkehrbaren Git-Befehle fragen nach. Die Trennlinie ist nicht
„gefährlich/ungefährlich", sondern **umkehrbar/nicht umkehrbar**: Ein falscher Build kostet Zeit,
ein falscher `reset --hard` kostet Arbeit, die es nicht mehr gibt.

Nachgefragt wird deshalb bei `push`, `reset --hard`, `clean`, `rebase`, `checkout --`,
`checkout .`, `checkout HEAD -- …`, `restore`, `branch -D` und `stash drop`. Die hinteren fünf
standen lange nicht dabei, obwohl sie dasselbe anrichten wie `reset --hard`: Sie überschreiben
oder werfen weg, was nicht committet ist. Ein `reset --hard` sieht gefährlich aus und fragt
deshalb; `git restore .` sieht harmlos aus und vernichtet dieselbe Arbeit — die Liste folgt der
Wirkung, nicht dem Klang des Befehls.

## `hooks/` — greifen von selbst

- `dart-format.ps1` formatiert am Ende einer Sitzung (Ereignis `Stop`) die Dart-Dateien, die
  laut `git status --porcelain` geändert oder neu sind — generierte ausgenommen. Die CI prüft
  Dart-Formatierung zwar auch (`dart format --set-exit-if-changed`), aber erst nach dem Commit;
  ohne diesen Hook sammelt sich bis dahin Rauschen in den Diffs und verdeckt die Änderung.

Er schweigt bei eigener Störung — die ausführliche Begründung steht im Kopf der Datei. Ein
Wächter, der bei eigenem Fehler die Arbeit anhält, wird abgeschaltet.

**Der Geheimnis-Wächter ist bewusst kein Agenten-Hook**, sondern `.githooks/pre-commit`: Nur ein
Git-Hook greift auch bei einem Commit im Terminal, bei `git commit -am` und bei `git -C`. Er wird
über `core.hooksPath` verdrahtet, das `scripts/check.ps1` beim ersten Lauf setzt. Einzelheiten in
[`docs/RELEASE.md`](../docs/RELEASE.md).

### Was ein Hook kostet — gemessen

Ein Hook ist ein `powershell.exe`-Start, und der kostet auf diesem Rechner rund **1,1 s**, bevor
die erste Zeile des Skripts läuft. Ein Shell-Skript wäre etwa viermal billiger, fällt aber aus:
`bash` auf dem Windows-PATH ist der WSL-Starter (`C:\WINDOWS\system32\bash.exe`), nicht das
Git-Bash daneben.

Entscheidend ist deshalb nicht, was ein Hook tut, sondern **wie oft sein Ereignis eintritt**:

- `Stop` tritt einmal je Antwort ein. Dort ist der Preis vertretbar — und der Hook sieht die
  ganze Sitzung statt nur den zuletzt geschriebenen Pfad.
- `PreToolUse` und `PostToolUse` treten bei *jedem* Werkzeugaufruf ein, auch bei `ls`: Der Matcher
  trifft nur das Werkzeug, nicht den Befehl und nicht die Dateiendung. Der Formatierer hing bis
  September 2026 an `Edit|Write` und kostete gemessen 1,3 s je Nicht-Dart-Änderung und 3,7 s je
  Dart-Änderung — bei zwanzig Bearbeitungen rund eine Minute, die niemand sieht und die mit
  jeder weiteren Bearbeitung wächst.

Dazu kommt bei `PreToolUse`: Der Hook sieht nur eine Zeichenkette und kann einen Befehl nicht von
Prosa über einen Befehl unterscheiden. Wer eine Beispielzeile in eine Datei schreibt, löst ihn mit
aus. Beides zusammen ist der Grund, die Muster eng zu fassen.

**Der Zweignamen-Hook ist im September 2026 daran gescheitert und gestrichen worden.** Er lief
1,37 s vor jedem Bash- und PowerShell-Aufruf und musste zweimal nachgebessert werden, weil er bei
Alltagsbefehlen anschlug: `git branch | grep master`, weil `\S+` auch die Pipe fing, danach
`git branch -a`, weil der Bindestrich in den Zeichenvorrat gehört (`feature/zwei-namen`), aber
nicht an dessen Anfang. Gefangen hat er in 200 CI-Läufen keinen einzigen schiefen Zweignamen. Die
Regel selbst steht weiter: Der CI-Schritt „Zweigname" (`.github/workflows/ci.yml`, rund 5 s am
Pull Request) prüft sie, [`docs/RELEASE.md`](../docs/RELEASE.md) beschreibt sie.

## `commands/` — auf Zuruf

- `/pruefen` — die komplette Prüfkette, dieselben Schritte wie die CI.

`/generieren` stand hier bis September 2026 und ist gestrichen: Sein Inhalt — der Befehl, die
beiden versionierten Ergebnisse, „generierte Dateien nie von Hand ändern" — steht fast wörtlich
in `Automation_App_Frontend/CLAUDE.md`, die beim Arbeiten im Frontend ohnehin geladen wird. Zwei
Fassungen desselben Textes laufen früher oder später auseinander.

## `agents/` — bringen ihre Regeln selbst mit

`umsetzer` ist der Subagent für mechanische Umsetzungsarbeit: viele gleichartige Aufrufstellen
umstellen, Doku nachziehen, Befunde beheben. Er läuft auf Sonnet (`model: sonnet` in der
Frontmatter) und trägt die verbindlichen Projektregeln und die Umgebungsfallstricke — gepinntes
SDK, kein Hintergrundprozess, Berichtsformat — in seinem eigenen Prompt.

Vorher standen genau diese Absätze als Textbausteine im Skill `subagent-auftrag` und mussten in
jeden Auftrag hineinkopiert werden; ein vergessener Absatz hat schon Sitzungen gekostet. Als
Agentendefinition gelten sie, ohne dass jemand daran denkt, und der Auftrag beschreibt nur noch
die Sache und den Dateiumfang.

Bewusst **ohne** `tools`-Eintrag: Eine Werkzeugliste in der Frontmatter müsste bei jeder Änderung
der Werkzeugnamen mitgepflegt werden und schneidet im Zweifel etwas weg, das die Aufgabe braucht.
Was der Agent *nicht* tun soll — weiterdelegieren, committen, den Zweig wechseln —, steht
stattdessen in seinem Prompt.

## `skills/` — zieht sich selbst

`neuer-endpunkt` ist das Rezept für einen neuen oder geänderten HTTP-Endpunkt über beide Seiten.
`subagent-auftrag` sagt einem koordinierenden Agenten, wie er einen Auftrag zuschneidet: welche
Agentendefinition bzw. welches Modell, wie die Dateimengen getrennt werden, was er hinterher
selbst verifiziert — die Regeln stehen in `agents/umsetzer.md`. `issue-loesen` ist die
Ablaufcheckliste, ein GitHub-Issue von der Auswahl bis zum Pull Request zu lösen.
Der Unterschied zu `commands/`: Ein Skill braucht niemanden, der ihn aufruft — genau das, was ein
Agent mit frischem Kontext nicht weiß.
