using System.Security.Cryptography;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>Ergebnis von <see cref="SetupPruefung"/>.</summary>
public enum SetupPruefErgebnis
{
    InOrdnung,
    Fehlt,
    GroesseFalsch,
    PruefsummeFalsch,
}

/// <summary>
/// Die Echtheitsprüfung der Setup-Datei (#196): Größe und SHA256 gegen das,
/// was die GitHub-API über die veröffentlichte Datei sagt. Mehr gibt es nicht —
/// keine Authenticode-Signatur —, deshalb läuft sie zweimal: nach dem Download
/// und unmittelbar vor dem Start des Installers. Dazwischen liegt die Datei
/// auf der Platte, und ausgeführt wird, was dann dort liegt.
/// </summary>
public static class SetupPruefung
{
    public static SetupPruefErgebnis Pruefe(string pfad, SetupDatei setup)
    {
        try
        {
            using var datei = new FileStream(pfad, FileMode.Open, FileAccess.Read, FileShare.Read);
            return Pruefe(datei, setup);
        }
        catch (Exception ausnahme) when (ausnahme is FileNotFoundException or DirectoryNotFoundException)
        {
            return SetupPruefErgebnis.Fehlt;
        }
    }

    /// <summary>
    /// Prüft eine schon geöffnete Datei vom Anfang an. So kann der Aufrufer sie
    /// zwischen Prüfung und Installer-Start offen und gegen Schreiben gesperrt
    /// halten (<see cref="FileShare.Read"/>) — geprüft ist dann genau das, was
    /// gestartet wird.
    /// </summary>
    public static SetupPruefErgebnis Pruefe(FileStream datei, SetupDatei setup)
    {
        ArgumentNullException.ThrowIfNull(datei);
        ArgumentNullException.ThrowIfNull(setup);

        if (datei.Length != setup.Groesse)
        {
            return SetupPruefErgebnis.GroesseFalsch;
        }

        datei.Position = 0;
        var sha256 = Convert.ToHexStringLower(SHA256.HashData(datei));
        return string.Equals(sha256, setup.Sha256, StringComparison.Ordinal)
            ? SetupPruefErgebnis.InOrdnung
            : SetupPruefErgebnis.PruefsummeFalsch;
    }
}
