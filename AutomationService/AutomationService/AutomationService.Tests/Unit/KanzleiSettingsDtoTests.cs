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
        AppDatenOrdner: string.Empty,
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

    const string Wurzel = @"C:\Users\Meier\OneDrive - Kanzlei";

    static readonly Func<string, string?> MitGeschaeftskonto =
        name => name == "OneDriveCommercial" ? Wurzel : null;

    /// <summary>
    /// Die Umrechnungsgrenze (#103): Das Frontend schickt zurück, was der
    /// Ordnerdialog geliefert hat — einen absoluten Pfad. Relativ gemacht wird
    /// er hier, im Backend, sonst wandert die Pfadmathematik in zwei Sprachen.
    /// </summary>
    [Fact]
    public void ToEntity_SpeichertOrdnerUnterOneDriveRelativ()
    {
        var entity = Dto(RegisterSpiegelVorgabe.FilterAlle) with
        {
            AppDatenOrdner = $@"{Wurzel}\Kanzlei App Daten",
            AktenStammordner = @"D:\Kanzlei\Akten",
        };

        var gespeichert = entity.ToEntity(MitGeschaeftskonto);

        gespeichert.AppDatenOrdner.Should().Be(@"%OneDriveCommercial%\Kanzlei App Daten");
        gespeichert.AktenStammordner.Should().Be(@"D:\Kanzlei\Akten",
            "was ausserhalb liegt, bleibt absolut");
    }

    [Fact]
    public void From_LiefertDenAufgeloestenPfadHinaus()
    {
        var entity = Dto(RegisterSpiegelVorgabe.FilterAlle)
            .ToEntity(MitGeschaeftskonto);
        entity.AppDatenOrdner = @"%OneDriveCommercial%\Kanzlei App Daten";

        KanzleiSettingsDto.From(entity, MitGeschaeftskonto).AppDatenOrdner
            .Should().Be($@"{Wurzel}\Kanzlei App Daten");
    }

    /// <summary>
    /// Der Rechner ohne dieses Konto zeigt die Speicherform statt eines leeren
    /// Felds. Ein leeres Feld ginge beim nächsten Speichern als „gelöscht"
    /// zurück und nähme dem anderen Rechner seine gültige Einstellung.
    /// </summary>
    [Fact]
    public void From_ZeigtDieSpeicherform_WennDerAnkerHierFehlt()
    {
        var entity = Dto(RegisterSpiegelVorgabe.FilterAlle).ToEntity(MitGeschaeftskonto);
        entity.AppDatenOrdner = @"%OneDriveCommercial%\Kanzlei App Daten";

        KanzleiSettingsDto.From(entity, _ => null).AppDatenOrdner
            .Should().Be(@"%OneDriveCommercial%\Kanzlei App Daten");
    }

    static readonly Func<string, string?> MitZweiKontenAufDerselbenWurzel =
        name => name is "OneDriveCommercial" or "OneDrive" ? Wurzel : null;

    /// <summary>
    /// Anker-Drift (Review-Befund #103): <c>From</c> liefert den aufgeloesten
    /// absoluten Pfad hinaus, das Frontend schickt ihn beim Speichern
    /// unveraendert zurueck. Zeigen zwei Variablen auf denselben Ordner, muss
    /// <c>ToEntity</c> mit dem bisherigen Stand denselben Anker
    /// wiederherstellen statt ihn neu gegen die Vorzugsreihenfolge zu
    /// bestimmen — sonst wechselt die Speicherform bei jedem Speichern.
    /// </summary>
    [Fact]
    public void FromDannToEntity_MitBisherigemStand_VeraendertDieSpeicherformNicht()
    {
        var gespeichert = (Dto(RegisterSpiegelVorgabe.FilterAlle) with
        {
            AppDatenOrdner = @"%OneDrive%\Kanzlei App Daten",
        }).ToEntity(MitZweiKontenAufDerselbenWurzel);

        var angezeigt = KanzleiSettingsDto.From(gespeichert, MitZweiKontenAufDerselbenWurzel);
        var erneutGespeichert = angezeigt.ToEntity(gespeichert, MitZweiKontenAufDerselbenWurzel);

        erneutGespeichert.AppDatenOrdner.Should().Be(@"%OneDrive%\Kanzlei App Daten");
    }
}
