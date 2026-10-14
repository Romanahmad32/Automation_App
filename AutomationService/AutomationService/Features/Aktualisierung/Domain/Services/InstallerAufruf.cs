namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Wie der Dienst den Inno-Installer startet (#196). Die Schalter sind ein
/// Vertrag mit <c>installer/setup.iss</c>:
/// <list type="bullet">
/// <item><c>/SILENT</c> — nur das kleine Fortschrittsfenster, kein Assistent;</item>
/// <item><c>/SUPPRESSMSGBOXES</c> — keine Rückfrage, die ein Anwender falsch beantworten kann;</item>
/// <item><c>/NORESTART</c> — nie ein Windows-Neustart;</item>
/// <item><c>/CLOSEAPPLICATIONS</c> — Inno schließt per Restart Manager jede Anwendung,
///   die dann noch eine Datei hält, die das Setup ersetzen will — nicht nur die
///   eigene, und auch ohne „force“: Der Restart Manager bittet sie zu beenden, und
///   eine Anwendung, die mitspielt, geht zu. Word trifft das nicht, weil es keine
///   dieser Dateien hält: Ersetzt wird nur, was im Paket steht (<c>[Files]</c> in
///   <c>setup.iss</c>, der Inhalt von <c>dist\Automation_App</c>). Die
///   Arbeitskopien, die Word öffnet, entstehen erst zur Laufzeit unter
///   <c>{app}\backend\Generated</c> — das Paket bringt dort keine Datei mit —, die
///   Vorlagen öffnet es aus dem Vorlagenordner unter <c>%APPDATA%</c> (oder dem
///   gewählten), die fertigen Schreiben aus dem Aktenordner. Die verborgene
///   Word-Instanz des Dienstes ist vorher fort: Das Setup wartet in
///   <c>InitializeSetup</c>, bis der Dienst beendet ist.
///   <b>Nie <c>/FORCECLOSEAPPLICATIONS</c></b>: Das beendete eine Anwendung auch,
///   wenn sie sich weigert — etwa ein Word, das noch nach dem ungespeicherten
///   Schriftsatz des Anwalts fragt;</item>
/// <item><c>/NEUSTART=1</c> — eigener Schalter: Nur damit startet der
///   <c>[Run]</c>-Eintrag die App nach der stillen Installation neu;</item>
/// <item><c>/LOG="…"</c> — das Inno-Protokoll neben der Setup-Datei, für Rückfragen.</item>
/// </list>
/// </summary>
/// <param name="SetupPfad">Die geprüfte Setup-Datei.</param>
/// <param name="Argumente">Die Befehlszeile hinter dem Programmnamen.</param>
/// <param name="Arbeitsordner">
/// Der Aktualisierungsordner — nicht das Arbeitsverzeichnis des Dienstes:
/// Das liegt im Programmordner, und ein Prozess mit Arbeitsverzeichnis dort
/// hält den Ordner fest, den Inno gerade ersetzen will.
/// </param>
/// <param name="ZielVersion">Die Version, auf die aktualisiert wird.</param>
public sealed record InstallerAufruf(string SetupPfad, string Argumente, string Arbeitsordner, string ZielVersion)
{
    /// <summary>Der Parameter, den <c>setup.iss</c> über <c>{param:NEUSTART|0}</c> liest.</summary>
    public const string NeustartSchalter = "/NEUSTART=1";

    public static InstallerAufruf Fuer(string setupPfad, string logPfad, string arbeitsordner, Versionsnummer zielVersion)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(setupPfad);
        ArgumentException.ThrowIfNullOrWhiteSpace(logPfad);
        ArgumentNullException.ThrowIfNull(zielVersion);

        // Anführungszeichen um den Pfad: Unter %LOCALAPPDATA% steht der
        // Benutzername, und der darf Leerzeichen enthalten.
        var argumente = $"/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS {NeustartSchalter} /LOG=\"{logPfad}\"";
        return new InstallerAufruf(setupPfad, argumente, arbeitsordner, zielVersion.ToString());
    }
}
