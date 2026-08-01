using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.Versicherer.Domain.Persistence;

/// <summary>
/// Schema-Mapping des Versicherer-Registers. Der normalisierte Name ist der
/// fachliche Schlüssel — Unique-Index, damit jede Gesellschaft genau einmal
/// gelernt wird.
/// </summary>
public class VersichererEntityConfiguration : IEntityTypeConfiguration<VersichererEntity>
{
    public void Configure(EntityTypeBuilder<VersichererEntity> builder)
    {
        builder.Property(v => v.Name).IsRequired();
        builder.Property(v => v.NameNormalisiert).IsRequired();
        builder.HasIndex(v => v.NameNormalisiert).IsUnique();
    }
}
