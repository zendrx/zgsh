const std = @import("std");
const ast = @import("ast.zig");
const Alloc = std.mem.Allocator;

const Child = struct { pid: std.process.Child.Id };

pub const ExecError = error{
    CommandNotFound,
    ForkFailed,
    PipeFailed,
    OutOfMemory,
};

pub fn exec(stmt: *const ast.Stmt, alloc: Alloc) ExecError!void {
    switch (stmt.*) {
        .simple => |*cmd| try execSimple(cmd, alloc),
        .pipeline => |*p| try execPipe(p, alloc),
    }
}

fn execSimple(cmd: *const ast.Command, alloc: Alloc) ExecError!void {
    const argvz = try argvToZ(alloc, cmd.argv.items);

    const pid = fork() catch return ExecError.ForkFailed;

    if (pid == 0) {
        execvp(argvz) catch {
            std.log.err("command not found: {s}\n", .{argvz[0]});
            std.process.exit(127);
        };
    }

    _ = std.os.linux.waitpid(pid, 0, 12);
}

fn execPipe(p: *ast.Pipeline, alloc: Alloc) ExecError!void {
    const cmd = p.commands.items;
    const n = cmd.len;

    const pipes = alloc.alloc([2]std.posix.fd_t, n - 1) catch return ExecError.OutOfMemory;
    for (pipes) |*pipe| {
        pipe.* = std.os.linux.pipe();
    }

    var pids = alloc.alloc(std.process.Child.Id, n) catch return ExecError.OutOfMemory;
    for (cmd, 0..) |*cmds, i| {
        const argvz = try argvToZ(alloc, cmds.argv.items);
        const pid = fork() catch return ExecError.ForkFailed;
        pids[i] = pid;
        if (pid == 0) {
            runChild(cmds.len, i, pipes, argvz);
            std.process.exit(127);
        }
    }

    for (pipes) |p| {
        std.os.linux.close(p[0]);
        std.os.linux.close(p[1]);
    }

    for (pids) |pid| {
        _ = std.os.linux.waitpid(pid, 0, 0);
    }
}

fn runChild(n: usize, i: usize, pipes: []const [2]std.posix.fd_t, argv: []const ?[*:0]const u8) noreturn {
    if (i > 0) {
        const read_end = pipes[i - 1][0];
        std.os.linux.dup2(read_end, std.posix.STDIN_FILENO) catch {
            std.log.err("dup failed\n", .{});
            std.process.exit(1);
        };
    }
    if (i < n - 1) {
        const write_end = pipes[i][1];
        std.os.linux.dup2(write_end, std.posix.STDOUT_FILENO) catch {
            std.log.err("dup failed\n", .{});
            std.process.exit(1);
        };
    }

    for (pipes) |p| {
        std.os.linux.close(p[0]);
        std.os.linux.close(p[1]);
    }

    execvp(argv) catch {
        std.log.err("command not found: {s}\n", .{argv[0]});
        std.process.exit(127);
    };

    unreachable;
}

fn fork() !std.process.Child.Id {
    return std.os.linux.fork();
}

fn execvp(argv: []const ?[*:0]const u8) !void {
    //try std.os.linux.execve()
}

fn argvToz(alloc: Alloc, args: []const ast.Arg) ![]const ?[*:0]const u8 {
    const argvz = try alloc.alloc(?[*:0]const u8, args.len + 1);
    for (args, 0..) |arg, i| {
        argvz[i] = (try alloc.dupe(u8, arg.text)).ptr;
    }

    argvz[args.len] = null;
    return argvz;
}
