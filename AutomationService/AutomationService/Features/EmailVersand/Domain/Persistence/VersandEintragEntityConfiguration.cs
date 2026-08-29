using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AutomationService.Features.EmailVersand.Domain.Persistence;

/// <summary>
/// Schema-Mapping des Versandprotokolls. Gelesen wird immer „alle Versände zu
/// diesem Vorgang" — dafür der Index auf der Referenz. <b>Kein</b>
/// Unique-Index: Zu einem Vorgang gehen mehrere Mails hinaus (Mandant
/// nachträglich, Korrekturschreiben, siehe §4.8).
/// </summary>
public class VersandEintragEntityConfiguration : IEntityTypeConfiguration<VersandEintragEntity>
{
    public void Configure(EntityTypeBuilder<VersandEintragEntity> builder)
    {
        builder.Property(e => e.VorgangReferenz).IsRequired();
        builder.HasIndex(e => e.VorgangReferenz);
    }
}
