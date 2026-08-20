const std = @import("std");
const root = @import("root.zig");
const testing = std.testing;
const parse = root.parse;
const BasicLitKind = root.BasicLitKind;
const BinOpKind = root.BinOpKind;
const UniOpKind = root.UniOpKind;
const Expr = root.Expr;

test "parse: single integer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "42");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.int, result.basic_lit.kind);
    try testing.expectEqualStrings("42", result.basic_lit.text);
}

test "parse: single float" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "3.14");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.float, result.basic_lit.kind);
    try testing.expectEqualStrings("3.14", result.basic_lit.text);
}

test "parse: addition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.op);
    try testing.expectEqualStrings("1", result.bin_op.lhs.basic_lit.text);
    try testing.expectEqualStrings("2", result.bin_op.rhs.basic_lit.text);
}

test "parse: subtraction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "5 - 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.minus, result.bin_op.op);
}

test "parse: multiplication" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "2 * 4");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op.op);
}

test "parse: mult binds tighter than plus" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2 * 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.op);
    try testing.expect(result.bin_op.rhs.* == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op.rhs.bin_op.op);
}

test "parse: plus is left-associative" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "1 + 2 + 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.op);
    try testing.expect(result.bin_op.lhs.* == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.lhs.bin_op.op);
}

test "parse: parenthesized expression" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "(42)");
    try testing.expect(result == .basic_lit);
    try testing.expectEqual(BasicLitKind.int, result.basic_lit.kind);
    try testing.expectEqualStrings("42", result.basic_lit.text);
}

test "parse: parens override precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    // (1 + 2) * 3 should parse as (* (+ 1 2) 3), not (+ 1 (* 2 3))
    const result = try parse(arena.allocator(), "(1 + 2) * 3");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.mult, result.bin_op.op);
    try testing.expect(result.bin_op.lhs.* == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.lhs.bin_op.op);
    try testing.expectEqualStrings("1", result.bin_op.lhs.bin_op.lhs.basic_lit.text);
    try testing.expectEqualStrings("2", result.bin_op.lhs.bin_op.rhs.basic_lit.text);
    try testing.expectEqualStrings("3", result.bin_op.rhs.basic_lit.text);
}

test "parse: simple if" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "if(1){2}3");
    try testing.expect(result == .seq);
    try testing.expect(result.seq.a.* == .if_expr);
    const if_expr = result.seq.a.if_expr;
    try testing.expectEqualStrings("1", if_expr.head.cond.basic_lit.text);
    try testing.expectEqualStrings("2", if_expr.head.body.basic_lit.text);
    try testing.expectEqual(@as(usize, 0), if_expr.elseifs.len);
    try testing.expectEqual(@as(?*Expr, null), if_expr.else_body);
    try testing.expectEqualStrings("3", result.seq.b.basic_lit.text);
}

test "parse: if elif else" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "if(1){2}elif(3){4}else{5}6");
    try testing.expect(result == .seq);
    const if_expr = result.seq.a.if_expr;
    try testing.expectEqualStrings("1", if_expr.head.cond.basic_lit.text);
    try testing.expectEqualStrings("2", if_expr.head.body.basic_lit.text);
    try testing.expectEqual(@as(usize, 1), if_expr.elseifs.len);
    try testing.expectEqualStrings("3", if_expr.elseifs[0].cond.basic_lit.text);
    try testing.expectEqualStrings("4", if_expr.elseifs[0].body.basic_lit.text);
    try testing.expect(if_expr.else_body != null);
    try testing.expectEqualStrings("5", if_expr.else_body.?.basic_lit.text);
    try testing.expectEqualStrings("6", result.seq.b.basic_lit.text);
}

test "parse struct: one field array type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: []int}1");
    try testing.expect(result == .seq);
    const se = result.seq.a.struct_expr;
    try testing.expectEqualStrings("Foo", se.name);
    try testing.expectEqual(@as(usize, 1), se.fields.len);
    try testing.expectEqualStrings("foo1", se.fields[0].name);
    try testing.expect(se.fields[0].type.* == .array_type);
    try testing.expectEqualStrings("int", se.fields[0].type.array_type.name);
}

test "parse struct: one field set type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: set[int]}1");
    try testing.expect(result == .seq);
    const se = result.seq.a.struct_expr;
    try testing.expectEqual(@as(usize, 1), se.fields.len);
    try testing.expectEqualStrings("foo1", se.fields[0].name);
    try testing.expect(se.fields[0].type.* == .set_type);
    try testing.expectEqualStrings("int", se.fields[0].type.set_type.name);
}

test "parse struct: set of array type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: set[[]op]}1");
    try testing.expect(result == .seq);
    const field = result.seq.a.struct_expr.fields[0];
    try testing.expectEqualStrings("foo1", field.name);
    try testing.expect(field.type.* == .set_type);
    try testing.expect(field.type.set_type.* == .array_type);
    try testing.expectEqualStrings("op", field.type.set_type.array_type.name);
}

test "parse struct: array of array type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {grid: [][]int}1");
    try testing.expect(result == .seq);
    const field = result.seq.a.struct_expr.fields[0];
    try testing.expect(field.type.* == .array_type);
    try testing.expect(field.type.array_type.* == .array_type);
    try testing.expectEqualStrings("int", field.type.array_type.array_type.name);
}

test "parse struct: set of set type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {nested: set[set[int]]}1");
    try testing.expect(result == .seq);
    const field = result.seq.a.struct_expr.fields[0];
    try testing.expect(field.type.* == .set_type);
    try testing.expect(field.type.set_type.* == .set_type);
    try testing.expectEqualStrings("int", field.type.set_type.set_type.name);
}

test "parse struct: two fields with trailing comma" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: set[[]op], foo2: string,}1");
    try testing.expect(result == .seq);
    const se = result.seq.a.struct_expr;
    try testing.expectEqualStrings("Foo", se.name);
    try testing.expectEqual(@as(usize, 2), se.fields.len);
    try testing.expectEqualStrings("foo1", se.fields[0].name);
    try testing.expect(se.fields[0].type.* == .set_type);
    try testing.expectEqualStrings("foo2", se.fields[1].name);
    try testing.expect(se.fields[1].type.* == .name);
    try testing.expectEqualStrings("string", se.fields[1].type.name);
}

test "parse struct: two fields without trailing comma" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "struct Foo {foo1: set[[]op], foo2: string}1");
    try testing.expect(result == .seq);
    const se = result.seq.a.struct_expr;
    try testing.expectEqual(@as(usize, 2), se.fields.len);
    try testing.expectEqualStrings("foo1", se.fields[0].name);
    try testing.expectEqualStrings("foo2", se.fields[1].name);
}

test "parse struct: empty struct" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try testing.expectError(error.ExtendEmpty, parse(arena.allocator(), "struct Empty {}1"));
}

test "parse proc: no args no return type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "proc foo() { 42 }1");
    try testing.expect(result == .seq);
    const p = result.seq.a.proc;
    try testing.expectEqualStrings("foo", p.name);
    try testing.expectEqual(@as(usize, 0), p.fields.len);
    try testing.expectEqual(@as(?*Expr, null), p.type);
    try testing.expect(p.content.* == .basic_lit);
    try testing.expectEqualStrings("42", p.content.basic_lit.text);
}

test "parse proc: two args" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "proc add(x int, y int) { x }1");
    try testing.expect(result == .seq);
    const p = result.seq.a.proc;
    try testing.expectEqualStrings("add", p.name);
    try testing.expectEqual(@as(usize, 2), p.fields.len);
    try testing.expectEqualStrings("x", p.fields[0].name);
    try testing.expectEqualStrings("int", p.fields[0].type.name);
    try testing.expectEqualStrings("y", p.fields[1].name);
    try testing.expectEqualStrings("int", p.fields[1].type.name);
}

test "parse proc: with return type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "proc foo() int { 42 }1");
    try testing.expect(result == .seq);
    const p = result.seq.a.proc;
    try testing.expectEqualStrings("foo", p.name);
    try testing.expectEqual(@as(usize, 0), p.fields.len);
    try testing.expect(p.type != null);
    try testing.expectEqualStrings("int", p.type.?.name);
    try testing.expectEqualStrings("42", p.content.basic_lit.text);
}

test "parse extend: empty body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "extend Foo {}1");
    try testing.expect(result == .seq);
    const e = result.seq.a.extend;
    try testing.expectEqualStrings("Foo", e.struct_name);
    try testing.expectEqual(@as(?[]const u8, null), e.interface_name);
    try testing.expectEqual(@as(usize, 0), e.methods.len);
}

test "parse extend: one method" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "extend Foo { proc bar() { 1 } }1");
    try testing.expect(result == .seq);
    const e = result.seq.a.extend;
    try testing.expectEqualStrings("Foo", e.struct_name);
    try testing.expectEqual(@as(usize, 1), e.methods.len);
    try testing.expectEqualStrings("bar", e.methods[0].proc.name);
}

test "parse extend: two methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), "extend Foo { proc bar() { 1 } proc baz() { 2 } }1");
    try testing.expect(result == .seq);
    const e = result.seq.a.extend;
    try testing.expectEqual(@as(usize, 2), e.methods.len);
    try testing.expectEqualStrings("bar", e.methods[0].proc.name);
    try testing.expectEqualStrings("baz", e.methods[1].proc.name);
}

test "parse: postfix ! binds tighter than +" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    // 2 + 3! should parse as 2 + (3!), not (2 + 3)!
    const result = try parse(arena.allocator(), "2 + 3!");
    try testing.expect(result == .bin_op);
    try testing.expectEqual(BinOpKind.plus, result.bin_op.op);
    try testing.expectEqualStrings("2", result.bin_op.lhs.basic_lit.text);
    try testing.expect(result.bin_op.rhs.* == .uni_op);
    try testing.expectEqual(UniOpKind.not, result.bin_op.rhs.uni_op.op);
    try testing.expectEqualStrings("3", result.bin_op.rhs.uni_op.operand.basic_lit.text);
}
