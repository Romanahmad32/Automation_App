using AutomationService.Features.WordAutomation.Domain.Services;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Arbeitsordner je Vorgang: Ordnernamen aus einer Referenz bilden, die
/// Schrägstriche enthält, und nach der Ablage restlos verschwinden.
/// </summary>
public sealed class ArbeitsVerzeichnisTests : IDisposable
{
    private readonly string _wurzel =
        Path.Combine(Path.GetTempPath(), $"ArbeitsVerzeichnisTests_{Guid.NewGuid():N}");

    private ArbeitsVerzeichnis Verzeichnis() =>
        new(_wurzel, NullLogger<ArbeitsVerzeichnis>.Instance);

    [Fact]
    public void Ordnername_ErsetztVerzeichnistrenner()
    {
        // Die Referenz der Kanzlei ist "Nr/Jahr Abteilung_Kennzeichen" — der
        // Schrägstrich darin wechselte sonst das Verzeichnis.
        ArbeitsVerzeichnis.Ordnername("84/26 C03_GG-XY 123")
            .Should().Be("84-26 C03_GG-XY 123");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("..")]
    public void Ordnername_OhneBrauchbarenSchluessel_NutztDenFreienOrdner(string? schluessel)
    {
        ArbeitsVerzeichnis.Ordnername(schluessel).Should().Be(ArbeitsVerzeichnis.OhneVorgang);
    }

    [Fact]
    public void OrdnerFuer_LegtDenOrdnerUnterhalbDerWurzelAn()
    {
        var ordner = Verzeichnis().OrdnerFuer("84/26 C03_GG-XY 123");

        Directory.Exists(ordner).Should().BeTrue();
        Path.GetDirectoryName(ordner).Should().Be(Path.GetFullPath(_wurzel));
    }

    [Fact]
    public void Aufraeumen_LoeschtDenOrdnerMitsamtInhalt()
    {
        var verzeichnis = Verzeichnis();
        var ordner = verzeichnis.OrdnerFuer("84/26 C03_GG-XY 123");
        File.WriteAllText(Path.Combine(ordner, "Schreiben.docx"), "Inhalt");

        verzeichnis.Aufraeumen("84/26 C03_GG-XY 123").Should().BeTrue();
        Directory.Exists(ordner).Should().BeFalse();
    }

    [Fact]
    public void Aufraeumen_OhneVorhandenenOrdner_IstErfolgreich()
    {
        // Nie erzeugt oder schon aufgeräumt: nichts zu tun ist kein Fehler.
        Verzeichnis().Aufraeumen("nie dagewesen").Should().BeTrue();
    }

    [Fact]
    public void AlteOrdnerLoeschen_LaesstFrischeOrdnerStehen()
    {
        var verzeichnis = Verzeichnis();
        var frisch = verzeichnis.OrdnerFuer("84/26 C03_GG-XY 123");
        var verwaist = verzeichnis.OrdnerFuer("11/25 C03_AB-CD 1");
        Directory.SetLastWriteTimeUtc(verwaist, DateTime.UtcNow.AddDays(-15));

        verzeichnis.AlteOrdnerLoeschen();

        Directory.Exists(frisch).Should().BeTrue();
        Directory.Exists(verwaist).Should().BeFalse();
    }

    public void Dispose()
    {
        if (Directory.Exists(_wurzel))
        {
            Directory.Delete(_wurzel, true);
        }
    }
}
