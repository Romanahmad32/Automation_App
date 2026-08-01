using System.Text.Json;
using AutomationService.Features.FormTemplates.Domain.Persistence;

namespace AutomationService.Features.FormTemplates.Presentation.Dtos;

/// <summary>
/// Übertragungsformat einer Formularvorlage. Die Feldliste wird als opakes JSON
/// (<see cref="Fields"/>) verlustfrei durchgereicht — das Backend muss das
/// FieldData-Schema nicht doppelt pflegen.
/// </summary>
public sealed record FormTemplateDto(
    int Id,
    string TemplateName,
    JsonElement Fields,
    string? WordFilePathOhneAuflistung,
    string? WordFilePathMitAuflistung)
{
    public static FormTemplateDto From(FormTemplateEntity e) => new(
        e.Id,
        e.TemplateName,
        ParseFields(e.FieldsJson),
        e.WordFilePathOhneAuflistung,
        e.WordFilePathMitAuflistung);

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
