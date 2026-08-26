using AutomationService.Features.MailboxMonitor.Domain.Services;
using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.MailboxMonitor.Presentation.Dtos;

/// <summary>Ein vom Monitor erfasster Antwort-Treffer, wie ihn die Oberfläche abruft.</summary>
public sealed record ReceivedReplyDto(
    string Id,
    DateTimeOffset ReceivedAt,
    string? Subject,
    string? From,
    bool Acknowledged,
    ZentralrufReplyData Data,
    IReadOnlyList<string> Warnings,
    IReadOnlyList<string> AnhangPfade,
    string? RawText,
    bool ZuordnungVermutet)
{
    public static ReceivedReplyDto Create(ReceivedReply reply) => new(
        reply.Id,
        reply.ReceivedAt,
        reply.Subject,
        reply.From,
        reply.Acknowledged,
        reply.Data,
        reply.Warnings,
        reply.AnhangPfade,
        reply.RawText,
        reply.ZuordnungVermutet);
}
