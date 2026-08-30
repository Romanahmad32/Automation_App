using System.Text.RegularExpressions;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Erkennt am <em>Namen</em>, ob eine Datei neben dem Register-Spiegel die
/// Konfliktkopie des Spiegels ist — also das, was ein Synchronisierungsdienst
/// hinterlässt, wenn er zwei Fassungen nicht zusammenführen konnte.
///
/// Reine Namensregel, ohne Dateisystem: Steht der Ablageordner auf „Dateien
/// bei Bedarf", löste jeder Blick in eine Datei einen Download aus. Die Namen
/// stehen auch beim Platzhalter zur Verfügung, der Inhalt nicht.
///
/// Warum das genau sein muss: Die Oberfläche zeigt einen Treffer in
/// Fehlerfarbe und rät, die Kopie anzusehen und danach zu löschen. Ein
/// Fehlalarm ist hier also kein Schönheitsfehler — er fordert den Anwalt auf,
/// eine Datei wegzuwerfen, die niemand kopiert hat. Vorher genügte dafür der
/// gleiche Anfang, und „Sachgebiete-Register (App) Erläuterung.docx" daneben
/// reichte aus.
///
/// Deshalb muss der Rest hinter dem Basisnamen einem der Muster entsprechen,
/// die die verbreiteten Dienste tatsächlich anhängen. Was keinem entspricht,
/// gilt als eigenständige Datei des Anwenders — die harmlosere Richtung: Eine
/// unerkannte Konfliktkopie liegt still herum, eine falsch erkannte wird auf
/// Anraten der App gelöscht.
/// </summary>
public static class KonfliktkopieName
{
    const RegexOptions Regeln =
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.ExplicitCapture;

    /// <summary>Die Zählform von Explorer und OneDrive: „… (1)", „…(2)".</summary>
    static readonly Regex Gezaehlt = new(@"^ ?\(\d+\)$", Regeln);

    /// <summary>
    /// OneDrive hängt bei einem Gerätekonflikt den Rechnernamen an:
    /// „…-LAPTOP-ANWALT", gelegentlich zusätzlich gezählt. Der Rechnername
    /// enthält nie ein Leerzeichen — daran hängt, dass „… Erläuterung" nicht
    /// mehr darunter fällt.
    /// </summary>
    static readonly Regex MitRechnername = new(@"^-\S+( ?\(\d+\))?$", Regeln);

    /// <summary>Was Explorer und die englische Oberfläche anhängen.</summary>
    static readonly Regex Kopie = new(@"^ ?-? ?(Kopie|Copy)( ?\(\d+\))?$", Regeln);

    /// <summary>
    /// Die ausgeschriebene Form, die Dropbox und die deutschen Oberflächen
    /// verwenden: „… (in Konflikt stehende Kopie …)", „… (conflicted copy …)".
    /// </summary>
    static readonly Regex Ausgeschrieben = new(@"^ ?\(.*(konflikt|conflict).*\)$", Regeln);

    /// <summary>
    /// Ob <paramref name="name"/> (ohne Endung) wie eine Konfliktkopie von
    /// <paramref name="basisname"/> aussieht. Der Spiegel selbst — gleicher
    /// Name — ist keine.
    /// </summary>
    public static bool Erkennt(string basisname, string name)
    {
        ArgumentNullException.ThrowIfNull(basisname);
        ArgumentNullException.ThrowIfNull(name);

        if (!name.StartsWith(basisname, StringComparison.OrdinalIgnoreCase)) return false;

        var rest = name[basisname.Length..];
        if (rest.Length == 0) return false;

        return Gezaehlt.IsMatch(rest)
               || MitRechnername.IsMatch(rest)
               || Kopie.IsMatch(rest)
               || Ausgeschrieben.IsMatch(rest);
    }
}
