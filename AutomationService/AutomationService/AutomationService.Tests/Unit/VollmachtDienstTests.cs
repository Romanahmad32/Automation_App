using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xceed.Words.NET;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Vollmacht zum Vorgang (§4.11): Ausfüllen der mitgelieferten Muster,
/// Druck mit Löschen der Arbeitsdatei, Rückfall bei gescheitertem Druck. Der
/// Drucker ist eine Attrappe — die Tests laufen ohne Word.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class VollmachtDienstTests : IDisposable
{
    private const string Referenz = "84/26 C03_GG-XY 123";

    private readonly WordVorlagenUmgebung _umgebung = new();
    private readonly string _vorlagenOrdner =
        Path.Combine(Path.GetTempPath(), $"VollmachtVorlagen_{Guid.NewGuid():N}");
    private readonly DruckerAttrappe _drucker = new();

    private VollmachtVorlagenOrdner Ordner() =>
        new(_vorlagenOrdner, NullLogger<VollmachtVorlagenOrdner>.Instance);

    private VollmachtDienst Dienst() =>
        new(_umgebung.CreateService(), _drucker, Ordner(), NullLogger<VollmachtDienst>.Instance);

    /// <summary>Die versionierten Muster — dieselben Dateien, die das Setup mitbringt.</summary>
    private static string MusterOrdner() => Path.Combine(
        RepoWurzel.Pfad(), "AutomationService", "AutomationService", "Templates", VollmachtArten.Unterordner);

    private static VollmachtAuftrag Auftrag(VollmachtArt art) => new()
    {
        Art = art,
        Referenz = Referenz,
        MandantVorname = "Anna",
        MandantNachname = "Mustermann",
        MandantStrasse = "Musterweg 4",
        MandantPlz = "12345",
        MandantOrt = "Musterstadt",
        MandantTelefon = "0170 1234567",
        MandantEmail = "anna@example.org",
        Unfalldatum = "02.08.2026",
        InSachen = "Bußgeldsache Anna Mustermann",
        Wegen = "Schadensersatz nach Verkehrsunfall vom 02.08.2026",
    };

    [Theory]
    [InlineData(VollmachtArt.Unfallsachen)]
    [InlineData(VollmachtArt.Bussgeldsachen)]
    [InlineData(VollmachtArt.Strafsache)]
    public void Die_mitgelieferten_Muster_lassen_keinen_Platzhalter_offen(VollmachtArt art)
    {
        Ordner().Ergaenze(MusterOrdner()).Should().Be(3);

        var ergebnis = Dienst().FuelleAus(Auftrag(art));

        ergebnis.Art.Should().Be(VollmachtErgebnisArt.Ausgefuellt);
        ergebnis.Warnungen.Should().BeEmpty();
        using var dokument = DocX.Load(ergebnis.Pfad);
        dokument.Text.Should().Contain("Anna Mustermann, Musterweg 4, 12345 Musterstadt")
            .And.Contain("wegen: Schadensersatz nach Verkehrsunfall vom 02.08.2026")
            .And.NotContain("{{");
    }

    [Fact]
    public void Nur_die_Unfallvorlage_fragt_Telefon_und_EMail_ab()
    {
        Ordner().Ergaenze(MusterOrdner());

        using var unfall = DocX.Load(Dienst().FuelleAus(Auftrag(VollmachtArt.Unfallsachen)).Pfad);
        using var straf = DocX.Load(Dienst().FuelleAus(Auftrag(VollmachtArt.Strafsache)).Pfad);

        unfall.Text.Should().Contain("0170 1234567").And.Contain("anna@example.org");
        straf.Text.Should().NotContain("0170 1234567");
    }

    [Fact]
    public async Task Nach_dem_Druck_ist_die_Arbeitsdatei_weg()
    {
        Ordner().Ergaenze(MusterOrdner());

        var ergebnis = await Dienst().DruckeAsync(Auftrag(VollmachtArt.Strafsache));

        ergebnis.Art.Should().Be(VollmachtErgebnisArt.Gedruckt);
        ergebnis.Pfad.Should().BeNull();
        _drucker.Gedruckt.Should().ContainSingle();
        File.Exists(_drucker.Gedruckt[0]).Should().BeFalse();
    }

    /// <summary>
    /// Der Arbeitsordner gehört auch dem Anspruchsschreiben. Räumte der Druck
    /// den ganzen Ordner ab, wäre ein gerade erzeugtes, noch nicht abgelegtes
    /// Schreiben mit weg.
    /// </summary>
    [Fact]
    public async Task Ein_Schreiben_im_selben_Arbeitsordner_bleibt_liegen()
    {
        Ordner().Ergaenze(MusterOrdner());
        var schreiben = Path.Combine(_umgebung.ArbeitsVerzeichnis.OrdnerFuer(Referenz), "Anspruchsschreiben.docx");
        await File.WriteAllTextAsync(schreiben, "angefangen");

        await Dienst().DruckeAsync(Auftrag(VollmachtArt.Unfallsachen));

        File.Exists(schreiben).Should().BeTrue();
    }

    [Fact]
    public async Task Scheitert_der_Druck_bleibt_die_Datei_zum_Oeffnen()
    {
        Ordner().Ergaenze(MusterOrdner());
        _drucker.Scheitert = true;

        var ergebnis = await Dienst().DruckeAsync(Auftrag(VollmachtArt.Bussgeldsachen));

        ergebnis.Art.Should().Be(VollmachtErgebnisArt.DruckFehlgeschlagen);
        ergebnis.Meldung.Should().NotBeNullOrWhiteSpace();
        File.Exists(ergebnis.Pfad).Should().BeTrue();
    }

    [Fact]
    public async Task Fehlt_die_Vorlage_wird_nichts_gedruckt()
    {
        var ergebnis = await Dienst().DruckeAsync(Auftrag(VollmachtArt.Unfallsachen));

        ergebnis.Art.Should().Be(VollmachtErgebnisArt.VorlageFehlt);
        ergebnis.Meldung.Should().Contain("Vollmacht Unfallsachen.docx");
        _drucker.Gedruckt.Should().BeEmpty();
    }

    /// <summary>
    /// Ein Platzhalter, den die App nicht kennt — hier das Tatdatum, das es
    /// nirgends gibt —, bleibt stehen und kommt als Warnung zurück (§4.4).
    /// </summary>
    [Fact]
    public void Ein_unbekannter_Platzhalter_kommt_als_Warnung_zurueck()
    {
        var pfad = Ordner().PfadFuer(VollmachtArt.Bussgeldsachen);
        Directory.CreateDirectory(Path.GetDirectoryName(pfad)!);
        using (var vorlage = DocX.Create(pfad))
        {
            vorlage.InsertParagraph("{{MandantName}} wegen OWi am {{Tatdatum}}");
            vorlage.Save();
        }

        var ergebnis = Dienst().FuelleAus(Auftrag(VollmachtArt.Bussgeldsachen));

        ergebnis.Art.Should().Be(VollmachtErgebnisArt.Ausgefuellt);
        ergebnis.Warnungen.Should().Equal("Tatdatum");
    }

    public void Dispose()
    {
        _umgebung.Dispose();
        if (Directory.Exists(_vorlagenOrdner))
        {
            Directory.Delete(_vorlagenOrdner, true);
        }
    }

    private sealed class DruckerAttrappe : IWordDrucker
    {
        public List<string> Gedruckt { get; } = [];

        public bool Scheitert { get; set; }

        public Task DruckeAsync(string docxPfad, CancellationToken cancellationToken = default)
        {
            if (Scheitert)
            {
                throw new PdfConversionUnavailableException("Word fehlt.");
            }

            File.Exists(docxPfad).Should().BeTrue("gedruckt wird die ausgefüllte Datei");
            Gedruckt.Add(docxPfad);
            return Task.CompletedTask;
        }
    }
}
