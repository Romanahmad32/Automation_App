namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Bestimmt Name und Pfad der erzeugten Datei. Beides ist bewusst defensiv:
/// der Wunschname kommt aus einem Formularfeld und darf weder das
/// Zielverzeichnis wechseln noch eine vorhandene Akte überschreiben.
/// </summary>
public static class OutputFileNaming
{
    /// <summary>
    /// Nutzt den gewünschten Namen (auf den reinen Dateinamen reduziert, um
    /// Verzeichniswechsel zu verhindern) oder fällt auf "{Vorlage}_{Datum}"
    /// zurück. Punkte im Namen (z. B. Datumsangaben "12.05.2025") bleiben
    /// erhalten; nur eine bereits angehängte .docx/.doc-Endung wird entfernt.
    /// </summary>
    public static string BuildFileName(string requestedName, string templateName)
    {
        if (!string.IsNullOrWhiteSpace(requestedName))
        {
            // Nur das Verzeichnis abschneiden (Schutz vor Pfadwechsel).
            var safeName = Path.GetFileName(requestedName.Trim());
            foreach (var ext in new[] { ".docx", ".doc" })
            {
                if (safeName.EndsWith(ext, StringComparison.OrdinalIgnoreCase))
                {
                    safeName = safeName[..^ext.Length];
                    break;
                }
            }
            // Abschließende Punkte/Leerzeichen sind unter Windows als Dateiname unzulässig.
            safeName = safeName.Trim().TrimEnd('.', ' ');
            if (!string.IsNullOrWhiteSpace(safeName))
                return safeName + ".docx";
        }

        return $"{templateName}_{DateTime.Now:yyyy-MM-dd}.docx";
    }

    /// <summary>Hängt " (2)", " (3)" … an, falls die Zieldatei bereits existiert, statt sie zu überschreiben.</summary>
    public static string EnsureUniquePath(string path)
    {
        if (!File.Exists(path))
            return path;

        var directory = Path.GetDirectoryName(path)!;
        var name = Path.GetFileNameWithoutExtension(path);
        var extension = Path.GetExtension(path);

        for (var counter = 2; ; counter++)
        {
            var candidate = Path.Combine(directory, $"{name} ({counter}){extension}");
            if (!File.Exists(candidate))
                return candidate;
        }
    }
}
