using System.Reflection;
using MailKit;
using MimeKit;

namespace AutomationService.Tests.Support;

/// <summary>Erlaubt nur Kopfzeilenabrufe. Ein Vollabruf oder SEARCH schlägt im Test sofort fehl.</summary>
public class PosteingangOrdnerProxy : DispatchProxy
{
    public int Anzahl { get; set; } = 1_000_000;
    public Func<int, uint> UidAmIndex { get; set; } = index => (uint)(index + 1);
    public List<(int Start, int Ende, MessageSummaryItems Felder)> Abrufe { get; } = [];
    public BodyPart? InhaltStruktur { get; set; }
    public int TextAbrufe { get; private set; }

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
            case "FetchAsync" when args is [IList<UniqueId> uids, IFetchRequest, ..]:
                IList<IMessageSummary> inhalt = [new MessageSummary(0) { UniqueId = uids[0], Body = InhaltStruktur }];
                return Task.FromResult(inhalt);
            case "GetBodyPartAsync" when args is [UniqueId, string part, ..]:
                if (part != "1")
                {
                    throw new InvalidOperationException("Ein Anhang wurde ungefragt geladen.");
                }
                TextAbrufe++;
                return Task.FromResult<MimeEntity>(new TextPart("plain") { Text = "Der Mailtext" });
            case "FetchAsync" when args is [int start, int ende, IFetchRequest request, ..]:
                Abrufe.Add((start, ende, request.Items));
                IList<IMessageSummary> summaries = Enumerable.Range(start, ende - start + 1)
                    .Select(index => (IMessageSummary)new MessageSummary(index)
                    {
                        UniqueId = new UniqueId(UidAmIndex(index)),
                        Envelope = new Envelope { Subject = $"Kanzleimail {UidAmIndex(index)}" },
                        Size = 20_000_000,
                    }).ToList();
                return Task.FromResult(summaries);
            default: throw new InvalidOperationException($"Unerwarteter IMAP-Aufruf: {targetMethod?.Name}");
        }
    }
}
