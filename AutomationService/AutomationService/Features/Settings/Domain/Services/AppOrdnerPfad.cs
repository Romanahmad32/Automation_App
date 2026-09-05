namespace AutomationService.Features.Settings.Domain.Services;

/// <summary>
/// Rechnet die Ordnerpfade der Einstellungen zwischen gespeicherter und
/// nutzbarer Form um (#103).
///
/// Zwei Speicherformen, mehr gibt es nicht:
/// <list type="bullet">
/// <item><b>absolut</b> — <c>C:\Daten\Akten</c>. Maschinenabhaengig: Der Pfad
/// traegt den Benutzernamen und zeigt auf dem zweiten Arbeitsplatz ins Leere;
/// deshalb bleibt er bei der Uebernahme ausgenommen (#39).</item>
/// <item><b>relativ mit Anker</b> — <c>%OneDriveCommercial%\Kanzlei App
/// Daten</c>. Der Anker ist der Name der Umgebungsvariable, gegen die
/// gerechnet wurde; dahinter steht der Rest relativ zum Wurzelordner.</item>
/// </list>
///
/// Der Anker ist der eigentliche Kniff. Ein Rechner mit Geschaefts-OneDrive und
/// einer mit privatem haben <em>verschiedene</em> Wurzeln, und die Suche
/// bevorzugt das Geschaeftskonto (<see cref="SynchronisierterWurzelOrdner"/>).
/// Ohne festgehaltenen Anker loeste derselbe relative Pfad auf dem zweiten
/// Rechner still in einen anderen Baum auf — dieselbe Datenbank zeigte auf
/// zwei verschiedene Ordner, ohne dass jemand einen Fehler saehe. Fehlt der
/// Anker auf diesem Rechner, ist die Antwort deshalb <c>null</c> und nicht
/// „dann eben die naechste Variable".
///
/// Reine Pfadmathematik, keine IO — wie <c>VorlagenPfad</c> (#33), das
/// dieselbe Aufgabe eine Ebene tiefer loest (Dateien relativ zum
/// Vorlagenordner). Ob ein Ordner existiert, pruefen die Aufrufer.
/// </summary>
public static class AppOrdnerPfad
{
    /// <summary>
    /// Die Umgebung dieses Rechners — der Standard aller Ueberladungen. Als
    /// Funktion und nicht fest verdrahtet, damit die Tests denselben Weg
    /// fahren, der auch ausgeliefert wird, statt an echten Variablen zu haengen.
    /// </summary>
    public static readonly Func<string, string?> Umgebung = Environment.GetEnvironmentVariable;

    /// <inheritdoc cref="MacheRelativ(string?, string?, Func{string, string?})"/>
    public static string MacheRelativ(string? pfad) => MacheRelativ(pfad, null, Umgebung);

    /// <inheritdoc cref="MacheRelativ(string?, string?, Func{string, string?})"/>
    public static string MacheRelativ(string? pfad, Func<string, string?> umgebung) =>
        MacheRelativ(pfad, null, umgebung);

    /// <inheritdoc cref="MacheRelativ(string?, string?, Func{string, string?})"/>
    public static string MacheRelativ(string? pfad, string? bisher) => MacheRelativ(pfad, bisher, Umgebung);

    /// <summary>
    /// Speicherform: Liegt der absolute Pfad unterhalb eines synchronisierten
    /// Wurzelordners, wird daraus <c>%Var%\Rest</c>; sonst kommt er getrimmt,
    /// aber unveraendert zurueck. Ein Pfad, der bereits in <c>%Var%</c>-Form
    /// vorliegt, bleibt ebenfalls unangetastet.
    ///
    /// <paramref name="bisher"/> ist der zuletzt gespeicherte Wert desselben
    /// Feldes — gegen Anker-Drift: Zeigen zwei Variablen auf denselben Ordner
    /// (haeufig <c>OneDrive</c> == <c>OneDriveCommercial</c>), ermittelt das
    /// Frontend beim Anzeigen den aufgeloesten absoluten Pfad und schickt ihn
    /// beim naechsten Speichern unveraendert zurueck. Ohne <paramref
    /// name="bisher"/> griffe dann jedesmal neu die Vorzugsreihenfolge
    /// (<see cref="SynchronisierterWurzelOrdner.Variablen"/>) und schriebe
    /// still einen anderen Anker fest — auf einem Rechner ohne die bevorzugte
    /// Variable loest das dann nicht mehr auf. Traegt der bisherige Wert einen
    /// Anker und liegt der neue Pfad weiterhin unter dessen Wurzel auf diesem
    /// Rechner, bleibt genau dieser Anker erhalten; sonst gilt wie bisher die
    /// Vorzugsreihenfolge.
    /// </summary>
    public static string MacheRelativ(string? pfad, string? bisher, Func<string, string?> umgebung)
    {
        var wert = (pfad ?? string.Empty).Trim();

        // Nicht verwurzelt heisst hier: leer, schon in %Var%-Form, oder etwas,
        // das ohnehin niemand aufloesen kann. Alle drei bleiben, wie sie sind.
        if (wert.Length == 0 || !Path.IsPathRooted(wert))
        {
            return wert;
        }

        string voll;
        try
        {
            voll = Path.GetFullPath(wert);
        }
        catch (Exception ausnahme) when (ausnahme is ArgumentException or NotSupportedException or PathTooLongException)
        {
            // Was sich nicht normalisieren laesst, laesst sich auch nicht
            // einordnen. Ein unmoeglicher Pfad ist Sache der Oberflaeche, nicht
            // ein 500 beim Speichern der Einstellungen.
            return wert;
        }

        var treu = RelativZu(voll, Anker(bisher), umgebung);
        if (treu is not null)
        {
            return treu;
        }

        foreach (var name in SynchronisierterWurzelOrdner.Variablen)
        {
            var relativ = RelativZu(voll, name, umgebung);
            if (relativ is not null)
            {
                return relativ;
            }
        }

        return wert;
    }

    /// <summary>
    /// <c>%name%\Rest</c>, wenn die Variable gesetzt ist und der volle Pfad
    /// darunter liegt — sonst <c>null</c>.
    /// </summary>
    static string? RelativZu(string voll, string? name, Func<string, string?> umgebung)
    {
        if (name is null)
        {
            return null;
        }

        var wurzel = (umgebung(name) ?? string.Empty).Trim();
        if (wurzel.Length == 0 || !LiegtImOrdner(wurzel, voll))
        {
            return null;
        }

        var rest = Path.GetRelativePath(Path.GetFullPath(wurzel), voll);
        return $"%{name}%{Path.DirectorySeparatorChar}{rest}";
    }

    /// <inheritdoc cref="LoeseAuf(string?, Func{string, string?})"/>
    public static string? LoeseAuf(string? gespeichert) => LoeseAuf(gespeichert, Umgebung);

    /// <summary>
    /// Nutzform: <c>%Var%\Rest</c> wird gegen den Wert der Variable aufgeloest.
    /// Ist sie auf diesem Rechner nicht gesetzt, ist die Antwort <c>null</c> —
    /// ausdruecklich kein Ausweichen auf eine andere Variable. Ein absoluter
    /// Pfad kommt getrimmt zurueck, ein leerer bleibt leer.
    /// </summary>
    public static string? LoeseAuf(string? gespeichert, Func<string, string?> umgebung)
    {
        var wert = (gespeichert ?? string.Empty).Trim();
        var anker = Anker(wert);
        if (anker is null)
        {
            return wert;
        }

        var wurzel = (umgebung(anker) ?? string.Empty).Trim();
        if (wurzel.Length == 0)
        {
            return null;
        }

        var rest = Rest(wert);
        return rest.Length == 0 ? wurzel : Path.Combine(wurzel, rest);
    }

    /// <summary>Ob der gespeicherte Wert die relative Form mit Anker trägt.</summary>
    public static bool IstRelativ(string? gespeichert) => Anker(gespeichert) is not null;

    /// <summary>
    /// Der Name der Umgebungsvariable, gegen die gerechnet wurde — oder
    /// <c>null</c>, wenn der Wert leer, absolut oder mit einem hier nicht
    /// vorgesehenen Anker geschrieben ist.
    ///
    /// Zurueck kommt immer die Schreibweise aus
    /// <see cref="SynchronisierterWurzelOrdner.Variablen"/>, damit ein
    /// <c>%onedrive%\…</c> aus einer aelteren Datenbank denselben Anker
    /// bezeichnet wie <c>%OneDrive%\…</c>.
    /// </summary>
    public static string? Anker(string? gespeichert)
    {
        var wert = (gespeichert ?? string.Empty).Trim();
        if (wert.Length < 2 || wert[0] != '%')
        {
            return null;
        }

        var ende = wert.IndexOf('%', 1);
        if (ende < 2)
        {
            return null;
        }

        var name = wert[1..ende];
        return SynchronisierterWurzelOrdner.Variablen
            .FirstOrDefault(bekannt => string.Equals(bekannt, name, StringComparison.OrdinalIgnoreCase));
    }

    /// <summary>Alles hinter dem Anker, ohne fuehrende Trennzeichen.</summary>
    static string Rest(string wert)
    {
        var ende = wert.IndexOf('%', 1);
        return wert[(ende + 1)..]
            .TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }

    // Wie VorlagenPfad.LiegtImOrdner und AnhangAblage.LiegtImOutlookOrdner: der
    // Trenner am Ende verhindert, dass C:\OneDriveAlt als Inhalt von
    // C:\OneDrive durchgeht. Bewusst hier noch einmal und nicht aus einem
    // fremden Slice geliehen — fuenf Zeilen Pfadmathematik sind die schlechtere
    // Kopplung zwischen zwei Slices als die Kopie.
    static bool LiegtImOrdner(string ordner, string vollerPfad)
    {
        var wurzel = Path.GetFullPath(ordner);
        return vollerPfad.StartsWith(
            wurzel.EndsWith(Path.DirectorySeparatorChar) ? wurzel : wurzel + Path.DirectorySeparatorChar,
            StringComparison.OrdinalIgnoreCase);
    }
}
