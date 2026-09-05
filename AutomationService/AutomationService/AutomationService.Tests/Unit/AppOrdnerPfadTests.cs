using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Pfadmathematik hinter #103: Ordner unterhalb des synchronisierten
/// Wurzelordners werden relativ gespeichert und auf jedem Rechner gegen
/// <em>dessen</em> Wurzel wieder aufgeloest.
///
/// Zwei Dinge duerfen hier niemals passieren, und beide waeren lautlos:
/// Ein Pfad, der nur zufaellig wie ein Kindordner aussieht (C:\OneDriveAlt
/// neben C:\OneDrive), wuerde relativiert und zeigte spaeter woanders hin —
/// und ein gegen das Geschaeftskonto gespeicherter Pfad wuerde auf einem
/// Rechner ohne dieses Konto in den privaten Baum aufgeloest. Deshalb stehen
/// beide Faelle namentlich als Test.
/// </summary>
public sealed class AppOrdnerPfadTests
{
    const string Geschaeft = @"C:\Users\Meier\OneDrive - Kanzlei";
    const string Privat = @"C:\Users\Meier\OneDrive";

    static Func<string, string?> Umgebung(params (string Name, string Wert)[] eintraege) =>
        name => eintraege.FirstOrDefault(e => e.Name == name).Wert;

    [Fact]
    public void MacheRelativ_ErsetztDenWurzelordnerDurchDenAnker()
    {
        AppOrdnerPfad
            .MacheRelativ($@"{Geschaeft}\Kanzlei App Daten", Umgebung(("OneDriveCommercial", Geschaeft)))
            .Should().Be(@"%OneDriveCommercial%\Kanzlei App Daten");
    }

    [Fact]
    public void MacheRelativ_NimmtDasGeschaeftskontoZuerst()
    {
        // Beide Konten eingerichtet, der Ordner liegt im geschaeftlichen: Der
        // Anker muss das treffen, gegen das wirklich gerechnet wurde.
        AppOrdnerPfad
            .MacheRelativ(
                $@"{Geschaeft}\Kanzlei App Daten",
                Umgebung(("OneDriveCommercial", Geschaeft), ("OneDriveConsumer", Privat)))
            .Should().Be(@"%OneDriveCommercial%\Kanzlei App Daten");
    }

    [Fact]
    public void MacheRelativ_LaesstEinenPfadAusserhalbAbsolut()
    {
        AppOrdnerPfad
            .MacheRelativ(@"D:\Kanzlei\Akten", Umgebung(("OneDrive", Privat)))
            .Should().Be(@"D:\Kanzlei\Akten");
    }

    /// <summary>
    /// Die Trenner-Falle: C:\OneDriveAlt faengt zeichenweise mit C:\OneDrive an,
    /// liegt aber daneben und nicht darin. Ohne den Trenner am Ende wuerde er
    /// relativiert — und der Rest ("Alt\Daten") loeste auf dem zweiten Rechner
    /// in einen Ordner auf, den es nie gab.
    /// </summary>
    [Fact]
    public void MacheRelativ_FaelltNichtAufEinenGleichnamigenNachbarordnerHerein()
    {
        AppOrdnerPfad
            .MacheRelativ(@"C:\OneDriveAlt\Daten", Umgebung(("OneDrive", @"C:\OneDrive")))
            .Should().Be(@"C:\OneDriveAlt\Daten");
    }

    [Fact]
    public void MacheRelativ_IstUnempfindlichGegenGrossKleinschreibung()
    {
        AppOrdnerPfad
            .MacheRelativ(@"c:\onedrive\Kanzlei App Daten", Umgebung(("OneDrive", @"C:\OneDrive")))
            .Should().Be(@"%OneDrive%\Kanzlei App Daten");
    }

    [Fact]
    public void MacheRelativ_LaesstDieSpeicherformUnangetastet()
    {
        AppOrdnerPfad
            .MacheRelativ(@"%OneDriveCommercial%\Kanzlei App Daten", Umgebung(("OneDrive", Privat)))
            .Should().Be(@"%OneDriveCommercial%\Kanzlei App Daten");
    }

    [Fact]
    public void MacheRelativ_LaesstLeerLeer()
    {
        AppOrdnerPfad.MacheRelativ("   ", Umgebung(("OneDrive", Privat))).Should().BeEmpty();
    }

    /// <summary>
    /// Anker-Drift (Review-Befund #103): Das Frontend zeigt den aufgeloesten
    /// absoluten Pfad an und schickt ihn beim Speichern unveraendert zurueck.
    /// Zeigen zwei Variablen auf denselben Ordner (hier OneDrive und
    /// OneDriveCommercial), darf daraus nicht bei jedem Speichern ein anderer
    /// Anker werden — der bisherige (%OneDrive%) bleibt, obwohl
    /// OneDriveCommercial in der Vorzugsreihenfolge vorn steht.
    /// </summary>
    [Fact]
    public void MacheRelativ_BehaeltDenBisherigenAnker_WennBeideVariablenAufDieselbeWurzelZeigen()
    {
        var umgebung = Umgebung(("OneDriveCommercial", Geschaeft), ("OneDrive", Geschaeft));

        AppOrdnerPfad
            .MacheRelativ($@"{Geschaeft}\Kanzlei App Daten", @"%OneDrive%\Kanzlei App Daten", umgebung)
            .Should().Be(@"%OneDrive%\Kanzlei App Daten");
    }

    [Fact]
    public void MacheRelativ_NimmtDieVorzugsreihenfolge_WennKeinBisherigerAnkerVorliegt()
    {
        // Feld war bisher nicht gesetzt (kein Anker) — ein neu gewaehlter
        // Ordner rechnet wie eh und je gegen die Vorzugsreihenfolge.
        var umgebung = Umgebung(("OneDriveCommercial", Geschaeft), ("OneDriveConsumer", Privat));

        AppOrdnerPfad
            .MacheRelativ($@"{Geschaeft}\Kanzlei App Daten", bisher: "", umgebung)
            .Should().Be(@"%OneDriveCommercial%\Kanzlei App Daten");
    }

    /// <summary>
    /// Der Anwalt hat den Ordner wirklich gewechselt: der neue Pfad liegt nicht
    /// mehr unter der Wurzel des bisherigen Ankers. Dann gilt wieder die
    /// Vorzugsreihenfolge statt eines Ankers, der ins Leere zeigen wuerde.
    /// </summary>
    [Fact]
    public void MacheRelativ_FaelltAufDieVorzugsreihenfolgeZurueck_WennDerNeuePfadAusserhalbDesBisherigenAnkersLiegt()
    {
        var umgebung = Umgebung(("OneDriveCommercial", Geschaeft), ("OneDrive", Privat));

        AppOrdnerPfad
            .MacheRelativ($@"{Privat}\Kanzlei App Daten", @"%OneDriveCommercial%\Alt", umgebung)
            .Should().Be(@"%OneDrive%\Kanzlei App Daten");
    }

    /// <summary>
    /// Bewusst: Der Wurzelordner selbst liegt nicht "unterhalb" seiner selbst,
    /// er IST die Wurzel — die App legt darunter Unterordner an, nicht in ihm
    /// selbst. Wuerde er trotzdem relativiert, entstuende ein Anker mit leerem
    /// Rest, ein Fall, den <see cref="AppOrdnerPfad.LoeseAuf(string?, Func{string, string?})"/>
    /// gar nicht erst vorsieht.
    /// </summary>
    [Fact]
    public void MacheRelativ_LaesstDenWurzelordnerSelbstAbsolut()
    {
        AppOrdnerPfad
            .MacheRelativ(Privat, Umgebung(("OneDrive", Privat)))
            .Should().Be(Privat);
    }

    [Fact]
    public void LoeseAuf_LoestVorwaertsSchraegstrichAuf()
    {
        AppOrdnerPfad
            .LoeseAuf("%OneDrive%/Kanzlei App Daten", Umgebung(("OneDrive", Privat)))
            .Should().Be($@"{Privat}\Kanzlei App Daten");
    }

    [Fact]
    public void LoeseAuf_RechnetGegenDieWurzelDiesesRechners()
    {
        // Derselbe gespeicherte Wert, eine andere Wurzel: der zweite
        // Arbeitsplatz stellt nichts ein und trifft trotzdem seinen Ordner.
        AppOrdnerPfad
            .LoeseAuf(
                @"%OneDriveCommercial%\Kanzlei App Daten",
                Umgebung(("OneDriveCommercial", @"D:\Andere\OneDrive - Kanzlei")))
            .Should().Be(@"D:\Andere\OneDrive - Kanzlei\Kanzlei App Daten");
    }

    /// <summary>
    /// Der Anker ist der Kern von #103: Ohne ihn loeste derselbe relative Pfad
    /// auf einem Rechner mit nur privatem OneDrive still in den privaten Baum
    /// auf — die App legte Sicherungen in einem anderen Konto ab, ohne dass
    /// jemand etwas merkte.
    /// </summary>
    [Fact]
    public void LoeseAuf_WeichtNichtAufEinAnderesKontoAus()
    {
        AppOrdnerPfad
            .LoeseAuf(
                @"%OneDriveCommercial%\Kanzlei App Daten",
                Umgebung(("OneDriveConsumer", Privat), ("OneDrive", Privat)))
            .Should().BeNull();
    }

    [Fact]
    public void LoeseAuf_LaesstAbsolutesUndLeeresUnangetastet()
    {
        var umgebung = Umgebung(("OneDrive", Privat));

        AppOrdnerPfad.LoeseAuf(@"  D:\Kanzlei\Akten  ", umgebung).Should().Be(@"D:\Kanzlei\Akten");
        AppOrdnerPfad.LoeseAuf(string.Empty, umgebung).Should().BeEmpty();
        AppOrdnerPfad.LoeseAuf(null, umgebung).Should().BeEmpty();
    }

    [Fact]
    public void LoeseAuf_KenntDenAnkerAuchInAndererSchreibweise()
    {
        AppOrdnerPfad
            .LoeseAuf(@"%onedrivecommercial%\Daten", Umgebung(("OneDriveCommercial", Geschaeft)))
            .Should().Be($@"{Geschaeft}\Daten");
    }

    [Fact]
    public void HinUndZurueck_ErgibtDenselbenOrdner()
    {
        var umgebung = Umgebung(("OneDriveCommercial", Geschaeft));
        var ordner = $@"{Geschaeft}\Kanzlei App Daten\Sicherungen";

        var gespeichert = AppOrdnerPfad.MacheRelativ(ordner, umgebung);

        AppOrdnerPfad.LoeseAuf(gespeichert, umgebung).Should().Be(ordner);
    }

    [Theory]
    [InlineData(@"%OneDriveCommercial%\Daten", true, "OneDriveCommercial")]
    [InlineData(@"%OneDrive%\Daten", true, "OneDrive")]
    [InlineData(@"%onedrive%\Daten", true, "OneDrive")]
    [InlineData(@"C:\Daten", false, null)]
    [InlineData("", false, null)]
    // Ein hier nicht vorgesehener Anker zaehlt nicht als relativ: Was die
    // Uebernahme mitnimmt, muss die App selbst geschrieben haben.
    [InlineData(@"%USERPROFILE%\Daten", false, null)]
    public void IstRelativ_UndAnker_LesenDieSpeicherform(string wert, bool relativ, string? anker)
    {
        AppOrdnerPfad.IstRelativ(wert).Should().Be(relativ);
        AppOrdnerPfad.Anker(wert).Should().Be(anker);
    }
}
