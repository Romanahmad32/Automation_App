using System.Text.Json;
using AutomationService.Features.FormTemplates.Domain.Persistence;
using AutomationService.Features.FormTemplates.Domain.Services;

namespace AutomationService.Features.FormTemplates.Presentation.Dtos;

/// <summary>
/// Übertragungsformat einer Formularvorlage. Die Feldliste wird als opakes JSON
/// (<see cref="Fields"/>) verlustfrei durchgereicht — das Backend muss das
/// FieldData-Schema nicht doppelt pflegen. Die Word-Pfade gehen aufgelöst
/// (absolut) hinaus, obwohl sie relativ gespeichert sein können (#33): das
/// Frontend öffnet die Dateien direkt und kennt den Vorlagenordner nicht.
/// </summary>
public sealed record FormTemplateDto(
    int Id,
    string TemplateName,
    JsonElement Fields,
    string? WordFilePathOhneAuflistung,
    string? WordFilePathMitAuflistung)
{
    public static FormTemplateDto From(FormTemplateEntity e, string vorlagenOrdner) => new(
        e.Id,
        e.TemplateName,
        ParseFields(e.FieldsJson),
        VorlagenPfad.LoeseAuf(vorlagenOrdner, e.WordFilePathOhneAuflistung),
        VorlagenPfad.LoeseAuf(vorlagenOrdner, e.WordFilePathMitAuflistung));

    public FormTemplateEntity ToEntity() => new()
    {
        Id = Id,
        TemplateName = TemplateName,
        FieldsJson = Fields.ValueKind == JsonValueKind.Undefined ? "[]" : Fields.GetRawText(),
        WordFilePathOhneAuflistung = WordFilePathOhneAuflistung,
        WordFilePathMitAuflistung = WordFilePathMitAuflistung,
    };

    internal static JsonElement ParseFields(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return EmptyArray();
        try
        {
            using var doc = JsonDocument.Parse(json);
            return doc.RootElement.Clone();
        }
        catch
        {
            return EmptyArray();
        }
    }

    static JsonElement EmptyArray()
    {
        using var doc = JsonDocument.Parse("[]");
        return doc.RootElement.Clone();
    }
}
