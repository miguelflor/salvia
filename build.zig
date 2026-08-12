const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const salvia_mod = b.addModule("salvia", .{
        .root_source_file = b.path("src/root.zig"),

        .target = target,
    });

    const lexer_mod = b.addModule("lexer", .{
        .root_source_file = b.path("src/lexer/root.zig"),
        .target = target,
    });

    const error_mod = b.addModule("errors", .{
        .root_source_file = b.path("src/errors.zig"),
        .target = target,
    });

    const parser_mod = b.addModule("parser", .{
        .root_source_file = b.path("src/parser/root.zig"),
        .target = target,
    });

    parser_mod.addImport("lexer", lexer_mod);
    parser_mod.addImport("errors", error_mod);
    salvia_mod.addImport("parser", parser_mod);

    const exe = b.addExecutable(.{
        .name = "salvia",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,

            .imports = &.{
                .{ .name = "salvia", .module = salvia_mod },
                .{ .name = "lexer", .module = lexer_mod },
                .{ .name = "parser", .module = parser_mod },
                .{ .name = "errors", .module = error_mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_filter = b.option([]const u8, "test-filter", "Filter tests by name");

    const lexer_tests = b.addTest(.{
        .root_module = lexer_mod,
        .filters = if (test_filter) |f| &.{f} else &.{},
    });

    const run_mod_tests = b.addRunArtifact(lexer_tests);

    const parser_tests = b.addTest(.{
        .root_module = parser_mod,
        .filters = if (test_filter) |f| &.{f} else &.{},
    });

    const run_parser_tests = b.addRunArtifact(parser_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_parser_tests.step);
    test_step.dependOn(&run_exe_tests.step);

}
