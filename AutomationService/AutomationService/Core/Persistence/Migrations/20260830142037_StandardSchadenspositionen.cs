using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class StandardSchadenspositionen : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "StandardSchadenspositionen",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Reihenfolge = table.Column<int>(type: "INTEGER", nullable: false),
                    Bezeichnung = table.Column<string>(type: "TEXT", nullable: false),
                    Betrag = table.Column<decimal>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StandardSchadenspositionen", x => x.Id);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StandardSchadenspositionen");
        }
    }
}
