namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Bestimmt den Namen der erzeugten Datei. Bewusst defensiv: der Wunschname
/// kommt aus einem Formularfeld und darf kein Verzeichnis wechseln.
///
/// Der Name ist absichtlich <em>deterministisch</em> — dieselbe Vorlage zum
/// selben Unfalldatum ergibt denselben Namen, sodass eine Korrektur die
/// vorige Fassung ersetzt, statt eine "(2)" danebenzulegen. Dass sich zwei
/// Vorgänge damit nicht ins Gehege kommen, sichert der getrennte
/// Arbeitsordner je Vorgang (<see cref="ArbeitsVerzeichnis"/>).
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
}
