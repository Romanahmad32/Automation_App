using System.Security.Cryptography;
using System.Text;
using AutomationService.Features.Aktualisierung.Domain.Services;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Update-Quelle im E2E-Testmodus (#196): kein GitHub, keine Anfrage nach
/// außen. Sie meldet ein erfundenes Release <see cref="Version"/> mit einer
/// kleinen Setup-Datei samt passender Größe und Prüfsumme — Auswahl, Download,
/// Prüfung und Merkdatei laufen damit echt, nur Herkunft und Installer-Start
/// (<see cref="TestmodusInstallerStarter"/>) sind ersetzt.
///
/// Die „Datei" liegt im Speicher und nirgends sonst: Sie ist durch ihren
/// Inhalt bestimmt, und eine Kopie auf der Platte wäre nur etwas, das der
/// Testlauf hinterher wegräumen müsste.
///
/// <b>Gegenfall „falsche Prüfsumme":</b> Mit <see cref="PruefsummeFalsch"/>
/// liefert der Download ein verändertes Byte bei gleicher Größe; die Prüfung
/// verwirft die Datei, und der Installer startet nicht. Umgeschaltet wird
/// über <c>POST api/Simulation/aktualisierung</c>.
/// </summary>
public sealed class TestmodusAktualisierungsQuelle(TimeSpan? verzoegerungJeBlock = null) : IAktualisierungsQuelle
{
    public const string Version = "9.9.9";
    public const string Dateiname = "Automation_App_Setup_9.9.9.exe";

    /// <summary>
    /// Die Domain <c>.invalid</c> löst nie auf. Als <c>downloadUrl</c> reicht der
    /// Dienst sie nicht weiter — das tut er nur mit <c>https://github.com/…</c>
    /// (<see cref="SetupAuswahl.FuerDenBrowser"/>) —, „Lieber selbst
    /// herunterladen" fehlt im Testmodus also, und kein Klick öffnet einen Browser.
    /// </summary>
    public static readonly Uri Adresse = new($"https://testmodus.invalid/{Dateiname}");

    /// <summary>
    /// Ein MiB in Blöcken zu 64 KiB mit je 150 ms Pause: rund 2,4 s im Zustand
    /// <c>laedt</c> — lang genug, dass eine E2E-Suite Fortschritt und Abbruch
    /// sieht, kurz genug, dass sie darauf nicht wartet.
    /// </summary>
    private static readonly byte[] Inhalt = BaueInhalt(1024 * 1024);

    private static readonly string Sha256 = Convert.ToHexStringLower(SHA256.HashData(Inhalt));

    private readonly TimeSpan _verzoegerung = verzoegerungJeBlock ?? TimeSpan.FromMilliseconds(150);
    private volatile bool _pruefsummeFalsch;

    /// <summary>Ob der nächste Download eine verfälschte Datei liefert.</summary>
    public bool PruefsummeFalsch
    {
        get => _pruefsummeFalsch;
        set => _pruefsummeFalsch = value;
    }

    public Task<ReleaseBeschreibung> HoleNeuesteAsync(CancellationToken cancellationToken) =>
        Task.FromResult(new ReleaseBeschreibung(
            $"v{Version}",
            [new ReleaseDatei(Dateiname, Inhalt.Length, $"sha256:{Sha256}", Adresse.AbsoluteUri)]));

    public Task<Stream> OeffneAsync(Uri adresse, CancellationToken cancellationToken)
    {
        if (adresse != Adresse)
        {
            // Nur die eigene Adresse: Kommt etwas anderes, ist die Auswahl
            // falsch verdrahtet — dann soll der Testlauf das sehen.
            throw new HttpRequestException($"Die Testmodus-Quelle kennt nur {Adresse}, nicht {adresse}.");
        }

        var daten = Inhalt;
        if (PruefsummeFalsch)
        {
            daten = (byte[])Inhalt.Clone();
            daten[^1] ^= 0xFF;
        }

        return Task.FromResult<Stream>(new TestmodusDownloadStream(daten, _verzoegerung));
    }

    /// <summary>Lesbarer Text statt Zufall: Wer die Datei öffnet, sieht, was sie ist.</summary>
    private static byte[] BaueInhalt(int groesse)
    {
        var zeile = Encoding.ASCII.GetBytes("Testmodus-Attrappe (#196): kein Installationsprogramm.\r\n");
        var inhalt = new byte[groesse];
        for (var stelle = 0; stelle < groesse; stelle++)
        {
            inhalt[stelle] = zeile[stelle % zeile.Length];
        }

        return inhalt;
    }
}
