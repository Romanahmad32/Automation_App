using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddReceivedReplyFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Absender",
                table: "ReceivedReplies",
                type: "TEXT",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DedupeKey",
                table: "ReceivedReplies",
                type: "TEXT",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "Quittiert",
                table: "ReceivedReplies",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "Rohtext",
                table: "ReceivedReplies",
                type: "TEXT",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WarnungenJson",
                table: "ReceivedReplies",
                type: "TEXT",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ReceivedReplies_DedupeKey",
                table: "ReceivedReplies",
                column: "DedupeKey",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ReceivedReplies_DedupeKey",
                table: "ReceivedReplies");

            migrationBuilder.DropColumn(
                name: "Absender",
                table: "ReceivedReplies");

            migrationBuilder.DropColumn(
                name: "DedupeKey",
                table: "ReceivedReplies");

            migrationBuilder.DropColumn(
                name: "Quittiert",
                table: "ReceivedReplies");

            migrationBuilder.DropColumn(
                name: "Rohtext",
                table: "ReceivedReplies");

            migrationBuilder.DropColumn(
                name: "WarnungenJson",
                table: "ReceivedReplies");
        }
    }
}
