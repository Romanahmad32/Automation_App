using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddVorgangFeldWerte : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "FeldWerteJson",
                table: "Vorgaenge",
                type: "TEXT",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SchadensaufstellungJson",
                table: "Vorgaenge",
                type: "TEXT",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FeldWerteJson",
                table: "Vorgaenge");

            migrationBuilder.DropColumn(
                name: "SchadensaufstellungJson",
                table: "Vorgaenge");
        }
    }
}
