using AutomationService.Features.Aktualisierung.Domain.Services;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace AutomationService.Tests.Support;

/// <summary>
/// Ein <see cref="AktualisierungsDienst"/> mit eigenem Ordner im Temp-Verzeichnis,
/// einer steuerbaren Quelle, einem Installer-Start, der nichts startet, und einem
/// Herunterfahren, das nur mitzählt (#196).
/// Jede Testklasse bekommt ihren eigenen Ordner: Der Dienst räumt beim Start
/// fremde Setup-Dateien weg, und parallele Klassen täten das sonst gegenseitig.
/// </summary>
internal sealed class AktualisierungsUmgebung : IDisposable
{
    public const string LaufendeVersion = "1.3.0+abc1234";
    public const string NeueVersion = "1.4.0";

    public AktualisierungsUmgebung(TimeSpan? leerlauf = null)
    {
        Basis = Path.Combine(Path.GetTempPath(), "AutomationService.Tests", $"Aktualisierung_{Guid.NewGuid():N}");
        Ordner = new AktualisierungsOrdner(Basis);
        Optionen = new AktualisierungOptions { DownloadLeerlauf = leerlauf ?? TimeSpan.FromSeconds(30) };
    }

    public string Basis { get; }

    public AktualisierungsOrdner Ordner { get; }

    public AktualisierungOptions Optionen { get; }

    public QuelleAttrappe Quelle { get; } = new();

    public InstallerStarterAttrappe Starter { get; } = new();

    public HerunterfahrenAttrappe Herunterfahren { get; } = new();

    public string SetupPfad => Ordner.SetupPfad(Versionsnummer.Lies(NeueVersion)!);

    public string Teildatei => AktualisierungsOrdner.Teildatei(SetupPfad);

    public Merkdatei Merkdatei => new(Ordner.Merkdatei);

    public AktualisierungsDienst Dienst(string laufendeVersion = LaufendeVersion) =>
        Dienst(Quelle, Starter, laufendeVersion);

    /// <summary>Mit anderer Quelle und anderem Start — etwa den Attrappen des Testmodus.</summary>
    public AktualisierungsDienst Dienst(IAktualisierungsQuelle quelle, IInstallerStarter starter, string laufendeVersion = LaufendeVersion) => new(
        quelle,
        starter,
        Herunterfahren,
        Ordner,
        Options.Create(Optionen),
        NullLogger<AktualisierungsDienst>.Instance,
        laufendeVersion);

    /// <summary>Prüft, lädt und wartet, bis die Setup-Datei geprüft bereitliegt.</summary>
    public static async Task<AktualisierungsStand> LadeBisBereit(IAktualisierungsDienst dienst)
    {
        (await dienst.PruefeAsync(CancellationToken.None)).Zustand.Should().Be(AktualisierungsZustand.Verfuegbar);
        dienst.StarteDownload().Ablehnung.Should().BeNull();
        return await WarteAuf(dienst, AktualisierungsZustand.Bereit);
    }

    /// <summary>Wartet, bis der Hintergrund-Download den Zustand erreicht hat.</summary>
    public static Task<AktualisierungsStand> WarteAuf(IAktualisierungsDienst dienst, AktualisierungsZustand zustand) =>
        WarteBis(dienst, stand => stand.Zustand == zustand, $"Zustand {zustand}");

    /// <summary>
    /// Fragt den Stand ab, bis <paramref name="bedingung"/> gilt — höchstens 30 s. Großzügig, weil
    /// die volle Suite den Thread-Pool zeitweise auslastet; im Normalfall sind es Millisekunden.
    /// </summary>
    public static async Task<AktualisierungsStand> WarteBis(
        IAktualisierungsDienst dienst,
        Func<AktualisierungsStand, bool> bedingung,
        string beschreibung)
    {
        var frist = DateTime.UtcNow.AddSeconds(30);
        while (DateTime.UtcNow < frist)
        {
            var stand = dienst.Stand();
            if (bedingung(stand))
            {
                return stand;
            }

            await Task.Delay(20);
        }

        var zuletzt = dienst.Stand();
        bedingung(zuletzt).Should().BeTrue($"der Download sollte innerhalb von 30 s „{beschreibung}“ erreichen (steht: {zuletzt})");
        return zuletzt;
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
