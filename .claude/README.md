# Agent-Setup (`.claude/`)

Alles in diesem Ordner ist versioniert, damit jeder Agent dieselbe Umgebung vorfindet — hier, im
Worktree, in der Cloud. Maschinenlokales gehört in `.claude/settings.local.json`; die bleibt
ignoriert.

Diese Datei lag bis Ende August 2026 als Abschnitt in der Wurzel-`CLAUDE.md`. Sie ist hierher
gezogen, weil die Wurzel-Datei in *jeder* Sitzung vollständig geladen wird und ihr Zeilenbudget
aufgebraucht war: Wer selten Gebrauchtes dort stehen lässt, bezahlt es bei jedem Start mit.

## `settings.json` — Rechte und Hooks

Die Routinebefehle der Toolchain (`flutter`, `dart`, `dotnet`, `git`) laufen ohne Rückfrage. Die
auswärts wirkenden bzw. schwer umkehrbaren Git-Befehle (`push`, `reset --hard`, `clean`, `rebase`,
`checkout --`) fragen nach. Die Trennlinie ist nicht „gefährlich/ungefährlich", sondern
**umkehrbar/nicht umkehrbar**: Ein falscher Build kostet Zeit, ein falscher `reset --hard` kostet
Arbeit, die es nicht mehr gibt.

## `hooks/` — greifen von selbst

- `dart-format.ps1` formatiert jede geschriebene `.dart`-Datei. Die CI prüft Dart-Formatierung
  zwar auch (`dart format --set-exit-if-changed`), aber erst nach dem Commit; ohne diesen Hook
  sammelt sich bis dahin Rauschen in den Diffs und verdeckt die Änderung.
- `zweigname.ps1` hält das Anlegen oder Umbenennen eines Zweigs an, dessen Name kein `feature/`-,
  `bugfix/`- oder `dependabot/`-Präfix trägt.

Beide schweigen bei eigener Störung — die ausführliche Begründung steht jeweils im Kopf der Datei.
Ein Wächter, der bei eigenem Fehler die Arbeit anhält, wird abgeschaltet.

**Der Geheimnis-Wächter ist bewusst kein Agenten-Hook**, sondern `.githooks/pre-commit`: Nur ein
Git-Hook greift auch bei einem Commit im Terminal, bei `git commit -am` und bei `git -C`. Er wird
über `core.hooksPath` verdrahtet, das `scripts/check.ps1` beim ersten Lauf setzt. Einzelheiten in
[`docs/RELEASE.md`](../docs/RELEASE.md).

Zwei Eigenschaften eines PreToolUse-Hooks sind beim Ändern zu bedenken, beide gemessen:

- Er kostet **je Werkzeugaufruf** einen PowerShell-Start (rund 400 ms), auch bei `ls`. Der Matcher
  trifft nur das Werkzeug, nicht den Befehl. Ein Shell-Skript wäre etwa viermal billiger, fällt
  aber aus: `bash` auf dem Windows-PATH ist der WSL-Starter (`C:\WINDOWS\system32\bash.exe`), nicht
  das Git-Bash daneben.
- Er sieht nur eine Zeichenkette und kann einen Befehl nicht von Prosa über einen Befehl
  unterscheiden. Wer eine Beispielzeile in eine Datei schreibt, löst ihn mit aus.

Beides zusammen ist der Grund, die Muster eng zu fassen. `zweigname.ps1` hat das zweimal gelernt:
`git branch | grep master` wurde angehalten, weil `\S+` auch die Pipe fing, danach `git branch -a`,
weil der Bindestrich in den Zeichenvorrat gehört (`feature/zwei-namen`), aber nicht an dessen
Anfang. Seither steht das Verhalten in
`Automation_App_Frontend/test/architecture/zweigname_hook_test.dart` — samt der Prüfung, dass die
Präfixliste des Hooks und die des CI-Schritts dieselbe ist.

## `commands/` — auf Zuruf

- `/pruefen` — die komplette Prüfkette, dieselben Schritte wie die CI.
- `/generieren` — build_runner und was danach zu prüfen ist.

## `skills/` — zieht sich selbst

`neuer-endpunkt` ist das Rezept für einen neuen oder geänderten HTTP-Endpunkt über beide Seiten.
`subagent-auftrag` ist der Textbaustein, den ein koordinierender Agent jedem Subagenten mitgibt —
Modellwahl, Umgebungsfallstricke, Regeln, Prüfumfang. `issue-loesen` ist die Ablaufcheckliste, ein
GitHub-Issue von der Auswahl bis zum Pull Request zu lösen.
Der Unterschied zu `commands/`: Ein Skill braucht niemanden, der ihn aufruft — genau das, was ein
Agent mit frischem Kontext nicht weiß.
