using System.Reflection;

namespace AutomationService.Core.Lifetime;

/// <summary>
/// Die Fassung, die hier gerade laeuft — als eine Zeichenkette, wie sie in
/// Health-Antwort und Arbeitsplatz-Akte steht.
///
/// Einmal gelesen und gemerkt: Das Attribut aendert sich zur Laufzeit nicht,
/// und Reflexion ist die teuerste Art, dieselbe Antwort zweimal zu bekommen.
/// </summary>
public static class Programmfassung
{
    /// <summary>Steht in <c>GET /health</c> und in <c>arbeitsplatz-&lt;Rechner&gt;.json</c>.</summary>
    public const string Unbekannt = "unbekannt";

    /// <summary>
    /// Informationsfassung der Assembly (z. B. „1.4.2"), sonst
    /// <see cref="Unbekannt"/>. Beim Support die erste Frage („welcher Stand
    /// laeuft da?"), bei der Uebergabe die zweite („und auf dem anderen
    /// Rechner?") — ein aelterer Stand kann eine neuere Sicherung nicht lesen.
    /// </summary>
    public static string Aktuell { get; } =
        Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
        ?? Unbekannt;
}
