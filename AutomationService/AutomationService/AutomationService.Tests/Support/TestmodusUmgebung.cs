using System.Globalization;
using System.Text;
using System.Text.Json;
using AutomationService.Features.DevSimulation.Domain.Services;
using FluentAssertions;

namespace AutomationService.Tests.Support;

/// <summary>
/// Ein eigener Testmodus-Ordner je Testklasse (#168) samt Protokoll — und das
/// Lesen von <c>protokoll.jsonl</c> so, wie die E2E-Skripte und die Suite es
/// tun: Jede Zeile wird dabei gegen den Vertrag geprüft (UTF-8 ohne BOM, LF,
/// genau die vier Felder in dieser Reihenfolge, Zeitstempel mit Versatz).
///
/// Nicht über <c>AppDataPaths</c>: Dessen Ordner teilt sich der ganze
/// Testlauf, und parallele Klassen läsen sonst die Zeilen der anderen mit.
/// </summary>
public sealed class TestmodusUmgebung : IDisposable
{
    private static readonly JsonSerializerOptions JsonOptionen = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    public TestmodusUmgebung(TimeProvider? zeit = null)
    {
        Basis = Path.Combine(Path.GetTempPath(), "AutomationService.Tests", $"Testmodus_{Guid.NewGuid():N}");
        Directory.CreateDirectory(Basis);
        Ordner = new TestmodusOrdner(Path.Combine(Basis, "Testmodus"), zeit);
        Protokoll = new TestmodusProtokoll(Ordner);
    }

    /// <summary>Der Ordner über <c>Testmodus</c> — Platz für Eingabedateien wie Anhänge.</summary>
    public string Basis { get; }

    public TestmodusOrdner Ordner { get; }

    public TestmodusProtokoll Protokoll { get; }

    /// <summary>Legt eine Eingabedatei neben dem Testmodus-Ordner an.</summary>
    public string Eingabedatei(string name, string inhalt)
    {
        var pfad = Path.Combine(Basis, name);
        File.WriteAllText(pfad, inhalt);
        return pfad;
    }

    /// <summary>Der volle Pfad zu einer <c>datei</c>-Angabe des Protokolls.</summary>
    public string VollerPfad(string relativ) =>
        Path.Combine(Ordner.Wurzel, relativ.Replace('/', Path.DirectorySeparatorChar));

    /// <summary>Alle Zeilen des Protokolls, jede gegen den Vertrag geprüft.</summary>
    public IReadOnlyList<TestmodusProtokollZeile> Zeilen()
    {
        if (!File.Exists(Protokoll.Pfad))
        {
            return [];
        }

        var bytes = File.ReadAllBytes(Protokoll.Pfad);
        var mitBom = bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
        mitBom.Should().BeFalse("das Protokoll ist UTF-8 ohne BOM — ein BOM landete im ersten JSON-Objekt");

        var text = Encoding.UTF8.GetString(bytes);
        text.Should().NotContain("\r", "Zeilen enden mit LF").And.EndWith("\n");

        return [.. text.Split('\n', StringSplitOptions.RemoveEmptyEntries).Select(Lies)];
    }

    private static TestmodusProtokollZeile Lies(string json)
    {
        using (var dokument = JsonDocument.Parse(json))
        {
            dokument.RootElement.EnumerateObject().Select(feld => feld.Name)
                .Should().Equal(["zeit", "aktion", "referenz", "datei"], "genau diese vier Felder sind der Vertrag");
            var zeit = dokument.RootElement.GetProperty("zeit").GetString();
            DateTimeOffset.TryParseExact(zeit, "o", CultureInfo.InvariantCulture, DateTimeStyles.None, out _)
                .Should().BeTrue($"„{zeit}“ ist ein Zeitpunkt im Roundtrip-Format mit Versatz");
        }

        return JsonSerializer.Deserialize<TestmodusProtokollZeile>(json, JsonOptionen)!;
    }

    public void Dispose()
    {
        try
        {
            Directory.Delete(Basis, recursive: true);
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            // Aufräumen ist best effort — der Ordner liegt im Temp-Verzeichnis.
        }
    }
}
