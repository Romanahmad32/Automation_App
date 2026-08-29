using System.Net.Sockets;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Der eigentliche Verbindungsaufbau zum Postausgangsserver (§4.7). Ab hier
/// sind die Fehler keine des Anwalts mehr, sondern die des Servers -- sie
/// werden uebersetzt, statt eine englische Protokollmeldung durchzureichen.
/// </summary>
public sealed class SmtpUebergabe(MicrosoftMailOAuthService microsoftOAuth) : ISmtpUebergabe
{
    public async Task UebergebeAsync(
        MimeMessage mime,
        SmtpZugang zugang,
        CancellationToken cancellationToken)
    {
        using var client = new SmtpClient();
        try
        {
            // Auto statt StartTls: Der Port ist konfigurierbar (EmailVersand:SmtpPort),
            // der Verschluesselungsweg haengt aber daran — 587 spricht STARTTLS, 465
            // verschluesselt sofort. Fest verdrahtetes StartTls liesse 465 an einem
            // Verbindungsfehler scheitern, der wie "Server nicht erreichbar" aussieht.
            await client.ConnectAsync(zugang.Host, zugang.Port, SecureSocketOptions.Auto, cancellationToken);
            await PostfachAnmeldung.AnmeldenAsync(client, zugang, microsoftOAuth, cancellationToken);
            await client.SendAsync(mime, cancellationToken);
            await client.DisconnectAsync(quit: true, cancellationToken);
        }
        catch (AuthenticationException exception)
        {
            throw new EmailVersandException(
                EmailVersandFehler.Anmeldung,
                "Das Postfach hat die Anmeldung abgelehnt. Bitte das Passwort in den Einstellungen "
                + "unter \"E-Mail\" prüfen — bei Gmail muss dort ein App-Passwort stehen, "
                + $"nicht das Kontopasswort. ({exception.Message})");
        }
        catch (Exception exception) when (exception is SmtpCommandException or SmtpProtocolException)
        {
            throw new EmailVersandException(
                EmailVersandFehler.Server,
                $"Der Postausgangsserver {zugang.Host} hat die Nachricht abgewiesen: {exception.Message}");
        }
        catch (Exception exception) when (exception is SocketException or IOException)
        {
            throw new EmailVersandException(
                EmailVersandFehler.Server,
                $"Der Postausgangsserver {zugang.Host}:{zugang.Port} ist nicht erreichbar. "
                + $"Besteht eine Internetverbindung? ({exception.Message})");
        }
    }
}
