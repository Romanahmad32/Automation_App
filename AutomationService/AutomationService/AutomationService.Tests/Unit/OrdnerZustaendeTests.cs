using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Die Auskunft hinter <c>GET api/Settings/ordner</c> (#103). Sie ist der
/// Ersatz fuer etwas, das ein einzelnes Textfeld nicht mehr sagen kann: Ein
/// leeres Feld kann trotzdem einen wirksamen Ordner haben, ein gefuelltes kann
/// auf diesem Rechner ins Leere zeigen. Ohne diese Auskunft stuende in den
/// Einstellungen im schlechtesten Fall ein Pfad, den es hier nicht gibt.
/// </summary>
public sealed class OrdnerZustaendeTests : IDisposable
{
    const string Wurzel = @"C:\Users\Meier\OneDrive - Kanzlei";

    readonly SqliteConnection _connection;
    readonly AutomationDbContext _db;

    static readonly Func<string, string?> MitGeschaeftskonto =
        name => name == "OneDriveCommercial" ? Wurzel : null;

    public OrdnerZustaendeTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AutomationDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AutomationDbContext(options);
        _db.Database.EnsureCreated();
    }

    [Fact]
    public void Liefert_immer_genau_fuenf_Eintraege_in_der_vereinbarten_Reihenfolge()
    {
        Ermittle(alleDa: false).Select(z => z.Feld).Should().Equal(
            "appDatenOrdner",
            "aktenStammordner",
            "vorlagenOrdner",
            "registerAblageOrdner",
            "sicherungsAblageOrdner");
    }

    [Fact]
    public void Ohne_jede_Einstellung_ist_nur_der_Vorlagenordner_der_Standard()
    {
        var zustaende = Ermittle(alleDa: false);

        Zustand(zustaende, "appDatenOrdner").Should().Be(OrdnerZustandArten.NichtGesetzt);
        Zustand(zustaende, "aktenStammordner").Should().Be(OrdnerZustandArten.NichtGesetzt);
        Zustand(zustaende, "vorlagenOrdner").Should().Be(OrdnerZustandArten.Standard);
        Zustand(zustaende, "registerAblageOrdner").Should().Be(OrdnerZustandArten.NichtGesetzt);
        Zustand(zustaende, "sicherungsAblageOrdner").Should().Be(OrdnerZustandArten.NichtGesetzt);
    }

    [Fact]
    public void Mit_App_Daten_Ordner_sind_die_drei_uebrigen_abgeleitet()
    {
        Speichere(satz => satz.AppDatenOrdner = @"%OneDriveCommercial%\Kanzlei App Daten");

        var zustaende = Ermittle(alleDa: true);

        Zustand(zustaende, "appDatenOrdner").Should().Be(OrdnerZustandArten.Bereit);
        Zustand(zustaende, "vorlagenOrdner").Should().Be(OrdnerZustandArten.Abgeleitet);
        Zustand(zustaende, "registerAblageOrdner").Should().Be(OrdnerZustandArten.Abgeleitet);
        Zustand(zustaende, "sicherungsAblageOrdner").Should().Be(OrdnerZustandArten.Abgeleitet);

        var appDaten = zustaende.Single(z => z.Feld == "appDatenOrdner");
        appDaten.Gespeichert.Should().Be(@"%OneDriveCommercial%\Kanzlei App Daten");
        appDaten.Wirksam.Should().Be(Path.Combine(Wurzel, "Kanzlei App Daten"));
        appDaten.Anker.Should().Be("OneDriveCommercial");
    }

    /// <summary>
    /// Der Ordner ist noch nicht da — das ist kein Fehler, sondern das gewollte
    /// Verhalten: Angelegt wird beim ersten Schreiben, nicht beim Speichern der
    /// Einstellung.
    /// </summary>
    [Fact]
    public void Ein_noch_nicht_angelegter_Ordner_meldet_ordnerFehlt()
    {
        Speichere(satz => satz.AppDatenOrdner = @"%OneDriveCommercial%\Kanzlei App Daten");

        Zustand(Ermittle(alleDa: false), "appDatenOrdner")
            .Should().Be(OrdnerZustandArten.OrdnerFehlt);
    }

    /// <summary>
    /// Der zweite Rechner ohne Geschaeftskonto: Die Einstellung sagt, was fehlt,
    /// statt einen Pfad ins Leere zu zeigen — und der Dienst laeuft mit dem
    /// bekannten Rueckfall weiter.
    /// </summary>
    [Fact]
    public void Ein_fehlender_Anker_wird_benannt_statt_still_ausgewichen()
    {
        Speichere(satz => satz.AppDatenOrdner = @"%OneDriveCommercial%\Kanzlei App Daten");

        var zustaende = OrdnerZustaende.Ermittle(_db, _ => null, _ => true);
        var appDaten = zustaende.Single(z => z.Feld == "appDatenOrdner");

        appDaten.Zustand.Should().Be(OrdnerZustandArten.AnkerFehlt);
        appDaten.Anker.Should().Be("OneDriveCommercial");
        appDaten.Wirksam.Should().BeEmpty();
        Zustand(zustaende, "vorlagenOrdner").Should().Be(OrdnerZustandArten.Standard);
    }

    [Fact]
    public void Ein_eigens_gewaehlter_Ordner_meldet_sich_als_bereit()
    {
        Speichere(satz =>
        {
            satz.AppDatenOrdner = @"%OneDriveCommercial%\Kanzlei App Daten";
            satz.VorlagenOrdner = @"D:\Kanzlei\Eigene Vorlagen";
        });

        var vorlagen = Ermittle(alleDa: true).Single(z => z.Feld == "vorlagenOrdner");

        vorlagen.Zustand.Should().Be(OrdnerZustandArten.Bereit);
        vorlagen.Wirksam.Should().Be(@"D:\Kanzlei\Eigene Vorlagen");
        vorlagen.Anker.Should().BeEmpty("ein absoluter Pfad hat keinen Anker");
    }

    IReadOnlyList<OrdnerZustand> Ermittle(bool alleDa) =>
        OrdnerZustaende.Ermittle(_db, MitGeschaeftskonto, _ => alleDa);

    static string Zustand(IReadOnlyList<OrdnerZustand> zustaende, string feld) =>
        zustaende.Single(z => z.Feld == feld).Zustand;

    void Speichere(Action<KanzleiSettingsEntity> setze)
    {
        var settings = KanzleiSettingsRepository.CreateDefault();
        setze(settings);
        _db.KanzleiSettings.Add(settings);
        _db.SaveChanges();
        _db.ChangeTracker.Clear();
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }
}
