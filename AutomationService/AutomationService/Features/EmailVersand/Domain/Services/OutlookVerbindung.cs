using System.Collections.Concurrent;
using System.Runtime.InteropServices;

namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Der Draht zum installierten Outlook (§4.7): Entwürfe zeigen und Anhänge aus
/// der gerade geöffneten Nachricht holen.
///
/// Late Binding über die ProgID statt der Interop-PIAs — dieselbe Begründung
/// wie bei <c>WordInteropPdfConversionService</c>: Die PIA-Assemblys sind unter
/// .NET ohne GAC zur Laufzeit nicht auflösbar und würden den Prozess crashen.
///
/// <b>Die Anwendungsinstanz bleibt am Leben.</b> Der erste Zugriff auf ein
/// geschlossenes Outlook startet outlook.exe samt Profil und Add-ins und dauert
/// spürbar; jeder weitere hängt sich an die laufende Instanz und ist sofort da.
/// Genau dieser Unterschied fiel beim Testen auf. Deshalb derselbe Aufbau wie
/// beim Word-Interop: ein dauerhafter STA-Thread mit Warteschlange, der die
/// Instanz hält, dazu ein Vorwärmen, das den Kaltstart bezahlt, während der
/// Anwalt noch tippt.
/// </summary>
public sealed class OutlookVerbindung : IDisposable
{
    /// <summary>
    /// Ein kalt startendes Outlook braucht spürbar länger als ein laufendes.
    /// Läuft es danach immer noch nicht, ist der Dateiweg schneller als weiter
    /// zu warten.
    /// </summary>
    private static readonly TimeSpan Geduld = TimeSpan.FromSeconds(90);

    private sealed record Auftrag(
        Func<dynamic, object?>? Arbeit,
        TaskCompletionSource<object?> Fertig);

    private readonly BlockingCollection<Auftrag> _auftraege = [];
    private readonly ILogger<OutlookVerbindung> _logger;

    private dynamic? _outlook;
    private bool _entsorgt;

    public OutlookVerbindung(ILogger<OutlookVerbindung> logger)
    {
        _logger = logger;
        var arbeiter = new Thread(ArbeiterSchleife)
        {
            IsBackground = true,
            Name = "OutlookVerbindung",
        };
        arbeiter.SetApartmentState(ApartmentState.STA);
        arbeiter.Start();
    }

    /// <summary>
    /// Startet Outlook im Hintergrund, damit der erste echte Zugriff den
    /// Kaltstart nicht bezahlt. Kehrt sofort zurück — misslingt es, ist der
    /// Entwurfsweg deswegen nicht kaputt, nur wieder langsam.
    /// </summary>
    public void WaermeVor()
    {
        if (Verfuegbar)
        {
            Einreichen(null);
        }
    }

    /// <summary>
    /// True, wenn der Entwurf offen auf dem Schirm steht. False heißt nur „hier
    /// nicht" — kein Fehler, sondern das Stichwort für den Dateiweg.
    /// </summary>
    public bool OeffneEntwurf(EmailNachricht nachricht)
    {
        if (!Verfuegbar)
        {
            return false;
        }

        return Warte(
            Einreichen(outlook => OutlookNachricht.Zeige(outlook, nachricht)))
            is true;
    }

    /// <summary>
    /// Die Anhänge der Nachricht, die in Outlook gerade offen oder ausgewählt
    /// ist — abgelegt und mit vollem Pfad zurückgegeben (§4.7). Leer, wenn
    /// nichts ausgewählt ist oder nichts dranhängt.
    /// </summary>
    public IReadOnlyList<string> AnhaengeDerAuswahl()
    {
        if (!Verfuegbar)
        {
            return [];
        }

        return Warte(Einreichen(OutlookAuswahl.Anhaenge)) as IReadOnlyList<string> ?? [];
    }

    private bool Verfuegbar => OperatingSystem.IsWindows() && !_entsorgt;

    private Auftrag? Einreichen(Func<dynamic, object?>? arbeit)
    {
        var auftrag = new Auftrag(
            arbeit,
            new TaskCompletionSource<object?>(TaskCreationOptions.RunContinuationsAsynchronously));

        try
        {
            _auftraege.Add(auftrag);
            return auftrag;
        }
        catch (InvalidOperationException)
        {
            return null;
        }
    }

    private object? Warte(Auftrag? auftrag)
    {
        if (auftrag is null)
        {
            return null;
        }

        if (auftrag.Fertig.Task.Wait(Geduld))
        {
            return auftrag.Fertig.Task.Result;
        }

        _logger.LogWarning(
            "Outlook hat den Auftrag nicht innerhalb von {Sekunden} Sekunden erledigt.",
            Geduld.TotalSeconds);
        return null;
    }

    private void ArbeiterSchleife()
    {
        foreach (var auftrag in _auftraege.GetConsumingEnumerable())
        {
            try
            {
                auftrag.Fertig.TrySetResult(Erledige(auftrag.Arbeit));
            }
            catch (COMException ausnahme)
            {
                // Outlook kann zwischendurch beendet worden sein. Einmal frisch
                // anfassen und den Auftrag wiederholen.
                _logger.LogWarning(ausnahme, "Outlook-Zugriff fehlgeschlagen, baue die Verbindung neu auf.");
                _outlook = null;
                try
                {
                    auftrag.Fertig.TrySetResult(Erledige(auftrag.Arbeit));
                }
                catch (Exception zweite)
                {
                    _logger.LogWarning(zweite, "Der Outlook-Zugriff ist gescheitert.");
                    auftrag.Fertig.TrySetResult(null);
                }
            }
            catch (Exception ausnahme)
            {
                _logger.LogWarning(ausnahme, "Der Outlook-Zugriff ist gescheitert.");
                auftrag.Fertig.TrySetResult(null);
            }
        }
    }

    private object? Erledige(Func<dynamic, object?>? arbeit)
    {
        var outlook = Anwendung();
        if (outlook is null)
        {
            return null;
        }

        // Ohne Arbeit war es ein Vorwärmen: Die Instanz steht, mehr war nicht
        // verlangt.
        return arbeit?.Invoke(outlook);
    }

    /// <summary>
    /// Die laufende Outlook-Instanz, sonst eine neu gestartete. Die Referenz
    /// bleibt liegen — sie ist der ganze Unterschied zwischen „öffnet sofort"
    /// und „öffnet nach einer halben Minute".
    /// </summary>
    private dynamic? Anwendung()
    {
        if (_outlook is not null)
        {
            return _outlook;
        }

        if (!OperatingSystem.IsWindows())
        {
            return null;
        }

        var typ = Type.GetTypeFromProgID("Outlook.Application");
        if (typ is null)
        {
            return null;
        }

        _outlook = Activator.CreateInstance(typ);
        return _outlook;
    }

    public void Dispose()
    {
        if (_entsorgt)
        {
            return;
        }

        _entsorgt = true;
        _auftraege.CompleteAdding();

        // Die Instanz nur loslassen, nicht Outlook beenden: Sie kann längst dem
        // Anwalt gehören, der sein Postfach offen hat.
        _outlook = null;
        _auftraege.Dispose();
    }
}
