using System.Text.Json;
using AutomationService.Features.FormTemplates.Domain.Persistence;

namespace AutomationService.Features.FormTemplates.Presentation.Dtos;

/// <summary>
/// Eingabe zum Anlegen einer Formularvorlage. Die Id vergibt das Backend.
/// </summary>
public sealed record CreateFormTemplateDto(
    string TemplateName,
    JsonElement Fields,
    string? WordFilePathOhneAuflistung,
    string? WordFilePathMitAuflistung)
{
    public FormTemplateEntity ToEntity() => new()
    {
        TemplateName = TemplateName,
        FieldsJson = Fields.ValueKind == JsonValueKind.Undefined ? "[]" : Fields.GetRawText(),
        WordFilePathOhneAuflistung = WordFilePathOhneAuflistung,
        WordFilePathMitAuflistung = WordFilePathMitAuflistung,
    };
}
