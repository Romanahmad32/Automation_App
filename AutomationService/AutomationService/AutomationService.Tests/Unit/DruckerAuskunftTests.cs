using AutomationService.Features.PdfConversion.Domain.Services;
using AutomationService.Features.Vollmacht.Presentation.Dtos;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Was der Vollmacht-Dialog über den Drucker sagt (§4.11, #164): welcher es
/// ist und ob Windows ihn für bereit hält. Die Abfrage selbst braucht einen
/// echten Drucker; geprüft wird hier die Übersetzung dessen, was Windows und
/// Word liefern.
/// </summary>
public sealed class DruckerAuskunftTests
{
    [Theory]
    [InlineData("Brother MFC-7460DN Printer auf Ne01:", "Brother MFC-7460DN Printer")]
    [InlineData("HP LaserJet on Ne02:", "HP LaserJet")]
    [InlineData(@"\\kanzlei-srv\Flur Drucker auf Ne03:", @"\\kanzlei-srv\Flur Drucker")]
    [InlineData("Microsoft Print to PDF on PORTPROMPT:", "Microsoft Print to PDF")]
    [InlineData("Drucker ohne Anschluss", "Drucker ohne Anschluss")]
    [InlineData("  Kanzleidrucker  ", "Kanzleidrucker")]
    public void Word_nennt_den_Drucker_mit_Anschluss_gezeigt_wird_nur_der_Name(string activePrinter, string erwartet)
    {
        WordDruckerName.AusActivePrinter(activePrinter).Should().Be(erwartet);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Ohne_Angabe_von_Word_gibt_es_keinen_Namen(string? activePrinter)
    {
        WordDruckerName.AusActivePrinter(activePrinter).Should().BeNull();
    }

    [Theory]
    [InlineData(0x0u, 0x0u, DruckerZustand.Bereit)]
    [InlineData(0x0u, 0x400u, DruckerZustand.Offline)]
    [InlineData(0x80u, 0x0u, DruckerZustand.Offline)]
    [InlineData(0x1000u, 0x0u, DruckerZustand.Offline)]
    [InlineData(0x8u, 0x0u, DruckerZustand.Gestoert)]
    [InlineData(0x10u, 0x0u, DruckerZustand.Gestoert)]
    [InlineData(0x40000u, 0x0u, DruckerZustand.Gestoert)]
    [InlineData(0x400000u, 0x0u, DruckerZustand.Gestoert)]
    [InlineData(0x1u, 0x0u, DruckerZustand.Angehalten)]
    public void Windows_Status_wird_zum_Zustand(uint status, uint attribute, DruckerZustand erwartet)
    {
        WindowsDruckerAuskunft.ZustandAus(status, attribute).Should().Be(erwartet);
    }

    /// <summary>
    /// Offline schlägt alles andere: Ein angehaltener Drucker, der zugleich
    /// offline ist, druckt auch nach dem Fortsetzen nicht.
    /// </summary>
    [Fact]
    public void Offline_wiegt_schwerer_als_Stoerung_und_Pause()
    {
        WindowsDruckerAuskunft.ZustandAus(0x1u | 0x8u, 0x400u).Should().Be(DruckerZustand.Offline);
    }

    /// <summary>
    /// Die echte Abfrage über <c>winspool.drv</c>. Was sie liefert, hängt am
    /// Rechner (der CI-Läufer hat vielleicht gar keinen Drucker) — geprüft wird,
    /// dass sie nicht wirft und ihre Antwort in sich stimmt. Eine falsche
    /// Signatur oder ein falsches <c>PRINTER_INFO_2</c> fiele hier auf, nicht
    /// erst beim Öffnen des Dialogs.
    /// </summary>
    [Fact]
    public void Die_echte_Abfrage_wirft_nicht_und_antwortet_stimmig()
    {
        if (!OperatingSystem.IsWindows())
        {
            return;
        }

        var lage = new WindowsDruckerAuskunft(NullLogger<WindowsDruckerAuskunft>.Instance).Standarddrucker();

        if (lage.Name is null)
        {
            lage.Zustand.Should().Be(DruckerZustand.KeinDrucker);
        }
        else
        {
            lage.Zustand.Should().NotBe(DruckerZustand.KeinDrucker);
        }
    }

    [Fact]
    public void Ein_bereiter_Drucker_braucht_keinen_Hinweis()
    {
        var dto = VollmachtDruckerDto.From(new DruckerLage("Kanzleidrucker", DruckerZustand.Bereit));

        dto.Should().Be(new VollmachtDruckerDto("Kanzleidrucker", "bereit", null));
    }

    [Theory]
    [InlineData(DruckerZustand.Offline, "offline")]
    [InlineData(DruckerZustand.Gestoert, "gestoert")]
    [InlineData(DruckerZustand.Angehalten, "angehalten")]
    [InlineData(DruckerZustand.Unbekannt, "unbekannt")]
    public void Jeder_andere_Zustand_sagt_in_Worten_was_los_ist(DruckerZustand zustand, string wert)
    {
        var dto = VollmachtDruckerDto.From(new DruckerLage("Kanzleidrucker", zustand));

        dto.Zustand.Should().Be(wert);
        dto.Name.Should().Be("Kanzleidrucker");
        dto.Hinweis.Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public void Ohne_Standarddrucker_gibt_es_keinen_Namen()
    {
        var dto = VollmachtDruckerDto.From(new DruckerLage(null, DruckerZustand.KeinDrucker));

        dto.Name.Should().BeNull();
        dto.Zustand.Should().Be("keinDrucker");
        dto.Hinweis.Should().Contain("kein Standarddrucker");
    }
}
