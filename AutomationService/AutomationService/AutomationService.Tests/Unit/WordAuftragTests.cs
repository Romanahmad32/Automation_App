using AutomationService.Features.PdfConversion.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Wer zuerst kommt, Word-Thread oder wartender Aufrufer, entscheidet über
/// den Auftrag (§4.11): Ein Druck, den die App nach Ablauf der Wartezeit schon
/// als gescheitert gemeldet hat, darf danach nicht doch noch herauskommen.
/// </summary>
public sealed class WordAuftragTests
{
    [Fact]
    public void Ein_aufgegebener_Auftrag_laeuft_nicht_mehr_an()
    {
        var auftrag = new WordAuftrag(@"C:\Arbeit\Vollmacht Unfallsachen.docx", drucken: true);

        auftrag.GibAuf().Should().BeTrue("Word hatte ihn noch nicht angefasst");

        auftrag.Beginne().Should().BeFalse();
        auftrag.Ergebnis.Task.IsCanceled.Should().BeTrue();
    }

    [Fact]
    public void Ein_laufender_Auftrag_laesst_sich_nicht_mehr_aufgeben()
    {
        var auftrag = new WordAuftrag(@"C:\Arbeit\Vollmacht Unfallsachen.docx", drucken: true);

        auftrag.Beginne().Should().BeTrue();

        auftrag.GibAuf().Should().BeFalse("ein Druck kann jetzt noch herauskommen");
        auftrag.Ergebnis.Task.IsCompleted.Should().BeFalse("das Ergebnis setzt der Word-Thread");
    }

    [Fact]
    public void Ein_Auftrag_beginnt_nur_einmal()
    {
        var auftrag = new WordAuftrag(@"C:\Arbeit\Schreiben.docx");

        auftrag.Beginne().Should().BeTrue();
        auftrag.Beginne().Should().BeFalse();
    }

    /// <summary>
    /// Der eigentliche Wettlauf: Word-Thread und Zeitablauf treffen im selben
    /// Augenblick ein. Genau einer von beiden darf gewinnen — nie beide (Druck
    /// und Rückfall), nie keiner (Auftrag hinge).
    /// </summary>
    [Fact]
    public async Task Bei_gleichzeitigem_Zugriff_gewinnt_genau_einer()
    {
        for (var runde = 0; runde < 500; runde++)
        {
            var auftrag = new WordAuftrag(@"C:\Arbeit\Vollmacht Strafsache.docx", drucken: true);
            using var start = new Barrier(2);

            var beginnt = Task.Run(() =>
            {
                start.SignalAndWait();
                return auftrag.Beginne();
            });
            var gibtAuf = Task.Run(() =>
            {
                start.SignalAndWait();
                return auftrag.GibAuf();
            });

            var ergebnisse = await Task.WhenAll(beginnt, gibtAuf);
            ergebnisse.Count(gewonnen => gewonnen).Should().Be(1, $"Runde {runde}");
        }
    }
}
