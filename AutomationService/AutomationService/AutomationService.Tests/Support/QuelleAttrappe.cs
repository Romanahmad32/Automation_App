using System.Security.Cryptography;
using AutomationService.Features.Aktualisierung.Domain.Services;
using AutomationService.Features.DevSimulation.Domain.Services;
using FluentAssertions;

namespace AutomationService.Tests.Support;

/// <summary>
/// Eine Update-Quelle im Speicher (#196): ein Release <see cref="AktualisierungsUmgebung.NeueVersion"/>
/// mit passender Prüfsumme, das sich für jeden Gegenfall verbiegen lässt —
/// falsche Bytes, hängende Antwort, abreißende Leitung. Kein Netz.
/// </summary>
internal sealed class QuelleAttrappe : IAktualisierungsQuelle
{
    /// <summary>
    /// Eine Adresse, wie GitHub sie meldet — nur dann reicht der Dienst sie als
    /// <c>downloadUrl</c> weiter (<see cref="SetupAuswahl.FuerDenBrowser"/>).
    /// Abgerufen wird sie nie; den Download liefert diese Attrappe selbst.
    /// </summary>
    public static readonly Uri Adresse = new("https://github.com/Romanahmad32/Automation_App/releases/download/v1.4.0/Automation_App_Setup_1.4.0.exe");

    private int _abfragen;
    private int _downloads;

    public byte[] Inhalt { get; set; } = [.. Enumerable.Range(0, 300_000).Select(i => (byte)(i % 251))];

    /// <summary>Was die Quelle als Digest meldet; ohne Angabe der richtige.</summary>
    public string? Digest { get; set; }

    /// <summary>Was der Download liefert; ohne Angabe <see cref="Inhalt"/>.</summary>
    public byte[]? Geliefert { get; set; }

    /// <summary>Pause vor jedem Block des Downloads — hält ihn für Abbruch und Leerlauf im Zustand „laedt".</summary>
    public TimeSpan Verzoegerung { get; set; } = TimeSpan.Zero;

    /// <summary>So lange lässt die Prüfung auf sich warten — wie hinter einer Firewall, die Anfragen verschluckt.</summary>
    public TimeSpan Antwortzeit { get; set; } = TimeSpan.Zero;

    /// <summary>Die Prüfung scheitert damit (kein Netz, GitHub weg).</summary>
    public Exception? Ausnahme { get; set; }

    /// <summary>Der Download reißt nach so vielen Bytes ab (<see cref="IOException"/>, wie eine getrennte Leitung).</summary>
    public int? AbrissNach { get; set; }

    public int Abfragen => Volatile.Read(ref _abfragen);

    public int Downloads => Volatile.Read(ref _downloads);

    public string RichtigerDigest => $"sha256:{Convert.ToHexStringLower(SHA256.HashData(Inhalt))}";

    public ReleaseBeschreibung Release() => new(
        $"v{AktualisierungsUmgebung.NeueVersion}",
        [
            new ReleaseDatei("Automation_App_Setup_1.4.0.exe", Inhalt.Length, Digest ?? RichtigerDigest, Adresse.AbsoluteUri),
            new ReleaseDatei("Prüfsummen.txt", 120, "sha256:" + new string('0', 64), "https://downloads.example.invalid/x.txt"),
        ]);

    public async Task<ReleaseBeschreibung> HoleNeuesteAsync(CancellationToken cancellationToken)
    {
        Interlocked.Increment(ref _abfragen);
        if (Antwortzeit > TimeSpan.Zero)
        {
            await Task.Delay(Antwortzeit, cancellationToken);
        }

        return Ausnahme is not null ? throw Ausnahme : Release();
    }

    public Task<Stream> OeffneAsync(Uri adresse, CancellationToken cancellationToken)
    {
        adresse.Should().Be(Adresse, "geladen wird nur die ausgewählte Setup-Datei");
        Interlocked.Increment(ref _downloads);

        var daten = Geliefert ?? Inhalt;
        Stream strom = AbrissNach is { } abriss
            ? new AbreissenderStrom(daten[..abriss])
            : new TestmodusDownloadStream(daten, Verzoegerung);
        return Task.FromResult(strom);
    }
}

/// <summary>Liefert seine Bytes und wirft dann eine <see cref="IOException"/> — die Leitung ist weg.</summary>
internal sealed class AbreissenderStrom(byte[] daten) : MemoryStream(daten, writable: false)
{
    public override async ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default)
    {
        var gelesen = await base.ReadAsync(buffer, cancellationToken);
        return gelesen > 0 ? gelesen : throw new IOException("Die Verbindung wurde getrennt.");
    }
}
