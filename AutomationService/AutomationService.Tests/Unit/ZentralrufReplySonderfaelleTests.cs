using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Sonderfälle der Zentralruf-Antwortmail jenseits des Block-Standardformats:
/// Zwischennachricht (Auskunft nicht sofort möglich, Fachabteilung / Grüne
/// Karte) und das "Datenblatt"-Format mit beschrifteten Zeilen.
/// </summary>
public class ZentralrufReplySonderfaelleTests
{
    private readonly ZentralrufReplyParser _parser = new();

    private const string ZwischennachrichtMail = """
        Zwischennachricht zu Ihrer Anfrage beim Zentralruf - Vorgangsnummer: 12345678

        Sehr geehrte Damen und Herren,

        eine automatische Zuordnung war für das Kennzeichen GG XY 123 zum Schadentag 09.03.2026 leider nicht sofort möglich.

        Ihre Anfrage wurde an die zuständige Fachabteilung zur manuellen Überprüfung weitergeleitet.
        Wir melden uns unaufgefordert, sobald uns das Ergebnis vorliegt.

        Mit freundlichen Grüßen
        Zentralruf der Autoversicherer
        """;

    [Fact]
    public void Parse_Zwischennachricht_SetztFlagUndKeineVersichererdaten()
    {
        var data = _parser.Parse(ZwischennachrichtMail);

        data.Zwischennachricht.Should().BeTrue();
        data.KeinVersichererErmittelt.Should().BeFalse();
        data.VersichererName.Should().BeNull();
        data.UnfallDatum.Should().Be("09.03.2026");
    }

    [Fact]
    public void Warnings_Zwischennachricht_ErklaertDenFall()
    {
        var warnings = ZentralrufReplyWarnings.Collect(_parser.Parse(ZwischennachrichtMail));

        warnings.Should().ContainSingle(w => w.Contains("Zwischennachricht"));
    }

    [Fact]
    public void Parse_AuslandsfallGrueneKarte_GiltAlsZwischennachricht()
    {
        const string mail = """
            Ihre Anfrage vom 08.04.2026
            Ihr Zeichen: 84/26 C03_GG-XY 123

            Bei ausländischen Kennzeichen ermitteln wir derzeit das zuständige deutsche Regulierungsbüro (Grüne Karte).
            Wir melden uns, sobald uns das Ergebnis vorliegt.
            """;

        var data = _parser.Parse(mail);

        data.Zwischennachricht.Should().BeTrue();
        data.Referenz.Should().Be("84/26 C03_GG-XY 123");
    }

    [Fact]
    public void Parse_PositivUndNegativAntwort_SindKeineZwischennachricht()
    {
        const string negativMail = """
            zu dem Kennzeichen GG XY 123 konnte leider kein Versicherer zum Unfalldatum 09.03.2026 ermittelt werden.
            """;
        const string positivMail = """
            zu dem Kennzeichen GG XY 123 konnte folgender Versicherer zum Unfalldatum 09.03.2026 ermittelt werden:

            HUK-COBURG
            Lyoner Str. 10
            60524 Frankfurt
            """;

        _parser.Parse(negativMail).Zwischennachricht.Should().BeFalse();
        _parser.Parse(positivMail).Zwischennachricht.Should().BeFalse();
    }

    [Fact]
    public void Parse_DatenblattFormat_ExtrahiertBeschrifteteFelder()
    {
        const string datenblattMail = """
            Ihre Anfrage an den Zentralruf der Autoversicherer - Vorgangsnummer: 12345678

            Sehr geehrte Damen und Herren,

            zu Ihrer Anfrage vom 08.04.2026 teilen wir Ihnen nachfolgend die ermittelten Versicherungsdaten mit:

            Abgefragtes Kennzeichen: GG XY 123
            Schadentag: 09.03.2026
            Name der Versicherung: Allianz Versicherungs-AG
            Versicherungsscheinnummer / Policennummer: 40/1234/56789
            Anschrift der Versicherung: Königinstraße 28, 80802 München
            Telefonnummer / Kontakt: 0800/1234567

            Mit freundlichen Grüßen
            Zentralruf der Autoversicherer
            """;

        var data = _parser.Parse(datenblattMail);

        data.Kennzeichen.Should().Be("GG-XY 123");
        data.UnfallDatum.Should().Be("09.03.2026");
        data.VersichererName.Should().Be("Allianz Versicherungs-AG");
        data.VersicherungsscheinNr.Should().Be("40/1234/56789");
        data.VersichererStrasse.Should().Be("Königinstraße 28");
        data.VersichererPlz.Should().Be("80802");
        data.VersichererOrt.Should().Be("München");
        data.VersichererTelefon.Should().Be("0800/1234567");
        data.Zwischennachricht.Should().BeFalse();
        data.KeinVersichererErmittelt.Should().BeFalse();
    }

    [Fact]
    public void Parse_Blockformat_BehaeltVorrangVorDatenblattFallback()
    {
        // Enthält eine Mail beide Muster, gewinnt der bewährte Blockparser.
        const string mail = """
            zu dem Kennzeichen GG XY 123 konnte folgender Versicherer zum Unfalldatum 09.03.2026 ermittelt werden:

            HUK-COBURG
            Lyoner Str. 10
            60524 Frankfurt
            Versicherungsschein-Nr.: 999/123456-X

            Name der Versicherung: Andere Versicherung AG
            """;

        var data = _parser.Parse(mail);

        data.VersichererName.Should().Be("HUK-COBURG");
        data.VersicherungsscheinNr.Should().Be("999/123456-X");
    }
}
