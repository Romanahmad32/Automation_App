using AutomationService.Features.EmailVersand.Domain.Services;

namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Die Signatur, wie sie nach einer Übernahme in den Einstellungen liegt
/// (REQUIREMENTS.md §4.7).
///
/// <b>Die HTML-Fassung geht mit</b> — zum Anzeigen, nicht zum Bearbeiten. Sie
/// hielt sich hier lange heraus mit der Begründung, sie sei zehntausende
/// Zeichen groß; das ist die ganze Outlook-Datei mit Word-Stilvorlage. Was
/// davon übrig bleibt und wirklich versendet wird, ist der Rumpf: bei einer
/// üppigen Kanzleisignatur wenige Kilobyte. Ohne ihn zeigte die Vorschau nur
/// Outlooks Nur-Text-Übersetzung — und damit etwas anderes, als beim
/// Empfänger ankommt.
/// </summary>
/// <param name="Text">Outlooks Nur-Text-Fassung derselben Signatur.</param>
/// <param name="HatFormat">Ob eine formatierte Fassung übernommen ist.</param>
/// <param name="Html">Die formatierte Fassung, wie sie in die Mail geht.</param>
/// <param name="Bilder">Die Bilder darin, mit ihrer Größe.</param>
/// <param name="Uebergangen">
/// Bilder, die beim Übernehmen <b>nicht</b> mitgenommen werden konnten — zu
/// groß, leer oder nicht lesbar. Ihre Bildmarken sind aus dem HTML entfernt,
/// damit beim Empfänger kein Platzhalterkreuz steht; hier stehen sie, damit
/// der Anwalt erfährt, was fehlt. Beim bloßen Abfragen des Stands immer leer:
/// Übergangen wird beim Übernehmen, nicht beim Nachsehen.
/// </param>
public sealed record SignaturStandDto(
    string Text,
    bool HatFormat,
    string Html,
    IReadOnlyList<SignaturBildDto> Bilder,
    IReadOnlyList<string> Uebergangen)
{
    public static SignaturStandDto From(
        SignaturBlock block,
        IReadOnlyList<string>? uebergangen = null) => new(
        block.Text,
        block.Html.Length > 0,
        block.Html,
        [.. block.Bilder.Select(SignaturBildDto.From)],
        uebergangen ?? []);
}
