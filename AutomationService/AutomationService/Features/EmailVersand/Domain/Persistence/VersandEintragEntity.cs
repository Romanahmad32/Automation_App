namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Ein Versand zu einem Vorgang, wie er in der Datenbank liegt (§4.7).
///
/// Adressiert über die <b>Referenz</b> des Vorgangs, nicht über einen
/// Fremdschlüssel: Die Versand-Slice darf die Vorgangs-Slice nicht kennen
/// (<c>SliceIsolationTests</c>), und eine Referenz wie <c>84/26 C03_HG-E 1427</c>
/// genügt zum Wiederfinden vollauf.
///
/// Listen liegen als JSON in einer Spalte — dasselbe Muster wie
/// <c>VorgangEntity.AntwortJson</c>. Eine eigene Tabelle für zwei Adressen und
/// drei Dateinamen zahlte sich nicht aus: Gelesen wird immer der ganze Eintrag.
/// </summary>
public class VersandEintragEntity
{
    public int Id { get; set; }

    /// <summary>Referenz des Vorgangs; leer wird nie geschrieben.</summary>
    public string VorgangReferenz { get; set; } = string.Empty;

    /// <summary>UTC — dieselbe Haltung wie bei den übrigen Zeitpunkten.</summary>
    public DateTime GesendetAm { get; set; }

    /// <summary>Direktversand, Outlook-Entwurf oder Entwurfsdatei.</summary>
    public string Weg { get; set; } = string.Empty;

    public string Absender { get; set; } = string.Empty;

    public string EmpfaengerJson { get; set; } = "[]";

    public string KopieJson { get; set; } = "[]";

    public string Betreff { get; set; } = string.Empty;

    /// <summary>
    /// Die Namen, unter denen die Anhänge <b>hinausgingen</b> — nicht die auf
    /// Platte. Umbenannt wird je Mail; wer später nachsieht, sucht den Namen,
    /// den der Empfänger vor sich hatte.
    /// </summary>
    public string AnhaengeJson { get; set; } = "[]";

    /// <summary>Ob die Kopie im Ordner "Gesendet" des Postfachs landete.</summary>
    public bool ImGesendetOrdner { get; set; }

    /// <summary>
    /// Die Message-ID der versendeten Nachricht. Sie ist der eigentliche
    /// Nachweis: Mit ihr lässt sich gegenüber der Gegenseite belegen, dass
    /// genau diese Mail eingeliefert wurde. Null beim Entwurfsweg — dort
    /// vergibt sie das Mailprogramm.
    /// </summary>
    public string? MessageId { get; set; }
}
