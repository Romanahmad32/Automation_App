namespace AutomationService.Features.PdfConversion.Domain.Services;

/// <summary>
/// Der Druckername aus Words <c>Application.ActivePrinter</c>. Word hängt den
/// Anschluss an, in der Sprache der Installation: „Brother MFC Printer auf
/// Ne01:", „HP LaserJet on Ne02:". Gezeigt werden soll nur der Name — und der
/// darf selbst Leerzeichen enthalten. Abgetrennt werden deshalb genau die
/// letzten beiden Wörter, und nur, wenn das letzte ein Anschluss ist
/// (endet auf Doppelpunkt).
/// </summary>
public static class WordDruckerName
{
    public static string? AusActivePrinter(string? activePrinter)
    {
        var text = activePrinter?.Trim();
        if (string.IsNullOrEmpty(text))
        {
            return null;
        }

        var woerter = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return woerter.Length >= 3 && woerter[^1].EndsWith(':')
            ? string.Join(' ', woerter[..^2])
            : text;
    }
}
