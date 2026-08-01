namespace AutomationService.Features.ZentralrufAutomation.Domain.Services;

public interface IZentralrufReplyParser
{
    /// <summary>
    /// Extrahiert die für das Anspruchsschreiben relevanten Daten aus dem
    /// Rohtext einer Zentralruf-Antwortmail.
    /// </summary>
    ZentralrufReplyData Parse(string emailText);
}
