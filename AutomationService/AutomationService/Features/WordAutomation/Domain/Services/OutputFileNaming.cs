namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Bestimmt den Namen der erzeugten Datei. Bewusst defensiv: der Name kommt
/// aus dem Frontend und darf kein Verzeichnis wechseln.
///
/// Gebaut wird der Name <em>dort</em> — nach der Kanzlei-Konvention
/// "Anspruchsschreiben an {Versicherung} {Nr} {Vorlagenname}" (§4.9,
/// <c>schreiben_dateiname.dart</c>): Versicherer, Vorlage und laufende Nummer
/// liegen im Frontend bereits vor, im Backend wären sie nur über einen Zugriff
/// auf den Vorgangs-Slice zu holen. Hier steht der Schutzwall davor.
///
/// Der Name ist absichtlich <em>deterministisch</em>: Dieselbe Nummer ergibt
/// denselben Namen, sodass eine Korrektur die vorige Fassung ersetzt, statt
/// eine "(2)" danebenzulegen. Was zwei Schreiben eines Vorgangs unterscheidet,
/// ist die laufende Nummer — und die vergibt der Anwalt, nicht die Uhr. Dass
/// sich zwei Vorgänge nicht ins Gehege kommen, sichert zusätzlich der getrennte
/// Arbeitsordner je Vorgang (<see cref="ArbeitsVerzeichnis"/>).
/// </summary>
public static class OutputFileNaming
{
    /// <summary>Ersetzt unzulässige Zeichen; wie in <see cref="ArbeitsVerzeichnis.Ordnername"/>.</summary>
    private const char Ersatzzeichen = '-';

    /// <summary>
    /// Macht aus dem gewünschten Namen einen gültigen Dateinamen und hängt
    /// ".docx" an; ohne brauchbaren Namen bleibt "{Vorlage}_{Datum}".
    ///
    /// Punkte im Namen (z. B. Datumsangaben "12.05.2025") bleiben erhalten; nur
    /// eine bereits angehängte .docx/.doc-Endung wird entfernt.
    /// </summary>
    public static string BuildFileName(string requestedName, string templateName)
    {
        if (!string.IsNullOrWhiteSpace(requestedName))
        {
            var safeName = Bereinige(requestedName.Trim());
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

        return $"{Bereinige(templateName)}_{DateTime.Now:yyyy-MM-dd}.docx";
    }

    /// <summary>
    /// Ersetzt jedes unter Windows unzulässige Zeichen durch
    /// <see cref="Ersatzzeichen"/>.
    ///
    /// Das ist zugleich der Schutz vor einem Verzeichniswechsel: <c>/</c>,
    /// <c>\</c> und <c>:</c> stehen alle in
    /// <see cref="Path.GetInvalidFileNameChars"/> und überleben diesen Durchlauf
    /// nicht. Ein vorgeschaltetes <c>Path.GetFileName</c> stand hier früher und
    /// ist seit #32 <b>falsch</b>: Es schnitte bei einem Versicherer wie
    /// "AXA/DBV" alles vor dem Schrägstrich ab und machte aus dem Namen
    /// wortlos "DBV 1 Vorlage" — kein ungültiger Dateiname, sondern ein
    /// stillschweigend verstümmelter. Der Versicherername stammt aus einer
    /// Zentralruf-Antwort und ist nicht in der Hand der Kanzlei.
    ///
    /// <c>&amp;</c> bleibt stehen: unter Windows ist es erlaubt, und
    /// "Rhion &amp; Co" soll auch so heißen.
    /// </summary>
    private static string Bereinige(string name)
    {
        var ungueltig = Path.GetInvalidFileNameChars();
        return string.Create(name.Length, name, (ziel, quelle) =>
        {
            for (var i = 0; i < quelle.Length; i++)
            {
                ziel[i] = Array.IndexOf(ungueltig, quelle[i]) >= 0
                    ? Ersatzzeichen
                    : quelle[i];
            }
        });
    }
}
