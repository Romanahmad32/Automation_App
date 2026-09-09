using AutomationService.Core.Persistence;
using AutomationService.Features.Backup.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace AutomationService.Tests.Unit;

public class SynchronisationsSchutzTests
{
    [Fact]
    public async Task Spaet_erzeugter_Kontext_behaelt_die_Generation_des_laufenden_Auftrags()
    {
        using var env = new SynchronisationsUmgebung();
        await env.Initialisiere();
        var vorher = DatenbankWechsel.Auftrag.Value;
        DatenbankWechsel.Auftrag.Value = (env.Datenbank, DatenbankWechsel.Generation(env.Datenbank));
        try
        {
            DatenbankWechsel.Vollzogen(env.Datenbank);
            await using var db = env.Kontext();
            var speichern = () => db.SaveChangesAsync();
            await speichern.Should().ThrowAsync<InvalidOperationException>();
        }
        finally { DatenbankWechsel.Auftrag.Value = vorher; }
    }

    [Fact]
    public async Task Unbekannte_Migration_verhindert_den_Tausch_des_lokalen_Bestands()
    {
        using var quelle = new SynchronisationsUmgebung();
        using var ziel = new SynchronisationsUmgebung();
        await quelle.Initialisiere();
        await ziel.Initialisiere();
        await ziel.Mandant("Behalten");
        await using (var db = quelle.Kontext())
        {
            await db.Database.ExecuteSqlRawAsync("INSERT INTO __EFMigrationsHistory (MigrationId, ProductVersion) VALUES ('20990101000000_Zukunft', '99.0')");
        }
        var archiv = await quelle.Sicherung.CreateBackupFileAsync();
        try
        {
            await using var strom = File.OpenRead(archiv);
            var import = () => ziel.Sicherung.ImportBackupAsync(strom);
            await import.Should().ThrowAsync<InvalidBackupException>().WithMessage("*neueren App-Version*");
            await using var db = ziel.Kontext();
            (await db.Mandanten.SingleAsync()).Nachname.Should().Be("Behalten");
        }
        finally { File.Delete(archiv); }
    }

    [Fact]
    public async Task Veralteter_HTTP_Schreibauftrag_wird_abgewiesen()
    {
        var erreicht = false;
        var middleware = new DatenstandMiddleware(_ => { erreicht = true; return Task.CompletedTask; });
        var context = new DefaultHttpContext();
        context.Request.Method = "POST";
        context.Request.Headers[DatenstandMiddleware.Header] = "-1";
        context.Response.Body = new MemoryStream();
        await middleware.InvokeAsync(context);
        context.Response.StatusCode.Should().Be(409);
        erreicht.Should().BeFalse();
    }

    [Fact]
    public void Aktenverweise_werden_am_Ziel_auf_dessen_Stammordner_aufgeloest()
    {
        var portable = AktenPfadSicherung.PasseAn(@"C:\Bueroprofil\OneDrive\Akten\Meier\Brief.pdf", @"C:\Bueroprofil\OneDrive\Akten", true);
        portable.Should().Be("@akten/Meier/Brief.pdf");
        AktenPfadSicherung.PasseAn(portable, @"D:\Laptop\OneDrive\Akten", false)
            .Should().Be(@"D:\Laptop\OneDrive\Akten\Meier\Brief.pdf");
    }

    [Fact]
    public async Task Nicht_bestaetigte_Dateiaenderungen_werden_zurueckgenommen()
    {
        using var env = new SynchronisationsUmgebung();
        var quelle = Path.Combine(env.Wurzel, "quelle");
        var ziel = Path.Combine(env.Wurzel, "ziel");
        Directory.CreateDirectory(quelle);
        Directory.CreateDirectory(ziel);
        await File.WriteAllTextAsync(Path.Combine(quelle, "alt.pdf"), "ersetzt");
        await File.WriteAllTextAsync(Path.Combine(quelle, "neu.pdf"), "neu");
        await File.WriteAllTextAsync(Path.Combine(ziel, "alt.pdf"), "vorher");
        using (var dateien = new ImportDateien(env.Wurzel)) dateien.Anhaenge(quelle, ziel);
        (await File.ReadAllTextAsync(Path.Combine(ziel, "alt.pdf"))).Should().Be("vorher");
        File.Exists(Path.Combine(ziel, "neu.pdf")).Should().BeFalse();
    }
}
