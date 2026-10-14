using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.Aktualisierung.Presentation.Dtos;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// <c>fehlerArt</c> (#196): An jeder Stelle, an der die Aktualisierung in
/// <c>fehler</c> endet, setzt der Dienst neben dem Satz die Ursache — das
/// Frontend wählt danach seinen kurzen Satz und muss den Wortlaut der Meldung
/// nicht mehr deuten. Hier jede Fehlerstelle einzeln; den Weg durch den
/// Dienst (auch den verweigerten Installer-Start) zeigen die Download-,
/// Installations- und Dienst-Tests.
/// </summary>
public sealed class AktualisierungsFehlerArtTests
{
    public static TheoryData<string, Exception, AktualisierungsFehlerArt, string> Downloadfehler => new()
    {
        { "Leerlauf", new TimeoutException(), AktualisierungsFehlerArt.Verbindung, AktualisierungsMeldungen.Stockt },
        { "abgerissen", new HttpRequestException("weg"), AktualisierungsFehlerArt.Verbindung, AktualisierungsMeldungen.Unterbrochen },
        { "Netz-E/A", new IOException("Verbindung getrennt"), AktualisierungsFehlerArt.Verbindung, AktualisierungsMeldungen.Unterbrochen },
        {
            "mehr als angekündigt",
            new InvalidDataException(),
            AktualisierungsFehlerArt.Pruefung,
            AktualisierungsMeldungen.Fuer(SetupPruefErgebnis.PruefsummeFalsch)
        },
        { "kein Schreibrecht", new UnauthorizedAccessException(), AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.NichtGespeichert },
        // ERROR_DISK_FULL und ERROR_HANDLE_DISK_FULL als HRESULT.
        { "Platte voll", new IOException("voll", unchecked((int)0x80070070)), AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.NichtGespeichert },
        { "Handle voll", new IOException("voll", unchecked((int)0x80070027)), AktualisierungsFehlerArt.Sonstig, AktualisierungsMeldungen.NichtGespeichert },
    };

    [Theory]
    [MemberData(nameof(Downloadfehler))]
    public void Ein_gescheiterter_Download_traegt_seine_Ursache(
        string fall,
        Exception ausnahme,
        AktualisierungsFehlerArt art,
        string meldung)
    {
        var fehler = SetupBeschaffung.FehlerZu(ausnahme);

        fehler.Art.Should().Be(art, fall);
        fehler.Meldung.Should().Be(meldung, fall);
    }

    [Theory]
    [InlineData(SetupPruefErgebnis.GroesseFalsch, AktualisierungsFehlerArt.Pruefung)]
    [InlineData(SetupPruefErgebnis.PruefsummeFalsch, AktualisierungsFehlerArt.Pruefung)]
    [InlineData(SetupPruefErgebnis.Fehlt, AktualisierungsFehlerArt.Sonstig)]
    public void Eine_gescheiterte_Pruefung_traegt_ihre_Ursache(SetupPruefErgebnis ergebnis, AktualisierungsFehlerArt art)
    {
        var fehler = AktualisierungsFehler.Zu(ergebnis);

        fehler.Art.Should().Be(art);
        fehler.Meldung.Should().Be(AktualisierungsMeldungen.Fuer(ergebnis));
    }

    [Theory]
    [InlineData(AuswahlArt.OhnePruefsumme)]
    [InlineData(AuswahlArt.OhneSetup)]
    public void Ein_unvollstaendiges_Release_ist_sonstig(AuswahlArt auswahl)
    {
        var version = Versionsnummer.Lies("1.4.0");

        var (zustand, fehler) = new SetupAuswahlErgebnis(auswahl, version, null, "https://example.invalid/x.exe").Bewertung();

        zustand.Should().Be(AktualisierungsZustand.Fehler);
        fehler!.Art.Should().Be(AktualisierungsFehlerArt.Sonstig, "nur der Satz des Dienstes sagt, dass es an der Veröffentlichung liegt");
        fehler.Meldung.Should().Contain("1.4.0");
    }

    [Theory]
    [InlineData(AuswahlArt.KeinUpdate)]
    [InlineData(AuswahlArt.Verfuegbar)]
    public void Ohne_Fehler_keine_Ursache(AuswahlArt auswahl)
    {
        var (_, fehler) = new SetupAuswahlErgebnis(auswahl, null, null, null).Bewertung();

        fehler.Should().BeNull();
    }

    [Theory]
    [InlineData(AktualisierungsFehlerArt.Verbindung, "verbindung")]
    [InlineData(AktualisierungsFehlerArt.Pruefung, "pruefung")]
    [InlineData(AktualisierungsFehlerArt.Sonstig, "sonstig")]
    public void Auf_der_Leitung_steht_der_ausgeschriebene_Wert(AktualisierungsFehlerArt art, string text)
    {
        var stand = new AktualisierungsStand("1.3.0", "1.4.0", AktualisierungsZustand.Fehler, 0, 10, "Satz", art, null, null);

        AktualisierungsStandDto.From(stand).FehlerArt.Should().Be(text);
    }

    [Fact]
    public void Jede_Art_hat_einen_Wert_und_ohne_Fehler_steht_null()
    {
        Enum.GetValues<AktualisierungsFehlerArt>()
            .Select(art => AktualisierungsStandDto.FehlerArtAlsText(art))
            .Should().OnlyHaveUniqueItems().And.NotContainNulls("eine neue Art braucht ihren Wert im Vertrag");
        AktualisierungsStandDto.FehlerArtAlsText(null).Should().BeNull();
        AktualisierungsStandDto.FehlerArtAlsText((AktualisierungsFehlerArt)99).Should().BeNull();
    }
}
