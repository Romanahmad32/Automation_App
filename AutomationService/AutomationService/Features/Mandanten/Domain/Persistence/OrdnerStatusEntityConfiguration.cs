using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Schema-Mapping der Ordner-Vermerke. Der Ordnername ist der fachliche
/// Schlüssel — Unique-Index, damit ein Ordner nicht zweimal entschieden wird.
/// </summary>
public class OrdnerStatusEntityConfiguration : IEntityTypeConfiguration<OrdnerStatusEntity>
{
    public void Configure(EntityTypeBuilder<OrdnerStatusEntity> builder)
    {
        builder.Property(o => o.Ordnername).IsRequired();
        builder.Property(o => o.Status).IsRequired();
        builder.HasIndex(o => o.Ordnername).IsUnique();
    }
}
