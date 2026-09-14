using System.Text;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die reinen Bausteine des Zwischenlagers (§4.3), unabhängig vom IMAP-Abruf:
/// Namen entschärfen, atomar schreiben, einen Anhang über seinen Schlüssel
/// statt über seine Größe wiedererkennen.
/// </summary>
public sealed class PosteingangZwischenlagerTests
{
    [Theory]
    [InlineData("..")]
    [InlineData(".")]
    [InlineData("   ")]
    [InlineData("")]
    public void Entschaerft_ErsetztReineVerzeichnisverweiseDurchAnhang(string wert)
    {
        // "." und ".." sind erlaubte Dateinamenzeichen und ueberleben das
        // Ersetzen der verbotenen Zeichen unveraendert -- als Dateiname zeigen
        // sie aber auf den aktuellen bzw. den Elternordner. File.Create wirft
        // dort eine UnauthorizedAccessException statt eine Datei anzulegen.
        PosteingangZwischenlager.Entschaerft(wert).Should().Be("Anhang");
    }

    [Fact]
    public void Entschaerft_LaesstGewoehnlicheNamenUnveraendert()
    {
        PosteingangZwischenlager.Entschaerft("Rechnung 2026.pdf").Should().Be("Rechnung 2026.pdf");
    }

    [Fact]
    public async Task SchreibeAtomarAsync_AbbruchMittendrin_HinterlaesstKeineDateiUnterDemZielnamen()
    {
        var ordner = NeuerOrdner();
        var ziel = Path.Combine(ordner, "Gutachten.pdf");

        var schreiben = () => PosteingangZwischenlager.SchreibeAtomarAsync(async strom =>
        {
            await strom.WriteAsync(Encoding.UTF8.GetBytes("Angefangen"));
            throw new OperationCanceledException();
        }, ziel);

        await schreiben.Should().ThrowAsync<OperationCanceledException>();
        File.Exists(ziel).Should().BeFalse();
        Directory.EnumerateFiles(ordner).Should().BeEmpty();
    }

    [Fact]
    public async Task SchreibeAtomarAsync_ErfolgreichesSchreiben_LegtDenInhaltUnterDemZielnamenAb()
    {
        var ordner = NeuerOrdner();
        var ziel = Path.Combine(ordner, "Gutachten.pdf");

        await PosteingangZwischenlager.SchreibeAtomarAsync(
            strom => strom.WriteAsync(Encoding.UTF8.GetBytes("Fertig")).AsTask(), ziel);

        File.ReadAllText(ziel).Should().Be("Fertig");
    }

    [Fact]
    public void VorhandenUndMerke_ErkenntDenselbenSchluesselWieder_OhneAufDieGroesseZuSchauen()
    {
        var ordner = NeuerOrdner();
        var pfad = Path.Combine(ordner, "Rechnung.pdf");
        File.WriteAllText(pfad, "Inhalt");

        PosteingangZwischenlager.Vorhanden(ordner, "3").Should().BeNull();
        PosteingangZwischenlager.Merke(ordner, "3", "Rechnung.pdf");

        PosteingangZwischenlager.Vorhanden(ordner, "3").Should().Be(pfad);
    }

    private static string NeuerOrdner() =>
        Directory.CreateDirectory(
            Path.Combine(Path.GetTempPath(), "AutomationService.Tests", Guid.NewGuid().ToString("N"))).FullName;
}
