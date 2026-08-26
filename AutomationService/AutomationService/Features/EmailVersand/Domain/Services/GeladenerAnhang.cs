namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Ein Anhang, der bereits vollständig im Speicher liegt. Die Dateien werden
/// <b>vor</b> dem Verbindungsaufbau gelesen: Was nicht lesbar ist, soll den
/// Versand verhindern, bevor irgendetwas hinausgegangen ist.
/// </summary>
public sealed record GeladenerAnhang(string Dateiname, byte[] Inhalt);
