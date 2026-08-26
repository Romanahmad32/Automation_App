using System.Net.Sockets;
using AutomationService.Features.MailboxMonitor.Domain.Services;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Versendet über SMTP mit demselben Postfach-Zugang, über den auch empfangen
/// wird (REQUIREMENTS.md §4.7).
///
/// Reihenfolge ist Absicht: Erst Zugang, dann Anhänge, dann Adressen, und
/// zuletzt die Verbindung. Alles, was der Anwalt selbst beheben kann, soll
/// scheitern, bevor irgendetwas das Haus verlassen hat.
/// </summary>
public sealed class SmtpEmailVersender(
    MailboxConfigStore configStore,
    MicrosoftMailOAuthService microsoftOAuth,
    GesendetOrdnerAblage gesendetOrdner,
    KanzleiSignatur signatur,
    IOptions<EmailVersandOptions> optionen,
    ILogger<SmtpEmailVersender> logger) : IEmailVersender
{
    public async Task<EmailVersandBereitschaft> PruefeBereitschaftAsync(CancellationToken cancellationToken)
    {
        var zugang = SmtpZugang.Aus(configStore.Current, optionen.Value);
        if (zugang is null)
        {
            return EmailVersandBereitschaft.Nicht(
                "Es ist kein Postfach-Zugang hinterlegt. Bitte in den Einstellungen unter "
                + "\"Postfach-Zugang\" die Kanzlei-Adresse einrichten.");
        }

        if (zugang.AuthMethod == MailboxAuthMethod.MicrosoftOAuth
            && string.IsNullOrEmpty(await microsoftOAuth.GetAccessTokenSilentAsync(cancellationToken)))
        {
            return EmailVersandBereitschaft.Nicht(
                "Die Microsoft-Anmeldung ist abgelaufen. Bitte in den Einstellungen unter "
                + "\"Postfach-Zugang\" erneut mit Microsoft anmelden.");
        }

        return new EmailVersandBereitschaft(true, zugang.Absender, null);
    }

    public async Task<EmailVersandErgebnis> SendeAsync(
        EmailNachricht nachricht,
        CancellationToken cancellationToken)
    {
        var einstellungen = optionen.Value;
        var zugang = SmtpZugang.Aus(configStore.Current, einstellungen)
            ?? throw new EmailVersandException(
                EmailVersandFehler.KeinZugang,
                "Es ist kein Postfach-Zugang hinterlegt. Bitte in den Einstellungen unter "
                + "\"Postfach-Zugang\" die Kanzlei-Adresse einrichten.");

        var anhaenge = AnhangPruefung.Lade(nachricht.AnhangPfade, einstellungen.MaxAnhangGesamtMb);

        // Die Signatur kommt erst hier dazu, nicht im Formular: Sie gehört den
        // Einstellungen, nicht dem einzelnen Entwurf (§4.7).
        var mitSignatur = nachricht with
        {
            Text = await signatur.UnterAsync(nachricht.Text, cancellationToken),
        };
        var mime = EmailNachrichtBauer.Baue(mitSignatur, zugang.Absender, anhaenge);

        await UebergebeAsync(mime, zugang, cancellationToken);
        var gesendetAm = DateTimeOffset.Now;
        logger.LogInformation(
            "E-Mail über {Absender} an {Anzahl} Empfänger gesendet ({Anhaenge} Anhänge).",
            zugang.Absender,
            mime.To.Count + mime.Cc.Count,
            anhaenge.Count);

        var kopieNoetig = einstellungen.KopieInGesendet ?? !zugang.ServerLegtKopieSelbstAb;
        var kopieAbgelegt = !kopieNoetig
            || await gesendetOrdner.LegeAbAsync(mime, zugang, cancellationToken);

        return new EmailVersandErgebnis(
            gesendetAm,
            [.. mime.To.Mailboxes.Concat(mime.Cc.Mailboxes).Select(adresse => adresse.Address)],
            ImGesendetOrdner: kopieAbgelegt,
            Hinweis: kopieAbgelegt
                ? null
                : "Die Mail ist versendet, konnte aber nicht in den Ordner \"Gesendet\" "
                  + "des Postfachs kopiert werden.");
    }

    /// <summary>
    /// Der eigentliche Verbindungsaufbau. Ab hier sind die Fehler keine des
    /// Anwalts mehr, sondern die des Servers — sie werden übersetzt, statt eine
    /// englische Protokollmeldung durchzureichen.
    /// </summary>
    private async Task UebergebeAsync(
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
                + "unter \"Postfach-Zugang\" prüfen — bei Gmail muss dort ein App-Passwort stehen, "
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
