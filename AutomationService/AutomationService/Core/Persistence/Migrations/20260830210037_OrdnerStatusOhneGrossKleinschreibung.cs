using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class OrdnerStatusOhneGrossKleinschreibung : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Ordnername",
                table: "OrdnerStatus",
                type: "TEXT",
                nullable: false,
                collation: "NOCASE",
                oldClrType: typeof(string),
                oldType: "TEXT");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Ordnername",
                table: "OrdnerStatus",
                type: "TEXT",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "TEXT",
                oldCollation: "NOCASE");
        }
    }
}
