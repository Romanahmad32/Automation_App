using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Tests.Support;
using FluentAssertions;
using Xunit;

namespace AutomationService.Tests.Unit;

/// <summary>
/// Ein Virenscanner hält eine frisch geschriebene Datei kurz offen (#196). Der
/// Download darf daran nicht scheitern, wenn die Sperre nach Sekundenbruchteilen
/// weicht — und muss mit der bekannten Meldung enden, wenn sie bleibt. Die
/// Sperre hält hier der Test selbst, mit <see cref="FileShare.None"/>.
/// </summary>
public sealed class AktualisierungsDownloadSperreTests : IDisposable
{
    private readonly AktualisierungsUmgebung _umgebung = new();

    public void Dispose() => _umgebung.Dispose();

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Eine_kurz_gesperrte_Datei_haelt_den_Download_nicht_auf(bool teildatei)
    {
        Directory.CreateDirectory(_umgebung.Ordner.Pfad);
        var gesperrt = teildatei ? _umgebung.Teildatei : _umgebung.SetupPfad;
        var sperre = new FileStream(gesperrt, FileMode.Create, FileAccess.Write, FileShare.None);
        _ = Task.Run(async () =>
        {
            await Task.Delay(300);
            await sperre.DisposeAsync();
        });
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);

        dienst.StarteDownload();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Bereit);
        stand.Meldung.Should().BeNull();
        File.Exists(_umgebung.Teildatei).Should().BeFalse();
    }

    [Fact]
    public async Task Eine_dauerhaft_gesperrte_Datei_endet_in_fehler_ohne_Teildatei()
    {
        Directory.CreateDirectory(_umgebung.Ordner.Pfad);
        await using var sperre = new FileStream(
            _umgebung.SetupPfad, FileMode.Create, FileAccess.Write, FileShare.None);
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);

        dienst.StarteDownload();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Fehler);
        stand.Meldung.Should().Be(AktualisierungsMeldungen.NichtGespeichert);
        stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Sonstig);
        File.Exists(_umgebung.Teildatei).Should().BeFalse();
    }

    /// <summary>
    /// Hält etwas die Teildatei dauerhaft offen, ist das kein Netzproblem: Die
    /// Meldung sagt „nicht gespeichert“, nicht „unterbrochen“.
    /// </summary>
    [Fact]
    public async Task Eine_dauerhaft_gesperrte_Teildatei_wird_nicht_als_Netzproblem_gemeldet()
    {
        Directory.CreateDirectory(_umgebung.Ordner.Pfad);
        await using var sperre = new FileStream(
            _umgebung.Teildatei, FileMode.Create, FileAccess.Write, FileShare.None);
        using var dienst = _umgebung.Dienst();
        await dienst.PruefeAsync(CancellationToken.None);

        dienst.StarteDownload();

        var stand = await AktualisierungsUmgebung.WarteAuf(dienst, AktualisierungsZustand.Fehler);
        stand.Meldung.Should().Be(AktualisierungsMeldungen.NichtGespeichert);
        stand.FehlerArt.Should().Be(AktualisierungsFehlerArt.Sonstig);
    }
}
