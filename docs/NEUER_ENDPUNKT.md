# Ein neuer Endpunkt: was wo hingehört

Ein einziger neuer Endpunkt berührt rund ein Dutzend Dateien in zwei Sprachen und
drei Schichten je Seite. Wer sich das Muster aus einem beliebigen Feature abschaut,
trifft mal das aktuelle und mal ein älteres — deshalb steht hier **ein** Weg.
Vorlage ist das `Versicherer`-Feature: es ist das jüngste, das kleinste und macht
nichts, was von der Regel abweicht.

Reihenfolge: **Backend → Vertrag → Frontend**. Andersherum baut man gegen Feldnamen,
die es noch nicht gibt.

## Auf einen Blick

| # | Datei | Zweck |
|---|---|---|
| **Backend** | | |
| 1 | `Features/<Name>/Domain/Services/I<Name>Dienst.cs` | Was der Dienst kann |
| 2 | `Features/<Name>/Domain/Services/<Name>Dienst.cs` | Die Logik |
| 3 | `Features/<Name>/Presentation/Dtos/<Name>Dto.cs` | Was über die Leitung geht |
| 4 | `Features/<Name>/Presentation/Controllers/<Name>Controller.cs` | Route und Statuscodes |
| 5 | `Features/<Name>/Presentation/DependencyInjection/<Name>Injection.cs` | `Add<Name>Services()` |
| 6 | `Program.cs` | ein Aufruf von `Add<Name>Services()` |
| **Vertrag** | | |
| 7 | `docs/openapi.json` | **nicht von Hand** — siehe unten |
| **Frontend** | | |
| 8 | `features/<name>/domain/entities/<sache>.dart` | Domain-Typ (`fromJson`) |
| 9 | `features/<name>/domain/repositories/<sache>_repository.dart` | Schnittstelle |
| 10 | `features/<name>/data/datasources/<sache>_datasource.dart` | `Api…Datasource`, spricht Dio |
| 11 | *(optional)* `features/<name>/data/repositories/<sache>_repository_impl.dart` | Übersetzung in `Either<Failure, …>` |
| 12 | `features/<name>/presentation/blocs/<sache>_cubit.dart` | Zustand |
| 13 | `lib/core/di/injection.config.dart` | **generiert** — `build_runner`, nie von Hand |

Neue Tabelle nötig? Dann kommen `Domain/Persistence/<Name>Entity.cs`,
`…EntityConfiguration.cs`, ein `DbSet` in `Core/Persistence/AutomationDbContext.cs`
und eine Migration dazu (siehe [Persistenz](#persistenz)).

## Backend

Die Slice ist in sich geschlossen: alles unter `Features/<Name>/`, keine Referenz
auf eine andere Slice. `Architecture/SliceIsolationTests.cs` prüft das, und
`Architecture/NamespaceKonventionTests.cs` erzwingt, dass der Namespace dem
Ordnerpfad entspricht.

**Dienst** — die Schnittstelle beschreibt die Fachaufgabe, nicht die Ablage:

```csharp
namespace AutomationService.Features.Versicherer.Domain.Services;

public interface IVersichererWissen
{
    Task<IReadOnlyList<VersichererEntity>> GetAllAsync(CancellationToken cancellationToken);
}
```

**Dto** — ein `sealed record` mit einer statischen `From(...)`-Abbildung. Die Entity
verlässt die Slice nie; das Dto ist die einzige Form, die der Anwender zu sehen
bekommt, und darum auch die Stelle, an der Felder bewusst weggelassen werden.

**Controller** — dünn: Dienst rufen, abbilden, `Ok(...)`. `[ProducesResponseType]`
ist nicht Zierde, sondern das, was im Vertrag landet:

```csharp
[ApiController]
[Route("api/[controller]")]
public class VersichererController(IVersichererWissen wissen) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<VersichererDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<VersichererDto>>> GetAll(CancellationToken ct)
        => Ok((await wissen.GetAllAsync(ct)).Select(VersichererDto.From).ToList());
}
```

**Verdrahtung** — eine Erweiterungsmethode je Slice, ein Aufruf in `Program.cs`:

```csharp
public static IServiceCollection AddVersichererServices(this IServiceCollection services)
{
    services.AddScoped<IVersichererWissen, VersichererWissen>();
    return services;
}
```

Optionen aus `appsettings.json` werden hier gebunden (`services.Configure<…>`), nicht
im Controller.

## Vertrag

`docs/openapi.json` ist die verbindliche Beschreibung beider Seiten und wird
**nicht von Hand gepflegt**. `Integration/OpenApiVertragTests.cs` holt die
Beschreibung aus dem laufenden Dienst und vergleicht sie mit der Datei:

```powershell
cd AutomationService/AutomationService
dotnet test AutomationService.Tests --filter "FullyQualifiedName~OpenApiVertragTests"
```

Weicht sie ab, **schreibt der Test die neue Fassung und schlägt fehl**. Der zweite
Lauf ist grün. Die geänderte `docs/openapi.json` gehört in denselben Commit wie der
Controller — sonst behauptet der Vertrag etwas, das der Dienst nicht mehr tut.

Ein absichtlich geänderter Vertrag ist damit im Diff sichtbar. Das ist der Zweck:
Frontend und Backend sind nur über Zeichenketten verbunden (Pfade, camelCase-Feld-
namen), und ein Tippfehler darin ist zur Laufzeit ein leeres Feld statt eines
Compilerfehlers.

## Frontend

Die Feature-Struktur ist `data/` → `domain/` → `presentation/`;
`test/architecture/clean_architecture_test.dart` prüft die Richtung der
Abhängigkeiten.

**Domain** — Entity mit `fromJson`, dessen Schlüssel exakt den Feldnamen aus dem
Vertrag entsprechen, und die Repository-Schnittstelle. Beide kennen weder Dio noch
Flutter.

**Datasource** — die einzige Stelle, die HTTP spricht. Die Dio-Instanz kommt aus
`lib/core/network/network_module.dart` und trägt die Basisadresse aus
`BackendEndpoint` bereits in sich; im Aufruf steht nur der Pfad, nie Host oder Port:

```dart
@Injectable(as: VersichererRepository)
class ApiVersichererDatasource implements VersichererRepository {
  final Dio _dio;
  ApiVersichererDatasource(this._dio);

  @override
  Future<List<Versicherer>> ladeVersicherer() async {
    final response = await _dio.get('/api/Versicherer');
    return (response.data as List)
        .map((item) => Versicherer.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
```

Zur Benennung — `<sache>_datasource.dart` als Datei, `Api…Datasource` als Klasse —
siehe CLAUDE.md; `test/architecture/benennung_test.dart` erzwingt sie.

**Repository-Schicht: zwei erlaubte Muster.** Welches gilt, entscheidet die Frage,
ob es etwas zu übersetzen gibt:

* *Ohne Übersetzung* (oben): die Datasource setzt das Repository direkt um, ihre
  Rückgabe ist bereits der Domain-Typ. Es gibt keine `…RepositoryImpl`-Datei.
  So arbeiten `versicherer`, `vorgaenge`, `backup`, `dev_simulation`.
* *Mit Übersetzung*: gibt die Schnittstelle `Either<Failure, T>` zurück, kommt
  `data/repositories/<sache>_repository_impl.dart` dazu. Sie fängt die Ausnahme der
  Datasource und macht ein `Left(ServerFailure(...))` daraus — Fehler werden zu
  Werten, damit die Präsentation sie behandeln *muss* statt sie zu vergessen.

Beides ist zulässig. Was nicht zulässig ist: dieselbe Rolle unter zwei Namen.

**DI** — `@Injectable(as: <Schnittstelle>)` an die konkrete Klasse, dann

```powershell
cd Automation_App_Frontend
dart run build_runner build --delete-conflicting-outputs
```

`injection.config.dart` ist generiert; Änderungen darin von Hand werden beim
nächsten Lauf überschrieben. Nach dem Lauf `git status` prüfen und `pubspec.lock`
zurücksetzen, falls er sie umgeschrieben hat — dazu unten mehr.

## Persistenz

Nur nötig, wenn eine neue Tabelle dazukommt.

1. `Features/<Name>/Domain/Persistence/<Name>Entity.cs` und
   `<Name>EntityConfiguration.cs` (Schlüssel, Indizes, Feldlängen).
2. `DbSet<…>` in `Core/Persistence/AutomationDbContext.cs` ergänzen.
3. Migration erzeugen — der Ausgabepfad ist nicht der Standard:

```powershell
cd AutomationService/AutomationService
dotnet ef migrations add <Name> -o Core/Persistence/Migrations
```

`AutomationDbContextFactory` liefert den Kontext dafür ohne laufende Anwendung; es
wird keine Verbindung geöffnet, nur das Modell gelesen. Angewendet wird die
Migration beim Start durch `DatabaseMigrationService` — der Anwender bekommt davon
nichts mit außer der Sicherung, die vorher automatisch angelegt wird
(siehe [RELEASE.md](RELEASE.md)).

## Zum Schluss

```powershell
./scripts/check.ps1
```

Fährt dieselben Schritte wie die CI. Erst wenn der grün ist, ist der Endpunkt
fertig. Die Prüfungen, die typischerweise bei genau dieser Arbeit anschlagen:

| Rot | Was fehlt |
|---|---|
| `OpenApiVertragTests` | `docs/openapi.json` nicht mitgeführt |
| `http_vertrag_test.dart` | Dart benutzt einen Pfad oder ein Feld, das der Vertrag nicht kennt |
| `benennung_test.dart` | Datasource oder Repository-Umsetzung falsch benannt |
| `file_length_test.dart` | Datei über 300 Zeilen — aufteilen, nicht das Limit heben |
| `private_typen_test.dart` | privates `_Widget` statt eigener Datei |
| `SliceIsolationTests` | Backend-Slice greift in eine andere Slice |
| `git diff --exit-code` (CI) | `build_runner` nicht gelaufen oder Ergebnis nicht committet |

Schlägt eine dieser Prüfungen fehl, ist die Antwort nie, die Regel zu lockern.

> **`pubspec.lock`**: Ein lokales `pub get`/`build_runner` schreibt die Datei um und
> stuft dabei ab (analyzer 10.2.0 → 10.0.1). Das ist keine gewollte Änderung —
> `git checkout -- Automation_App_Frontend/pubspec.lock`, solange die Abhängigkeiten
> nicht bewusst geändert werden.
