namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Was ein Import zu berichten hat: die Vorlagen, die nicht ersetzt wurden,
/// weil lokal eine gleichnamige Datei mit anderem Inhalt liegt (#33). Sie
/// werden dem Anwender genannt statt still ueberschrieben — sein lokaler
/// Stand koennte der neuere sein, und die Vor-Import-Sicherung daneben ist
/// nur ein Rettungsanker, kein Freibrief.
/// </summary>
/// <param name="UebersprungeneVorlagen">Relative Pfade im Vorlagenordner.</param>
public sealed record SicherungsImportErgebnis(IReadOnlyList<string> UebersprungeneVorlagen)
{
    public static readonly SicherungsImportErgebnis Leer = new([]);
}
