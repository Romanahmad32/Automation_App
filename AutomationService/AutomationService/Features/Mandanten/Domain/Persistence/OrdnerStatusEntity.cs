namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Vermerk zu einem Akten-Ordner, der keinem Mandanten zugeordnet werden muss
/// (§6.1) — Organisations- und Sammelordner, Sachgebiete außerhalb des
/// Verkehrsunfalls. Ein dritter Zustand neben <em>zugeordnet</em> (der Ordner
/// steht am Mandanten) und <em>offen</em> (er steht nirgends).
///
/// Bewusst ein Status und kein bloßes Ausblenden: Der Zuordnungsstapel soll ein
/// Arbeitsvorrat sein, der auf null gehen kann, und die Entscheidung soll
/// sichtbar und jederzeit zurücknehmbar bleiben, statt still zu verschwinden.
///
/// Gleicher Fallstrick wie bei der Zuordnung: Der Vermerk hängt am
/// <b>Ordnernamen</b>, nicht am Pfad. Ein im Explorer umbenannter Ordner taucht
/// deshalb wieder als offen auf.
/// </summary>
public class OrdnerStatusEntity
{
    public int Id { get; set; }

    /// <summary>Ordnername relativ zum Akten-Stammordner.</summary>
    public string Ordnername { get; set; } = string.Empty;

    /// <summary>Einer der Werte aus <see cref="OrdnerStatusArten"/>.</summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>Wann die Entscheidung getroffen wurde.</summary>
    public DateTime GesetztAm { get; set; }
}

/// <summary>
/// Die erlaubten Werte von <see cref="OrdnerStatusEntity.Status"/>. Heute genau
/// einer — die Tabelle trägt trotzdem eine Statusspalte statt bloßer Zeilen,
/// weil daneben absehbar weitere Entscheidungen stehen werden (Sammelordner,
/// Ablage) und ein nachträglich eingezogener Status eine Migration mehr wäre.
/// </summary>
public static class OrdnerStatusArten
{
    public const string OhneMandantenbezug = "ohneMandantenbezug";

    public static readonly IReadOnlySet<string> Alle =
        new HashSet<string>(StringComparer.Ordinal) { OhneMandantenbezug };
}
