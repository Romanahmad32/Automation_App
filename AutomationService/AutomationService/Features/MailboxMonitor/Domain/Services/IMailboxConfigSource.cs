namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Lesender Blick auf den hinterlegten Postfach-Zugang (§4.3, §7.1).
///
/// <see cref="MailboxConfigStore"/> setzt das um und kann mehr: schreiben,
/// persistieren, Aenderungen signalisieren. Wer den Zugang nur <b>liest</b> --
/// der Versand etwa --, haengt an dieser Schnittstelle statt an der Klasse.
///
/// Der Grund ist nicht Formsache: Der Store liest im Konstruktor
/// <c>%APPDATA%\AutomationService\mailbox_config.json</c>. Ein Test, der ihn
/// baut, liest damit das <b>echte</b> Postfach des Rechners, auf dem er laeuft
/// -- er faellt bei dem einen Entwickler und nicht bei dem anderen, und in der
/// CI wieder anders. Genau darueber ist der erste Anlauf zu
/// <c>VersandwegTests</c> gestolpert.
/// </summary>
public interface IMailboxConfigSource
{
    /// <summary>Die aktuell gueltige, vollstaendige Konfiguration.</summary>
    MailboxOptions Current { get; }
}
