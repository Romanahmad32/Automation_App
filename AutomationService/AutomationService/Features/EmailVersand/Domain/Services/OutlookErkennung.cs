using System.Runtime.Versioning;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Sieht <b>einmal beim Start</b> nach, welches Outlook auf diesem Rechner
/// steht (§4.7), und behält die Antwort.
///
/// Einmal, weil sich zwischen zwei Starts der App nichts daran ändert, was
/// installiert ist — und weil die Auskunft dann sofort dasteht, wenn der
/// Versanddialog aufgeht, statt beim ersten Klick eine Zehntelsekunde zu
/// kosten.
///
/// <b>Warum <see cref="IHostedService"/>.</b> Die Erkennung steht im
/// Konstruktor, und ein Singleton baut das Container erst, wenn es zum ersten
/// Mal gebraucht wird — beim ersten Klick also, nicht beim Start. Als
/// Hosted Service wird er beim Hochfahren aufgelöst; <see cref="StartAsync"/>
/// selbst hat deshalb nichts mehr zu tun.
/// </summary>
public sealed class OutlookErkennung : IHostedService
{
    /// <summary>Die Kennung, unter der sich das klassische Outlook anmeldet.</summary>
    private const string ProgId = "Outlook.Application";

    /// <summary>
    /// Der Paketordner der Store-App. Über ihn wird nur die <em>Formulierung</em>
    /// des Hinweises entschieden ("das neue Outlook" statt "kein Outlook") —
    /// ob etwas geht, entscheidet allein die COM-Kennung.
    /// </summary>
    private const string NeuesPaket = "Microsoft.OutlookForWindows_8wekyb3d8bbwe";

    public OutlookStand Stand { get; }

    public OutlookErkennung(ILogger<OutlookErkennung> logger)
    {
        Stand = OperatingSystem.IsWindows() ? Erkenne() : OutlookStand.Keines;
        logger.LogInformation(
            "Outlook auf diesem Rechner: klassisch={Klassisch}, neu={Neu}.",
            Stand.Klassisch,
            Stand.Neu);
    }

    /// <summary>Die Arbeit ist im Konstruktor getan; hier bleibt nichts.</summary>
    public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    [SupportedOSPlatform("windows")]
    private static OutlookStand Erkenne() => new(KennungRegistriert(), PaketVorhanden());

    private static bool KennungRegistriert()
    {
        try
        {
            return Type.GetTypeFromProgID(ProgId) is not null;
        }
        catch (Exception ausnahme) when (ausnahme is InvalidOperationException or NotSupportedException)
        {
            // Eine unlesbare Registrierung ist keine: Dann gilt Outlook als
            // nicht steuerbar, und der Hinweis erscheint. Das ist die
            // freundlichere Fehlrichtung — die andere wäre ein Knopf, der
            // wortlos nichts tut.
            return false;
        }
    }

    private static bool PaketVorhanden()
    {
        try
        {
            var lokal = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            return lokal.Length > 0
                && Directory.Exists(Path.Combine(lokal, "Packages", NeuesPaket));
        }
        catch (Exception ausnahme) when (ausnahme is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }
}
