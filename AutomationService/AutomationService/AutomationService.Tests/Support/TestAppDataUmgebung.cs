using System.Runtime.CompilerServices;
using AutomationService.Core.Persistence;

namespace AutomationService.Tests.Support;

/// <summary>
/// Lenkt <see cref="AppDataPaths"/> für die gesamte Testlaufzeit in ein
/// Temp-Verzeichnis um, statt in das echte %APPDATA%\AutomationService.
///
/// Ohne das migriert jeder Testlauf die Produktivdatenbank des Anwalts: Die
/// Integrationstests fahren <c>WebApplicationFactory&lt;Program&gt;</c> gegen
/// denselben <c>PersistenceInjection</c>, der den Verbindungsstring aus
/// <see cref="AppDataPaths.DatabaseFilePath"/> baut, und
/// <c>DatabaseMigrationService</c> legt dabei Sicherungen unter
/// %APPDATA%\AutomationService\Sicherungen an. Ebenso legt
/// <c>VorlagenOrdnerVorgabeTests</c> (ein reiner Unit-Test) über
/// <see cref="AppDataPaths.EnsureVorlagenDirectory"/> echte Ordner an.
///
/// Ein <see cref="ModuleInitializerAttribute"/> statt eine Fixture pro
/// Testklasse: Er läuft einmalig beim Laden dieser Testassembly, bevor
/// irgendein Test oder eine WebApplicationFactory einen Pfad auflöst — anders
/// als ein statisches Feld, das mehrere parallel laufende Testklassen
/// gleichzeitig setzen könnten (xunit führt Testklassen standardmäßig
/// parallel aus), gibt es hier nur einen einzigen, unangefochtenen
/// Zuweisungszeitpunkt.
/// </summary>
public static class TestAppDataUmgebung
{
    [ModuleInitializer]
    public static void Initialisieren()
    {
        var verzeichnis = Directory.CreateDirectory(
            Path.Combine(Path.GetTempPath(), "AutomationService.Tests", Guid.NewGuid().ToString("N")));
        AppDataPaths.WurzelFuerTests = verzeichnis.FullName;

        AppDomain.CurrentDomain.ProcessExit += (_, _) => Aufraeumen(verzeichnis.FullName);
    }

    private static void Aufraeumen(string verzeichnis)
    {
        try
        {
            Directory.Delete(verzeichnis, recursive: true);
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            // Aufräumen ist best effort — der Prozess beendet sich ohnehin.
        }
    }
}
