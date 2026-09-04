using AutomationService.Core.Persistence;
using AutomationService.Features.Settings.Domain.Persistence;
using Microsoft.EntityFrameworkCore;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Übernimmt eine in Outlook eingerichtete Signatur in die Einstellungen
/// (§4.7 „Signatur") — Text, formatierte Fassung und Bilder in einem Schritt.
///
/// Der Vorgang läuft bewusst im Dienst und nicht in der Oberfläche: Die Bilder
/// müssen abgelegt werden, und die HTML-Fassung ist zehntausende Zeichen groß.
/// Beides durch die HTTP-Schnittstelle und ein Formular zu schleifen, nur damit
/// es von dort wieder zurückkommt, wäre ein Umweg mit drei Stellen, an denen
/// etwas verlorengeht.
///
/// Es gibt immer nur eine übernommene Signatur: Eine neue ersetzt die alte
/// samt ihren Bildern.
/// </summary>
public sealed class SignaturUebernahme(
    AutomationDbContext db,
    SignaturAblage ablage,
    ILogger<SignaturUebernahme> logger)
{
    /// <summary>
    /// Liest die Signatur mit diesem Namen, <b>ohne etwas zu speichern</b>
    /// (§4.7, ergänzt am 02.09.2026) — für die Vorschau im Formular, bevor der
    /// Anwalt auf „Speichern" drückt.
    ///
    /// Der Grund: <see cref="UebernimmAsync"/> schrieb bisher schon beim
    /// Übernehmen — Text, HTML und Bilder waren in der Datenbank, bevor
    /// irgendwer gespeichert hatte, und die bisherigen Bilder waren dabei
    /// unwiederbringlich weg. Wer sich die Signatur nur ansehen wollte, hatte
    /// sie damit gewechselt.
    ///
    /// Die Bilder kommen als <b>Angabe</b> zurück, nicht als Inhalt: Sie
    /// dürfen 25 MB groß sein (<see cref="SignaturAblage.MaxBildBytes"/>) und
    /// gehen nicht über die Leitung, nur um von dort wieder zurückzukommen.
    /// Abgelegt werden sie erst bei der Übernahme; zu sehen sind sie
    /// vorher — die Oberfläche holt jedes einzeln aus Outlooks Beiordner
    /// (<see cref="OutlookSignaturen.LiesBild"/>).
    ///
    /// Bis zum 04.09.2026 ging sie stattdessen an die Ablage, und weil Outlook
    /// jedes erste Bild <c>image001.png</c> nennt, bekam sie von dort das Logo
    /// der <b>vorigen</b> Signatur geliefert — ohne dass irgendwo stand, dass
    /// es das alte ist.
    /// </summary>
    /// <exception cref="EmailVersandException">
    /// Wenn es unter diesem Namen keine Signatur gibt.
    /// </exception>
    public (SignaturBlock Block, IReadOnlyList<string> Uebergangen) Lies(string name)
    {
        var (text, format) = LiesAusOutlook(name);
        var bilder = format is null ? [] : ablage.Vorschau(format.Bilder);
        return (
            new SignaturBlock(text ?? string.Empty, format?.Html ?? string.Empty, bilder),
            format?.Uebergangen ?? []);
    }

    /// <summary>
    /// Text und formatierte Fassung aus Outlook — die eine Stelle, die den
    /// Namen auflöst, damit Lesen und Übernehmen nicht auseinanderlaufen.
    /// </summary>
    private static (string? Text, OutlookSignaturFormat? Format) LiesAusOutlook(string name)
    {
        var text = OutlookSignaturen.LiesTextVon(name);
        var format = OutlookSignaturen.LiesFormat(name);

        if (text is null && format is null)
        {
            throw new EmailVersandException(
                EmailVersandFehler.Anhang,
                $"In Outlook gibt es keine Signatur namens \"{name}\" (mehr).");
        }

        return (text, format);
    }

    /// <summary>
    /// Übernimmt die Signatur mit diesem Namen. Gibt zurück, was danach
    /// gespeichert ist — die Oberfläche zeigt daraus Text und Bildliste — und
    /// welche Bilder dabei übergangen werden mussten.
    /// </summary>
    /// <exception cref="EmailVersandException">
    /// Wenn es unter diesem Namen keine Signatur gibt. Der Anwalt hat sie aus
    /// einer Liste gewählt; ist sie inzwischen weg, ist das eine Meldung wert
    /// und kein stilles Leeren der Einstellungen.
    /// </exception>
    public async Task<(SignaturBlock Block, IReadOnlyList<string> Uebergangen)> UebernimmAsync(
        string name,
        CancellationToken cancellationToken)
    {
        var (text, format) = LiesAusOutlook(name);

        IReadOnlyList<SignaturBild> bilder = [];
        if (format is null)
        {
            // Nur Text uebernommen: Die Bilder der vorigen Signatur haetten
            // sonst keinen Verweis mehr, der auf sie zeigt.
            ablage.Leere();
        }
        else
        {
            bilder = ablage.Ersetze(format.Bilder);
        }

        var block = new SignaturBlock(text ?? string.Empty, format?.Html ?? string.Empty, bilder);
        await SchreibeAsync(block, cancellationToken);

        IReadOnlyList<string> uebergangen = format?.Uebergangen ?? [];
        logger.LogInformation(
            "Signatur \"{Name}\" übernommen ({Zeichen} Zeichen HTML, {Bilder} Bilder, "
            + "{Uebergangen} übergangen).",
            name,
            block.Html.Length,
            bilder.Count,
            uebergangen.Count);

        if (uebergangen.Count > 0)
        {
            // Nicht verschweigen: Der Anwalt sieht die Signatur danach ohne
            // dieses Bild und soll wissen, warum — und dass es an der Groesse
            // liegen kann, nicht an einem Fehler der App.
            logger.LogWarning(
                "Diese Bilder der Signatur \"{Name}\" wurden übergangen (zu groß, leer oder "
                + "nicht lesbar): {Bilder}",
                name,
                string.Join(", ", uebergangen));
        }

        return (block, uebergangen);
    }

    /// <summary>
    /// Wirft die formatierte Fassung weg und lässt nur den Text stehen — für
    /// den Anwalt, dem die übernommene Formatierung nicht gefällt. Die
    /// Nur-Text-Fassung bleibt: Sie ist in den Einstellungen von Hand pflegbar.
    /// </summary>
    public async Task<SignaturBlock> VerwirfFormatAsync(CancellationToken cancellationToken)
    {
        var settings = await LadeAsync(cancellationToken);
        ablage.Leere();
        var block = new SignaturBlock(settings.MailSignatur, string.Empty, []);
        await SchreibeAsync(block, cancellationToken);
        return block;
    }

    private async Task SchreibeAsync(SignaturBlock block, CancellationToken cancellationToken)
    {
        var settings = await LadeAsync(cancellationToken);
        if (block.Text.Length > 0)
        {
            settings.MailSignatur = block.Text;
        }

        settings.MailSignaturHtml = block.Html;
        await db.SaveChangesAsync(cancellationToken);
    }

    private async Task<KanzleiSettingsEntity> LadeAsync(CancellationToken cancellationToken)
    {
        var settings = await db.KanzleiSettings
            .FirstOrDefaultAsync(s => s.Id == KanzleiSettingsEntity.SingletonId, cancellationToken);
        if (settings is not null)
        {
            return settings;
        }

        settings = new KanzleiSettingsEntity { Id = KanzleiSettingsEntity.SingletonId };
        db.KanzleiSettings.Add(settings);
        return settings;
    }
}
