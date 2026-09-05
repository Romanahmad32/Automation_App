namespace AutomationService.Features.Settings.Domain.Persistence;

/// <summary>
/// Persistenz-Abbild der Kanzlei-/App-Einstellungen. Bewusst eine Single-Row-
/// Tabelle mit festem <see cref="SingletonId"/> = 1: es gibt genau einen
/// Einstellungssatz. Enthält u. a. die laufende Auftragsnummer (§7.1), die
/// nach Abschluss eines Vorgangs hochgezählt wird.
/// </summary>
public class KanzleiSettingsEntity
{
    public const int SingletonId = 1;

    public int Id { get; set; } = SingletonId;

    public string Personentyp { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string StrasseHausnummer { get; set; } = string.Empty;
    public string Postleitzahl { get; set; } = string.Empty;
    public string Ort { get; set; } = string.Empty;
    public string EmailAdresse { get; set; } = string.Empty;
    public string Telefonnummer { get; set; } = string.Empty;

    public int LaufendeAuftragsnummer { get; set; }
    public string Abteilung { get; set; } = string.Empty;
    public string TabellenkopfFarbeHex { get; set; } = string.Empty;

    /// <summary>
    /// Der eine Ordner, unter dem die App alles ablegt, was sie ablegt (#103).
    /// Darunter entstehen beim ersten Schreiben die Unterordner Vorlagen,
    /// Register und Sicherungen (<c>AppDatenOrdnerVorgabe</c>); die drei
    /// Einzelfelder daneben bleiben als Ausweg fuer den, dessen Vorlagen
    /// anderswo liegen. Leer heisst: nicht gesetzt, dann gilt je Feld der
    /// bisherige Rueckfall.
    ///
    /// Zur Speicherform gilt fuer alle fuenf Ordnerfelder dasselbe: absolut
    /// (<c>C:\Daten\Akten</c>) oder relativ mit Anker
    /// (<c>%OneDriveCommercial%\Kanzlei App Daten</c>). Gerechnet wird
    /// ausschliesslich im Backend (<c>AppOrdnerPfad</c>) — das Frontend zeigt
    /// nur den aufgeloesten Pfad an.
    /// </summary>
    public string AppDatenOrdner { get; set; } = string.Empty;

    /// <summary>
    /// Stammordner der gewachsenen Aktenablage der Kanzlei (§6.1). Bleibt
    /// bewusst eine eigene Wahl neben dem <see cref="AppDatenOrdner"/>: Die
    /// rund 4000 vorhandenen Ordner (#19) gehoeren nicht unter einen neu
    /// angelegten App-Ordner.
    /// </summary>
    public string AktenStammordner { get; set; } = string.Empty;

    /// <summary>
    /// Signaturblock unter dem Mailtext beim Direktversand (§4.7). Kommt aus
    /// der bereits eingerichteten Signatur des Mailprogramms ("Aus Outlook
    /// übernehmen"), nicht aus Abtippen. Beim Entwurf im Mailprogramm bleibt
    /// er ungenutzt — dort setzt Outlook seine eigene ein.
    /// </summary>
    public string MailSignatur { get; set; } = string.Empty;

    /// <summary>
    /// Die formatierte Fassung derselben Signatur als HTML-Rumpf (§4.7):
    /// Schrift, Farben, Logo. Uebernommen aus Outlook (<c>SignaturUebernahme</c>),
    /// nicht von Hand gepflegt — die Bilder liegen daneben im Dateisystem
    /// (<c>SignaturAblage</c>) und werden hier ueber ihren Dateinamen
    /// angesprochen. Leer heisst: Die Mail geht als reiner Text hinaus.
    /// </summary>
    public string MailSignaturHtml { get; set; } = string.Empty;

    /// <summary>
    /// Abweichender Zielordner des Register-Spiegels (§6.2, #40). Gedacht ist
    /// ein Ordner im synchronisierten Bereich (OneDrive), damit das Register
    /// unterwegs lesbar ist — die App kennt aber keine Cloud, sie legt eine
    /// Datei ab und der Client synchronisiert.
    ///
    /// Leer heisst seit #103 nicht mehr „kein Spiegel", sondern
    /// <c>&lt;AppDatenOrdner&gt;\Register</c>, und erst ohne den: kein Spiegel,
    /// der Export laeuft nur auf Knopfdruck (<c>RegisterAblageVorgabe</c>).
    /// </summary>
    public string RegisterAblageOrdner { get; set; } = string.Empty;

    /// <summary>
    /// Abweichender Ordner, in dem die Word-Vorlagen des Anwalts liegen (#33).
    /// Leer heisst seit #103: <c>&lt;AppDatenOrdner&gt;\Vorlagen</c> — und ohne
    /// den der App-Ordner unter %APPDATA%
    /// (<c>AppDataPaths.EnsureVorlagenDirectory</c>), der Stand vor dieser
    /// Einstellung.
    ///
    /// Ob der Wert beim Einspielen einer Sicherung uebernommen wird, haengt an
    /// seiner Form, nicht mehr am Feld: relativ gespeichert ist er
    /// maschinenunabhaengig und kommt mit, absolut zeigt er auf dem anderen
    /// Rechner ins Leere und bleibt ausgenommen (#39, #103).
    /// </summary>
    public string VorlagenOrdner { get; set; } = string.Empty;

    /// <summary>
    /// Abweichender Ordner, in den die App beim Beenden selbsttaetig eine
    /// Sicherung legt (§7.2, #39). Gedacht ist ein Ordner im synchronisierten
    /// Bereich: von dort bietet der zweite Arbeitsplatz den Stand beim Oeffnen
    /// zur Uebernahme an. Leer heisst seit #103:
    /// <c>&lt;AppDatenOrdner&gt;\Sicherungen</c> — und erst ohne den keine
    /// automatische Sicherung (<c>SicherungsAblageVorgabe</c>).
    ///
    /// Ein <em>absoluter</em> Pfad zu demselben OneDrive-Ordner lautet auf
    /// jedem Rechner anders. Wuerde er beim Einspielen mituebernommen, legte
    /// dieser Rechner seine Sicherungen woanders ab, als er sein Angebot liest;
    /// deshalb bleibt er ausgenommen. Die relative Form traegt den Anker mit
    /// und meint auf beiden Rechnern denselben Ordner — sie kommt mit (#103).
    /// </summary>
    public string SicherungsAblageOrdner { get; set; } = string.Empty;

    /// <summary>
    /// Basisname der Spiegeldateien ohne Endung; daraus entstehen
    /// "&lt;Name&gt;.docx" und "&lt;Name&gt;.pdf". Bewusst einstellbar und
    /// bewusst nicht der Name des gewachsenen Kanzleidokuments: Das bleibt
    /// unangetastet liegen, bis der Altbestand-Import nachweislich sauber
    /// durchgelaufen ist.
    /// </summary>
    public string RegisterDateiname { get; set; } = string.Empty;

    /// <summary>
    /// Ob der Spiegel nach jedem Vorgangsabschluss neu geschrieben wird. Der
    /// Schreibvorgang liegt hinter dem Commit des Abschlusses und kann ihn
    /// nicht umwerfen (siehe VorgangAbschlussService).
    /// </summary>
    public bool RegisterNachAbschlussSchreiben { get; set; }

    /// <summary>
    /// Welche Vorgaenge in die Datei kommen: <c>alle</c> oder nur
    /// <c>abgeschlossen</c>. Bewusst eine Einstellung und nicht der Filter der
    /// Ansicht — sonst haenge der Inhalt der Datei davon ab, was gerade am
    /// Bildschirm eingestellt war, und zwei Schreibvorgaenge ergaeben zwei
    /// verschiedene Register unter demselben Namen.
    /// </summary>
    public string RegisterExportFilter { get; set; } = string.Empty;
}
