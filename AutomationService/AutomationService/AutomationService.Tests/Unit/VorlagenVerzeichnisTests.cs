using AutomationService.Features.WordAutomation.Domain.Services;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Sichert die eine Eigenschaft ab, auf die es beim Vorlagenordner ankommt:
/// mitgelieferte Vorlagen werden <em>ergaenzt</em>, nie ueberschrieben.
///
/// Wuerde hier ueberschrieben, verloere der Anwalt mit jedem Update seine
/// Anpassungen an einer Vorlage — Briefkopf, Formulierungen — und merkte es
/// erst an einem bereits verschickten Schreiben. Genau deshalb liegt der Ordner
/// ueberhaupt in %APPDATA% und nicht im Installationsverzeichnis.
/// </summary>
public sealed class VorlagenVerzeichnisTests : IDisposable
{
    private readonly string _quelle;

    public VorlagenVerzeichnisTests()
    {
        _quelle = Path.Combine(Path.GetTempPath(), "vorlagen-quelle-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_quelle);
    }

    [Fact]
    public void Ergaenzt_fehlende_Vorlagen()
    {
        File.WriteAllText(Path.Combine(_quelle, "Anspruch.docx"), "mitgeliefert");
        var (verzeichnis, ordner) = LegeLeerenVorlagenordnerAn();

        var kopiert = verzeichnis.Ergaenze(_quelle);

        kopiert.Should().Be(1);
        File.ReadAllText(Path.Combine(ordner, "Anspruch.docx")).Should().Be("mitgeliefert");
    }

    [Fact]
    public void Ueberschreibt_eine_vorhandene_Vorlage_nicht()
    {
        File.WriteAllText(Path.Combine(_quelle, "Anspruch.docx"), "mitgeliefert");
        var (verzeichnis, ordner) = LegeLeerenVorlagenordnerAn();
        File.WriteAllText(Path.Combine(ordner, "Anspruch.docx"), "vom Anwalt angepasst");

        var kopiert = verzeichnis.Ergaenze(_quelle);

        kopiert.Should().Be(0);
        File.ReadAllText(Path.Combine(ordner, "Anspruch.docx")).Should().Be("vom Anwalt angepasst");
    }

    [Fact]
    public void Fehlende_Quelle_ist_kein_Fehler()
    {
        var (verzeichnis, _) = LegeLeerenVorlagenordnerAn();

        var kopiert = verzeichnis.Ergaenze(Path.Combine(_quelle, "gibt-es-nicht"));

        kopiert.Should().Be(0, "ohne mitgelieferte Vorlagen soll die Anwendung trotzdem starten");
    }

    [Fact]
    public void Listet_die_Vorlagen_des_Ordners()
    {
        File.WriteAllText(Path.Combine(_quelle, "A.docx"), "a");
        File.WriteAllText(Path.Combine(_quelle, "B.docx"), "b");
        File.WriteAllText(Path.Combine(_quelle, "keine-vorlage.txt"), "x");
        var (verzeichnis, _) = LegeLeerenVorlagenordnerAn();
        verzeichnis.Ergaenze(_quelle);

        var vorlagen = verzeichnis.Auflisten();

        vorlagen.Select(v => v.Name).Should().BeEquivalentTo("A.docx", "B.docx");
        vorlagen.Should().OnlyContain(v => File.Exists(v.Pfad));
    }

    private (VorlagenVerzeichnis, string Ordner) LegeLeerenVorlagenordnerAn()
    {
        var ordner = Path.Combine(_quelle, "ziel");
        var verzeichnis = new VorlagenVerzeichnis(ordner, NullLogger<VorlagenVerzeichnis>.Instance);
        return (verzeichnis, verzeichnis.Pfad);
    }

    public void Dispose()
    {
        try
        {
            Directory.Delete(_quelle, recursive: true);
        }
        catch (IOException)
        {
            // Aufraeumen ist best effort.
        }
    }
}
