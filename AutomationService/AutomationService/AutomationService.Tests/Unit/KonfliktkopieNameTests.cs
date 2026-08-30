using AutomationService.Features.Settings.Domain.Services;
using AutomationService.Features.Vorgaenge.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Welcher Dateiname neben dem Register-Spiegel als Konfliktkopie gilt (§6.2,
/// #40).
///
/// Die Frage hat zwei Seiten, und die zweite wiegt schwerer: Die Oberfläche
/// zeigt einen Treffer in Fehlerfarbe und rät, die Kopie anzusehen und danach
/// zu löschen. Ein Fehlalarm fordert den Anwalt also auf, eine Datei
/// wegzuwerfen, die niemand kopiert hat — und im selben Ordner liegt das
/// gewachsene Kanzleidokument.
/// </summary>
public sealed class KonfliktkopieNameTests
{
    const string Basis = RegisterSpiegelVorgabe.Dateiname;

    /// <summary>
    /// Was die verbreiteten Dienste tatsächlich anhängen. OneDrive nimmt den
    /// Rechnernamen, Explorer zählt oder schreibt „Kopie", Dropbox schreibt es
    /// aus.
    /// </summary>
    [Theory]
    [InlineData("Sachgebiete-Register (App)-LAPTOP-ANWALT")]
    [InlineData("Sachgebiete-Register (App)-DESKTOP-4711 (2)")]
    [InlineData("Sachgebiete-Register (App) (1)")]
    [InlineData("Sachgebiete-Register (App)(3)")]
    [InlineData("Sachgebiete-Register (App) - Kopie")]
    [InlineData("Sachgebiete-Register (App) - Kopie (2)")]
    [InlineData("Sachgebiete-Register (App)-Kopie")]
    [InlineData("Sachgebiete-Register (App) - Copy")]
    [InlineData("Sachgebiete-Register (App) (in Konflikt stehende Kopie von Anwalt 2026-08-30)")]
    [InlineData("Sachgebiete-Register (App) (LAPTOP-ANWALT's conflicted copy 2026-08-30)")]
    public void Erkennt_WasEinSynchronisierungsdienstHinterlaesst(string name)
    {
        KonfliktkopieName.Erkennt(Basis, name).Should().BeTrue();
    }

    /// <summary>
    /// Der eigentliche Punkt dieser Klasse. Alle vier fingen mit dem
    /// Basisnamen an und galten deshalb als Konfliktkopie — obwohl es
    /// eigenständige Dateien des Anwenders sind, die im selben Ordner liegen
    /// dürfen.
    /// </summary>
    [Theory]
    [InlineData("Sachgebiete-Register (App) Erläuterung")]
    [InlineData("Sachgebiete-Register (App) Stand 2026")]
    [InlineData("Sachgebiete-Register (App) alte Fassung")]
    [InlineData("Sachgebiete-Register (App)_Archiv")]
    public void ErkenntNicht_WasNurSoAehnlichHeisst(string name)
    {
        KonfliktkopieName.Erkennt(Basis, name).Should().BeFalse();
    }

    [Fact]
    public void ErkenntNicht_DenSpiegelSelbst()
    {
        KonfliktkopieName.Erkennt(Basis, Basis).Should().BeFalse();
    }

    [Fact]
    public void ErkenntNicht_WasGarNichtSoAnfaengt()
    {
        KonfliktkopieName.Erkennt(Basis, "Sachgebiete_laufende Nummern_ab 2018")
            .Should().BeFalse();
    }

    /// <summary>
    /// Der Basisname ist einstellbar — die Regel darf nicht an der Vorgabe
    /// hängen.
    /// </summary>
    [Fact]
    public void GiltAuchFuerEinenEingestelltenNamen()
    {
        KonfliktkopieName.Erkennt("Register", "Register-LAPTOP").Should().BeTrue();
        KonfliktkopieName.Erkennt("Register", "Register Notizen").Should().BeFalse();
    }
}
