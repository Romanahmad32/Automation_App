using System.Diagnostics;
using System.Text;
using AutomationService.Tests.Support;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Der versionierte Bestand, gelesen ueber git selbst und nicht ueber das
/// Dateisystem: Im Arbeitsbaum liegen ignorierte Kanzleivorlagen und
/// Beispiele, die nie ins Repository kommen -- und in der Historie steht, was
/// der Arbeitsbaum laengst nicht mehr zeigt.
/// </summary>
public static class GitBestand
{
    /// <summary>
    /// Die versionierten Dateien, Pfade relativ zur Repository-Wurzel mit '/'.
    /// </summary>
    public static IReadOnlyList<string> VersionierteDateien() =>
        Encoding.UTF8.GetString(Git("ls-files", "-z"))
            .Split('\0', StringSplitOptions.RemoveEmptyEntries);

    /// <summary>
    /// Jeder Blob, der von HEAD aus erreichbar ist, je einmal mit einem Pfad,
    /// unter dem er vorkam. In einem flachen Klon nur der vorhandene Teil der
    /// Historie -- die CI holt deshalb die ganze (ci.yml, Job backend).
    /// </summary>
    public static IEnumerable<(string Blob, string Pfad)> ObjekteDerHistorie() =>
        Encoding.UTF8.GetString(Git("rev-list", "--objects", "HEAD"))
            .Split('\n')
            .Select(zeile => zeile.Split(' ', 2))
            .Where(teile => teile.Length == 2 && teile[1].Length > 0)
            .Select(teile => (teile[0], teile[1]));

    /// <summary>Der Inhalt eines Blobs, Byte fuer Byte.</summary>
    public static byte[] Inhalt(string blob) => Git("cat-file", "blob", blob);

    /// <exception cref="InvalidOperationException">
    /// Wenn git fehlt oder scheitert. Bewusst ein harter Fehler: Eine
    /// Pruefung, die ohne git still gruen wird, hat nie stattgefunden.
    /// </exception>
    static byte[] Git(params string[] argumente)
    {
        var start = new ProcessStartInfo("git")
        {
            WorkingDirectory = RepoWurzel.Pfad(),
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };
        foreach (var argument in argumente)
        {
            start.ArgumentList.Add(argument);
        }

        using var prozess = Process.Start(start)
            ?? throw new InvalidOperationException("git liess sich nicht starten.");
        var fehler = prozess.StandardError.ReadToEndAsync();
        using var ausgabe = new MemoryStream();
        prozess.StandardOutput.BaseStream.CopyTo(ausgabe);
        prozess.WaitForExit();
        if (prozess.ExitCode != 0)
        {
            throw new InvalidOperationException(
                $"git {string.Join(' ', argumente)} endete mit {prozess.ExitCode}: {fehler.Result}");
        }

        return ausgabe.ToArray();
    }
}
