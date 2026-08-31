namespace AutomationService.Features.FormTemplates.Domain.Services;

/// <summary>
/// Rechnet Vorlagenpfade zwischen gespeicherter und nutzbarer Form um (#33).
///
/// Gespeichert wird relativ zum eingestellten Vorlagenordner, damit dieselbe
/// Datenbank auf zwei Rechnern mit verschiedenen Ordnern funktioniert — der
/// absolute Pfad des einen Rechners traegt den Benutzernamen und zeigt auf dem
/// anderen ins Leere. Beides bleibt tolerant: Ein absoluter Pfad (Altbestand
/// oder eine Datei ausserhalb des Ordners) wird unveraendert verwendet.
///
/// Reine Pfadmathematik, keine IO: ob die Datei existiert, pruefen weiterhin
/// die Konsumenten (WordAutomationService wirft 404 template_not_found, das
/// Frontend prueft vor dem Ausfuellen).
/// </summary>
public static class VorlagenPfad
{
    /// <summary>
    /// Speicherform: Liegt der Pfad im Ordner, bleibt nur der Rest ab dem
    /// Ordner uebrig; sonst kommt er unveraendert zurueck.
    /// </summary>
    public static string? MacheRelativ(string ordner, string? pfad)
    {
        if (string.IsNullOrWhiteSpace(pfad))
        {
            return pfad;
        }

        var voll = Path.GetFullPath(pfad.Trim());
        return LiegtImOrdner(ordner, voll)
            ? Path.GetRelativePath(Path.GetFullPath(ordner), voll)
            : pfad;
    }

    /// <summary>
    /// Nutzform: Ein relativer Pfad wird gegen den Ordner aufgeloest, ein
    /// absoluter (Altbestand, aussenliegende Datei) unveraendert verwendet.
    /// </summary>
    public static string? LoeseAuf(string ordner, string? gespeichert)
    {
        if (string.IsNullOrWhiteSpace(gespeichert) || Path.IsPathRooted(gespeichert))
        {
            return gespeichert;
        }

        return Path.GetFullPath(Path.Combine(ordner, gespeichert));
    }

    // Wie AnhangAblage.LiegtImOutlookOrdner: der Trenner am Ende verhindert,
    // dass C:\VorlagenAlt als Inhalt von C:\Vorlagen durchgeht.
    static bool LiegtImOrdner(string ordner, string vollerPfad)
    {
        var wurzel = Path.GetFullPath(ordner);
        return vollerPfad.StartsWith(
            wurzel.EndsWith(Path.DirectorySeparatorChar) ? wurzel : wurzel + Path.DirectorySeparatorChar,
            StringComparison.OrdinalIgnoreCase);
    }
}
