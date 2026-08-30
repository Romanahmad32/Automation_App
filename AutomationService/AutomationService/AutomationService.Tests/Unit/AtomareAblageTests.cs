using AutomationService.Features.Vorgaenge.Domain.Services;
using AutomationService.Features.WordAutomation.Domain.Exceptions;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Prüft die Zusicherung, auf der die OneDrive-Anbindung ruht (#40): Im
/// Zielordner geschieht entweder nichts oder eine vollständige neue Fassung.
///
/// Das ist kein akademischer Punkt. Ein Synchronisierungsdienst beobachtet den
/// Ordner und lädt hoch, sobald sich etwas rührt — sähe er eine halb
/// geschriebene .docx, läge sie so auf dem Handy.
/// </summary>
public sealed class AtomareAblageTests : IDisposable
{
    readonly string _ordner = Directory.CreateTempSubdirectory("atomare-ablage").FullName;

    string Pfad(string name) => Path.Combine(_ordner, name);

    string Quelle(string inhalt = "neu")
    {
        var pfad = Pfad($"{Guid.NewGuid():N}.bau");
        File.WriteAllText(pfad, inhalt);
        return pfad;
    }

    [Fact]
    public void Ersetze_LegtDieDateiAnUndRaeumtDieQuelleWeg()
    {
        var quelle = Quelle();
        var ziel = Pfad("register.docx");

        AtomareAblage.Ersetze(quelle, ziel);

        File.ReadAllText(ziel).Should().Be("neu");
        File.Exists(quelle).Should().BeFalse();
    }

    [Fact]
    public void Ersetze_LegtFehlendeOrdnerAn()
    {
        var ziel = Path.Combine(_ordner, "Kanzlei", "Register", "register.docx");

        AtomareAblage.Ersetze(Quelle(), ziel);

        File.Exists(ziel).Should().BeTrue();
    }

    [Fact]
    public void Ersetze_UeberschreibtEineVorhandeneFassung()
    {
        var ziel = Pfad("register.docx");
        File.WriteAllText(ziel, "alt");

        AtomareAblage.Ersetze(Quelle(), ziel);

        File.ReadAllText(ziel).Should().Be("neu");
    }

    /// <summary>
    /// Der Schreibschutz ist die eigene Vorsichtsmaßnahme des Spiegels. Nähme
    /// ihn niemand zurück, scheiterte der zweite Lauf an dem, was der erste
    /// gesetzt hat.
    /// </summary>
    [Fact]
    public void Ersetze_KommtAmEigenenSchreibschutzVorbei()
    {
        var ziel = Pfad("register.docx");
        File.WriteAllText(ziel, "alt");
        AtomareAblage.SchreibschutzSetzen(ziel);

        AtomareAblage.Ersetze(Quelle(), ziel);

        File.ReadAllText(ziel).Should().Be("neu");
    }

    /// <summary>
    /// Der häufigste Fehlerfall überhaupt: Das Register ist gerade in Word
    /// geöffnet. Dann muss die alte Fassung unangetastet liegen bleiben — eine
    /// halb ersetzte Datei wäre der schlechtestmögliche Ausgang.
    /// </summary>
    [Fact]
    public void Ersetze_LaesstDieAlteFassungStehen_WennDasZielGesperrtIst()
    {
        var ziel = Pfad("register.docx");
        File.WriteAllText(ziel, "alt");
        using var sperre = new FileStream(ziel, FileMode.Open, FileAccess.Read, FileShare.None);

        var tat = () => AtomareAblage.Ersetze(Quelle(), ziel);

        tat.Should().Throw<ZieldateiGesperrtException>()
            .WithMessage("*register.docx*geöffnet*");
        sperre.Dispose();
        File.ReadAllText(ziel).Should().Be("alt");
    }

    [Fact]
    public void Ersetze_LaesstKeinenZwischenstandZurueck_WennDasZielGesperrtIst()
    {
        var ziel = Pfad("register.docx");
        File.WriteAllText(ziel, "alt");
        using var sperre = new FileStream(ziel, FileMode.Open, FileAccess.Read, FileShare.None);
        var quelle = Quelle();

        var tat = () => AtomareAblage.Ersetze(quelle, ziel);
        tat.Should().Throw<ZieldateiGesperrtException>();

        sperre.Dispose();
        Directory.EnumerateFiles(_ordner).Select(Path.GetFileName)
            .Should().ContainSingle("weder die Quelle noch ein Zwischenstand bleiben liegen")
            .Which.Should().Be("register.docx");
    }

    /// <summary>
    /// Liegt das Ziel auf einem anderen Laufwerk, kopiert die Ablage zuerst
    /// neben das Ziel — mitten in den synchronisierten Ordner. Stürzt der Dienst
    /// zwischen Kopieren und Umbenennen ab, bleibt diese Datei dort für immer:
    /// Der Bauordner räumt sie nicht weg, sie liegt ja woanders. Auf dem Handy
    /// erscheint sie als „~Sachgebiete-Register (App)-a3f9….tmp", eine je
    /// Absturz.
    ///
    /// Der Laufwerkswechsel selbst lässt sich hier nicht nachstellen (die CI
    /// hat ein Laufwerk) — die Altlast, die er hinterlässt, sehr wohl.
    /// </summary>
    [Fact]
    public void Ersetze_RaeumtLiegenGebliebeneZwischenstaendeWeg()
    {
        var ziel = Pfad("register.docx");
        var altlast = Pfad("~register-a3f9c1d2e4b60718.tmp");
        File.WriteAllText(altlast, "vom Absturz von gestern");

        AtomareAblage.Ersetze(Quelle(), ziel);

        File.Exists(altlast).Should().BeFalse();
        File.ReadAllText(ziel).Should().Be("neu");
    }

    /// <summary>
    /// Aufgeräumt wird nur, was unverkennbar von hier stammt. Der Zielordner
    /// ist der Ordner des Anwalts, und was dort sonst liegt, geht die Ablage
    /// nichts an — auch dann nicht, wenn es ähnlich heisst.
    /// </summary>
    [Fact]
    public void Ersetze_LaesstFremdeDateienImZielordnerLiegen()
    {
        var ziel = Pfad("register.docx");
        var fremd = new[]
        {
            Pfad("~register-a3f9.docx"),          // andere Endung
            Pfad("~notizen-a3f9.tmp"),            // anderer Basisname
            Pfad("register-a3f9.tmp"),            // ohne Tilde
            Pfad("~register.tmp"),                // ohne Kennung
        };
        foreach (var datei in fremd) File.WriteAllText(datei, "gehoert dem Anwalt");

        AtomareAblage.Ersetze(Quelle(), ziel);

        foreach (var datei in fremd) File.Exists(datei).Should().BeTrue(datei);
    }

    public void Dispose() => Directory.Delete(_ordner, recursive: true);
}
