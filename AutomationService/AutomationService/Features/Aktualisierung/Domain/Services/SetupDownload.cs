using System.Globalization;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Lädt die Setup-Datei gestreamt in eine Teildatei (#196): mit Fortschritt,
/// abbrechbar, und mit einer Leerlaufgrenze statt eines Gesamtlimits.
///
/// Geprüft wird hier nur, was sich unterwegs prüfen lässt — dass nicht mehr
/// ankommt als angekündigt. Größe und SHA256 der fertigen Datei prüft
/// <see cref="SetupPruefung"/>, und zwar an der Datei auf der Platte, nicht am
/// Strom: Geprüft ist dann das, was später ausgeführt wird.
/// </summary>
public static class SetupDownload
{
    private const int Puffergroesse = 81920;

    /// <param name="quelle">Liefert den Strom.</param>
    /// <param name="setup">Adresse und angekündigte Größe.</param>
    /// <param name="teildatei">Wird angelegt oder überschrieben.</param>
    /// <param name="leerlauf">So lange darf ein einzelner Lesevorgang dauern.</param>
    /// <param name="fortschritt">Bisher geschriebene Bytes, nach jedem Block.</param>
    /// <param name="abbruch">Der Abbruch durch den Anwender oder das Herunterfahren.</param>
    /// <param name="zeit">Die Uhr, nach der der Leerlauf zählt — ein Test stellt sie vor, statt zu warten.</param>
    /// <exception cref="TimeoutException">Kein Byte mehr innerhalb von <paramref name="leerlauf"/> — meist eine abgerissene Verbindung.</exception>
    /// <exception cref="InvalidDataException">Es kam mehr an als angekündigt.</exception>
    public static async Task LadeAsync(
        IAktualisierungsQuelle quelle,
        SetupDatei setup,
        string teildatei,
        TimeSpan leerlauf,
        Action<long> fortschritt,
        CancellationToken abbruch,
        TimeProvider? zeit = null)
    {
        ArgumentNullException.ThrowIfNull(quelle);
        ArgumentNullException.ThrowIfNull(setup);
        ArgumentNullException.ThrowIfNull(fortschritt);

        // Zwei Quellen: Nur die Leerlauf-Quelle hängt an der Uhr; der Abbruch von
        // außen bleibt ein gewöhnliches Token, damit er unten unterscheidbar ist.
        using var leerlaufUhr = new CancellationTokenSource(Timeout.InfiniteTimeSpan, zeit ?? TimeProvider.System);
        using var frist = CancellationTokenSource.CreateLinkedTokenSource(abbruch, leerlaufUhr.Token);
        try
        {
            leerlaufUhr.CancelAfter(leerlauf);
            await using var eingang = await quelle.OeffneAsync(setup.Adresse, frist.Token);
            await using var ausgang = await KurzeSperre.WiederholeAsync(
                () => new FileStream(
                    teildatei, FileMode.Create, FileAccess.Write, FileShare.None, Puffergroesse, useAsync: true),
                frist.Token);

            var puffer = new byte[Puffergroesse];
            long geschrieben = 0;
            while (true)
            {
                leerlaufUhr.CancelAfter(leerlauf);
                var gelesen = await eingang.ReadAsync(puffer, frist.Token);
                if (gelesen == 0)
                {
                    break;
                }

                geschrieben += gelesen;
                if (geschrieben > setup.Groesse)
                {
                    // Ein Server, der mehr schickt als angekündigt, füllt sonst
                    // die Platte, bevor die Prüfsumme überhaupt zum Zug kommt.
                    throw new InvalidDataException(
                        $"Es kamen mehr als die angekündigten {setup.Groesse} Bytes an.");
                }

                await ausgang.WriteAsync(puffer.AsMemory(0, gelesen), frist.Token);
                fortschritt(geschrieben);
            }

            await ausgang.FlushAsync(abbruch);
        }
        catch (OperationCanceledException ausnahme) when (!abbruch.IsCancellationRequested)
        {
            throw new TimeoutException(
                string.Create(CultureInfo.InvariantCulture, $"Seit {leerlauf.TotalSeconds:0} s kam kein Byte mehr an."),
                ausnahme);
        }
    }
}

