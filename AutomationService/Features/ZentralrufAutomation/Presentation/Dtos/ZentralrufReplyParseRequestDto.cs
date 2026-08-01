namespace AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

/// <summary>
/// Eingabe für die Antwortmail-Extraktion. Entweder <see cref="EmailText"/>
/// (eingefügter Rohtext bzw. Inhalt einer .txt-Datei) oder
/// <see cref="EmailFileBase64"/> (komplette .eml-Datei, Base64-kodiert; wird
/// serverseitig MIME-dekodiert — Quoted-Printable, Base64-Bodies, HTML).
/// </summary>
public sealed record ZentralrufReplyParseRequestDto(
    string? EmailText,
    string? EmailFileBase64 = null);
