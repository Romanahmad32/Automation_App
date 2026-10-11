using System.IO.Compression;
using System.Text.Json;
using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vollmacht.Domain.Services;
using AutomationService.Features.Vollmacht.Presentation.Controllers;
using AutomationService.Features.Vollmacht.Presentation.Dtos;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Xceed.Words.NET;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Platzhalter je Vollmachtsvorlage (§4.11, #171): Der Dialog zeigt nur
/// die Felder, deren Platzhalter in der gewählten Vorlage steht. Was sich
/// nicht lesen lässt, ist „unbekannt" (null) — dann zeigt er alle Felder —
/// und nie ein Serverfehler.
///
/// Am Dienst statt über den Testwirt: Dessen Vorlagenordner liegt zwar dank
/// <see cref="TestAppDataUmgebung"/> nicht beim Anwalt, teilen sich aber alle
/// Integrationstests, und jeder Wirt sät beim Start die Muster hinein — was
/// dort gerade liegt, ist nicht Sache eines einzelnen Tests.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class VollmachtVorlagenPlatzhalterTests : IDisposable
{
    private static readonly string[] KopfPlatzhalter =
    [
        "MandantVorname", "MandantNachname", "MandantStrasse", "MandantPlz", "MandantOrt", "InSachen", "Wegen",
    ];

    private readonly WordVorlagenUmgebung _umgebung = new();
    private readonly string _vorlagenOrdner =
        Path.Combine(Path.GetTempPath(), $"VollmachtPlatzhalter_{Guid.NewGuid():N}");

    private VollmachtVorlagenOrdner Ordner() =>
        new(_vorlagenOrdner, NullLogger<VollmachtVorlagenOrdner>.Instance);

    private VollmachtDienst Dienst() => new(
        _umgebung.CreateService(),
        new KeinDrucker(),
        new PdfAttrappe(),
        Ordner(),
        _umgebung.ArbeitsVerzeichnis,
        NullLogger<VollmachtDienst>.Instance);

    private VollmachtVorlage VorlageDer(VollmachtArt art) => Dienst().Vorlagen().Single(v => v.Art == art);

    /// <summary>Nur die Unfallvorlage hat den Fußblock mit Telefon und E-Mail.</summary>
    [Fact]
    public void Die_Muster_nennen_ihre_Platzhalter_nur_Unfall_mit_Telefon_und_EMail()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());

        var vorlagen = Dienst().Vorlagen();

        vorlagen.Select(v => v.Art).Should().Equal(VollmachtArten.Alle);
        vorlagen.Single(v => v.Art == VollmachtArt.Unfallsachen).Platzhalter.Should()
            .BeEquivalentTo([.. KopfPlatzhalter, "MandantTelefon", "MandantEmail"]);
        vorlagen.Single(v => v.Art == VollmachtArt.Bussgeldsachen).Platzhalter.Should()
            .BeEquivalentTo(KopfPlatzhalter);
        vorlagen.Single(v => v.Art == VollmachtArt.Strafsache).Platzhalter.Should()
            .BeEquivalentTo(KopfPlatzhalter);
    }

    [Fact]
    public void Eine_fehlende_Vorlage_hat_unbekannte_Platzhalter()
    {
        var vorlage = VorlageDer(VollmachtArt.Strafsache);

        vorlage.Vorhanden.Should().BeFalse();
        vorlage.Platzhalter.Should().BeNull();
    }

    /// <summary>
    /// Eine kaputte oder nur umbenannte Datei unter dem festen Namen ist zu
    /// erwarten (die Datei tauscht der Anwalt im Explorer) — sie macht die
    /// anderen Vorlagen nicht unlesbar.
    /// </summary>
    [Fact]
    public void Eine_kaputte_Vorlage_hat_unbekannte_Platzhalter()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        File.WriteAllText(Ordner().PfadFuer(VollmachtArt.Bussgeldsachen), "kein Word-Dokument");

        var vorlagen = Dienst().Vorlagen();

        vorlagen.Single(v => v.Art == VollmachtArt.Bussgeldsachen).Platzhalter.Should().BeNull();
        vorlagen.Single(v => v.Art == VollmachtArt.Strafsache).Platzhalter.Should().NotBeNull();
    }

    /// <summary>
    /// Ein gültiges ZIP mit kaputtem XML darin wirft aus DocX keinen der
    /// Fehler, die das Ausfüllen erwartet — der Stand bleibt trotzdem lesbar,
    /// sonst öffnete der Dialog gar nicht.
    /// </summary>
    [Fact]
    public void Eine_Vorlage_mit_kaputtem_XML_hat_unbekannte_Platzhalter()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        using (var zip = ZipFile.Open(Ordner().PfadFuer(VollmachtArt.Strafsache), ZipArchiveMode.Update))
        {
            zip.GetEntry("word/document.xml")!.Delete();
            using var schreiber = new StreamWriter(zip.CreateEntry("word/document.xml").Open());
            schreiber.Write("<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>");
        }

        var vorlagen = Dienst().Vorlagen();

        vorlagen.Single(v => v.Art == VollmachtArt.Strafsache).Platzhalter.Should().BeNull();
        vorlagen.Single(v => v.Art == VollmachtArt.Unfallsachen).Platzhalter.Should().NotBeNull();
    }

    /// <summary>Etwa, weil Word sie gerade exklusiv offen hält.</summary>
    [Fact]
    public void Eine_gesperrte_Vorlage_hat_unbekannte_Platzhalter()
    {
        Ordner().Ergaenze(VollmachtDienstTests.MusterOrdner());
        using var sperre = new FileStream(
            Ordner().PfadFuer(VollmachtArt.Unfallsachen), FileMode.Open, FileAccess.ReadWrite, FileShare.None);

        VorlageDer(VollmachtArt.Unfallsachen).Platzhalter.Should().BeNull();
    }

    /// <summary>„Keine Platzhalter" ist etwas anderes als „unbekannt".</summary>
    [Fact]
    public void Eine_Vorlage_ohne_Platzhalter_hat_eine_leere_Liste()
    {
        LegeVorlageAn(VollmachtArt.Strafsache, "Vollmacht ohne ein einziges Feld");

        VorlageDer(VollmachtArt.Strafsache).Platzhalter.Should().NotBeNull().And.BeEmpty();
    }

    [Fact]
    public void Ein_Platzhalter_steht_einmal_in_der_Liste_auch_wenn_er_mehrfach_vorkommt()
    {
        LegeVorlageAn(VollmachtArt.Strafsache, "{{MandantName}}, {{MandantAnschrift}}", "gez. {{MandantName}}");

        VorlageDer(VollmachtArt.Strafsache).Platzhalter.Should()
            .BeEquivalentTo(["MandantName", "MandantAnschrift"], "jeder Name genau einmal");
    }

    /// <summary>
    /// Der Feldname ist Vertrag: Das Frontend liest <c>platzhalter</c>, und
    /// „unbekannt" muss als <c>null</c> ankommen, nicht als fehlendes Feld.
    /// </summary>
    [Fact]
    public void Der_Endpunkt_liefert_platzhalter_als_Liste_oder_null()
    {
        LegeVorlageAn(VollmachtArt.Unfallsachen, "{{MandantTelefon}}");
        var controller = new VollmachtController(Dienst(), Ordner(), new KeinDrucker());

        var antwort = controller.Vorlagen().Result.Should().BeOfType<OkObjectResult>().Subject;

        var json = JsonSerializer.Serialize(antwort.Value, JsonSerializerOptions.Web);
        json.Should().Contain("\"art\":\"unfallsachen\"")
            .And.Contain("\"platzhalter\":[\"MandantTelefon\"]")
            .And.Contain("\"art\":\"strafsache\"")
            .And.Contain("\"platzhalter\":null");
        ((VollmachtVorlagenDto)antwort.Value!).Vorlagen.Should().HaveCount(3);
    }

    private void LegeVorlageAn(VollmachtArt art, params string[] absaetze)
    {
        var pfad = Ordner().PfadFuer(art);
        Directory.CreateDirectory(Path.GetDirectoryName(pfad)!);
        using var vorlage = DocX.Create(pfad);
        foreach (var absatz in absaetze)
        {
            vorlage.InsertParagraph(absatz);
        }

        vorlage.Save();
    }

    public void Dispose()
    {
        _umgebung.Dispose();
        if (Directory.Exists(_vorlagenOrdner))
        {
            Directory.Delete(_vorlagenOrdner, true);
        }
    }

    /// <summary>Drucken kommt hier nicht vor; der Controller braucht nur einen Drucker.</summary>
    private sealed class KeinDrucker : IWordDrucker, IDruckerAuskunft
    {
        public Task<string?> DruckeAsync(string docxPfad, CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("Hier wird nicht gedruckt.");

        public DruckerLage Standarddrucker() => new(null, DruckerZustand.KeinDrucker);
    }
}
