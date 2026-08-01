namespace AutomationService.Features.FormTemplates.Domain.Persistence;

/// <summary>
/// Persistenz-Abbild einer benutzerdefinierten Formularvorlage. Die Feldliste
/// wird als Ganzes gelesen/geschrieben und nie einzeln abgefragt — daher als
/// JSON-Spalte (<see cref="FieldsJson"/>) statt eigener Kindtabelle. Die beiden
/// Word-Pfade verweisen auf die Vorlagen mit bzw. ohne Schadensaufstellung.
/// </summary>
public class FormTemplateEntity
{
    public int Id { get; set; }

    public string TemplateName { get; set; } = string.Empty;

    /// <summary>JSON-Array der Feld-Definitionen (List&lt;FieldData&gt;), nach Order sortiert.</summary>
    public string FieldsJson { get; set; } = "[]";

    public string? WordFilePathOhneAuflistung { get; set; }
    public string? WordFilePathMitAuflistung { get; set; }
}
