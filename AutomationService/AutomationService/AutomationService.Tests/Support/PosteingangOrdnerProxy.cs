using System.Reflection;
using MailKit;
using MimeKit;

namespace AutomationService.Tests.Support;

/// <summary>
/// Erlaubt nur, was der Posteingang holen darf. Ein Vollabruf, ein SEARCH oder
/// ein ungefragt geladener Anhang schlägt im Test sofort fehl.
///
/// Was geholt werden <em>darf</em>, steht in <see cref="Textteile"/> und
/// <see cref="Anhangsteile"/>: Jeder Test schaltet genau die Teile frei, die er
/// erwartet — alles andere fliegt. So bleibt die Zusage „die Liste lädt keinen
/// Inhalt, das Öffnen keinen Anhang" prüfbar und nicht bloß behauptet.
/// </summary>
public class PosteingangOrdnerProxy : DispatchProxy
{
    public int Anzahl { get; set; } = 1_000_000;
    public Func<int, uint> UidAmIndex { get; set; } = index => (uint)(index + 1);
    public List<(int Start, int Ende, MessageSummaryItems Felder)> Abrufe { get; } = [];

    /// <summary>Die Felder, die der Abruf einer einzelnen UID angefordert hat.</summary>
    public List<MessageSummaryItems> EinzelAbrufe { get; } = [];

    public BodyPart? InhaltStruktur { get; set; }

    /// <summary>Umschlag der einzeln abgerufenen Nachricht; null, wo der Test ihn nicht braucht.</summary>
    public Envelope? Umschlag { get; set; }

    /// <summary>Größe der einzeln abgerufenen Nachricht — entscheidet über die 50-MB-Grenze der .eml.</summary>
    public uint EinzelGroesse { get; set; } = 4096;

    public DateTimeOffset? Eingangszeit { get; set; }

    /// <summary>Teilbezeichner, die als Text geliefert werden — Bezeichner auf Inhalt.</summary>
    public Dictionary<string, string> Textteile { get; } = new(StringComparer.Ordinal)
    {
        ["1"] = "Der Mailtext",
    };

    /// <summary>Welche davon als <c>text/html</c> gelten.</summary>
    public HashSet<string> HtmlTeile { get; } = new(StringComparer.Ordinal);

    /// <summary>Teilbezeichner, die als Anhang geliefert werden — Bezeichner auf Bytes.</summary>
    public Dictionary<string, byte[]> Anhangsteile { get; } = new(StringComparer.Ordinal);

    /// <summary>Die ganze Nachricht für <c>GetMessageAsync</c>; ohne sie ist der Abruf ein Fehler.</summary>
    public MimeMessage? Nachricht { get; set; }

    /// <summary>Die Nachricht ist inzwischen verschoben oder gelöscht — der Abruf liefert nichts.</summary>
    public bool NachrichtFehlt { get; set; }

    public int TextAbrufe { get; private set; }
    public int AnhangAbrufe { get; private set; }
    public int NachrichtAbrufe { get; private set; }

    public static (IMailFolder Folder, PosteingangOrdnerProxy Proxy) Erzeuge()
    {
        var folder = Create<IMailFolder, PosteingangOrdnerProxy>();
        return (folder, (PosteingangOrdnerProxy)folder);
    }

    protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
    {
        switch (targetMethod?.Name)
        {
            case "get_Count": return Anzahl;
            case "get_UidValidity": return 17u;
            case "FetchAsync" when args is [IList<UniqueId> uids, IFetchRequest einzeln, ..]:
                EinzelAbrufe.Add(einzeln.Items);
                if (NachrichtFehlt)
                {
                    return Task.FromResult<IList<IMessageSummary>>([]);
                }
                IList<IMessageSummary> inhalt = [new MessageSummary(0)
                {
                    UniqueId = uids[0],
                    Body = InhaltStruktur,
                    Envelope = Umschlag,
                    Size = EinzelGroesse,
                    InternalDate = Eingangszeit,
                }];
                return Task.FromResult(inhalt);
            // Die Ueberladung mit BodyPart, nicht die mit dem string-Specifier:
            // genau die ruft PosteingangText.LadeAsync mit summary.TextBody.
            case "GetBodyPartAsync" when args is [UniqueId, BodyPart teil, ..]:
                return Task.FromResult(Teil(teil.PartSpecifier ?? string.Empty));
            case "GetMessageAsync" when args is [UniqueId, ..]:
                NachrichtAbrufe++;
                return Task.FromResult(Nachricht
                    ?? throw new InvalidOperationException("Die ganze Nachricht wurde ungefragt geladen."));
            case "FetchAsync" when args is [int start, int ende, IFetchRequest request, ..]:
                Abrufe.Add((start, ende, request.Items));
                IList<IMessageSummary> summaries = Enumerable.Range(start, ende - start + 1)
                    .Select(index => (IMessageSummary)new MessageSummary(index)
                    {
                        UniqueId = new UniqueId(UidAmIndex(index)),
                        Envelope = Umschlag ?? new Envelope { Subject = $"Kanzleimail {UidAmIndex(index)}" },
                        Body = InhaltStruktur,
                        Size = 20_000_000,
                    }).ToList();
                return Task.FromResult(summaries);
            default: throw new InvalidOperationException($"Unerwarteter IMAP-Aufruf: {targetMethod?.Name}");
        }
    }

    private MimeEntity Teil(string kennung)
    {
        if (Textteile.TryGetValue(kennung, out var text))
        {
            TextAbrufe++;
            return new TextPart(HtmlTeile.Contains(kennung) ? "html" : "plain") { Text = text };
        }

        if (Anhangsteile.TryGetValue(kennung, out var bytes))
        {
            AnhangAbrufe++;
            return new MimePart("application", "pdf")
            {
                Content = new MimeContent(new MemoryStream(bytes)),
            };
        }

        throw new InvalidOperationException($"Ein ungefragter Nachrichtenteil wurde geladen: {kennung}");
    }
}
