namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Die Zielpfade des Spiegels und die Suche nach Konfliktkopien daneben.
///
/// Getrennt vom Dienst, weil hier ausschließlich Namensregeln stehen — und
/// weil genau diese Regeln die Zusicherung tragen, dass das gewachsene
/// Kanzleidokument im selben Ordner unangetastet bleibt.
/// </summary>
/// <param name="ordner">Der eingestellte Ablageordner.</param>
/// <param name="basisname">Dateiname ohne Endung.</param>
public sealed class RegisterSpiegelAblage(string ordner, string basisname)
{
    /// <summary>
    /// Der bereinigte Basisname. Fällt auf die Vorgabe zurück, wenn die
    /// Einstellung leer ist oder nur aus Zeichen besteht, die in einem
    /// Dateinamen nichts zu suchen haben.
    /// </summary>
    public string Basisname { get; } = Bereinige(basisname);

    public string Ordner { get; } = ordner;

    public string Docx => Path.Combine(Ordner, $"{Basisname}.docx");

    public string Pdf => Path.Combine(Ordner, $"{Basisname}.pdf");

    /// <summary>
    /// Dateien im Ablageordner, die wie eine Konfliktkopie des Spiegels
    /// aussehen — welcher Name als solche gilt, entscheidet
    /// <see cref="KonfliktkopieName"/>.
    ///
    /// Bewusst <b>nicht</b> rekursiv und ohne die Dateien zu öffnen: Steht der
    /// Ordner auf „Dateien bei Bedarf", löste jeder Lesezugriff einen Download
    /// aus — die Namen stehen auch beim Platzhalter zur Verfügung.
    /// </summary>
    public IReadOnlyList<string> Konfliktkopien()
    {
        try
        {
            if (!Directory.Exists(Ordner)) return [];

            return Directory.EnumerateFiles(Ordner)
                .Where(SiehtNachKonfliktkopieAus)
                .Select(Path.GetFileName)
                .OfType<string>()
                .Order(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return [];
        }
    }

    bool SiehtNachKonfliktkopieAus(string pfad)
    {
        var endung = Path.GetExtension(pfad);
        if (!endung.Equals(".docx", StringComparison.OrdinalIgnoreCase)
            && !endung.Equals(".pdf", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return KonfliktkopieName.Erkennt(Basisname, Path.GetFileNameWithoutExtension(pfad));
    }

    static string Bereinige(string? name)
    {
        var roh = (name ?? string.Empty).Trim();
        foreach (var zeichen in Path.GetInvalidFileNameChars()) roh = roh.Replace(zeichen, '-');
        roh = roh.TrimEnd('.', ' ');
        return roh.Length == 0 ? Settings.Domain.Services.RegisterSpiegelVorgabe.Dateiname : roh;
    }
}
