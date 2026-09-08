using AutomationService.Features.Sachgebiete.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Kürzelregeln (§7.1) müssen auf beiden Seiten dieselbe Antwort geben —
/// das Gegenstück steht in <c>abteilung_kuerzel.dart</c>. Ein Kürzel, das hier
/// anders zerfällt als im Frontend, ordnet dieselbe Registerzeile zwei
/// Sachgebieten zu, und zwar wortlos.
/// </summary>
public sealed class AbteilungKuerzelTests
{
    [Theory]
    [InlineData("C 03o", "C03o")]
    [InlineData("C03o", "C03o")]
    [InlineData("  C 01 a ", "C01a")]
    [InlineData("", "")]
    public void Normalisiere_WirftJedesLeerzeichenHinaus(string eingabe, string erwartet)
    {
        AbteilungKuerzel.Normalisiere(eingabe).Should().Be(erwartet);
    }

    /// <summary>
    /// Ohne Wert eine leere Zeichenkette und keine Ausnahme: Der Bestand hat
    /// Zeilen ohne Abteilung, und die sollen als solche durch die Prüfung
    /// laufen statt sie abzubrechen.
    /// </summary>
    [Fact]
    public void Normalisiere_MachtAusNichtsEineLeereZeichenkette()
    {
        AbteilungKuerzel.Normalisiere(null).Should().BeEmpty();
    }

    [Fact]
    public void Zerlege_TrenntHauptUndNebensachgebiet()
    {
        AbteilungKuerzel.Zerlege("C05/3").Should().Be(("C05", "C03"));
    }

    [Fact]
    public void Zerlege_SetztDemNebenteilSeinPraefixWiederVor()
    {
        AbteilungKuerzel.Zerlege("C05/3o").Should().Be(("C05", "C03o"));
    }

    [Theory]
    [InlineData("C03o")]
    [InlineData("C 03o")]
    public void Zerlege_LaesstOhneSchraegstrichAllesHauptkuerzel(string abteilung)
    {
        AbteilungKuerzel.Zerlege(abteilung).Should().Be(("C03o", (string?)null));
    }

    /// <summary>
    /// Ein Schrägstrich ohne etwas dahinter ist kein Nebensachgebiet, sondern
    /// ein Tippfehler. Er darf keines erfinden — sonst stünde in der Zeile ein
    /// Kürzel „C0", das es im Katalog nicht gibt.
    /// </summary>
    [Fact]
    public void Zerlege_ErfindetKeinNebensachgebietAusEinemLeerenRest()
    {
        AbteilungKuerzel.Zerlege("C05/").Should().Be(("C05", (string?)null));
    }

    [Fact]
    public void Zerlege_KommtOhneWertAus()
    {
        AbteilungKuerzel.Zerlege(null).Should().Be((string.Empty, (string?)null));
    }
}
