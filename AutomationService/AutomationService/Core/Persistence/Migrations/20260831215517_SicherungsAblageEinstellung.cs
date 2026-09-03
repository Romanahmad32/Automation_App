using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SicherungsAblageEinstellung : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "SicherungsAblageOrdner",
                table: "KanzleiSettings",
                type: "TEXT",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SicherungsAblageOrdner",
                table: "KanzleiSettings");
        }
    }
}
