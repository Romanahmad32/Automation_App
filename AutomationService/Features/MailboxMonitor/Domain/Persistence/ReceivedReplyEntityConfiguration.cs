using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.MailboxMonitor.Domain.Persistence;

/// <summary>Schema-Mapping der empfangenen Antwort (Index auf die Referenz für die Zuordnung).</summary>
public class ReceivedReplyEntityConfiguration : IEntityTypeConfiguration<ReceivedReplyEntity>
{
    public void Configure(EntityTypeBuilder<ReceivedReplyEntity> builder)
    {
        // Eindeutig: derselbe Mail-Schlüssel darf nur einmal erfasst werden — der
        // Backstop der Dublettenprüfung, auch über Neustarts hinweg.
        builder.HasIndex(r => r.DedupeKey).IsUnique();
        builder.HasIndex(r => r.Referenz);
    }
}
