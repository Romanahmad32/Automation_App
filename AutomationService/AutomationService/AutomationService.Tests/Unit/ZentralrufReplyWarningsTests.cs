using AutomationService.Features.ZentralrufAutomation.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Der Abgleich „angefragtes Kennzeichen ↔ Kennzeichen in der Referenz". Seit
/// #144 schreibt der Parser nichts mehr um: Die Mail sagt <c>GG XY 123</c>, die
/// Referenz <c>GG-XY 123</c>. Das ist derselbe Wagen und darf keine Warnung
/// auslösen — sonst stünde sie unter jeder gewöhnlichen Antwort.
/// </summary>
public class ZentralrufReplyWarningsTests
{
    const string AbweichungsHinweis = "stimmt nicht mit dem Kennzeichen";

    [Theory]
    [InlineData("GG XY 123", "GG-XY 123")]
    [InlineData("HGE1427", "H-GE 1427")]
    [InlineData("123 abc", "123 ABC")]
    public void KeineWarnung_WennBeideDenselbenWagenNennen(string kennzeichen, string referenzKennzeichen)
    {
        ZentralrufReplyWarnings.Collect(Daten(kennzeichen, referenzKennzeichen))
            .Should().NotContain(warnung => warnung.Contains(AbweichungsHinweis));
    }

    [Fact]
    public void Warnung_WennEsEinAnderesFahrzeugIst()
    {
        ZentralrufReplyWarnings.Collect(Daten("HG-E 1427", "H-GE 1427"))
            .Should().ContainSingle(warnung => warnung.Contains(AbweichungsHinweis));
    }

    static ZentralrufReplyData Daten(string kennzeichen, string referenzKennzeichen) => new()
    {
        Referenz = $"84/26 C03_{referenzKennzeichen}",
        ReferenzAuftragsnummer = "84",
        ReferenzJahr = "26",
        ReferenzAbteilung = "C03",
        ReferenzKennzeichen = referenzKennzeichen,
        Kennzeichen = kennzeichen,
    };
}
