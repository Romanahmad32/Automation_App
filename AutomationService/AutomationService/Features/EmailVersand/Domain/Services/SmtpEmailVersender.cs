using AutomationService.Features.MailboxMonitor.Domain.Services;
using Microsoft.Extensions.Options;

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
    IMailboxConfigSource configStore,
    MicrosoftMailOAuthService microsoftOAuth,
    IGesendetOrdnerAblage gesendetOrdner,
    ISmtpUebergabe uebergabe,
    VersandProtokoll protokoll,
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
                + "\"E-Mail\" die Kanzlei-Adresse einrichten.");
        }

        if (zugang.AuthMethod == MailboxAuthMethod.MicrosoftOAuth
            && string.IsNullOrEmpty(await microsoftOAuth.GetAccessTokenSilentAsync(cancellationToken)))
        {
            return EmailVersandBereitschaft.Nicht(
                "Die Microsoft-Anmeldung ist abgelaufen. Bitte in den Einstellungen unter "
                + "\"E-Mail\" erneut mit Microsoft anmelden.");
        }

        var block = await signatur.BlockAsync(cancellationToken);
        return new EmailVersandBereitschaft(
            true,
            zugang.Absender,
            null,
            block.Text,
            block.Html,
            block.Bilder,
            optionen.Value.MaxAnhangGesamtMb);
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
                + "\"E-Mail\" die Kanzlei-Adresse einrichten.");

        // Die Signatur kommt erst hier dazu, nicht im Formular: Sie gehört den
        // Einstellungen, nicht dem einzelnen Entwurf (§4.7). Ihre Bilder wiegen
        // aber mit — deshalb steht sie vor der Anhangsprüfung.
        var signaturblock = await signatur.FuerVersandAsync(
            nachricht.OhneSignaturBilder ?? [],
            cancellationToken);

        var anhaenge = AnhangPruefung.Lade(
            nachricht.AnhangPfade,
            einstellungen.MaxAnhangGesamtMb,
            nachricht.AnhangNamen,
            SignaturBytes(signaturblock));

        var mime = EmailNachrichtBauer.Baue(nachricht, zugang.Absender, anhaenge, signaturblock);

        await uebergabe.UebergebeAsync(mime, zugang, cancellationToken);
        var gesendetAm = DateTimeOffset.Now;
        logger.LogInformation(
            "E-Mail über {Absender} an {Anzahl} Empfänger gesendet ({Anhaenge} Anhänge).",
            zugang.Absender,
            mime.To.Count + mime.Cc.Count,
            anhaenge.Count);

        var kopieNoetig = einstellungen.KopieInGesendet ?? !zugang.ServerLegtKopieSelbstAb;
        var kopieAbgelegt = !kopieNoetig
            || await gesendetOrdner.LegeAbAsync(mime, zugang, cancellationToken);

        // Erst hier, nicht vorher: Was protokolliert wird, ist hinausgegangen.
        // Ein Fehlschlag beim Schreiben haelt nichts auf (siehe VersandProtokoll).
        await protokoll.SchreibeAsync(
            new VersandEintrag(
                nachricht.VorgangReferenz,
                gesendetAm,
                VersandWeg.Direktversand,
                zugang.Absender,
                [.. mime.To.Mailboxes.Select(adresse => adresse.Address)],
                [.. mime.Cc.Mailboxes.Select(adresse => adresse.Address)],
                mime.Subject ?? string.Empty,
                [.. anhaenge.Select(anhang => anhang.Dateiname)],
                kopieAbgelegt,
                mime.MessageId),
            cancellationToken);

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
    /// Was die eingebetteten Signaturbilder wiegen. Sie sind keine Anhänge,
    /// gehen aber im selben Umschlag hinaus — für den Server der Gegenseite
    /// zählt die Nachricht als Ganzes.
    /// </summary>
    private static long SignaturBytes(SignaturVersand? signatur)
    {
        if (signatur is null)
        {
            return 0;
        }

        long gesamt = 0;
        foreach (var pfad in signatur.BildPfade)
        {
            var datei = new FileInfo(pfad);
            if (datei.Exists)
            {
                gesamt += datei.Length;
            }
        }

        return gesamt;
    }
}
