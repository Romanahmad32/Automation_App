using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Settings.Presentation.Dtos;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Was über <c>PUT api/Settings/kanzlei</c> hereinkommt, landet auf der Platte
/// — und muss dort so liegen, dass die Oberfläche es wieder anzeigen kann.
///
/// Der Register-Filter ist die Stelle, an der das auseinanderfallen konnte: Der
/// Spiegel liest ihn absichtlich tolerant (ein unbekannter Wert bedeutet „alle
/// Vorgänge"), das Auswahlfeld in den Einstellungen kennt aber genau zwei
/// Einträge. Ein gespeichertes „" brachte <c>ReactiveDropdownField</c> beim
/// nächsten Öffnen zum Abbruch — die Einstellungsseite liess sich dann gar
/// nicht mehr aufschlagen, ausgerechnet die Seite, auf der man es hätte
/// richtigstellen können.
/// </summary>
public sealed class KanzleiSettingsDtoTests
{
    static KanzleiSettingsDto Dto(string filter) => new(
        Personentyp: "kanzlei",
        Name: "Kanzlei Muster",
        StrasseHausnummer: "Hauptstr. 1",
        Postleitzahl: "61348",
        Ort: "Bad Homburg",
        EmailAdresse: "kanzlei@example.org",
        Telefonnummer: "06172 1234",
        LaufendeAuftragsnummer: 1,
        Abteilung: "C03",
        TabellenkopfFarbeHex: "#123456",
        AktenStammordner: @"C:\Akten",
        MailSignatur: string.Empty,
        MailSignaturHtml: string.Empty,
        RegisterAblageOrdner: @"C:\OneDrive\Kanzlei-Register",
        RegisterDateiname: RegisterSpiegelVorgabe.Dateiname,
        RegisterNachAbschlussSchreiben: true,
        RegisterExportFilter: filter,
        VorlagenOrdner: @"C:\Kanzlei\Vorlagen",
        SicherungsAblageOrdner: @"C:\OneDrive\Kanzlei-Sicherungen");

    [Theory]
    [InlineData("abgeschlossen")]
    [InlineData("Abgeschlossen")]
    [InlineData("  abgeschlossen  ")]
    public void ToEntity_HaeltDenFilterAufDemBekanntenWertFest(string filter)
    {
        Dto(filter).ToEntity().RegisterExportFilter
            .Should().Be(RegisterSpiegelVorgabe.FilterAbgeschlossen);
    }

    /// <summary>
    /// Alles, was nicht „abgeschlossen" heisst, wird zu „alle" — dem Wert, den
    /// der Spiegel ohnehin daraus liest. Gespeichert wird jetzt derselbe.
    /// </summary>
    [Theory]
    [InlineData("alle")]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("vielleicht")]
    public void ToEntity_MachtAusAllemUebrigenDieVorgabe(string filter)
    {
        Dto(filter).ToEntity().RegisterExportFilter
            .Should().Be(RegisterSpiegelVorgabe.FilterAlle);
    }
}
