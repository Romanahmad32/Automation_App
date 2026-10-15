using Microsoft.Extensions.Options;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Die Aktualisierung aus der App heraus (#196) als Zustandsmaschine — ein
/// Singleton, denn der Stand muss zwischen den Anfragen des Dialogs bestehen
/// bleiben, und der Download läuft im Hintergrund weiter, während das
/// Frontend ihn abfragt.
///
/// Jede Änderung am Zustand (<see cref="AktualisierungsLage"/>) geschieht unter
/// <see cref="_sperre"/>; nach außen geht nur die unveränderliche
/// <see cref="AktualisierungsStand"/>-Aufnahme. Was lange dauert (Anfrage,
/// Download), läuft außerhalb der Sperre.
/// </summary>
public sealed class AktualisierungsDienst : IAktualisierungsDienst, IDisposable
{
    private readonly IAktualisierungsQuelle _quelle;
    private readonly IInstallerStarter _starter;
    private readonly IHerunterfahrenNachInstallerStart _herunterfahren;
    private readonly AktualisierungsOrdner _ordner;
    private readonly Merkdatei _merkdatei;
    private readonly AktualisierungOptions _optionen;
    private readonly ILogger<AktualisierungsDienst> _logger;
    private readonly TimeProvider _zeit;
    private readonly string _laufendeVersion;
    private readonly AktualisierungsLage _lage;
    private readonly Lock _sperre = new();

    /// <summary>
    /// Reiht nur <see cref="Installiere"/> hintereinander. Zweite Prüfung und
    /// Anlauffrist dauern Sekunden; so lange soll <see cref="Stand"/> nicht warten.
    /// </summary>
    private readonly Lock _installation = new();

    private bool _installerGestartet;
    private CancellationTokenSource? _abbruch;
    private Task _download = Task.CompletedTask;

    /// <summary>Die laufende Version kommt herein, wie <c>/health</c> sie meldet (<c>Programmfassung.Aktuell</c>) — ein Test setzt sie.</summary>
    public AktualisierungsDienst(
        IAktualisierungsQuelle quelle,
        IInstallerStarter starter,
        IHerunterfahrenNachInstallerStart herunterfahren,
        AktualisierungsOrdner ordner,
        IOptions<AktualisierungOptions> optionen,
        ILogger<AktualisierungsDienst> logger,
        string laufendeVersion,
        TimeProvider? zeit = null)
    {
        ArgumentNullException.ThrowIfNull(ordner);
        ArgumentNullException.ThrowIfNull(optionen);

        _quelle = quelle;
        _starter = starter;
        _herunterfahren = herunterfahren;
        _ordner = ordner;
        _merkdatei = new Merkdatei(ordner.Merkdatei);
        _optionen = optionen.Value;
        _logger = logger;
        _laufendeVersion = laufendeVersion;
        _lage = new AktualisierungsLage(laufendeVersion);
        _zeit = zeit ?? TimeProvider.System;
    }

    public AktualisierungsStand Stand()
    {
        lock (_sperre)
        {
            return _lage.Momentaufnahme();
        }
    }

    public void Initialisiere()
    {
        var letzte = _merkdatei.Auswerten(_laufendeVersion);
        lock (_sperre)
        {
            _lage.Letzte = letzte;
        }

        _ordner.RaeumeAuf(behalten: Versionsnummer.Lies(letzte?.ZielVersion), _logger);
    }

    public async Task<AktualisierungsStand> PruefeAsync(CancellationToken cancellationToken)
    {
        lock (_sperre)
        {
            if (_lage.LaeuftOderBereit)
            {
                return _lage.Momentaufnahme();
            }
        }

        SetupAuswahlErgebnis auswahl;
        try
        {
            using var frist = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            frist.CancelAfter(_optionen.PruefZeitlimit);
            auswahl = SetupAuswahl.Waehle(await _quelle.HoleNeuesteAsync(frist.Token), _laufendeVersion);
        }
        catch (Exception ausnahme) when (!cancellationToken.IsCancellationRequested)
        {
            // Ohne Netz, hinter einer Firewall, bei einem Ausfall von GitHub oder
            // an seinem Ratenlimit: erwartbar, also kein Fehler — aber auch keine Entwarnung.
            _logger.LogInformation(ausnahme, "Die Prüfung auf Aktualisierungen ging nicht.");
            lock (_sperre)
            {
                if (!_lage.LaeuftOderBereit)
                {
                    _lage.Setze(
                        AktualisierungsZustand.Unbekannt, null, AktualisierungsMeldungen.NachGescheiterterPruefung(ausnahme));
                }

                return _lage.Momentaufnahme();
            }
        }

        lock (_sperre)
        {
            // Ein paralleles „Herunterladen" kann inzwischen gestartet sein.
            if (!_lage.LaeuftOderBereit)
            {
                _lage.Bewerte(auswahl);
            }

            return _lage.Momentaufnahme();
        }
    }

    public AktualisierungsSchritt StarteDownload()
    {
        lock (_sperre)
        {
            if (_lage.LaeuftOderBereit)
            {
                return new AktualisierungsSchritt(_lage.Momentaufnahme(), null);
            }

            var auswahl = _lage.Auswahl;
            if (auswahl?.Setup is not { } setup)
            {
                // Bei fehlender Prüfsumme sagt die Meldung schon, warum nicht.
                var grund = auswahl?.Art is AuswahlArt.OhnePruefsumme or AuswahlArt.OhneSetup ? _lage.Meldung : null;
                return new AktualisierungsSchritt(_lage.Momentaufnahme(), grund ?? AktualisierungsMeldungen.KeineNeueVersion);
            }

            // Von „verfuegbar" oder nach einem gescheiterten Versuch aus „fehler".
            _abbruch?.Dispose();
            _abbruch = new CancellationTokenSource();
            var abbruch = _abbruch.Token;
            _lage.Setze(AktualisierungsZustand.Laedt, auswahl);
            _download = Task.Run(() => LadeAsync(setup, abbruch), CancellationToken.None);
            return new AktualisierungsSchritt(_lage.Momentaufnahme(), null);
        }
    }

    public async Task<AktualisierungsStand> BrecheAbAsync()
    {
        CancellationTokenSource? abbruch;
        Task download;
        lock (_sperre)
        {
            if (_lage.Zustand != AktualisierungsZustand.Laedt)
            {
                return _lage.Momentaufnahme();
            }

            abbruch = _abbruch;
            download = _download;
        }

        // Außerhalb der Sperre: Cancel führt Fortsetzungen unter Umständen
        // gleich auf diesem Thread aus, und die wollen die Sperre.
        try
        {
            await (abbruch?.CancelAsync() ?? Task.CompletedTask);
        }
        catch (ObjectDisposedException)
        {
            // Der Download war schon fertig, und ein neuer hat seine Quelle ersetzt.
        }

        await download;
        return Stand();
    }

    public AktualisierungsSchritt Installiere()
    {
        lock (_installation)
        {
            SetupDatei setup;
            lock (_sperre)
            {
                if (_lage.Zustand != AktualisierungsZustand.Bereit || _lage.Auswahl?.Setup is not { } bereit)
                {
                    return new AktualisierungsSchritt(_lage.Momentaufnahme(), AktualisierungsMeldungen.NichtBereit);
                }

                // Ein zweiter Klick startet kein zweites Setup.
                if (_installerGestartet)
                {
                    return new AktualisierungsSchritt(_lage.Momentaufnahme(), null);
                }

                // Etwa ein Dienst aus der Entwicklungsumgebung: Ablehnen, ohne
                // den Zustand zu ändern — die Datei ist ja geladen und geprüft.
                if (_starter.Sperrgrund is { } grund)
                {
                    return new AktualisierungsSchritt(_lage.Momentaufnahme(), grund);
                }

                setup = bereit;
            }

            // Außerhalb der Sperre: Prüfen und Anlauffrist dauern Sekunden.
            var fehler = InstallerStart.PruefeUndStarte(setup, _ordner, _merkdatei, _starter, _zeit, _logger);
            lock (_sperre)
            {
                if (fehler is null)
                {
                    _installerGestartet = true;
                    // Kehrt sofort zurück: Heruntergefahren wird erst, wenn die
                    // Antwort längst beim Frontend ist.
                    _herunterfahren.StoesseAn();
                    return new AktualisierungsSchritt(_lage.Momentaufnahme(), null);
                }

                // Auch ein Setup, das sich sofort wieder beendet hat: Der Dienst
                // bleibt an, das Frontend zeigt 2d und bleibt offen.
                _lage.SetzeFehler(_lage.Auswahl, fehler);
                return new AktualisierungsSchritt(_lage.Momentaufnahme(), fehler.Meldung);
            }
        }
    }

    public void QuittiereErgebnis()
    {
        _merkdatei.Loesche();
        lock (_sperre)
        {
            _lage.Letzte = null;
        }
    }

    public async Task SetzeZurueckAsync()
    {
        await BrecheAbAsync();
        lock (_sperre)
        {
            _lage.Setze(AktualisierungsZustand.Unbekannt, null);
            _installerGestartet = false;
        }

        _ordner.RaeumeAuf(behalten: null, _logger);
    }

    public void Dispose()
    {
        // Beim Herunterfahren: Der Download bricht ab und räumt seine
        // Teildatei weg; was liegen bleibt, räumt der nächste Start.
        _abbruch?.Cancel();
        _abbruch?.Dispose();
    }

    private async Task LadeAsync(SetupDatei setup, CancellationToken abbruch)
    {
        AktualisierungsFehler? fehler;
        try
        {
            fehler = await SetupBeschaffung.LadeUndPruefeAsync(
                _quelle, setup, _ordner, _optionen.DownloadLeerlauf, MeldeFortschritt, _logger, abbruch, _zeit);
        }
        catch (OperationCanceledException) when (abbruch.IsCancellationRequested)
        {
            // Abgebrochen: zurück auf „verfuegbar", die Teildatei ist schon weg.
            lock (_sperre)
            {
                _lage.Setze(AktualisierungsZustand.Verfuegbar, _lage.Auswahl);
            }

            return;
        }

        lock (_sperre)
        {
            if (fehler is null)
            {
                _lage.Bereit(setup.Groesse);
            }
            else
            {
                _lage.SetzeFehler(_lage.Auswahl, fehler);
            }
        }
    }

    private void MeldeFortschritt(long geschrieben)
    {
        lock (_sperre)
        {
            _lage.MeldeFortschritt(geschrieben);
        }
    }
}
