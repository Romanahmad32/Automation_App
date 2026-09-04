using AutomationService.Features.WordAutomation.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xceed.Words.NET;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Platzhalter, die die App selbst füllt (#31).
///
/// Zwei Dinge stehen hier auf dem Spiel, und beide enden im Brief an den
/// Gegner: dass <c>{{Gesamtforderung}}</c> dieselbe Zahl trägt wie die Zeile,
/// die der Anwalt in der App liest — und dass ein Schreiben **ohne**
/// Schadensaufstellung keine rohen <c>{{RvgBrutto}}</c> mehr hinausträgt.
/// Letzteres war bisher nur eine Warnung im Begutachten-Schritt, die bei jedem
/// Schreiben ohne Auflistung erschien und deshalb überlesen wurde.
/// </summary>
[Collection(WordDokumentSammlung.Name)]
public sealed class RvgPlatzhalterTests : IDisposable
{
    private readonly WordVorlagenUmgebung _umgebung = new();

    /// <summary>Eine Aufstellung über 4.250,00 € zum Regelsatz 1,3, ohne USt.</summary>
    private static DamageListing Aufstellung() => new()
    {
        Items =
        [
            new DamageItem { Description = "Reparaturkosten netto nach Gutachten", Amount = 4000m },
            new DamageItem { Description = "Wertminderung nach Gutachten", Amount = 250m }
        ],
        Gebuehrensatz = 1.3m,
        ApplyVat = false
    };

    [Fact]
    public void Setze_LegtAlleAchtWerteAb()
    {
        var werte = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        RvgPlatzhalter.Setze(Aufstellung(), werte);

        werte.Keys.Should().Contain(RvgPlatzhalter.Namen);
    }

    /// <summary>
    /// Die Zahl, die im Brief steht: Zwischensumme plus Anwaltskosten brutto —
    /// genau die Rechnung, die die App als "Gesamtforderung (inkl. RA-Kosten)"
    /// anzeigt. Gepinnt statt nachgerechnet, damit ein stillschweigend
    /// geändertes Zahlenformat auffällt.
    /// </summary>
    [Fact]
    public void Setze_Gesamtforderung_IstZwischensummePlusBrutto()
    {
        var werte = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        var kalkulation = RvgPlatzhalter.Setze(Aufstellung(), werte);

        werte[RvgPlatzhalter.Gegenstandswert].Should().Be("4.250,00");
        werte[RvgPlatzhalter.RvgBrutto].Should().Be("480,85");
        werte[RvgPlatzhalter.Gesamtforderung].Should().Be("4.730,85");
        (kalkulation.Gegenstandswert + kalkulation.Brutto).Should().Be(4730.85m);
    }

    /// <summary>
    /// Dieselbe Aufstellung mit Umsatzsteuer — die Rechnung, mit der die
    /// Vorlagenverwaltung ihre Beispielwerte beschriftet
    /// (<c>AppEigenePlatzhalter.eintraege</c> im Frontend). Gepinnt, damit die
    /// angezeigten Zahlen nicht auseinanderlaufen mit dem, was im Dokument
    /// landet.
    /// </summary>
    [Fact]
    public void Setze_MitUmsatzsteuer_ErgibtDieBeispielwerteDerVorlagenverwaltung()
    {
        var basis = Aufstellung();
        var mitUmsatzsteuer = new DamageListing
        {
            Items = basis.Items,
            Gebuehrensatz = basis.Gebuehrensatz,
            ApplyVat = true
        };
        var werte = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        RvgPlatzhalter.Setze(mitUmsatzsteuer, werte);

        werte[RvgPlatzhalter.Gegenstandswert].Should().Be("4.250,00");
        werte[RvgPlatzhalter.Gebuehrensatz].Should().Be("1,3");
        werte[RvgPlatzhalter.Geschaeftsgebuehr].Should().Be("460,85");
        werte[RvgPlatzhalter.Auslagenpauschale].Should().Be("20,00");
        werte[RvgPlatzhalter.RvgNetto].Should().Be("480,85");
        werte[RvgPlatzhalter.RvgUmsatzsteuer].Should().Be("91,36");
        werte[RvgPlatzhalter.RvgBrutto].Should().Be("572,21");
        werte[RvgPlatzhalter.Gesamtforderung].Should().Be("4.822,21");
    }

    [Fact]
    public void Leere_SetztAlleAchtAufLeer()
    {
        var werte = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        RvgPlatzhalter.Leere(werte);

        werte.Should().HaveCount(RvgPlatzhalter.Namen.Count);
        werte.Values.Should().OnlyContain(wert => wert == string.Empty);
    }

    /// <summary>
    /// Leeren schließt die Lücke, es wirft keine Eingabe weg: Wer sich ein Feld
    /// "Gesamtforderung" angelegt und von Hand gefüllt hat, bekommt seinen Wert
    /// und nicht die leere Zeichenkette.
    /// </summary>
    [Fact]
    public void Leere_LaesstEinenVonHandErfasstenWertStehen()
    {
        var werte = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [RvgPlatzhalter.Gesamtforderung] = "1.234,56"
        };

        RvgPlatzhalter.Leere(werte);

        werte[RvgPlatzhalter.Gesamtforderung].Should().Be("1.234,56");
        werte[RvgPlatzhalter.RvgBrutto].Should().BeEmpty();
    }

    /// <summary>
    /// Der Kanzleifehler, um den es geht: Eine Vorlage ohne Auflistung, die die
    /// RVG-Platzhalter trägt, ging bisher mit <c>{{RvgBrutto}}</c> im Text
    /// hinaus.
    /// </summary>
    [Fact]
    public void OhneSchadensaufstellung_BleibtKeinRvgPlatzhalterRohStehen()
    {
        var templatePath = _umgebung.CreateTemplate(
            "OhneAuflistung",
            "Wir fordern {{Gesamtforderung}} €, davon {{RvgBrutto}} € Anwaltskosten.");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = null
        });

        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().NotContain("{{");
        result.Warnings.Should().NotContain(warnung => warnung.Contains("Rvg", StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>
    /// Und die Gegenrichtung: Mit Aufstellung stehen die Werte im Dokument,
    /// auch wenn die Vorlage gar keine Tabelle einsetzt — die Kosten hängen an
    /// der Aufstellung, nicht am <c>{{Schadensaufstellung}}</c>-Platzhalter.
    /// </summary>
    [Fact]
    public void MitSchadensaufstellung_StehenDieWerteImDokument()
    {
        // Zwei Absätze: Der Absatz mit {{Schadensaufstellung}} weicht der
        // Tabelle und nimmt alles mit, was sonst noch in ihm steht.
        var templatePath = _umgebung.CreateTemplate(
            "MitAuflistung",
            "Gesamtforderung: {{Gesamtforderung}} €",
            "{{Schadensaufstellung}}");

        var service = _umgebung.CreateService();
        var result = service.GenerateReplacedDocument(new WordReplacementRequest
        {
            TemplateFilePath = templatePath,
            ReplacePatterns = new Dictionary<string, string> { ["Dummy"] = "x" },
            DamageListing = Aufstellung()
        });

        using var output = DocX.Load(result.OutputFilePath);
        output.Text.Should().Contain("4.730,85");
    }

    public void Dispose() => _umgebung.Dispose();
}
