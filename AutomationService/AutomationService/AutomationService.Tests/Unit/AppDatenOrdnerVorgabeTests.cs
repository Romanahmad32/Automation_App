using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;
using FluentAssertions;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Aus einer Ordnerwahl werden vier (#103): Wer nur den App-Daten-Ordner setzt,
/// bekommt Vorlagen, Register und Sicherungen darunter — ohne je einen zweiten
/// Dialog gesehen zu haben. Wer einen der drei eigens gewaehlt hat, behaelt ihn.
///
/// Der dritte Fall ist der stille: ein relativ gespeicherter Ordner, dessen
/// Anker auf diesem Rechner fehlt. Er zaehlt ausdruecklich wie „nicht gesetzt" —
/// die Alternative waere, in einen fremden OneDrive-Baum zu schreiben.
/// </summary>
public sealed class AppDatenOrdnerVorgabeTests : IDisposable
{
    const string Wurzel = @"C:\Users\Meier\OneDrive - Kanzlei";
    const string AppDaten = @"C:\Users\Meier\OneDrive - Kanzlei\Kanzlei App Daten";

    readonly SqliteConnection _connection;
    readonly AutomationDbContext _db;

    static readonly Func<string, string?> MitGeschaeftskonto =
        name => name == "OneDriveCommercial" ? Wurzel : null;

    static readonly Func<string, string?> OhneOneDrive = _ => null;

    public AppDatenOrdnerVorgabeTests()
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
    public void Ohne_AppDatenOrdner_gibt_es_nichts_abzuleiten()
    {
        Speichere(satz => satz.AppDatenOrdner = string.Empty);

        AppDatenOrdnerVorgabe.Ermittle(_db, MitGeschaeftskonto).Should().BeEmpty();
        RegisterAblageVorgabe.Ermittle(_db, MitGeschaeftskonto).Should().BeEmpty();
        SicherungsAblageVorgabe.Ermittle(_db, MitGeschaeftskonto).Should().BeEmpty();
        VorlagenOrdnerVorgabe.Eingestellt(_db, MitGeschaeftskonto).Should().BeEmpty();
        VorlagenOrdnerVorgabe.Ermittle(_db, MitGeschaeftskonto)
            .Should().Be(AppDataPaths.EnsureVorlagenDirectory());
    }

    [Fact]
    public void Ein_gesetzter_AppDatenOrdner_traegt_alle_drei_Unterordner()
    {
        Speichere(satz => satz.AppDatenOrdner = AppDaten);

        AppDatenOrdnerVorgabe.Ermittle(_db, MitGeschaeftskonto).Should().Be(AppDaten);
        VorlagenOrdnerVorgabe.Eingestellt(_db, MitGeschaeftskonto)
            .Should().Be(Path.Combine(AppDaten, "Vorlagen"));
        VorlagenOrdnerVorgabe.Ermittle(_db, MitGeschaeftskonto)
            .Should().Be(Path.Combine(AppDaten, "Vorlagen"));
        RegisterAblageVorgabe.Ermittle(_db, MitGeschaeftskonto)
            .Should().Be(Path.Combine(AppDaten, "Register"));
        SicherungsAblageVorgabe.Ermittle(_db, MitGeschaeftskonto)
            .Should().Be(Path.Combine(AppDaten, "Sicherungen"));
    }

    [Fact]
    public void Ein_relativ_gespeicherter_AppDatenOrdner_wird_aufgeloest()
    {
        Speichere(satz => satz.AppDatenOrdner = @"%OneDriveCommercial%\Kanzlei App Daten");

        AppDatenOrdnerVorgabe.Ermittle(_db, MitGeschaeftskonto).Should().Be(AppDaten);
        RegisterAblageVorgabe.Ermittle(_db, MitGeschaeftskonto)
            .Should().Be(Path.Combine(AppDaten, "Register"));
    }

    /// <summary>
    /// Der Rechner ohne dieses OneDrive-Konto: Der Ordner ist nicht aufloesbar,
    /// also gilt er als nicht gesetzt. Register und Sicherung bleiben damit aus
    /// (besser nichts als etwas am falschen Ort), der Vorlagenordner faellt auf
    /// %APPDATA% zurueck — die App startet und arbeitet weiter.
    /// </summary>
    [Fact]
    public void Ein_nicht_aufloesbarer_Ordner_zaehlt_wie_nicht_gesetzt()
    {
        Speichere(satz => satz.AppDatenOrdner = @"%OneDriveCommercial%\Kanzlei App Daten");

        AppDatenOrdnerVorgabe.Ermittle(_db, OhneOneDrive).Should().BeEmpty();
        RegisterAblageVorgabe.Ermittle(_db, OhneOneDrive).Should().BeEmpty();
        SicherungsAblageVorgabe.Ermittle(_db, OhneOneDrive).Should().BeEmpty();
        VorlagenOrdnerVorgabe.Ermittle(_db, OhneOneDrive)
            .Should().Be(AppDataPaths.EnsureVorlagenDirectory());
    }

    [Fact]
    public void Ein_eigens_gewaehlter_Ordner_schlaegt_den_abgeleiteten()
    {
        Speichere(satz =>
        {
            satz.AppDatenOrdner = AppDaten;
            satz.VorlagenOrdner = @"D:\Kanzlei\Eigene Vorlagen";
        });

        VorlagenOrdnerVorgabe.Ermittle(_db, MitGeschaeftskonto)
            .Should().Be(@"D:\Kanzlei\Eigene Vorlagen");
        RegisterAblageVorgabe.Ermittle(_db, MitGeschaeftskonto)
            .Should().Be(Path.Combine(AppDaten, "Register"), "die uebrigen bleiben abgeleitet");
    }

    /// <summary>
    /// Der Bestand aus der Zeit vor #103: vier absolute Ordner, kein
    /// App-Daten-Ordner. Er muss unveraendert weiterlaufen — der neue Ordner ist
    /// ein Angebot, kein Umzug.
    /// </summary>
    [Fact]
    public void Ein_Bestand_mit_vier_eigenen_Ordnern_bleibt_unberuehrt()
    {
        Speichere(satz =>
        {
            satz.VorlagenOrdner = @"C:\Alt\Vorlagen";
            satz.RegisterAblageOrdner = @"C:\Alt\Register";
            satz.SicherungsAblageOrdner = @"C:\Alt\Sicherungen";
        });

        VorlagenOrdnerVorgabe.Ermittle(_db, MitGeschaeftskonto).Should().Be(@"C:\Alt\Vorlagen");
        RegisterAblageVorgabe.Ermittle(_db, MitGeschaeftskonto).Should().Be(@"C:\Alt\Register");
        SicherungsAblageVorgabe.Ermittle(_db, MitGeschaeftskonto).Should().Be(@"C:\Alt\Sicherungen");
    }

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
