using AutomationService.Features.Mandanten.Domain.Persistence;

namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Der Zustand eines einzelnen Importlaufs: die beiden Verzeichnisse, gegen die
/// jede Zeile geprüft wird (Name → Mandant, Ordner → Besitzer), und was dabei
/// herauskommt.
///
/// Beide Verzeichnisse wachsen während des Laufs mit. Genau daran hängen zwei
/// Eigenschaften, die eine maschinell erzeugte Datei braucht: zwei Zeilen mit
/// demselben Namen ergeben <b>einen</b> Mandanten statt einer Dublette, und
/// zwei Zeilen, die denselben Ordner beanspruchen, können ihn nicht beide
/// bekommen — die zweite bekommt einen Hinweis.
/// </summary>
public sealed class MandantenImportLauf
{
    readonly Dictionary<string, MandantEntity> _nachName;

    // Ordnernamen kommen aus dem Windows-Dateisystem und vergleichen sich dort
    // ohne Rücksicht auf Groß-/Kleinschreibung. Ordinal verglichen bekämen
    // „Vunfallursache Mark" und „VUnfallursache Mark" zwei Mandanten.
    readonly Dictionary<string, MandantEntity> _besitzer =
        new(StringComparer.OrdinalIgnoreCase);

    // Was vor diesem Lauf schon als „ohne Mandantenbezug" vermerkt war. Ohne
    // dieses Wissen meldete ein zweiter Lauf derselben Datei dieselben Ordner
    // noch einmal als Neuigkeit — geschrieben wird zwar nichts Zusätzliches,
    // aber die Zahl im Bericht behauptete eine Wirkung, die es nicht gibt.
    readonly HashSet<string> _vermerkt;

    // Die Namen, die dieser Lauf selbst angelegt hat. Ein Widerspruch gegen
    // einen davon kommt aus einer früheren Zeile derselben Datei und nicht aus
    // dem Register — der Hinweis muss sagen, welches von beidem.
    readonly HashSet<string> _ausDerDatei = new(StringComparer.Ordinal);

    readonly List<ImportEintragBefund> _eintraege = [];
    readonly List<MandantEntity> _neue = [];
    readonly List<string> _zugeordneteOrdner = [];
    readonly List<string> _markierte = [];
    int _naechsteId;

    public MandantenImportLauf(
        IReadOnlyList<MandantEntity> register,
        IEnumerable<string>? vermerkteOrdner = null)
    {
        _vermerkt = new HashSet<string>(
            vermerkteOrdner ?? [], StringComparer.OrdinalIgnoreCase);
        _nachName = new Dictionary<string, MandantEntity>(StringComparer.Ordinal);
        foreach (var mandant in register)
        {
            _nachName[MandantName.Normalisiere(mandant.Vorname, mandant.Nachname)] = mandant;
            foreach (var ordner in MandantListen.Lies(mandant.AktenOrdnernamenJson))
            {
                _besitzer[ordner] = mandant;
            }
        }

        _naechsteId = register.Count == 0 ? 1 : register.Max(m => m.Id) + 1;
    }

    /// <summary>Neu anzulegende Mandanten — im Prüflauf bleiben sie liegen.</summary>
    public IReadOnlyList<MandantEntity> NeueMandanten => _neue;

    /// <summary>
    /// Ordner, die durch diesen Lauf an einen Mandanten gehen. Ein Vermerk
    /// „ohne Mandantenbezug" auf einem davon wird beim Schreiben zurückgenommen:
    /// ein zugeordneter Ordner kann nicht gleichzeitig keinem gehören.
    /// </summary>
    public IReadOnlyList<string> ZugeordneteOrdner => _zugeordneteOrdner;

    /// <summary>Ordner, die als „ohne Mandantenbezug" vermerkt werden.</summary>
    public IReadOnlyList<string> Markierte => _markierte;

    public void Verarbeite(int zeile, ImportMandant quelle)
    {
        var hinweise = new List<string>();
        var anzeige = MandantName.Anzeige(quelle.Vorname, quelle.Nachname);
        var norm = MandantName.Normalisiere(quelle.Vorname, quelle.Nachname);

        if (norm.Length == 0)
        {
            hinweise.Add("Ohne Vor- oder Nachnamen lässt sich kein Mandant anlegen.");
            _eintraege.Add(Befund(zeile, anzeige, [], ImportArten.Abgelehnt, null, quelle, hinweise));
            return;
        }

        var istNeu = !_nachName.TryGetValue(norm, out var ziel);
        ziel ??= Anlegen(quelle, norm);

        var woher = _ausDerDatei.Contains(norm) ? "frühere Zeile" : "Register";
        var geaendert = istNeu || MandantImportAbgleich.Uebernimm(ziel, quelle, hinweise, woher);
        var zugewiesen = WeiseOrdnerZu(quelle.AktenOrdnernamen, ziel, hinweise);

        var art = istNeu
            ? ImportArten.Neu
            : geaendert || zugewiesen.Count > 0
                ? ImportArten.Ergaenzt
                : ImportArten.Unveraendert;

        _eintraege.Add(Befund(zeile, anzeige, zugewiesen, art, ziel.Id, quelle, hinweise));
    }

    /// <summary>
    /// Übernimmt die Ordner, die der Erzeuger als „gehört keinem Mandanten"
    /// gemeldet hat. Übergangen wird, was diesem Lauf gerade zugeordnet wurde
    /// oder schon einem Mandanten gehört — die Zuordnung ist die stärkere
    /// Aussage —, und was den Vermerk bereits trägt: das wäre keine Änderung.
    /// </summary>
    public void MarkiereOhneBezug(IEnumerable<string> ordnernamen)
    {
        var zugeordnet = new HashSet<string>(_zugeordneteOrdner, StringComparer.OrdinalIgnoreCase);
        foreach (var name in Bereinige(ordnernamen))
        {
            if (zugeordnet.Contains(name) || _besitzer.ContainsKey(name)) continue;
            if (_vermerkt.Contains(name)) continue;
            _markierte.Add(name);
        }
    }

    /// <summary>
    /// Der Bericht. Die IDs neuer Mandanten stehen nur darin, wenn wirklich
    /// geschrieben wurde: im Prüflauf sind es Vorgriffe auf Schlüssel, die die
    /// Datenbank noch nicht vergeben hat, und ein Vertrag, der erfundene IDs
    /// führt, lädt dazu ein, mit ihnen weiterzuarbeiten.
    /// </summary>
    public MandantenImportBefund Ergebnis(bool angewendet) => new(
        angewendet ? _eintraege : [.. _eintraege.Select(e => e with { MandantId = null })],
        Neu: _eintraege.Count(e => e.Art == ImportArten.Neu),
        Ergaenzt: _eintraege.Count(e => e.Art == ImportArten.Ergaenzt),
        Unveraendert: _eintraege.Count(e => e.Art == ImportArten.Unveraendert),
        Abgelehnt: _eintraege.Count(e => e.Art == ImportArten.Abgelehnt),
        OrdnerZugeordnet: _zugeordneteOrdner.Count,
        OhneMandantenbezug: _markierte.Count,
        Angewendet: angewendet);

    MandantEntity Anlegen(ImportMandant quelle, string norm)
    {
        var neu = new MandantEntity
        {
            Id = _naechsteId++,
            Anrede = quelle.Anrede.Trim(),
            Vorname = quelle.Vorname.Trim(),
            Nachname = quelle.Nachname.Trim(),
            StrasseHausnummer = quelle.StrasseHausnummer.Trim(),
            Postleitzahl = quelle.Postleitzahl.Trim(),
            Ort = quelle.Ort.Trim(),
            EmailAdresse = quelle.EmailAdresse.Trim(),
            Telefonnummer = quelle.Telefonnummer.Trim(),
            Notiz = quelle.Notiz.Trim(),
            ErstelltAm = DateTime.Now,
            KennzeichenJson = MandantListen.Schreib(Bereinige(quelle.Kennzeichen)),
        };

        _nachName[norm] = neu;
        _ausDerDatei.Add(norm);
        _neue.Add(neu);
        return neu;
    }

    List<string> WeiseOrdnerZu(IEnumerable<string> ordnernamen, MandantEntity ziel, List<string> hinweise)
    {
        var zugewiesen = new List<string>();
        foreach (var name in Bereinige(ordnernamen))
        {
            if (_besitzer.TryGetValue(name, out var inhaber))
            {
                if (ReferenceEquals(inhaber, ziel)) continue;
                hinweise.Add(
                    $"Ordner „{name}“ gehört bereits " +
                    $"{MandantName.Anzeige(inhaber.Vorname, inhaber.Nachname)} — nicht übernommen.");
                continue;
            }

            _besitzer[name] = ziel;
            zugewiesen.Add(name);
            _zugeordneteOrdner.Add(name);
        }

        if (zugewiesen.Count > 0)
        {
            var bestand = MandantListen.Lies(ziel.AktenOrdnernamenJson);
            ziel.AktenOrdnernamenJson = MandantListen.Schreib(bestand.Concat(zugewiesen));
        }

        return zugewiesen;
    }

    static ImportEintragBefund Befund(
        int zeile,
        string anzeige,
        IReadOnlyList<string> ordner,
        string art,
        int? mandantId,
        ImportMandant quelle,
        IReadOnlyList<string> hinweise) =>
        new(zeile, anzeige, ordner, art, mandantId, quelle.Sicherheit.Trim(), quelle.Quelle.Trim(), hinweise);

    static List<string> Bereinige(IEnumerable<string> werte) => werte
        .Select(wert => wert.Trim())
        .Where(wert => wert.Length > 0)
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .ToList();
}
