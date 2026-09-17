---
title: "Pattern Matching: `match` Expression"
document: D2688R6
date: today
audience: Evolution
author:
  - name: Michael Park
    email: <mcypark@gmail.com>
toc: true
toc-depth: 4
highlighting:
  keywords:
    cpp: ["match", "let", "inspect", "is", "as"]
---

# Revision History {-}

<details markdown="1">
<summary>Show revision history</summary>

## R5 → R6 {- .unlisted}
  - Prior to the Hagenberg meeting in January 2025, further implementation
    work was completed.
    - Runtime code generation was fully implemented by Bruno Cardoso Lopes.
    - `match` expressions were implemented in dependent contexts.
    - Parsing was added for `@*type-constraint*@: @*pattern*@`.
    - A `try_cast` protocol was added for the
      `@*type-id*@: @*pattern*@` alternative pattern.
  - At the Hagenberg meeting in February 2025, the following poll was taken in EWG:

    > Poll: [@P2688R5] - Pattern Matching: `match` Expression: forward to CWG
    > for inclusion in C++26.
    >
    >  SF    F   N   A   SA
    > ----  --- --- --- ----
    >  20   11   6   13  5
    >
    > Result: Not consensus

  - The proposal now targets C++29.
  - Updated the examples in [Comparison Tables] with [@P2392R3] syntax.
  - Match cases require `case`.
  - A multi-arm selection is now written with a prefix introducer,
    `match (subjects...) { ... }`. One subject is matched directly. Multiple
    subjects form an unnamed product whose elements preserve the value
    categories of the corresponding expressions. In expression-only contexts
    the selection is an expression. At the start of a statement it is a
    statement with an implicit `-> void`, each handler is an ordinary
    statement, and the selection does not require a trailing semicolon.
  - Declaration patterns replace `let` bindings. Their restricted declarator
    follows a *conversion-type-id*, with a separate structured-binding form.
    The identifier may be omitted, but the declaration is still initialized.
  - Add recursively composable or-patterns, written `P1 || P2`. Alternatives
    may introduce the same names with independently deduced types; the guard
    and handler form an implicit template region over the selected alternative.
  - Braces explicitly request choice projection: `{ P }`, `{ T: P }`,
    `{ C: P }`, `{ .name: P }`, `{ .name }`, and `{}`. A choice can also
    provide parameterized names, such as variant's `{ .index<I>: P }` and
    `{ .index<I> }`. Here `C` is a type-constraint applied to the declared
    alternative type.
  - A declaration or type pattern applied directly to a polymorphic class
    object can perform `dynamic_cast`-equivalent refinement. Pointer
    declarations remain static; a pointer is first dereferenced through its
    nullable `{ P }` projection before its object can be refined.
  - The R5 optional pattern is removed. Parenthesized patterns are retained and
    generalized to group every pattern form. The unbraced `T: P` selector is
    replaced by the explicit braced form `{ T: P }`.
  - A single-pattern test is written `match(subjects..., case P)`. The
    `case` keyword separates the subject list from the pattern, while the
    parentheses delimit both from the surrounding expression. No new
    operator-precedence level is needed.
  - An expression handler can be marked `not return`. Such a handler is
    evaluated as a discarded-value expression and does not participate in
    result-type deduction.
  - Pattern conditions use `case P = subject`; range-for additionally
    supports `case P : range` with filtering semantics.
  - The proposed `alternative_traits` protocol supports closed indexed
    choices, named views, non-projectable states, and open type-erased choices.
  - Non-exhaustiveness and redundant cases are language errors. Coverage
    distinguishes required states from residual states.
  - The Clang prototype now supports dependent case instantiation, runtime and
    constant evaluation, subject lifetime extension, projection reuse,
    structured-binding packs, CFG integration, and pattern-matrix analysis.

The most visible source changes are summarized below. These are representative
spellings rather than mechanical source transformations.

| Facility | R5 | R6 |
|---|---|---|
| Selection | `value match { P => E; }` | `match (value) { case P => E; }` |
| Single-pattern test | `value match P` | `match(value, case P)` |
| Binding | `let value` | `auto&& value` or another declaration |
| Nullable projection | `? P` | `{ P }` |
| Empty nullable state | `_` after a `? P` case | `{}` |
| Typed alternative | `T: P` | `{ T: P }` |
| Multiple subjects | an explicit tuple | `match (x, y)` with `[P, Q]` |

## R4 → R5 {- .unlisted}
  - Further progress on [Proposed Wording].
  - Update the description of [Alternative Pattern] from `std::cast` to ADL-`try_cast`.

## R3 → R4 {- .unlisted}
  - Submitted companion papers for LEWG
    - [@P3521R0]: Pattern Matching: Customization Point for Open Sum Types
    - [@P3527R0]: Pattern Matching: *variant-like* and `std::expected`
  - Further progress on [Proposed Wording].
  - At the Wrocław meeting in November 2024, the following poll was taken in EWG:

    > Poll: [@P2688R3] - Pattern Matching: `match` Expression, we encourage more work
    > on the language-only paper towards C++26 in the next meeting (note: voting
    > against this poll does not exclude getting pattern matching in C++29)
    >
    >  SF    F   N   A   SA
    > ----  --- --- --- ----
    >  17   16   6   1   9

## R2 → R3 {- .unlisted}
  - Required parentheses for the match guard syntax.
    - Example: `@*expr*@ match @*pattern*@ if @[(]{.add}@ @*condition*@ @[)]{.add}@`
    - Added support for *init-stmt* and condition variables in match guards.
    - See [Why Guards Require Parentheses] for the current design.
  - Removed support for matching multiple values.
    - This paper now relies on `std::tuple` facilities, with room for the feature
      to be added separately in the future.
    - See [@P2688R3] for details of that revision.
  - Added discussion now reflected in [The `=>` Separator].
  - Added discussion now reflected in [Subject and Lifetime].
  - At the EWG Telecon in October 2024,  the following poll was taken:

    > Poll: [@P2688R2] - Pattern Matching: EWG likes direction of the paper.
    >
    >  SF   F   N   A   SA
    > ---- --- --- --- ----
    >  13   3   1   0   1

## R1 → R2 {- .unlisted}
  - Gained further [Implementation Experience]
  - Started on [Proposed Wording]
  - Defined the operator precedence used by the R5 postfix syntax.
  - Decided against proposing reflection-based tuple-like and variant-like
    protocols in that revision.
  - At the Tokyo meeting in March 2024, the following poll was taken in EWG:

    > Poll: [@P2688R1] - Pattern Matching: EWG encourages more work on pattern matching, knowing our time is limited.
    >
    >  SF   F   N   A   SA
    > ---- --- --- --- ----
    >  34   9   0   0   0

## R0 → R1 {- .unlisted}
  - At the Kona meeting in November 2022, [@P2688R0] and [@P2392R2]
    were discussed together, and the following poll was taken in EWG:

    > Poll: "EWG prefers composition over chaining in pattern matching syntax."
    >
    >  SF    F   N   A   SA
    > ----  --- --- --- ----
    >  13    9   2   1   0

</details>

# Introduction

This paper proposes pattern matching for C++29. It is the next revision of
[@P2688R5], which was considered for C++26 at the February 2025 Hagenberg
meeting but did not reach consensus for forwarding to CWG.

The basic problem remains the same. C++ has value tests, structured bindings,
`visit`, nullable types, and runtime class refinement, but these facilities do
not compose. A program that needs two or three of them at once spreads one
logical operation across tests, projections, visitors, and declarations.

R6 uses ordinary C++ declarations to introduce names, ordinary expressions to
match values, and explicit braces to project choice types. It provides
selection statements and expressions, Boolean tests, pattern conditions,
exhaustiveness checking, and recursive composition over products and choices.

R6 differs substantially from R5. The revision history records the changes,
and [Design Decisions and Alternatives Considered] explains why they were
made. The examples below first present the proposal as it would be used, before
describing its language and library rules.

# The Proposal in Examples

This section is intentionally example-first. Later sections define the rules
and discuss the alternatives.

## User-Side Examples

Values are expressions, while new names are introduced by declarations:

```cpp
match (command) {
  case Command::quit => return;
  case Command::move => move_cursor();
  case _             => report_unknown(command);
}

auto magnitude = match (point) {
  case [0, 0]             => 0;
  case [int x, 0]         => std::abs(x);
  case [0, int y]         => std::abs(y);
  case [int x, int y]     => std::abs(x) + std::abs(y);
};
```

Patterns compose. `||` applies alternatives to the same subject, and
parentheses group patterns:

```cpp
match (direction) {
  case Direction::north || Direction::south => vertical();
  case Direction::east || Direction::west   => horizontal();
}

match (record) {
  case [0, [const std::string& name, int value]] => use(name, value);
  case _ => ignore(record);
}
```

Braces explicitly project a choice. `{}` selects an advertised state with no
projection:

```cpp
std::optional<int> optional;
std::variant<int, std::string> variant;

match (optional) {
  case { int value } => use(value);
  case {}            => use_default();
}

return match (variant) -> std::size_t {
  case { int value }                  => value;
  case { const std::string& string }  => string.size();
};
```

Named selectors describe choices whose states have domain names:

```cpp
match (result) {
  case { .value: auto&& value }       => consume(value);
  case { .error: const Error& error } => report(error);
}
```

A single-pattern test produces `bool`. A pattern condition additionally makes
its declarations available in the successful branch:

```cpp
bool at_origin = match(point, case [0, 0]);

if (case [int x, int y] = read_point() && x < y) {
  use(x, y);
}
```

Several subjects form an unnamed product and are matched with one
decomposition pattern:

```cpp
match (old_state, new_state) {
  case [connection_state::disconnected, connection_state::connected]
    => on_connected();
  case [connection_state::connected, connection_state::disconnected]
    => on_disconnected();
  case [_, _] => ;
}
```

A declaration can refine a polymorphic object. Pointer declarations remain
ordinary static matches; projecting a non-null pointer first gives the same
object-refinement rule:

```cpp
match (shape) {
  case Circle& circle       => draw(circle);
  case Rectangle& rectangle => draw(rectangle);
  case _                    => draw_unknown(shape);
}

match (shape_pointer) {
  case {}                 => no_shape();
  case { Circle& circle } => draw(circle);
  case { Shape& shape }   => draw_unknown(shape);
}
```

`match constexpr` discards unselected handlers in the same spirit as
`if constexpr`:

```cpp
template<Format format>
auto parse(std::string_view input) {
  return match constexpr (format) {
    case Format::text   => parse_text(input);
    case Format::binary => parse_binary(input);
    case _ => static_assert(false, "unsupported format");
  };
}
```

## Library-Author Examples

A closed choice advertises its states, discriminator, and projections through
`alternative_traits`:

```cpp
namespace std {

template<class T, class E>
struct alternative_traits<::result<T, E>> {
  static constexpr alternative_info alternatives[] = {^^T, ^^E};
  static constexpr bool has_residual_states = false;

  enum class state : bool { value, error };

  static constexpr state index(::result<T, E> const& value) noexcept {
    return value.has_value() ? state::value : state::error;
  }

  template<state State, class Self>
  static constexpr decltype(auto) get(Self&& self) {
    if constexpr (State == state::value)
      return *std::forward<Self>(self);
    else
      return std::forward<Self>(self).error();
  }
};

} // namespace std
```

The names of the discriminator become named selectors, so this model supports
`{ .value: P }` and `{ .error: P }`. A closed choice can instead advertise
constant states or provider-defined parameterized selectors such as
`variant`'s `.index<I>`.

An open choice omits the finite state list and supplies a type-indexed cast:

```cpp
namespace std {

template<>
struct alternative_traits<::any_value> {
  template<class T, class Self>
  static auto try_cast(Self&& self) noexcept;

  static bool has_value(::any_value const&) noexcept;
};

} // namespace std
```

This supports `{ T value }` for requested types, `{}` for the empty state, and
`{ _ }` for the unknown non-empty remainder.

# Motivation and Scope

C++ already has most of the individual operations that make up pattern
matching. We use `switch` for values, `if` for arbitrary predicates,
structured bindings for products, `std::visit` for closed choices, and
`dynamic_cast` for class hierarchies. The problem is composition. A simple
operation over a nested value often requires several of these facilities at
once, with the test in one place and the value access in another.

We want one construct that says what a value looks like, introduces the names
needed by the selected case, and lets the compiler check that the cases cover
the domain. We do not expect every `if`, `switch`, or one-line `visit` to become
a `match`. The examples below include cases where existing C++ is already just
as clear.

The goals of this revision are:

  1. Make pattern matching feel natural in C++ by using ordinary expressions and
     declarations instead of dedicated syntax such as `let` and `? @*pattern*@`.
  2. Focus on a small, composable set of patterns supported by evidence from
     real-world production C++.
  3. Improve safety by requiring diagnostics for non-exhaustive selections and
     redundant cases.

This paper also preserves the following decisions from earlier EWG
discussions:

  - Patterns compose recursively rather than forming a chain of separate
    matching operations. EWG expressed a preference for this direction at the
    Kona meeting in November 2022.
  - Pattern matching is available in selection statements, selection
    expressions, and ordinary control-flow conditions. At the July 7, 2021 EWG
    teleconference, EWG expressed support for matching outside a dedicated
    `inspect` construct.
  - Expressions retain their ordinary meaning. Earlier EWG feedback
    emphasized that declarations should visibly introduce names and that an
    identifier should not silently declare or shadow a variable merely because
    it appears in a pattern.

[@P2688R5] used `let` to make name introduction explicit. This paper retains that
distinction between declarations and expressions while using ordinary
declaration syntax to express type, ownership, references, and forwarding.
A bare identifier remains an expression that refers to an existing name.

This paper covers selection statements and expressions, single-pattern tests,
and pattern conditions. It covers products, several subjects, nullable types,
closed and open choices, and polymorphic types. User-defined choice types
participate through `std::alternative_traits`.

Extractors, range patterns, named-member decomposition, matching types
themselves as subjects, and pattern combinators such as `and` and `not` remain
future work.

# Comparison Tables

The following are 4-way comparison tables between C++23, [@P1371R3], [@P2392R3],
and this paper.

## Matching Integrals

::: cmptable

### C++23
```cpp
switch (x) {
  case 0: std::print("got zero"); break;
  case 1: std::print("got one"); break;
  default: std::print("don't care");
}
```

### P1371R3
```cpp
inspect (x) {
  0 => std::print("got zero");
  1 => std::print("got one");
  __ => std::print("don't care");
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (x) {
  is 0 => std::print("got zero");
  is 1 => std::print("got one");
  is _ => std::print("don't care");
};
```

### This Paper
```cpp
match (x) {
  case 0 => std::print("got zero");
  case 1 => std::print("got one");
  case _ => std::print("don't care");
}
```

:::

## Matching Strings

::: cmptable

### C++23
```cpp
if (s == "foo") {
  std::print("got foo");
} else if (s == "bar") {
  std::print("got bar");
} else {
  std::print("don't care");
}
```

### P1371R3
```cpp
inspect (s) {
  "foo" => std::print("got foo");
  "bar" => std::print("got bar");
  __ => std::print("don't care");
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (s) {
  is "foo" => std::print("got foo");
  is "bar" => std::print("got bar");
  is _ => std::print("don't care");
};
```

### This Paper
```cpp
match (s) {
  case "foo" => std::print("got foo");
  case "bar" => std::print("got bar");
  case _ => std::print("don't care");
}
```

:::

\pagebreak

## Matching Tuples

::: cmptable

### C++23
```cpp
auto&& [x, y] = p;
if (x == 0 && y == 0) {
  std::print("on origin");
} else if (x == 0) {
  std::print("on y-axis at {}", y);
} else if (y == 0) {
  std::print("on x-axis at {}", x);
} else {
  std::print("at {}, {}", x, y);
}
```

### P1371R3
```cpp
inspect (p) {
  [0, 0] => std::print("on origin");
  [0, y] => std::print("on y-axis at {}", y);
  [x, 0] => std::print("on x-axis at {}", x);
  [x, y] => std::print("at {}, {}", x, y);
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (p) {
  is [0, 0] =>
    std::print("on origin");
  is [0, _ y] =>
    std::print("on y-axis at {}", y);
  is [_ x, 0] =>
    std::print("on x-axis at {}", x);
  is [x, y] =>
    std::print("at {}, {}", x, y);
};
```

### This Paper
```cpp
match (p) {
  case [0, 0] =>
    std::print("on origin");
  case [0, int y] =>
    std::print("on y-axis at {}", y);
  case [int x, 0] =>
    std::print("on x-axis at {}", x);
  case [int x, int y] =>
    std::print("at {}, {}", x, y);
}
```

:::

\pagebreak

## Matching Variants

::: cmptable

### C++23
```cpp
struct visitor {
  void operator()(int32_t i32) const {
    std::print("got int32: {}", i32);
  }
  void operator()(int64_t i64) const {
    std::print("got int64: {}", i64);
  }
  void operator()(float f) const {
    std::print("got float: {}", f);
  }
  void operator()(double d) const {
    std::print("got double: {}", d);
  }
};
std::visit(visitor{}, v);
```

### P1371R3
```cpp
inspect (v) {
  <int32_t> i32 =>
    std::print("got int32: {}", i32);
  <int64_t> i64 =>
    std::print("got int64: {}", i64);
  <float> f =>
    std::print("got float: {}", f);
  <double> d =>
    std::print("got double: {}", d);
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (v) {
  as int32_t i32 =>
    std::print("got int32: {}", i32);
  as int64_t i32 =>
    std::print("got int64: {}", i64);
  as float f =>
    std::print("got float: {}", f);
  as double d =>
    std::print("got double: {}", d);
};
```

### This Paper
```cpp
match (v) {
  case { int32_t i32 } =>
    std::print("got int32: {}", i32);
  case { int64_t i64 } =>
    std::print("got int64: {}", i64);
  case { float f } =>
    std::print("got float: {}", f);
  case { double d } =>
    std::print("got double: {}", d);
}
```

:::

\pagebreak

## Matching Variant Alternatives with Concepts

This example matches variant alternatives using concepts.

::: cmptable

### C++23
```cpp
struct visitor {
  void operator()(
      std::integral auto i) const {
    std::print("got integral: {}", i);
  }
  void operator()(
      std::floating_point auto f) const {
    std::print("got float: {}", f);
  }
};
std::visit(visitor{}, v);
```

### P1371R3
```cpp
inspect (v) {
  <std::integral> i =>
    std::print("got integral: {}", i);
  <std::floating_point> f =>
    std::print("got float: {}", f);
};
```

:::

::: cmptable

### P2392R3
```cpp
// not supported






```

### This Paper
```cpp
match (v) {
  case { std::integral auto i } =>
    std::print("got integral: {}", i);
  case { std::floating_point auto f } =>
    std::print("got float: {}", f);
}
```

:::

\pagebreak

## Matching Polymorphic Types

```cpp
struct Shape { virtual ~Shape() = default; };
struct Circle : Shape { int radius; };
struct Rectangle : Shape { int width, height; };
```

::: cmptable

### C++23
```cpp
virtual int Shape::get_area() const = 0;

int Circle::get_area() const override {
  return 3.14 * radius * radius;
}
int Rectangle::get_area() const override {
  return width * height;
}
```

### P1371R3
```cpp
int get_area(const Shape& shape) {
  return inspect (shape) {
    <Circle> [r] => 3.14 * r * r;
    <Rectangle> [w, h] => w * h;
  };
}
```

:::

::: cmptable

### P2392R3
```cpp
int get_area(const Shape& shape) {
  return inspect (shape) {
    as Circle [r] => 3.14 * r * r;
    as Rectangle [w, h] => w * h;
  };
}
```

### This Paper
```cpp
int get_area(const Shape& shape) {
  return match (shape) {
    case const Circle& circle =>
      3.14 * circle.radius * circle.radius;
    case const Rectangle& rectangle =>
      rectangle.width * rectangle.height;
    case _ => throw UnknownShape{};  // required: the hierarchy is open
  };
}
```

:::

## Matching Nested Structures

```cpp
struct Rgb { int r, g, b; };
struct Hsv { int h, s, v; };

using Color = variant<Rgb, Hsv>;

struct Quit {};
struct Move { int x, y; };
struct Write { string s; };
struct ChangeColor { Color c; };

using Command = variant<Quit, Move, Write, ChangeColor>;

Command cmd = ChangeColor { Hsv { 0, 160, 255 } };
```

::: cmptable

### C++23
```cpp
struct CommandVisitor {
  void operator()(Quit) const {}
  void operator()(const Move& move) const {
    const auto& [x, y] = move;
    // ...
  }
  void operator()(const Write& write) const {
    const auto& text = write.s;
    // ...
  }
  void operator()(
      const ChangeColor& cc) const {
    struct ColorVisitor {
      void operator()(const Rgb& rgb) {
        const auto& [r, g, b] = rgb;
        // ...
      }
      void operator()(const Hsv& hsv) {
        const auto& [h, s, v] = hsv;
        // ...
      }
    };
    std::visit(ColorVisitor{}, cc.c);
  }
};
std::visit(CommandVisitor{}, cmd);
```

### P1371R3
```cpp
inspect (cmd) {
  <Quit> _ => // ...
  <Move> [x, y] => // ...
  <Write> [text] => // ...
  <ChangeColor> [<Rgb> [r, g, b]] => // ...
  <ChangeColor> [<Hsv> [h, s, v]] => // ...
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (cmd) {
  is Quit => // ...
  as Move [x, y] => // ...
  as Write [text]  => // ...
  as ChangeColor as [Rgb] [[r, g, b]] => // ...
  as ChangeColor as [Hsv] [[h, s, v]] => // ...
}
```

### This Paper
```cpp
match (cmd) {
  case { Quit } => // ...
  case { Move: auto& [x, y] } => use(x, y);
  case { Write: auto& [text] } => use(text);
  case { ChangeColor: [{ Rgb: auto& [r, g, b] }] } => use(r, g, b);
  case { ChangeColor: [{ Hsv: auto& [h, s, v] }] } => use(h, s, v);
}
```

:::

This example is adapted from
[Destructuring Nested Structs and Enums](https://doc.rust-lang.org/book/ch18-03-pattern-syntax.html#destructuring-nested-structs-and-enums)
in the Rust documentation.

This paper retains the recursive operation of the R5 selector, but places it
inside braces. This allows type selection and structural matching to compose
without making a bare declaration look inside a choice.

\pagebreak

# Evidence from Existing C++

We surveyed pinned revisions of [Chromium](https://github.com/chromium/chromium/tree/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5) and [LLVM](https://github.com/llvm/llvm-project/tree/52a463254a82be0bcd75f0b7cbfe4728e31c1b26). The survey covered approximately 13.29 million lines in 72,503 non-test Chromium files and 6.50 million lines in 12,366 non-test LLVM files. The examples below are representative rewrites, not changes submitted to those projects. The same forms appeared repeatedly:

| Existing form | Operation being expressed |
|---|---|
| `std::visit(overloaded{...})` | Dispatch by active alternative and bind it |
| `get_if` / `holds_alternative` chains | Ordered runtime type dispatch |
| `switch (v.index())` plus `get<I>` | Dispatch by state, then project |
| `has_value()` / `hasError()` branches | Split value, empty, and error states |
| `dynamic_cast` chains | Refine a polymorphic object |
| Generic visitor plus an inner value test | Apply one pattern across alternatives |
| Nested tests over tuple members | Compose type, value, and structure tests |

Most `variant` code binds a concrete alternative. Handling an alternative
generically and matching the same structure across several alternatives are
less common, but both show up in real code and are important for a C++ sum
type.

## Values and Enums

The smallest use case remains a direct replacement for a value `switch`:

```cpp
switch (value) {
case 0:
  zero();
  break;
case 1:
  one();
  break;
default:
  other();
  break;
}
```

```cpp
match (value) {
  case 0 => zero();
  case 1 => one();
  case _ => other();
}
```

Unlike `switch`, the patterns can be nested inside decomposition and choice
patterns. Unlike a visitor, the cases remain ordered and can be checked for
exhaustiveness.

## Replacing Visitor Ceremony

The following is typical code that turns several variant alternatives into one
result type. Chromium's [`EnterpriseCompanionStatus::code()`](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/chrome/enterprise_companion/enterprise_companion_status.h#L80-L85) is a compact public example; LLVM's [artifact serializer](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/clang/lib/ScalableStaticAnalysis/Core/Serialization/JSONFormat/Artifact.cpp#L188-L208) uses a generic visitor followed by an `if constexpr` chain:

```cpp
return std::visit(
    overloaded{
        [](shared_ptr<const IdentifierRecord> record) {
          return ResultValue(record->value);
        },
        [](shared_ptr<const Parameter> parameter) {
          return ResultValue(clone(parameter->value));
        },
        [](uint64_t value) {
          return ResultValue(static_cast<int64_t>(value));
        },
        [](auto&& value) {
          return ResultValue(
              std::forward<decltype(value)>(value));
        }},
    std::move(input));
```

With pattern matching:

```cpp
return match (std::move(input)) -> ResultValue {
  case { shared_ptr<const IdentifierRecord> record }
    => ResultValue(record->value);

  case { shared_ptr<const Parameter> parameter }
    => ResultValue(clone(parameter->value));

  case { uint64_t value }
    => ResultValue(static_cast<int64_t>(value));

  case { auto&& value }
    => ResultValue(std::forward<decltype(value)>(value));
};
```

The braces say to match the active alternative rather than the `variant`
itself. The final case is instantiated for every remaining alternative and
preserves its value category.

## One Structural Pattern Across Several Alternatives

The following example handles one tuple alternative by naming its concrete
tuple type and calling `get`:

```cpp
return std::visit(
    overloaded{
        [](const CompositeKey& key) {
          return records().lookup(
              std::get<0>(key), std::get<1>(key));
        },
        [](reference_wrapper<const Record> ref) {
          return ref.get().view();
        },
        [](const auto&) -> RecordView {
          throw invalid_argument("unsupported record reference");
        }},
    input);
```

The pattern version expresses the relevant structure instead of one nominal
tuple type:

```cpp
return match (input) -> RecordView {
  case { [auto&& first, auto&& second] }
    => records().lookup(first, second);

  case { reference_wrapper<const Record> ref }
    => ref.get().view();

  case { _ }
    => throw invalid_argument("unsupported record reference");
};
```

The same case can match a `pair`, `tuple`, array, or user-defined type with the
same two-element shape.

## Applying One Value Pattern Across Alternatives

Here is a similar example that checks numeric telemetry values:

```cpp
using MetricValue =
    variant<int16_t, int32_t, int64_t, float, double>;

return ranges::all_of(metrics, [](const auto& item) {
  return std::visit(
      [](auto value) { return value == 0; },
      item.second);
});
```

The pattern applies `0` to every projected alternative for which the
comparison is viable:

```cpp
return ranges::all_of(metrics, [](const auto& item) {
  return match (item.second) {
    case { 0 } => true;
    case _    => false;
  };
});
```

This is an important example. `{ P }` cannot just be syntax for declaring a
payload of type `T`. The outer braces select an alternative, and the inner `0`
matches its value.

## Optional and Expected States

An optional value currently requires a test followed by a projection. Chromium's [`StringViewOrString::get()`](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/base/base64url.cc#L27-L41) is a small example of this form:

```cpp
auto value = parseIntegerText(input);
if (!value.has_value()) {
  throw ParseError(fieldName, "expected an integer");
}
return std::move(*value);
```

Pattern matching can name both states directly:

```cpp
return match (parseIntegerText(input)) -> string {
  case { string value }
    => std::move(value);

  case {}
    => throw ParseError(fieldName, "expected an integer");
};
```

Expected-like types naturally use named states:

```cpp
match (loadResources()) {
  case { .value: auto&& resources }
    => context.resources = std::move(resources);

  case { .error: const string& error }
    => return unexpected(format_error(error));
}
```

`{}` does not specifically mean `nullopt`. It matches a state that has no
value to project. Named states come from the choice's `alternative_traits`.

## Matching Representation Shape

A configuration type can use a `variant` of five tuple shapes:

```cpp
variant<
    tuple<UniformMode, T>,
    tuple<DeltaMode, T>,
    tuple<ClobberMode, T>,
    tuple<DeltaMode, T, T>,
    tuple<ClobberMode, T, T>>
    value;
```

The original code contained one visitor overload per alternative. A property
that depends only on tuple arity becomes:

```cpp
bool has_secondary() const {
  return match (value) {
    case { [_, _, _] } => true;
    case { [_, _] }    => false;
  };
}
```

Selecting the delta component composes type, structure, and binding:

```cpp
const T* delta() const {
  return match (value) -> const T* {
    case { [DeltaMode, const auto& delta] }
      => &delta;

    case { [DeltaMode, const auto& delta, _] }
      => &delta;

    case { [ClobberMode, _, const auto& delta] }
      => &delta;

    case _ => nullptr;
  };
}
```

## Matching Several Values

The parenthesized subject list can contain several expressions. Code that
merges two compact-or-expanded keyed representations commonly contains a
nested matrix of `holds_alternative` and `get_if` tests. The state space can
instead be made explicit by matching the two values directly:

```cpp
using SingleEntry = pair<Key, Values>;
using EntryMap = folly::F14FastMap<Key, Values>;
using Entries = variant<monostate, SingleEntry, EntryMap>;

void merge(Entries& destination, Entries&& source) {
  match (std::move(source), destination) {
    case [{ monostate }, _] => ;

    case [{ auto&& value }, { monostate }]
      => destination = std::move(value);

    case [{ auto&& [sourceKey, sourceValue] },
          { auto&& [destinationKey, destinationValue] }] => do {
      if (sourceKey != destinationKey) {
        EntryMap map;
        map.emplace(destinationKey, std::move(destinationValue));
        map.emplace(sourceKey, std::move(sourceValue));
        destination = std::move(map);
      }
    };

    case [{ auto&& [key, value] }, { EntryMap& map }]
      => map.try_emplace(key, std::move(value));

    case [{ EntryMap&& map }, { auto&& [key, value] }] => do {
      map.insert_or_assign(key, std::move(value));
      destination = std::move(map);
    };

    case [{ EntryMap&& sourceMap }, { EntryMap& destinationMap }] => do {
      for (auto&& [key, value] : sourceMap)
        destinationMap.try_emplace(key, std::move(value));
    };
  }
}
```

This makes all of the combinations visible without constructing a named or
library product.

## Visitor Replacement Is Not Purely Mechanical

Overload selection and first-match pattern coverage are different. This
visitor does nothing for a nonzero `int`; the generic overload is never called:

```cpp
visit(overloaded{
  [](int value) {
    if (value == 0)
      zero();
  },
  [](const auto&) {
    other();
  }
}, value);
```

A naive rewrite changes behavior:

```cpp
match (value) {
  case { 0 } => zero();
  case { _ } => other(); // also handles nonzero int
}
```

The faithful rewrite explicitly covers the rest of the `int` alternative:

```cpp
match (value) {
  case { 0 }   => zero();
  case { int } => ;
  case { _ }   => other();
}
```

This is an important difference between a visitor overload set and ordered,
composable patterns. A rewrite needs to preserve it explicitly.

# Design Overview

We propose one `match` construct for both selection and testing:

```cpp
match (@*expression*@) {
  case @*pattern*@ => @*handler*@;
  // ...
}
```

Every pattern has a current subject. A declaration pattern initializes its
declaration from that subject using ordinary C++ rules:

```cpp
constexpr int x = 42;

match (@*expression*@) {
  case x => ...           // match against the existing `x`
  case int x => ...       // introduce a new `x` by value
  case const int& x => ...// introduce a reference
}
```

Braces match the value stored inside a choice type:

```cpp
variant<int, string> value;

match (value) {
  case auto&& whole => inspect(whole);
  case { int integer } => use(integer);
  case { const string& text } => print(text);
}
```

The first case makes the later cases unreachable; it is only here to make the
distinction visible. `auto&& whole` binds the `variant`. Braces enter the
choice, so `{ auto&& payload }` binds its active alternative.

Polymorphic class objects instead use declaration-shaped runtime refinement:

```cpp
Shape& shape = get_shape();

match (shape) {
  case Circle& refined => draw(refined); // dynamic_cast-equivalent refinement
  case _               => draw_unknown(shape);
}

Circle circle;
match (circle) {
  case Circle& exact => static_circle(exact); // ordinary exact binding
}
```

When the declaration exactly matches the subject's static type, this is an
ordinary declaration. Otherwise, a class declaration can refine a polymorphic
class. See [Static Matching and Polymorphic Refinement].

For a selection statement, the right operand of `=>` is an ordinary C++
statement. It can therefore be a compound statement, declaration statement,
control statement, `static_assert`, null statement, or jump statement:

```cpp
match (command) {
  case start => {
    initialize();
    run();
  }
  case retry => if (ready()) run(); else schedule();
  case stop  => return;
  case _    => ;
}
```

An expression selection has a smaller handler grammar because it has to
produce a result. It supports expressions, a null statement, `static_assert`,
and the structured jump actions described below. `not return expression`
marks an expression that does not return normally and therefore contributes no
result type. A `do` expression [@P2806R2] provides a statement block that
yields a value.

The following tests one or more values against one pattern:

```cpp
match( @*match-subject-list*@ , case @*pattern*@ )
```

It produces a `bool`; declarations in the pattern are not available afterward.
Use a pattern condition when the controlled statement needs those names:

```cpp
if (case [0, int foo] = @*expr*@) {
  // `foo` is available here
} else {
  // but not here
}
```

A selection case can also have a guard:

```cpp
std::pair<int, int> fetch(int id);

bool is_acceptable(int id, int abs_limit) {
  return match (fetch(id)) {
    case [int min, int max]
      if (-abs_limit <= min && max <= abs_limit) => true;
    case _ => false;
  };
}
```

## Syntax Overview

The following is an informal grammar. Complete wording remains to be written.

```cpp
// Single-pattern test; does not export names.
match( @*match-subject-list*@ , case @*pattern*@ )

// Pattern condition.
case @*pattern*@ = @*inclusive-or-expression*@

// Selection expression; only in an expression-only context.
match @`constexpr`*~opt~*@ ( @*match-subject-list*@ ) @*trailing-return-type~opt~*@ {
    @*match-preamble-declaration-seq~opt~*@
    @*attribute-specifier-seq~opt~*@ case @*pattern*@ @*guard~opt~*@ => @*expression-handler*@
}

@*expression-handler*@:
    @*expr-or-braced-init-list~opt~*@ ;
    ! return @*expression*@ ;
    @*static_assert-declaration*@
    break ;
    continue ;
    return @*expr-or-braced-init-list~opt~*@ ;
    co_return @*expr-or-braced-init-list~opt~*@ ;
    do_return @*expr-or-braced-init-list~opt~*@ ;

// Selection statement; implicit `-> void`, no trailing semicolon.
match @`constexpr`*~opt~*@ ( @*match-subject-list*@ ) {
    @*match-preamble-declaration-seq~opt~*@
    @*attribute-specifier-seq~opt~*@ case @*pattern*@ @*guard~opt~*@ => @*statement*@
}

@*match-preamble-declaration-seq*@:
    @*match-preamble-declaration*@
    @*match-preamble-declaration-seq*@ @*match-preamble-declaration*@

@*match-preamble-declaration*@:
    @*using-declaration*@
    @*using-enum-declaration*@
    @*using-directive*@
    @*alias-declaration*@
    @*namespace-alias-definition*@
    @*static_assert-declaration*@

@*guard*@:
    if ( @*init-statement~opt~*@ @*condition*@ )

@*pattern*@:
    @*or-pattern*@

@*or-pattern*@:
    @*primary-pattern*@
    @*or-pattern*@ || @*primary-pattern*@

@*primary-pattern*@:
    _
    @*match-expression*@
    @*declaration-pattern*@
    @*type-pattern*@
    ( @*pattern*@ )
    { @*pattern*@ }
    { . @*identifier*@ : @*pattern*@ }
    { . @*identifier*@ }
    { }
    [ @*pattern-list~opt~*@ ]
```

# Syntax and Selection Forms

## Selection Statements and Expressions

In an expression-only context, a selection is an expression:

```cpp
match constexpr(opt) ( subject-list ) trailing-return-type(opt) {
  match-preamble-declaration-seq(opt)
  attribute-specifier-seq(opt) case pattern guard(opt) => handler;
}
```

At the start of a statement, the same prefix instead introduces a selection
statement:

```cpp
match constexpr(opt) ( subject-list ) {
  match-preamble-declaration-seq(opt)
  attribute-specifier-seq(opt) case pattern guard(opt) => handler;
}
```

The *subject-list* is a non-empty comma-separated list of assignment
expressions. A list with one expression selects that expression directly. A
list with more than one expression forms the unnamed product described in
[Multiple Subjects]. A pack expansion keeps the product interpretation even
when an instantiation expands it to zero or one element.

The optional preamble is a sequence of *using-declaration*s,
*using-enum-declaration*s, *using-directive*s, *alias-declaration*s,
*namespace-alias-definition*s, and *static_assert-declaration*s. It must appear
before the first case. Each declaration is in scope from its point of
declaration through the remainder of the preamble and every case. A case does
not make its bindings visible to the preamble or to another case.

The preamble does not admit a *simple-declaration*, so it cannot declare an
object or perform runtime initialization. It is also not present in a
single-pattern test. A *consteval-block-declaration* is not included in R6.
In a dependent selection, the preamble is instantiated once for the enclosing
selection specialization, before any applicable source case is instantiated
for alternative projections. It is not duplicated for each such case
instantiation and cannot refer to a binding introduced by one.

A selection statement behaves as though it had an implicit `-> void`: handler
expressions are discarded-value expressions, no common result type is
required, and no semicolon follows the closing brace. An expression match can
be forced at statement scope by placing it in an expression-only context.

For example:

```cpp
int result = match (value) -> int {
  [[likely]] case 0 => 1;
  case int x if (x > 0) => x;
  [[unlikely]] case _ => -1;
};

match (value) {
  case 0 => record_zero();
  case _ => record_other();
}
```

## Single-Pattern Tests and Pattern Conditions

A single-pattern test is:

```cpp
match(subjects..., case pattern)
```

The `case` keyword marks the final comma-separated operand as a pattern rather
than another subject. The test does not export bindings. A non-viable pattern
makes the expression ill-formed.

Pattern conditions are used in `if`, `while`, and traditional `for` statements:

```cpp
if (case pattern = subject) statement
while (case pattern = subject) statement
for (init-statement; case pattern = subject; expression) statement
```

The corresponding range-for form is:

```cpp
for (case pattern : range) statement
```

Pattern conditions can participate in a left-to-right built-in conjunction:

```cpp
if (ready && case [int x, int y] = first &&
    x < y && case { string text } = second && !text.empty()) {
  use(x, y, text);
}
```

The first top-level `=` separates the pattern from the subject. A direct
assignment expression is therefore not available as a pattern in this form;
it can be factored into a named or helper expression. A trailing pattern guard
is not accepted in this form; a later `&&` condition is the guard.

The range-for form filters: an element for which the pattern does not match is
skipped.

## Guards

A selection-case guard is introduced by `if` and requires parentheses. It can
contain an init-statement and a condition declaration:

```cpp
match (value) {
  case Widget widget
    if (auto status = validate(widget); status.ok())
      => consume(widget, status);

  case _ => reject();
}
```

Pattern bindings are visible in the guard. A guard init-statement declaration
is visible in the guard condition and selected handler. Neither is visible in
later cases.

Guarded cases do not contribute to exhaustiveness, even when a guard is
manifestly `true`. This keeps coverage independent of arbitrary constant
evaluation and avoids changing exhaustiveness when a guard expression is
refactored.

## Parsing

`match` remains an identifier and can already name a type, function, or
object. A parser therefore recognizes a prefix selection tentatively and
returns to ordinary C++ parsing if the complete token sequence does not select
the match grammar. This classification does not build the subject, perform
overload resolution, or emit diagnostics.

For valid programs, the recognition flow is:

```text
start at `match`
|
+- next token is `constexpr` -> selection
+- next token is not `(`     -> ordinary C++
`- scan through the balanced non-empty `( ... )`
   |
   +- no matching `)` -> ordinary C++
   `- inspect the token after `)`
      |
      +- `{`
      |  +- expression-only context -> selection expression
      |  `- direct statement context
      |     +- body begins with `case`, `[[`, or a preamble declaration
      |     |  -> selection statement
      |     +- `match` is not a type-name -> selection statement
      |     `- otherwise, a valid tentative declarator -> ordinary C++
      |
      +- `->`
      |  +- direct statement context -> ordinary C++
      |  `- expression-only context
      |     +- complete type-id followed by `{` -> selection expression
      |     `- otherwise -> ordinary C++
      |
      `- anything else -> ordinary C++
```

The tentative declarator branch preserves existing declarations such as:

```cpp
struct match { match(int); };

match object(0);
match (object) { 0 };
```

In an expression-only context, `match (subject) {` is unambiguously a
selection expression. At the start of a statement, the body introducer and
ordinary lookup distinguish it from the declaration case. A single `[` does
not commit to a selection because a braced initializer can begin with a
lambda; `[[` does commit because it begins an arm attribute.

The token following the subject can be arbitrarily far from `match`. C++
already requires this kind of decision for declarations and expressions:

```cpp
T (*****x) = y;   // declaration
T (*****x) == y;  // expression
```

The prototype scans the balanced subject before performing the selected real
parse. A production parser can avoid repeated work in deeply nested cases by
caching matching delimiters.

A trailing result type is recognized only when a complete *type-id* is
followed by `{`. This preserves ordinary member access:

```cpp
return match (value) -> Result { case _ => Result{}; }; // selection
return match (value)->result;                           // member access
```

The implementation uses the existing tentative type-id and declarator
facilities. For malformed programs it can run the real trailing-return-type
parser tentatively, including normal recovery and typo correction, and then
rewind to issue a match-specific diagnostic. Similarly, a top-level `=>` in a
declaration-shaped body can support a focused missing-`case` diagnostic without
changing the grammatical classification.

The difficult paths appear uncommon. A survey of non-test Chromium and LLVM
sources found no existing statement or expression of the form
`match (...) { ... }`, no `match (...) ->` occurrence, and no type named
`match`. LLVM has many functions and members named `match`, which remain
ordinary because their calls are not followed by a selection body.

The single-pattern form is simpler. A top-level comma followed by `case`
separates the subject list from the pattern:

```cpp
match(value, case a * b) // expression pattern
match(value, case T * x) // declaration pattern if T names a type
match(value, case a) * b // multiplication outside the test
```

Within a pattern, `_`, `(`, `[`, and `{` commit to wildcard,
parenthesized, decomposition, and alternative pattern grammar. Expressions
beginning with those tokens use an unambiguous expression spelling such as
`auto(_ + 1)` or `auto([] { return 1; }())`. Declaration patterns use a
restricted *type-specifier-seq* and *conversion-declarator*; `T value` and
`T* value` are declarations, while `T(value)` and `auto(value)` are
expressions. The only localized overlap is `[[`, which can begin either an
attribute or a nested decomposition. The parser accepts the attribute
interpretation only when a complete attribute can continue the surrounding
declaration.

## Handlers

For a selection statement, a handler is any *statement*. This includes
declaration statements, compound statements, control statements, and jump
statements. An expression used as a statement has its value discarded in the
ordinary way.

For a selection expression, a handler can be:

- an expression;
- a non-returning expression, written `not return expression`;
- a null statement, written `=> ;`;
- a `static_assert` declaration;
- `break`, `continue`, `return`, or `co_return` where that action is valid.

The `do` expression composes with match when a handler needs a statement block
that yields a value:

```cpp
return match (value) -> int {
  case int x => do {
    log(x);
    do_return x;
  };

  case _ => static_assert(false, "unsupported specialization");
};
```

# Pattern Specifications
## The Current Subject

Every pattern has one current subject:

- a declaration or type pattern applies directly to it, with built-in runtime
  refinement when a class target is matched against a polymorphic class
  object;
- `[P1, P2]` decomposes it and gives each child a component subject;
- `{ P }` requests choice projection and applies `P` to the resulting subject;
- `{ T: P }` selects a projected type before applying `P`;
- `{ C: P }` selects a projected alternative whose declared type satisfies
  type-constraint `C`;
- `{ .index<I>: P }` uses a provider-defined parameterized name to select
  state `I`;
- `{ .name: P }` first selects a named state;
- `_` ignores it without performing projection.

A declaration never implicitly looks inside a `variant`. Braces first change
the subject to an alternative; the nested declaration then binds that
alternative. Polymorphic refinement is different because the derived object is
the same object. Only the reference is adjusted.
## Wildcard Pattern

> | `_`

A wildcard pattern always matches any *subject*.

```cpp
int v = 42;
match (v) {
    case _ => std::print("ignored");
//  ^  wildcard pattern
}
```

This paper again proposes `_` as the wildcard pattern.
See [Expressions as Patterns and `_` as the Wildcard] for further discussion.

- Matching Condition: None
## Value and Predicate Patterns

> | `@*inclusive-or-expression*@`

A value pattern ordinarily compares its expression with the current subject.
The expression has to be constant: a literal, `constexpr` variable,
enumerator, or constexpr function object, for example. A direct name of an
immediate function can also be used as a predicate without first forming a
pointer. The pattern expression is not reevaluated each time the case is
attempted. If a closed choice advertises the constant as a state label, the
match uses the discriminator instead of calling `operator==`.

- Matching Condition: the advertised-state test, if any. Otherwise, if
  `bool(@*subject*@ == @*inclusive-or-expression*@)` is well-formed, that
  expression. Otherwise,
  `bool(@*inclusive-or-expression*@(@*subject*@))`.

We try equality first. If equality is not available, we try invocation. This
keeps the ordinary meaning of value patterns and avoids eagerly probing an
unconstrained call operator:

```cpp
struct at_least {
  int value;

  constexpr bool operator()(int subject) const {
    return subject >= value;
  }
};

constexpr at_least five{5};

match (value) {
  case five => at_least_five();
  case _ => smaller();
}
```

This is particularly useful with reflection predicates. A lambda can combine
several queries; `auto(...)` makes the lambda unambiguously an expression where
`[` would otherwise begin a decomposition pattern:

```cpp
consteval std::string_view classify(std::meta::info entity) {
  return match (entity) {
    case std::meta::is_type => "type";
    case std::meta::is_variable => "variable";
    case auto([](std::meta::info candidate) consteval {
      return std::meta::is_function(candidate) &&
             std::meta::is_deleted(candidate);
    }) => "deleted function";
    case std::meta::is_function => "function";
    case _ => "other";
  };
}

static_assert(classify(^^int) == "type");
```

A predicate does not contribute to exhaustiveness. The predicate object is a
constant, but its result is generally a runtime property.
## Declaration Patterns

A declaration pattern is an ordinary declaration initialized from the current
subject:

```cpp
case Widget value
case const Widget& reference
case auto&& forwarded
case std::integral auto integer
```

The declaration grammar uses a *type-specifier-seq*, an optional
*conversion-declarator*, and an optional identifier with attributes. It also
admits structured-binding declarations. This supports the familiar scalar,
pointer, reference, member-pointer, constrained-placeholder, and structured-
binding forms without inheriting the whole declarator grammar:

```cpp
case int value
case const Widget& reference
case int Owner::* member
case std::integral auto integer
case auto&& [first, second]
```

In particular, `T(value)`, `bool(value)`, and `auto(value)` are expression
patterns rather than declarations. Function and array declarators require a
type alias. Storage-class forms such as `static` and `thread_local` are not
permitted.

The usual declaration rules answer the questions we otherwise would have to
answer again for patterns:

- by-value copy and move construction;
- reference binding and cv-qualification;
- forwarding-reference deduction;
- constraints on placeholder types;
- `decltype` of the introduced name;
- accessibility, deleted functions, and destruction.

We restrict applicability to exact-match standard conversion sequences:
identity, lvalue transformations, qualification adjustment, and function
pointer conversion. Promotions, conversion-rank standard conversions, and
user-defined conversions do not make a declaration pattern applicable.

There is one additional rule. If ordinary exact matching does not apply, a
class declaration can refine a polymorphic class subject. The runtime test and
object adjustment are those of the corresponding pointer-form `dynamic_cast`.
The declaration is then initialized from the adjusted object. We do not apply
this rule to pointer declarations:

```cpp
Shape& shape = get_shape();

match (shape) {
  case Circle& circle => draw(circle); // runtime refinement
  case Shape& other   => draw(other);  // ordinary exact binding
}
```

Pointers use ordinary declaration matching. A non-null pointer can be
projected to its referent with `{ P }`, after which the same class-refinement
rule composes naturally:

```cpp
Shape* shape = get_shape_pointer();

match (shape) {
  case {}                => no_shape();
  case { Circle& circle } => draw(circle);
  case { Shape& other }   => draw(other);
}
```

Patterns are ordered, not overloaded. The first matching case wins. We use
overload ranking only to define the allowed conversions; it never reorders
cases.

For a closed choice, every written declaration must be applicable to at least
one alternative unless dependence makes it potentially useful:

```cpp
variant<int, double> value;

match (value) {
  case { int integer } => use(integer);
  case { double real }  => use(real);
  case { char byte }    => use(byte); // error: not useful
}
```

Qualification adjustment can intentionally make one earlier case cover several
alternatives:

```cpp
variant<int*, const int*> pointer;

match (pointer) {
  case { const int* value } => inspect(value); // can cover both alternatives
  case { int* value }       => mutate(value);  // error if fully dominated
}
```

The second case is rejected as useless. The language does not reorder these
cases the way an overload set would.

### Applicability Versus Failed Initialization

There are three possible outcomes for a declaration pattern:

1. It is not applicable to its current subject.
2. It is applicable and initialization succeeds.
3. It is applicable, but the selected initialization is ill-formed.

Only the first can remove the corresponding case instantiation from a
dependent match. The third is an error. This follows overload resolution: once
a by-value overload has been selected, a failed copy does not retry an
ellipsis fallback.

```cpp
struct Job {
  Job(Job&&) = default;
  Job(const Job&) = delete;
};

void process(auto&& value) {
  match (std::forward<decltype(value)>(value)) {
    case Job job => execute(std::move(job));
    case _      => report_unsupported();
  }
}

Job job;
process(Job{}); // moves
process(job);   // error: selected Job initialization requires a copy
```

Silently choosing the wildcard arm in the second call would turn an ownership
error into different program behavior.
## Type Patterns

A declaration pattern can omit its identifier. The resulting type pattern has
the same initialization semantics as the corresponding named declaration:

```cpp
case int
case const Widget&
case auto&&
case std::integral auto
case [auto&&, auto&&]
```

The declaration is initialized even though it has no identifier, following the
precedent of unnamed function parameters. Consequently, a value type may copy
or move and is destroyed normally. A reference type provides the non-owning
form:

```cpp
case Widget         // initializes and destroys an unnamed object
case const Widget&  // binds a reference
```

`void` and cv-`void` are explicitly supported. This matters for dependent
void-valued expressions and `expected<void, E>` projections.

An omitted identifier is also permitted on constrained placeholder
declarations:

```cpp
case std::integral auto
case std::ranges::viewable_range auto&&
```

A bare type-constraint is not a general declaration or type pattern. It is
permitted as the discriminator in `{ C: P }`, where it is applied directly to
the closed protocol's declared alternative type. This does not infer an
implicit `auto` or `auto&&`; those spellings remain available when placeholder
deduction and cv/ref control are wanted in an ordinary declaration pattern.
## Parenthesized Pattern

> | `( @*pattern*@ )`

A parenthesized pattern groups any pattern. It has the same matching semantics
and introduces the same bindings as its nested pattern.

- Matching condition: the matching condition of the enclosed pattern.

```cpp
match (direction) {
  case (north || south) => vertical();
  case _ => horizontal();
}

match (pair) {
  case ([0, int value]) => use(value);
  case (_) => fallback();
}
```

Parentheses around `_` or `[P...]` are not normally useful when written
directly. They are useful for substitution: a macro or future pattern
abstraction can wrap an arbitrary pattern without knowing its outer grammar.

```cpp
#define GROUP_PATTERN(...) (__VA_ARGS__)

match (value) {
  case GROUP_PATTERN(0 || 1) => small();
  case GROUP_PATTERN([int x, int y]) => pair(x, y);
  case GROUP_PATTERN(_) => fallback();
}
```

General grouping also avoids committing the grammar of later prefix, infix,
or postfix patterns to today's precedence choices. For example, if a future
revision adds an as-pattern operator, `(P) @ auto value` can accept any `P`.

The opening `(` selects pattern grammar. A parenthesized pattern therefore
cannot continue as an ordinary postfix or binary expression after its closing
`)`. An expression that begins with pattern syntax can instead be placed in a
functional cast whose initializer is parsed as an expression.

```cpp
case (north || south)       // parenthesized or-pattern
case (_)                    // parenthesized wildcard pattern
case ([int x, int y])       // parenthesized decomposition pattern
case (Widget value)         // parenthesized declaration pattern

case int(value)             // functional-cast expression pattern
case auto(value)            // placeholder functional-cast expression pattern
case auto(_ + 1)            // expression using an outer `_`
case auto((value)++)        // postfix expression pattern
case auto((int)value)       // C-style cast expression pattern
case auto([] { return 1; }()) // lambda-call expression pattern
case auto(({ int x = 1; x; })) // GNU statement-expression pattern
```

Consequently `(A || B)` groups an or-pattern. To match the result of
logical-or, use an unambiguous expression such as `bool(A || B)`. A bare `_`
always starts a wildcard pattern, and `[` always starts a decomposition
pattern. To match an expression beginning with either token, use a spelling
such as `auto(_ + 1)` or `auto([] { return 1; }())`. Unary operators remain
unambiguous expression starts, so `+_` is also available where appropriate.

The declaration-pattern grammar resolves the declaration/expression overlap
without another priority rule. `T(x)`, `T()`, `bool(x)`, and `auto(x)` cannot
complete as declaration patterns because a *conversion-declarator* contains
only pointer operators. They therefore retain their ordinary expression
meaning. This reaches the same result as the *nofun-type-id* direction in CWG
issue 2228 for `(T())`, while still allowing `(T value)` to group a declaration
pattern.
## Or-pattern

> | `@*pattern*@ || @*pattern*@`

An or-pattern applies every alternative to the same subject from left to right
and succeeds on the first match:

```cpp
match (direction) {
  case Direction::north || Direction::south => vertical();
  case Direction::east || Direction::west   => horizontal();
}
```

It composes recursively, so several values can share one projection:

```cpp
return match(instruction, case { Load || Store });

match (response) {
  case { .error: timeout || cancelled } => retry();
  case _ => fail();
}
```

General or-patterns are also provided by Rust, Scala, Haskell as an extension,
F#, OCaml, Python, and C#. Swift and Java can group alternatives in a case but
do not provide the same recursively composable operation. Most of these
languages also permit parenthesized patterns, which become important when an
or-pattern is combined with a whole-value binding or another future pattern
operator.

| Language | OR | AND | NOT | Grouping `(P)` |
|---|---|---|---|---|
| Swift | Limited | No | No | Yes |
| Rust | Yes, `P1 | P2` | No | No | Yes |
| Scala | Yes, `P1 | P2` | No | No | Yes |
| Haskell | Extension | No | No | Yes |
| F# | Yes, `P1 | P2` | Yes, `P1 & P2` | No | Yes |
| OCaml | Yes, `P1 | P2` | No | No | Yes |
| Python | Yes, `P1 | P2` | No | No | Yes |
| Java | Limited | No | No | No |
| C# | Yes, `P1 or P2` | Yes, `P1 and P2` | Yes | Yes |
| C++ (this paper) | Yes, `P1 || P2` | No | No | Yes |

This paper uses `||`, rather than `|`, because bitwise-or expressions are
already common case values. Production LLVM and Chromium contain many cases
such as `case Read | Write`. Preserving that meaning gives a useful visual
distinction:

```cpp
case Read | Write  => combined_value();
case Read || Write => either_value();
```

The alternative token `or` has the same grammatical meaning as `||`.
Parentheses still group a pattern, so matching the result of an ordinary
logical expression requires an unambiguous expression spelling:

```cpp
case first || second       => either_pattern();
case (first || second)     => grouped_pattern();
case bool(first || second) => boolean_expression();
```

Every alternative must introduce the same ordered names and pack structure.
The corresponding declarations need not have the same type. The selected
alternative determines their types, and the guard and handler form an implicit
template region:

```cpp
match (value) {
  case { int value } || { const std::string& value } => use(value);
}
```

Exactly one alternative's declarations are initialized. If its guard fails,
matching continues with the next source case, not with another alternative of
the same or-pattern.

## Decomposition Patterns

`[P1, P2, ...]` decomposes the current subject using the structured-binding
rules, then matches each component recursively:

```cpp
match (point) {
  case [0, 0] => origin();
  case [int x, 0] => on_x_axis(x);
  case [0, int y] => on_y_axis(y);
  case [int x, int y] => elsewhere(x, y);
}
```

Empty decomposition is the zero-element structural pattern:

```cpp
case [] => empty_product();
```

One arity-inferred subpattern pack is permitted:

```cpp
case [auto&& first, auto&& ...middle, auto&& last]
case [auto&& first, ..., auto&& last]
```

The first form binds a local pack. A bare `...` consumes and ignores an
arity-inferred sequence of elements. The pack can be empty. Its size is the
decomposition arity minus the fixed prefix and suffix. Both forms are
decomposition-list elements rather than patterns in their own right, so they
cannot be parenthesized or used outside a decomposition pattern. The same
restriction applies to an expanded expression subpattern such as `Values...`.

As with other declaration patterns, the identifier can be omitted:

```cpp
case [Widget ...] => handle();
```

This initializes one unnamed `Widget` from each consumed element. It is not
equivalent to a bare `...`, which performs no declaration initialization.

An or-pattern can combine complete decomposition patterns containing packs,
but cannot combine a pack element itself:

```cpp
case [0, auto&& ...values] || [auto&& ...values, 0] => use(values...);
case [auto&& ...values || _] => use(values...); // error
```

Declaration patterns can themselves contain structured-binding packs:

```cpp
case auto [...elements] => (... + elements);
```

The declaration, guard, and handler form an implicit template region where the
pack can be expanded.
## Alternative Pattern

> | `{ @*pattern*@ }`
> | `{ @*type-pattern*@ : @*pattern*@ }`
> | `{ @*type-constraint*@ : @*pattern*@ }`
> | `{ . @*identifier*@ : @*pattern*@ }`
> | `{ . @*identifier*@ }`
> | `{ . @*simple-template-id*@ : @*pattern*@ }`
> | `{ . @*simple-template-id*@ }`
> | `{ }`

For a choice type, braces select from the alternatives advertised by that type.
They do not by themselves request polymorphic refinement. If the selected
value is a polymorphic class object, an enclosed declaration or type pattern
can refine that object in the ordinary way.

- `{ P }` considers each projectable state and applies `P` to its projection.
- `{ T: P }` considers each projectable state for which type pattern `T` is
  applicable, then applies `P` to the selected projection. If that projection
  is itself a polymorphic class object, the type pattern can refine it under
  the ordinary declaration-pattern rule. Repeated alternatives are considered
  independently.
- `{ C: P }`, where `C` is a type-constraint, considers each projectable state
  whose declared alternative type satisfies `C`, then applies `P` to its
  projection.
- `{ .name: P }` selects a named state and applies `P` to its projection.
- `{ .name }` selects a named state without requiring its projection.
- A provider can expose parameterized names. For example, variant provides
  `.index<I>` for each declared index `I`; `{ .index<I>: P }` applies `P` to
  that alternative's projection, while `{ .index<I> }` selects the state
  without requiring a projection.
- `{}` matches an advertised state for which no projection exists.

```cpp
optional<int> value;

match (value) {
  case { int integer } => use(integer);
  case {} => empty();
}
```

```cpp
expected<int, Error> result;

match (result) {
  case { .value: int value } => use(value);
  case { .error: Error& error } => report(error);
}
```

```cpp
variant<int, tuple<int, int>, pair<int, int>> value;

match (value) {
  case { int: 0 } => zero();
  case { int: auto integer } => use(integer);
  case { tuple<int, int>: [auto x, auto y] } => use_tuple(x, y);
  case { pair<int, int>: [auto x, auto y] } => use_pair(x, y);
}
```

```cpp
variant<int, long, double> number;

match (number) {
  case { std::integral: auto value } => use_integer(value);
  case { std::same_as<double>: auto value } => use_double(value);
}
```

Unlike `std::integral auto`, the `std::integral` before `:` does not declare an
unnamed object or imply a placeholder type. It constrains the declared
alternative type supplied by `alternative_traits`.

The protocol for closed and open choices is described in
[The `alternative_traits` Protocol].

# Scope and Conditions

A name introduced by a pattern is visible in that case's guard and handler,
and nowhere else.

As in R5, the name is introduced immediately for lookup. Using it from the
same pattern is nevertheless ill-formed. Without that rule, adding a
declaration to an earlier part of a pattern could silently change a later
expression from an outer name to the new binding.

`match(subject, case P)` never exports names. In a pattern condition, names are
available in later `&&` elements and the successful controlled statement, but
not in `else`:

```cpp
if (case [int x, int y] = value && x < y) {
  use(x, y);
} else {
  // x and y are not in scope
}
```

`P` has to be valid after substitution. An invalid pattern does not quietly
produce `false`. Use a requires-expression to ask whether it is valid:

```cpp
if constexpr (requires { match(value, case [_, _]); }) {
  // a two-element decomposition is viable
}
```

`if constexpr (case P = E)` has the same rule. The `constexpr` applies after
the condition has been formed; it does not turn the pattern into a detection
operation.

The pattern binding is introduced before the subject of `case P = E` is parsed.
As a result, using the same name on the right is self-initialization and is
ill-formed:

```cpp
int x = 42;
if (case int x = x) { }   // error
if (case int x = ::x) { } // explicitly names an outer object
```

Range-for keeps its existing rule: the range initializer is outside the scope
of the element binding.

# Runtime Type and Choice Matching

## Static Matching and Polymorphic Refinement

A declaration or type pattern first tries ordinary exact matching. If that
does not apply, a class declaration can refine a polymorphic class subject at
runtime. The test has the semantics of the corresponding pointer-form
`dynamic_cast`:

```cpp
void draw(Shape& shape) {
  match (shape) {
    case Circle& circle       => draw_circle(circle);
    case Triangle& triangle   => draw_triangle(triangle);
    case Rectangle& rectangle => draw_rectangle(rectangle);
    case _                   => draw_unknown(shape);
  }
}
```

This includes public downcasts, virtual inheritance, pointer adjustment, and
valid cross-casts. A failed cast is a non-match. After a successful cast, the
declaration's cv/ref spelling has its ordinary effect: `Circle&` binds the
adjusted object, while `Circle` copies or moves from it. `auto&&` exactly
matches the current `Shape` subject; it does not somehow acquire the unknown
most-derived type.

This is an open-world operation. If `Square` derives from `Rectangle` in
another translation unit or shared library, a `Square` passed as `Shape&` must
still match `Rectangle&`. Comparing exact dynamic types or vptrs is not enough.
Listing every currently known derived class is not exhaustive, so a base-class
or wildcard fallback is still required.

A generic declaration can consequently be exact in one instantiation and a
runtime refinement in another:

```cpp
void inspect(auto& value) {
  match (value) {
    case Circle& circle => use(circle);
    case _             => fallback(value);
  }
}

Circle circle;
inspect(circle);                       // ordinary exact binding
inspect(static_cast<Shape&>(circle));  // runtime downcast succeeds
```

A small change to the static type can therefore add a runtime operation. This
is not ideal, but C++ has precedent: `typeid(expression)` observes the dynamic
type only when the expression is a glvalue of polymorphic class type.

This paper does not provide a pattern that asks for static-only class matching.
A generic function can constrain or assert the static types that it accepts.
Matching a type directly is discussed as a possible future extension.

## Polymorphic Refinement Syntax

We considered requiring braces for runtime class refinement:

```cpp
match (shape) {
  case { Circle& circle } => draw(circle);
  case _                  => draw_unknown(shape);
}
```

The argument for braces is straightforward:

- a bare declaration would always retain ordinary static meaning;
- braces would visibly mark every runtime operation, including `variant`,
  `any`, and polymorphic refinement; and
- a representation changed from a class hierarchy to a closed choice could
  preserve more arm syntax.

It also suggested a concise recursive selector such as
`{ Circle: auto&& [x, y] }`, combining refinement and decomposition.

But a derived object is not a value stored inside its base object. It *is* the
object denoted by the base reference. Declaration-shaped runtime type patterns
are also familiar from other languages.

`variant` needs braces because it has a useful generic operation that a
polymorphic hierarchy does not:

```cpp
case auto&& whole       // bind the variant
case { auto&& payload } // bind whichever alternative is active
```

There is no way to give `payload` the unknown most-derived type of an open
class hierarchy. In the code we looked at, a successful cast was normally
followed by member access or function calls. Immediately decomposing the
derived object was rare, and often would not work because the class has base
classes or private state.

Braces would make some migrations between a hierarchy and a `variant` easier.
We found little evidence for such migrations, and they generally require other
ownership and API changes anyway.

There is one real loss: without braces there is no direct
refinement-and-subpattern form. The derived object has to be bound and then
inspected in the handler. We did not find enough examples of this to justify
putting braces on every polymorphic case.

The strongest argument for braces remains the generic example above, where a
small type change introduces a runtime cast. We think the direct object syntax
is worth that cost. Compiler diagnostics and AST dumps should still make the
refinement visible.

## Pointer Subjects

The same rule does not work for pointers. Consider an ordinary generic pointer
match:

```cpp
template<class T>
int classify(T* pointer) {
  return match (pointer) {
    case int* value    => value ? 1 : 2;
    case double* value => value ? 3 : 4;
    case _            => 5;
  };
}
```

This is static dispatch on `T`. `classify<int>(nullptr)` should select the
`int*` case and bind a null pointer.

Now what should `Circle*` mean when the subject is a `Shape*`?
`dynamic_cast<Circle*>(pointer)` returns null when the object is not a `Circle`,
but it also returns null when `pointer` is null. If that is a successful match,
we enter a `Circle*` case with a null pointer. If it is a failed match, an exact
`Shape*` declaration and a refining `Circle*` declaration behave differently
for null despite looking the same. In a template, the same pattern could also
change from static type selection to a nullable runtime test as `T` changes.

We therefore do not perform polymorphic refinement from one pointer type to
another. Pointer declarations keep their ordinary exact-match behavior. To
inspect the pointee's runtime type, first match the non-null state and then
match the resulting object:

```cpp
void inspect(Shape* shape) {
  match (shape) {
    case {}                  => null_shape();
    case { Circle& circle }  => draw_circle(circle);
    case { Square& square }  => draw_square(square);
    case { Shape& unknown }  => draw_unknown(unknown);
  }
}
```

The braces above only perform the pointer's null/non-null projection.
`Circle&` then matches the resulting `Shape&` using the ordinary polymorphic
object rule. There is no special pointer-plus-polymorphism operation. If the
pointer is itself stored inside another choice, both projections are visible:

```cpp
variant<Shape*, int> value;

match (value) {
  case { { Circle& circle } } => draw_circle(circle);
  case { int integer }        => use(integer);
  case _                     => other();
}
```

For a known `Shape*` subject, a bare `Circle*` pattern is not an exact match and
is ill-formed. In a dependent match it follows the general rules for a
potentially applicable declaration case; it does not acquire pointer-downcast
semantics:

```cpp
template<class T>
int inspect_pointer(T* pointer) {
  return match (pointer) {
    case Circle* circle => 1;
    case _             => 0;
  };
}

Circle circle;
inspect_pointer(&circle);                    // 1: exact Circle* declaration
inspect_pointer(static_cast<Shape*>(&circle)); // 0: no pointer downcast
```

This difference is intentional. `{ Circle& }` asks about the runtime type of
the pointee. References do not have the null problem because a reference always
denotes an object.

## Choice Projection

Without a projection marker, this declaration is ambiguous in intent:

```cpp
variant<int, string> value;
case auto&& selected
```

It could bind the `variant` or its active payload. This paper gives it only the normal
declaration meaning: it binds the `variant`. Braces enter the choice:

```cpp
case auto&& whole       // the variant object
case { auto&& payload } // the active payload
```

The same rule applies to structure:

```cpp
variant<int, tuple<int, int>, pair<int, int>, array<int, 2>> value;

match (value) {
  case { int integer }       => scalar(integer);
  case { [int x, int y] }    => coordinates(x, y);
  case auto&& whole          => inspect_unmatched_choice(whole);
}
```

It would be too surprising for `[int x, int y]` to decompose the whole object
for one subject type but silently enter a choice for another.

## Closed Choices

For a closed choice, `{ P }` considers every projectable state for which `P` is
viable. At runtime, it tests the active state and uses the corresponding case
instantiation.

A pattern may cover more than one index:

```cpp
variant<int, int> value;

match (value) {
  case { const int& integer } => use(integer); // covers both indices
}
```

Qualification adjustments can also make one declaration apply to several
alternatives. Usefulness is checked against the actual indices and nested value
patterns, not just the type written in the source.

`{ auto&& value }` is the generic case. Its declaration, guard, and handler are
checked separately for every remaining alternative type.

## Named and Non-Projectable States

Named projection chooses an advertised state before matching its projection:

```cpp
expected<int, Error> result;

match (result) {
  case { .value: int value }    => use(value);
  case { .error: Error& error } => report(error);
}
```

`{}` matches a state that has no value to project:

```cpp
optional<int> value;

match (value) {
  case { int integer } => use(integer);
  case {}              => empty();
}
```

The `.name:` spelling is only available inside braces. A bare `name: P` would
make ordinary identifier lookup unexpectedly inspect a trait. The leading dot
also leaves `[.x: P, .y: Q]` available for future named aggregate
decomposition.

`expected<T, E>` is modeled as value/error, not value/empty. Both states are
projectable, including a `void` projection for `expected<void, E>`.

Raw pointers have a built-in null/non-null choice model:

```cpp
match (pointer) {
  case { Widget& widget } => use(widget);
  case {}                 => absent();
}
```

`nullptr` and `nullopt` retain ordinary value-pattern syntax. A closed
specialization can identify either value as the canonical label of an
advertised state. Such a pattern tests the saved discriminator rather than
calling `operator==`, and participates in exhaustiveness analysis. The pointer
and `optional` models do so: `nullptr` and `{}` cover the same pointer state,
and `nullopt` and `{}` cover the same optional state.

The rare valueless state of `variant` has no projection syntax and is not
required for exhaustiveness. Code that cares about it can test the whole object
first:

```cpp
match (value) {
  case auto&& whole if (whole.valueless_by_exception()) => recover();
  case { auto&& alternative } => use(alternative);
}
```

## Open Choices and `any`

An open choice such as `any` cannot enumerate all of its possible types. It
still uses braces to make the runtime access explicit:

```cpp
any value;

match (value) {
  case { int integer }       => use(integer);
  case { const string& text } => print(text);
  case { _ }                 => unknown_nonempty();
  case {}                    => empty();
}
```

A bare `case int integer` does not look inside the `any`; it matches the `any`
object itself. `{ auto&& value }` is ill-formed because there is no C++ type for
a binding to an arbitrary value stored in an `any`.

# The `alternative_traits` Protocol

We need one protocol for closed choices such as `variant` and another form of
the same protocol for open choices such as `any`. The name
`alternative_traits`, as well as some of its member names, remains open to
change.

The declarations are available only when pattern matching is enabled. In the
prototype, `-fpattern-matching` implies reflection. Enabling reflection alone
does not expose `alternative_traits` or its standard-library specializations.

## Closed Indexed Protocol

```cpp
template<class T>
struct alternative_traits;

struct alternative_info {
  meta::info info = {}; // null, a type, or a constant value
  bool empty = false;

  consteval alternative_info() = default;

  consteval alternative_info(meta::info r, bool empty = false)
    : info(meta::is_type(r) ? r : meta::constant_of(r)), empty(empty) {
    if (meta::is_type(r) && empty)
      throw "a typed alternative cannot be empty";
  }
};

template<>
struct alternative_traits<choice> {
  static constexpr alternative_info alternatives[] = {
    /* one descriptor per advertised state */
  };

  // Required for a closed protocol.
  static constexpr bool has_residual_states = false;

  enum class state : size_t { value = 0, error = 1 };

  static constexpr state index(choice const&) noexcept;

  template<state Selector, class Self>
    requires /* the selected state is projectable */
  static constexpr decltype(auto) get(Self&&);
};
```

The rules are:

- The bound of `alternatives` advertises a finite state set. Array element `I`
  describes state `I`.
- A non-null `alternatives[I].info` reflects either the declared
  alternative type or a canonical constant value for state `I`. A type
  reflection is used by `{ T: P }` and type-constraint selectors and requires
  the selected `get(subject)` to provide a compatible projection. The
  reflected type can be `void`. A value reflection covers the whole state and
  is also the preferred missing-case witness.
- A value pattern whose canonical constant value is the value advertised for
  state `I` tests whether the cached discriminator identifies state `I`; it
  does not invoke `operator==`.
  If several states advertise the same canonical value, the pattern tests
  membership in that set of indices and covers every such state. No
  relationship between `operator==` and `index` is required.
- A value pattern not represented by an advertised value retains its ordinary
  `subject == pattern` semantics. It does not cover an advertised state for
  exhaustiveness analysis, even if that comparison happens to return `true`
  for values in the state.
- `alternatives[I].empty` states that `{}` covers state `I`.
- The reflection cannot simultaneously describe both a type and a value. An empty
  state cannot have a type selector or a projection. A value selector can also
  mark an empty state, as for `nullopt`, but a value-selected state cannot have
  a projection.
- `index(subject)` identifies the active state and is `noexcept`. Its result
  can be an integral or enumeration type, or a provider-defined discriminator
  type that supports parameterized names.
- An advertised state may omit its selector, empty marker, and projection. It
  can still be selected if the provider gives it a name, including a
  parameterized name such as `.index<0>`.
- The selected `get` has the precondition that `index(subject) == I` and
  preserves the subject's cv/ref category as defined by the specialization.
- `has_residual_states == true` means runtime states can exist outside the
  advertised set. Those states are residual rather than required.
- A named selector is looked up by applying the corresponding member access to
  the saved discriminator. The selected member is a constant index into
  `alternatives`. Because C++ does not permit member access on an enumeration,
  an enumeration discriminator is handled specially: `.name` instead looks up
  the enumerator `name` in the discriminator type and uses its underlying
  value. An integral discriminator provides no named selectors.
- Parameterized names use the same rule. For example, `.index<I>` accesses
  `discriminator.index<I>`. A provider-defined discriminator class therefore
  exposes only the parameterized names that it intends to support.
- A named projection that selects state `I` uses the same `get` operation as
  every other spelling of that state.
- Every successful projection selector for the same state denotes the same
  logical projection. This permits implementations to reuse a projected value
  across arms regardless of whether the arm selected the state by a plain or
  parameterized name, type, or another selector.

The implementation can save the discriminator and call `get` only after
selecting `I`. A standard-library specialization can therefore use a private,
unchecked operation without adding another public API.

## Standard Models

| Subject | Model | Required states | Residual state |
|---|---|---|---|
| `T*` | built-in closed choice | null, non-null | none |
| `optional<T>` | closed choice | empty, value | none |
| `expected<T, E>` | closed named choice | value, error | none |
| `variant<Ts...>` | closed indexed choice | every declared index | valueless |
| `any` | open type-indexed choice | empty and unknown non-empty remainder | none |
| comparison category | closed value choice | every distinct result | none |
| `chrono::month` | closed value choice | the twelve named months | invalid values |
| `chrono::weekday` | closed value choice | the seven named weekdays | invalid values |

Raw pointers use built-in language semantics. We still provide an
`alternative_traits<T*>` specialization so that a smart pointer with exactly
the same state mapping can explicitly reuse it. Merely looking pointer-like
does not opt a user-defined type into an exhaustive two-state promise.

If a polymorphic class also provides `alternative_traits`, syntax selects the
operation rather than an implicit precedence rule: a bare class declaration
performs object refinement, while `{ P }` enters the advertised choice view.

`variant` uses its index and an unchecked projection whose precondition is the
selected index. `optional` advertises empty index 0 and value index 1.
`expected` advertises value index 0 and error index 1. A named binary choice
can use a `bool`-backed enumeration as its index type.

The built-in pointer behavior is equivalent to the following specialization.
Again, the specialization exists for explicit reuse; the compiler does not
need it to recognize a raw pointer:

```cpp
template<class T>
struct alternative_traits<T*> {
  static constexpr alternative_info alternatives[] = {
    {meta::reflect_constant(nullptr), /*empty=*/true},
    ^^T,
  };
  static constexpr bool has_residual_states = false;

  enum class state : bool { empty = false, value = true };

  static constexpr state index(auto const& value) noexcept {
    return value ? state::value : state::empty;
  }

  template<state Selector, class Self>
    requires (Selector == state::value)
  static constexpr decltype(auto) get(Self&& self) noexcept {
    if constexpr (is_void_v<T>)
      return;
    else
      return *std::forward<Self>(self);
  }

};

template<class T>
struct alternative_traits<optional<T>> {
  static constexpr alternative_info alternatives[] = {
    {^^nullopt, /*empty=*/true},
    ^^T,
  };

  enum class state : bool { empty = false, value = true };

  static constexpr state index(optional<T> const& value) noexcept {
    return value.has_value() ? state::value : state::empty;
  }

  template<state Selector, class Self>
    requires (Selector == state::value)
  static constexpr decltype(auto) get(Self&& self) noexcept {
    return *std::forward<Self>(self);
  }
};
```

The pointer specialization templates the parameter of `index` so that a smart
pointer with the same state mapping can inherit the implementation. For a
non-void pointee, the return type of `get` comes from dereferencing the actual
subject and therefore preserves cv/ref. For `void*`, the non-null state has
type `void`; `{ void }` selects it without dereferencing the pointer.

`optional` defines its own specialization because its empty state is spelled
`nullopt`. An ordinary `case 0` still asks whether an engaged `optional<int>`
contains zero.

`expected` advertises two projectable states, including `void` for a successful
`expected<void, E>`:

```cpp
template<class T, class E>
struct alternative_traits<expected<T, E>> {
  static constexpr alternative_info alternatives[] = {^^T, ^^E};
  static constexpr bool has_residual_states = false;

  enum class state : bool { value = false, error = true };

  static constexpr state index(expected<T, E> const& value) noexcept {
    return value.has_value() ? state::value : state::error;
  }

  template<state Selector, class Self>
  static constexpr decltype(auto) get(Self&& self) {
    if constexpr (Selector == state::value)
      return *std::forward<Self>(self);
    else
      return std::forward<Self>(self).error();
  }
};
```

Both names provide a `state` value. `{ .value: P }` projects the value and
`{ .error: P }` projects the error. `expected` does not expose `.index<I>`;
its state names are the better interface.

Variant advertises every declared index, exposes those indices through the
parameterized name `.index<I>`, and has a residual valueless state:

```cpp
template<class... Types>
struct alternative_traits<variant<Types...>> {
  static constexpr alternative_info alternatives[] = {
    ^^Types...,
  };
  static constexpr bool has_residual_states = true;

  struct state {
    size_t value;

    template<size_t I>
    static constexpr size_t index = I;

    constexpr operator size_t() const noexcept { return value; }
    friend constexpr bool operator==(state, state) = default;
  };

  static constexpr state index(variant<Types...> const& value) noexcept {
    return {value.index()};
  }

  template<size_t I, class Self>
  static constexpr decltype(auto) get(Self&& self) noexcept {
    return /* unchecked projection of alternative I */;
  }
};
```

`.index<I>` exists because `variant`'s discriminator provides the variable
template `index<I>`, not because positional selection is implicit in every
`alternative_traits` specialization. The unchecked operation is
exposition-only. Since the language has already checked and saved the index,
the standard-library specialization can use private unchecked access without
adding a new public `variant` API.

Names do not introduce a second state machine. Plain names can be enumerators
in the discriminator type returned by `index`, and a type that wants synonyms
defines them directly:

```cpp
enum class state : size_t {
  value = 0,
  some = 0,
  error = 1,
  empty = 1,
};
```

Because these names denote the same indexed states, usefulness,
exhaustiveness, and projection treat them identically:

```cpp
enum class state : bool {
  value = false,
  error = true,
  empty = true,
};

match (state_value) {
  case state::value => ...;
  case state::error => ...;
  case state::empty => ...; // error: redundant
}
```

The first two arms are exhaustive because the enum's full value range is
`false` and `true`. Replacing `error` with `empty` has the same coverage.

The same applies to named selectors. Both `.error` and `.empty` select state 1,
so `{ .empty }` makes a later `.error` arm redundant. Either name can select
the state without projection or select its projection with `: P`. `expected`
avoids the misleading synonym and exposes only `value` and `error`.

## Open Type-Indexed Protocol

An open choice omits `size`:

```cpp
template<>
struct alternative_traits<any> {
  template<class T, class Self>
  static auto try_cast(Self&& self) noexcept;

  static bool has_value(any const&) noexcept; // optional
};
```

For `{ T value }`, matching calls
`try_cast<remove_cvref_t<T>>(subject)`. A null result is a non-match. The
successful result is forwarded like the subject and then used to initialize
the declaration.

`has_value` enables `{}` for empty and `{ _ }` for the unknown non-empty
remainder. Without `has_value`, `{}` is ill-formed.

# Templates and Case Instantiation

## Strict Single-Pattern Tests

For a viable pattern, `match(E, case P)` has the same value as:

```cpp
match (E) {
  case P  => true;
  case _ => false;
}
```

This is not a source transformation. If `P` is invalid, the single-pattern
test is ill-formed. A dependent selection with several cases can instead omit
a case that does not apply to one specialization.

This separates two questions:

```cpp
requires { match(E, case P); } // is P viable?
match(E, case P)               // given viability, does this value match?
```

An irrefutable valid pattern always produces `true`, but it still evaluates
its subject and any projections or declarations. The requires-expression does
not.

## Dependent Case Matching

A source case can apply in one specialization and not another:

```cpp
template<class V>
int classify(V value) {
  return match (value) {
    case { int }    => 0;
    case { string } => 1;
    case { char }   => 2;
  };
}
```

For `variant<int, string>`, the `char` case is not instantiated. It remains
maybe useful because another specialization could contain `char`. The same
case on a non-dependent `variant<int, string>` is ill-formed because it cannot
match anything.

Reference binding can similarly make a case apply only in some
specializations:

```cpp
template<class T>
int classify(variant<T> value) {
  return match (std::move(value)) {
    case { T& reference } => 1;
    case _               => 2;
  };
}
```

For an ordinary `variant<T>`, projecting from `std::move(value)` produces
`T&&`. The `T&` case is omitted and `classify(variant<int>{42})` returns `2`.
This is the same result as the corresponding visitor:

```cpp
return std::visit(
    overload{
        [](T&) { return 1; },
        [](auto&&) { return 2; },
    },
    std::move(value));
```

Removing the fallback makes both forms ill-formed when instantiated. For
`match`, the remaining cases do not cover the required variant alternative.
For `visit`, the visitor is not invocable with `T&&`.

This does not mean that the case is generally useless for an rvalue choice.
In C++26, `optional<T&>` is valid and dereferencing it produces `T&` even when
the `optional` itself is an rvalue:

```cpp
template<class T>
int classify(optional<T> value) {
  return match (std::move(value)) {
    case { T& reference } => 1;
    case _               => 2;
  };
}

int value = 42;
classify(optional<int>{42});     // 2
classify(optional<int&>{value}); // 1
```

Some dependent patterns are nevertheless provably useless. A built-in array
has a fixed, non-customizable decomposition arity:

```cpp
template<class T>
int classify(T (&value)[2]) {
  return match (value) {
    case [T first, T second, T third] => 1;
    case _                           => 2;
  };
}
```

No substitution can make this three-element pattern match the two-element
array. The prototype currently calls it maybe useful because it is dependent.
Whether we should require this diagnostic remains an open question. We cannot
infer the same answer for `variant<T>` without making assumptions about
possible specializations and their projection behavior.

Exhaustiveness is checked for each concrete specialization:

```cpp
constexpr size_t arity(auto value) {
  return match (value) {
    case auto&& [...elements] => sizeof...(elements);
  };
}

static_assert(arity(tuple(1, 2)) == 2);
// arity(0); // error: the instantiated match is not exhaustive
```

## Implicit Template Regions

A generic projected case is instantiated once for each remaining alternative:

```cpp
variant<int, string> value;

match (value) {
  case { auto&& alternative } => use(alternative);
}
```

The declaration, guard, and handler form an implicit template region. Each
instantiation separately handles result deduction, `decltype`, constraints,
local statics, diagnostics, and structured-binding packs.

An earlier unguarded irrefutable semantic case closes only its own domain and
prevents later handlers for that domain from being instantiated:

```cpp
variant<int, string, vector<int>> value;

auto result = match (value) {
  case { int integer } => integer;
  case { auto&& data }  => static_cast<int>(data.size());
};
```

The second handler is instantiated for `string` and `vector<int>`, not for
`int`. This gives us the useful instantiation behavior of an overloaded visitor
without turning the cases into an overload set.

Whether a handler is instantiated depends on earlier individual irrefutable
cases, not on a combination of several refutable cases. Usefulness can still
diagnose the later case as redundant, but it does not retroactively suppress
that handler's instantiation.

# Exhaustiveness and Usefulness

Non-exhaustiveness and redundancy are hard errors, not optional warnings:

```cpp
bool value;

match (value) {
  case true => yes();
}; // error: example of a missing case: false
```

```cpp
match (value) {
  case true  => yes();
  case false => no();
  case _    => impossible();
}; // error: redundant case
```

Guarded cases are useful but do not contribute coverage because their guards
can fail.

The prototype uses the Maranget/Rust pattern-matrix algorithm. The
standard should specify the observable behavior rather than refer to one
implementation algorithm. A case can be:

- useful;
- maybe useful because dependence or opacity prevents a final answer; or
- not useful.

"Maybe useful" is the conservative answer for dependent and open cases.

## Required and Residual Domains

Required states must be covered for exhaustiveness. Residual states participate
in usefulness but are not required.

- `bool` requires `true` and `false`.
- integer types require their full value domain.
- an enum requires each distinct declared enumerator value. Other legal values
  in its underlying range are residual unless explicit constants cover them.
- `variant` requires each advertised index; valueless-by-exception is residual.
- exhaustive closed traits such as `optional` and `expected` require every
  advertised state and have no residual state.
- an open choice requires coverage of its unknown non-empty remainder and, if
  advertised, its empty state.

For an enum whose enumerators cover its full legal range, a trailing wildcard
is redundant. Otherwise it remains useful for unnamed values even after every
enumerator is covered.

Diagnostics should print source-like example witnesses:

```text
false
{ string }
{ false }
{}
[{ int }, false]
```

The word "example" is important for domains where the witness is not the only
missing value.

# Evaluation Model

## Subject and Lifetime

- The subject expression is evaluated exactly once.
- An lvalue subject continues to denote the original object.
- A prvalue subject is materialized in hidden storage.
- Its original value category is retained for projections.
- In a match expression, the hidden subject survives through the containing
  full-expression. In a match statement it survives through the statement.
- In a pattern condition, the hidden subject survives through the controlled
  statement, including the `else` path, using the same lifetime-extension
  machinery as condition variables and C++23 range-for.

A match case does not introduce a function-return boundary. A selected
reference result is diagnosed according to how the complete match expression
is used.

## Pattern Tests and Declarations

Cases are attempted in source order. Within one attempted case:

1. Refutable child tests run in source order with short-circuiting.
2. After the complete pattern succeeds, declaration bindings initialize in
   source order.
3. The guard init-statement and condition are evaluated.
4. On success, the handler is evaluated.
5. On guard failure, case-local declarations are destroyed and matching
   continues.

This prevents an early by-value declaration from moving out of the subject
before a later child establishes that the complete pattern matches:

```cpp
match (std::move(subject)) {
  case [Widget value, 0] => use(value);
  case _                => fallback();
}
```

If the second component is not zero, `value` is not initialized.

A failed guard does not undo side effects. However, a guarded declaration
pattern is ill-formed if its initialization invokes a non-trivial move
constructor. This rule applies equally when the declaration's identifier is
omitted. Otherwise, merely testing a case could consume the subject before
matching continues with the next case:

```cpp
match (std::move(value)) {
  case Widget owned if (owned.satisfies()) => use(std::move(owned)); // error
}
```

The spelling that tests before consuming is explicit:

```cpp
match (std::move(value)) {
  case Widget&& candidate if (candidate.satisfies()) =>
      use(Widget(std::move(candidate)));
}
```

Copies, reference bindings, scalar initialization, and trivial moves remain
valid in guarded declaration patterns. Non-trivial moves remain valid in
unguarded arms, where successful pattern selection cannot continue to a later
arm.

## Projection Reuse

We do not want the abstract machine to require repeated discrimination and
projection. An implementation can retain or recompute equivalent operations
within one match, including:

- closed-choice discriminators and selected projections;
- tuple-like `get<I>`;
- open-choice `try_cast<T>` and `has_value`;
- polymorphic runtime refinement and its adjusted pointer.

Expression comparisons for unadvertised values, declaration initializations,
and guards are still evaluated at each source occurrence. Advertised value
patterns are discriminator tests, so they participate in the same
discriminator reuse as braced alternative patterns. Operations used only by a
later case cannot be evaluated before that case is reached.

A failed guard does not require the implementation to throw away a saved
projection. If a guard modifies the subject, a later projection can be reused
or recomputed. Code that invalidates a saved reference has the usual C++
consequences.

We require `index(subject)` for a closed specialization to be `noexcept`. This
lets an implementation save the discriminator and lower the match to a switch
or decision tree. We do not specify the lowering.

## Unmatched Execution

Exhaustiveness normally rules out unmatched required states. We still need a
rule for residual states:

- an unmatched void-yielding match falls through;
- an unmatched non-void match terminates;
- an unmatched execution cannot succeed during constant evaluation.

This handles `variant::valueless_by_exception()` without forcing that rare
state into the ordinary projection syntax.

# Result Types and `match constexpr`

The handlers used by one specialization need a consistent result type unless
an explicit trailing return type supplies the conversion target. A `not
return` handler and a handler discarded by `match constexpr` do not
participate in deduction.

```cpp
constexpr auto result(auto value) {
  return match (value) {
    case int integer   => integer;
    case string& text  => text.size();
    case _ => static_assert(false, "unsupported type");
  };
}
```

The assertion is instantiated only for a specialization not closed by an
earlier unguarded irrefutable case.

`match constexpr` requires the selected pattern tests and guards to be constant
expressions. Like `if constexpr`, it discards the unselected handlers. It does
not make an invalid pattern into a failed match.

# Design Decisions and Alternatives Considered

## Why a Selection Has a Declaration Preamble

Cases often need names that are useful only within that selection. Without a
preamble, we have to repeat those declarations or put them in a wider scope.
Enumerator imports are the most direct example:

```cpp
match (token.kind()) {
  using enum token_kind;
  using result_type = parse_result;
  static_assert(sizeof(result_type) <= 2 * sizeof(void*));

  case identifier => result_type::identifier();
  case number     => result_type::number();
  case _         => result_type::invalid();
}
```

We allow namespace aliases, type aliases, using declarations, using directives,
and `static_assert`. These affect compile-time interpretation and require no
runtime execution when control enters the selection. The preamble gives them
the narrowest useful scope while making the names available to every guard and
handler.

All preamble declarations come before the cases. Allowing declarations between
cases would make visibility depend on case order even though control does not
flow from one case to the next. Putting them first gives every case the same
environment and leaves case order relevant only to matching.

We do not allow ordinary object declarations. If we did, we would have to say
whether initialization happens before or after subject evaluation, whether it
happens when no case can match, and how the object's lifetime interacts with a
selected handler or an escaping statement:

```cpp
match (value) {
  Widget helper = make_helper(); // not a preamble declaration
  case P => use(helper);
}
```

Such state can already be declared in the enclosing block. A name-only preamble
also avoids creating a second init-statement mechanism with different
control-flow rules.

We also leave `consteval` blocks out of R6. They permit much more than
introducing names or checking an invariant, and we do not yet have a
match-specific use that justifies importing their statement and scope rules.

## Why a Prefix Selection Has Statement and Expression Forms

R5 used one postfix expression form. Even when its result was discarded, that
form still performed result deduction, diagnosed unused handler values, and
required a semicolon after a braced construct:

```cpp
value match {
  case 0 => zero();
  case _ => other();
};
```

R6 gives the prefix form a contextual split instead. At the start of a
statement it has an implicit `-> void`; the right operand of each `=>` is an
ordinary statement and the closing brace needs no semicolon:

```cpp
match (value) {
  case 0 => zero();
  case _ => other();
}
```

In an expression-only context it is a selection expression with normal
result-type deduction:

```cpp
int result = match (value) {
  case 0 => 1;
  case _ => 2;
};
```

This is more than punctuation. Statement-oriented code can use handlers with
unrelated expression types without manufacturing a common result. The cost is
that context determines whether the same prefix begins a statement or an
expression. [Parsing] describes that distinction and how we preserve ordinary
declarations and calls named `match`.

The corresponding single-pattern Boolean test is
`match(subjects..., case P)`. It uses the same subject and pattern rules as a
selection and does not introduce a separate `is` expression.

## Why Statement Handlers Use `=> statement`

A selection statement can use the ordinary *statement* grammar directly for
its handlers:

```cpp
match (value) {
  case 0 => {
    first();
    second();
  }
  case 1 => if (ready()) proceed(); else wait();
  case _ => return;
}
```

This avoids a growing list of special handler forms. Declarations, compound
statements, control statements, and `static_assert` all work without involving
result-type deduction. Expression selections retain their narrower,
result-producing handler grammar.

The most plausible alternative is to distinguish the two forms with `:`:

```cpp
match (value) {
  case 0: {
    first();
    second();
  }
  case 1: return;
  default: ;
}
```

That spelling makes the statement grammar visible and resembles `switch`,
Python, and Swift. It also avoids using `=>` for two grammatically different
operands.

We nevertheless propose `=> statement`. A colon in C++ strongly suggests
`switch` semantics: fallthrough, stacked labels, and a construct targeted by
`break`. A match arm has none of those properties. Arms never fall through,
or-patterns replace stacked labels, and an unlabelled `break` in a handler
continues to target an enclosing loop or `switch`. The colon also becomes
visually dense next to alternative selectors:

```cpp
case { .value: int value }: consume(value);
```

Using `=>` keeps the arm boundary and non-fallthrough meaning uniform between
statement and expression selections. It also lets an arm be moved between the
two forms without changing its separator. The tradeoff is that the grammar to
the right of the same token depends on whether the enclosing selection is a
statement or an expression. That dependence already exists for the selection
itself and is explicit in [Syntax Overview].

A handler is a protected control-flow entry. A `goto` or enclosing `switch`
cannot jump directly to a label inside a handler and bypass pattern selection.
Jumps out perform ordinary cleanup. An unlabelled `break` or `continue` keeps
its normal target outside the match.

## Why `not return` Is Part of an Expression Handler

A non-returning expression arm should not participate in result-type
deduction:

```cpp
return match (status) -> int {
  case fatal => not return std::terminate();
  case _     => 42;
};
```

`not return` is a handler action, parallel to `return expression`. In the
grammar it is spelled `! return expression`, following the `if ! consteval`
precedent established by [@P1938R3]. The expression is evaluated as a
discarded-value expression; completing normally has undefined behavior.

The action follows `=>` because it describes only the selected handler. An
attribute before `case` would appear to describe the whole arm, including a
pattern or guard that can fail. `[[noreturn]]` would additionally make an
essential type-system property look like an ignorable attribute.

An exception-enabled workaround is `throw (std::terminate(), 0)`: the throw
expression contributes no result type, while the comma expression supplies an
otherwise unreachable operand. This is both obscure and unavailable under
`-fno-exceptions`. The general diverging-expression model in [@P3549R0] is the
better solution. `not return` is deliberately provisional and should be
removed if P3549 is adopted for C++29.

## Why Selection Cases Require `case`

R5 allowed a pattern to begin a case directly. We now require `case`. It gives
the parser a reliable recovery point, distinguishes case attributes from
declaration-pattern attributes, and makes empty and statement handlers easier
to parse. It also leaves more room to extend the pattern grammar later.

It also aligns the selection form with `switch` while retaining source-ordered
pattern semantics.

## Expressions as Patterns and `_` as the Wildcard

This paper retains `_` as the wildcard spelling. This follows [@P2392R2] and the broad
language precedent in Python, Rust, Scala, Swift, C#, Erlang, Prolog, Haskell,
OCaml, and others. [@P1371R3] used `__`, following [@P1110R0], while
[@P1469R0] proposed restricting `_` as an identifier in structured bindings.

The wildcard remains distinct from a C++26 placeholder variable:

```cpp
match (value) {
  case _      => ignore_without_initialization();
  case auto _ => initialize_an_unnamed_object();
}
```

The special interpretation means that a bare `_` cannot refer to an outer
variable in pattern position:

```cpp
int _ = 42;

match (value) {
  case _ => always_matches();
}
```

An ordinary expression can still perform that comparison through a guard:

```cpp
match (value) {
  case auto&& current if (current == _) => equal_to_outer_underscore();
  case _ => different();
}
```

I believe this is a small cost for using the wildcard spelling that everyone
expects.

## Why Expressions Are Patterns

Without expression patterns, the facility could not replace even the simplest
`switch`. Restricting the syntax to literals would still exclude named
constants and enumerators:

```cpp
enum class color { red, green, blue };
constexpr int protocol_version = 7;

match (value) {
  case color::red        => handle_red();
  case protocol_version  => handle_current_version();
  case _                => fallback();
}
```

Once literals, unqualified names, qualified names, and constant expressions
are allowed, we have to distinguish an expression that refers to an existing
name from a declaration that introduces a new one. This paper does not make a
bare identifier introduce a binding. Expressions and declarations keep their
ordinary C++ meaning.

Expression patterns also provide a constrained predicate facility. We try
equality first and invoke the pattern only when equality is unavailable.
This ordering matters because generic call operators are frequently
unconstrained: an invocation expression can appear well-formed even when
instantiating its body would fail. It also ensures that adding callability to
an equality-comparable value does not change the meaning of existing patterns.

Both operations are meaningful for a few types. For example,
`reference_wrapper<F>` can compare with `F` and invoke `F`. Such a pattern uses
equality. A lambda or a declaration pattern with a guard requests predicate
semantics unambiguously.

## Why Declarations Instead of `let`

R5's `let` provided a simple binding model. But "why does C++ need `let`?" was
by far the most common first question. C++ declarations
already express copies, moves, references, forwarding, constraints, and
`decltype`, and those distinctions matter when binding a pattern.

Declaration patterns are more familiar:

```cpp
case const string& text
case auto&& value
case std::integral auto integer
```

This comes with more rules. We have to specify copying, moving, reference
binding, deleted constructors, explicit constructors, and conversions. I
believe that is better than introducing a second binding language for C++.

This requires answering a few questions that `let` avoided.

First, `auto value` binds the current subject, not an implicitly selected
payload:

```cpp
variant<int, string> value;

match (value) {
  case auto&& whole       => inspect(whole);
  case { auto&& payload } => inspect(payload);
}
```

The first case makes the second unreachable. The point is that braces, not the
declaration's spelling, request choice projection.

Second, declarations use source-ordered first-match semantics rather than
forming an overload set. Conversion-ranked initialization would make this
surprising:

```cpp
variant<int, double> value;

match (value) {
  case { int integer } => use(integer);
  case { double real }  => use(real);
}
```

If arbitrary conversions were admitted, the `int` declaration could consume a
`double` and make the second case dead. This paper instead uses the exact-match
rank and lets usefulness analysis diagnose domination among the conversions
that remain.

Third, a by-value declaration really copies or moves. `auto value` copies an
lvalue and moves from an rvalue. `auto&& value` is the forwarding spelling. A
guarded declaration cannot invoke a non-trivial move constructor before testing
the guard; bind a reference and move in the handler instead.

## Why Choice Projection Is Explicit

A declaration pattern should have one meaning. Given
`variant<int, string> value`, `auto&& selected` cannot simultaneously mean
"bind the variant" and "bind whichever alternative is active." R6 makes the
projection visible:

```cpp
case auto&& whole       // bind the variant
case { auto&& payload } // bind the active alternative
```

The same distinction applies recursively. `[int x, int y]` decomposes its
current subject; `{ [int x, int y] }` first enters a choice and then decomposes
the selected payload. This keeps every nested pattern independent of how its
subject was obtained.

R5's `? P` combined a nullable test and dereference. R6 replaces it with
`{ P }` and `{}`, using the same choice model as `variant` and `expected`.
R5's unbraced `T: P` becomes `{ T: P }`. The braces perform choice selection,
`T` selects an advertised type, and `P` matches the projection. Variant's
`.index<I>` is the corresponding opt-in escape hatch for duplicate types.

Braces are required for open choices such as `any` as well. Otherwise an
ordinary-looking `int value` could silently perform a type-erased runtime
operation. Polymorphic classes are different: a derived object is the same
object denoted by the base reference, not a separately stored payload.

We considered making selected states transparent to value patterns. That
would make this exhaustive:

```cpp
match (optional_bool) {
  case true         => yes();
  case false        => no();
  case std::nullopt => empty();
}
```

The required promise is not uniform. It works for `optional`, but pointer
equality compares addresses rather than pointees, and an `expected` error
would require a transformation between `unexpected<E>` and `E`. The explicit
form remains `{ true }` and `{ false }`.

We also considered treating cases as an overload set or providing one implicit
`as` operation for testing, conversion, and binding. Either admits surprising
conversions: an `int` case could consume a `double` alternative before the
later `double` case. R6 uses source-ordered first match and exact-match
declaration conversions. Usefulness analysis diagnoses a dominated case.

## Why Non-Viability Is Not `false`

We considered making an invalid dependent single-pattern test evaluate to
`false`. This is convenient for shape detection, but combines two questions:

- can the operation be formed?
- does this runtime value match?

C++ normally answers the first with `requires` and the second with a Boolean
expression. We keep those questions separate. This also prevents a typo in a
required pattern condition from silently selecting `else`.

An explicit `match requires` mode was also considered. It makes generic
structural dispatch convenient, but gives us two nearly identical forms of
`match`. It also does not remove the need to distinguish an inapplicable case
from a selected declaration whose initialization is invalid. We keep
single-pattern tests strict and handle dependent selection cases separately.

This changes the strict static-condition rule explored in R5. That rule caught
mistakes such as a string literal in a character match:

```cpp
template<class Operator>
void evaluate(const Operator& op) {
  match (op.kind()) {
    case '+' => add();
    case '-' => subtract();
    case "/" => divide(); // probably meant '/'
    case _ => unknown();
  }
}
```

If `op.kind()` is dependent, the `"/"` case does not apply when the result is
`char`. This behavior is needed for generic cases over a dependent choice, but
it does make this typo harder to find. A strict single-pattern test and an
explicit `requires` expression can still ask whether a pattern is valid. We
should discuss whether dependent selections also need an opt-in strict mode.

## Why By-Value Patterns Remain Permitted

Allowing only reference declarations would simplify failed cases and permit
more projection reuse. It would also prevent a case from naturally consuming
its subject. We keep by-value declarations. We reject a non-trivial move before
a guard because a failed guard would expose the moved-from subject to later
cases. Such a case can bind a reference and move in the handler instead.

## Why Guards Require Parentheses

Without delimiters, a guard such as:

```cpp
match(value, case [int x, int y] if (x == y))
```

would require another unparenthesized boundary between a pattern and an
arbitrary condition. Requiring parentheses makes the boundary explicit:

```cpp
match (value) {
  case [int x, int y] if (x == y) => equal(x);
  case _ => different();
}
```

It also admits the full condition grammar, including init-statements and
condition declarations, without inventing another unparenthesized expression
boundary. The pattern condition uses a different solution:
top-level `&&` separates later conditions, so it does not accept a case-style
trailing guard.

## Multiple Subjects and Single-Pattern Tests

Prefix syntax provides a natural boundary for matching several values:

```cpp
match (first, second) {
  case [0, int value] => use(value);
  case [int value, 0] => use(value);
  case [_, _]         => fallback();
}
```

One subject is matched directly. Several subjects form an unnamed,
exposition-only product whose elements preserve the original value categories.
Every top-level case must therefore be a decomposition pattern, a
structured-binding declaration pattern, or a wildcard, including grouped and
or-pattern combinations of those forms. A declaration such as `auto whole`
cannot expose the unnamed product type.

The subject expressions follow function-argument evaluation: they are
indeterminately sequenced, their order is unspecified, and each is evaluated
exactly once. A bit-field is represented by value because it cannot initialize
a reference member. A pack expansion retains the product interpretation even
when it expands to zero or one element:

```cpp
match (values...) {
  case [auto&& ...elements] => use(elements...);
}
```

An ordinary comma expression remains one subject when parenthesized:

```cpp
match ((first(), second())) {
  case P => action();
}
```

The corresponding Boolean test is:

```cpp
match(value, case P)
match(first, second, case [P, Q])
```

The comma before `case` ends the subject list, and the closing parenthesis ends
the pattern. This gives both sides an explicit boundary:

```cpp
match(value, case A || B) || ready
```

The first `||` is an or-pattern and the second is an ordinary logical
operator. Logical expressions used as value patterns remain explicit, for
example `match(value, case bool(A || B))`.

R5 instead used the postfix test `value match P`. Once `||` became an
or-pattern, `value match A || B` could mean either one pattern or a logical
disjunction. It also needed a new operator precedence and did not extend
naturally to several subjects. Dropping `case` or writing `value match
(case P)` retained those problems.

We also considered `match(value; case P)` and `match(value) { case P }`. The
semicolon is a strong parser boundary but unfamiliar in the common one-subject
form. The handler-less selection looks incomplete and gives braces a second
set of exhaustiveness and result rules. `match(value, case P)` reads like a
function call while `case` remains an unambiguous pattern introducer.

A pattern condition remains a separate facility because it exports bindings
into a controlled statement:

```cpp
if (case int value = input)
  use(value);

bool is_integer = match(input, case int);
```

## The `=>` Separator

[@P2971R2] proposes an implication operator using the same token. If that work
is adopted, `=>` should remain the case separator in the syntactically delimited
match-case context. An implication expression can still be used as a pattern by
parenthesizing it:

```cpp
match (value) {
  case condition => consequence => handler();
  case (condition => consequence) => matched_implication();
}
```

The first line parses as a pattern `condition` followed by an implication
expression handler. This follows the general rule that a rare expression which
conflicts with the pattern boundary can be parenthesized. `->`, `:`, and a new
token such as `~>` were considered, but do not offer a compelling improvement:
`->` has the same issue, `:` is already heavily used by choice names and
labels, and a new token would be unfamiliar.

# Deferred Extensions

R6 deliberately leaves the following facilities for later work. Their syntax
and interaction with bindings should not be fixed accidentally by this paper.

## Relational and Range Patterns

Patterns such as `< 0`, `1..10`, or a general range test would make numeric
classification substantially more expressive. They also raise questions about
open and closed endpoints, floating-point values, overloaded comparisons, and
exhaustiveness. R6 retains ordinary predicate objects for these cases.

## And-, Not-, and Whole-Value Binding Patterns

An and-pattern becomes especially useful with relational patterns, while a
whole-value binding can name a value that also satisfies a nested pattern.
Other languages use forms such as Rust's `name @ P` and OCaml's `P as name`.
The C++ syntax, binding initialization order, and interaction with non-trivial
moves need to be designed together. R6 includes only `||`.

## Named-Member Decomposition

Positional decomposition is awkward when only a few members matter or member
order is not the semantic interface. A future extension could parallel
designated initialization:

```cpp
match (point) {
  case [.x: 0, .y: 0] => origin();
  case [.x: int x, .y: int y] => use(x, y);
}
```

## Static Type Subjects

Static dispatch should use an explicit type or reflection subject rather than
overloading value declaration patterns:

```cpp
match (^^T) {
  case ^^int    => integral_case();
  case ^^double => floating_case();
  case _        => fallback();
}
```

The lookup, constraint, and reflection models should be designed together.

## Extractors and Sequence Patterns

Extractors could permit user-defined structural views that are not naturally
modeled as choices or structured bindings. Dynamic slice and sequence patterns
would similarly extend decomposition beyond statically known arity. Neither is
needed for the product and choice model proposed here.

## Block-Scope Pattern Declarations

R6 does not introduce bindings into the remainder of an ordinary block. Forms
such as these remain possible future directions:

```cpp
auto&& case P = E else { return; }
if case P = E else { return; }
```

The failure path would have to prevent execution from reaching the following
statements. Such a declaration also cannot silently turn the rest of a block
into an implicit template region when its bindings have alternative-dependent
types or include a local pack. Nested structured bindings cover many of the
useful irrefutable cases independently of pattern matching.

## Further Customization

The R6 choice protocol uses reflection to describe states, but runtime
discrimination still uses `index(subject)` and projection uses `get`. A fully
reflection-driven projection protocol remains possible future work.

# Implementation Experience

We have implemented the proposal in Clang. The implementation is available at
<https://github.com/mpark/llvm-project/tree/p2688-pattern-matching> and on
[Compiler Explorer](https://godbolt.org) as
`x86-64 clang (pattern matching - P2688)`{.default}. It is enabled with
`-fpattern-matching`.

## What Is Implemented

- Parsing and AST representation for match expressions, cases, patterns, and
  pattern conditions.
- Declaration, type, value, decomposition, closed/open choice, pointer, and
  polymorphic object patterns, including recursive type and parameterized
  choice selectors such as variant's `.index<I>`.
- Dependent semantic case instantiation and implicit template regions.
- Constant evaluation and runtime code generation.
- Subject evaluation and lifetime extension.
- Multiple-subject products, including dependent packs and preservation of
  each subject's value category.
- Projection reuse, including discriminator caching.
- Structured-binding and subpattern packs.
- Arbitrary statement handlers for selection statements, and result deduction,
  null handlers, `static_assert`, non-returning expression handlers, jump
  actions, and `do` expressions for selection expressions.
- Pattern-matrix exhaustiveness and usefulness diagnostics with source-like
  witnesses.
- CFG and several analysis integrations.

## Implementation Notes

### Parsing Selections and Patterns

The prototype uses one tentative classifier for the prefix `match` form. It
scans the balanced subject list, uses Clang's existing tentative declarator and
type-id facilities only in the ambiguous cases, restores the parser, and then
runs either the ordinary parser or the selection parser normally. Diagnostic
recovery can recognize additional ill-formed match-shaped input without
changing the classification of valid programs.

For a single-pattern test, a top-level comma followed by `case` identifies the
pattern boundary. Nested delimiters are skipped. No binary-operator precedence
or infix parser hook is involved.

Pattern-specific introducers commit directly to pattern parsing. Declarations
use the restricted *type-specifier-seq* and *conversion-declarator* grammar.
The only localized probe is for `[[`, which can begin either an attribute or a
nested decomposition; ordinary nested structured bindings use the same probe.

A production-source survey found no existing Chromium or LLVM statement or
expression with selection-shaped `match (...) { ... }` syntax and no
`match (...) ->` occurrence. LLVM does contain many ordinary functions and
members named `match`; candidate-aware fallback preserves those calls and
their normal diagnostics.

### Source Cases and Case Instantiations

One source case can produce several differently typed case instantiations. The
prototype initially tried to mutate and replay source AST nodes; that model was
fragile under later tree transformations. It now separates source cases from
`MatchCaseInstantiation` objects. The wording needs to describe the resulting
implicit template region without exposing those implementation objects.

The prototype currently represents the multiple-subject product as an
implicit anonymous `CXXRecordDecl` with reference fields, and records its
identity in `Sema` so recursive decomposition can restore each element's value
category. That is sufficient for experimentation, but a production
implementation should use a durable AST representation or marker. The current
registry is not suitable for serialization, module import, or AST cloning in a
different semantic context.

### Lowering Choice Dispatch

At `-O2`, direct matches already become switches, merged destinations, or a
single direct call when the discriminator is known. Unlike `std::visit`, the
language form has no library abstraction barrier that makes this depend on
inlining a visitor implementation.

Ultimately, the frontend should preserve an alternative-dispatch operation
containing the discriminator, unchecked projections, guards, handlers, and
exhaustiveness information. A later lowering can choose:

| Situation | Possible lowering |
|---|---|
| Constant discriminator | Emit only the selected alternative |
| Small dispatch | Direct switch or branch tree |
| Cases sharing behavior | Merge destinations |
| Skewed profile | Hot direct cases plus cold fallback |
| Large unpredictable dispatch | Jump table or outlined thunk matrix |
| Multiple choices | Decision DAG; flatten only profitable products |

The prototype currently lowers through ordinary branches and relies on LLVM
optimization. A dedicated decision-DAG lowering is future work.

### Dynamic Class Matching

Polymorphic declaration patterns must retain the semantics of an ordered
sequence of `dynamic_cast` refinements, including open-world derived classes
and pointer adjustment. The compiler can still reuse repeated targets, derive
a base match from a successful more-derived match, use final-class fast paths,
and employ LTO or profile-guided caches while preserving those semantics.

### Caching Discriminators and Projections

A discriminator can often be shared more broadly than a projected object. In
a product match, a sibling choice index may be independent of an earlier
alternative selection, while its projected reference is created only inside a
particular dominated branch. The prototype therefore distinguishes cache
identity for discriminators from cache identity for selected projections.

## What Remains

- Polymorphic refinement does not yet implement every valid cross-cast.
- Modules and complete tooling support remain deferred.
- Some direct loop conditions that require case instantiation are still more
  restricted than `if`.
- The `alternative_traits` model for C++26 `optional<T&>` still needs to
  preserve its reference projection without forming a pointer-to-reference.
- Debug information and AST presentation for synthetic declarations and
  implicit template regions need production-quality design.
- The current lowering does not preserve a first-class match decision DAG into
  LLVM IR.

# Open Design Questions

Before the R6 wording can be completed, we need to resolve the following
points:

1. Confirm the precise exact-match conversion and reference-binding rules for
   declaration and type patterns, including bit-fields, arrays, and functions.
2. Confirm declaration-shaped polymorphic object refinement, the exclusion of
   pointer-to-pointer refinement, and the `{ Derived& }` nullable-pointer
   composition described above.
3. Finalize the `alternative_traits` names, malformed-specialization behavior,
   and header availability.
4. Finish the implicit template-region model for lookup, captures, local
   statics, diagnostics, and result deduction.
5. Specify projection ordering and reuse latitude precisely enough for guards
   that mutate or invalidate the subject.
6. Resolve enumerator policy for `[[maybe_unused]]`, unavailable enumerators,
   and duplicate values.
7. Decide whether all direct `while`, C-style `for`, and filtering range-for
   forms belong in the first standard revision.
8. Complete wording for handlers, unmatched execution, and reference-valued
   results.
9. Reconcile wildcard `_`, declaration-pattern placeholder variables, and
    unnamed structured-binding packs without implying that their initialization
    behavior is interchangeable.
10. Decide whether a dependent case that is provably useless for every valid
    substitution, such as a three-element decomposition of a built-in
    two-element array, must be diagnosed or can remain conservatively maybe
    useful.
11. Confirm the contextual split between prefix selection statements and
    expressions, including the `match` type-name disambiguation and the precise
    diagnostic recovery permitted for an apparent trailing return type in
    direct statement context.

# Proposed Polls

These polls will probably need to be split as the design is reviewed:

1. Forward the composable `match` facility described in P2688R6 toward C++29.
2. Use declaration patterns for binding and explicit braces for choice
   projection.
3. Permit declaration-shaped runtime refinement of polymorphic class objects,
   but not pointer-to-pointer refinement.
4. Require non-exhaustiveness and redundant cases to be diagnosed as errors.
5. Support the closed and open `alternative_traits` customization model.
6. Support the restricted compile-time declaration preamble for selections.
7. Support single-pattern tests and pattern conditions.

# Proposed Wording

The wording in [@P2688R5] describes the R5 design and is not reproduced here as
if it described R6. The grammar and semantic rules in this revision are a
design specification for the R6 facility. Complete wording remains to be
written after the open design questions and EWG polls are resolved.

The intended wording work includes the lexical treatment of `=>`, selection
statements and expressions, pattern grammar and semantics, scope, dependence,
constant evaluation, and the `alternative_traits` library protocol.

# Acknowledgements

Thank you to all of the following folks

- Corentin Jabot, Richard Smith, and Daveed Vandevoorde for their input
  on matching multiple values and implementation concerns.
- Matt Godbolt, for helping to get the implementation online on Compiler Explorer.
- Folks on the LLVM Discord who helped with the Clang implementation.
  - Specific thanks to \@Ætérnal, \@cor3ntin, and \@Aaron Ballman.
- Jens Maurer, for the time, effort, and guidance for wording work.
- Bruno Cardoso Lopes, specifically for his contributions to the prior implementation work.
- Bjarne Stroustrup for authoring [@P3332R0] and email discussions regarding it.
- Zach Laine, Barry Revzin, and Bruno Cardoso Lopes for the encouragement and
  long discussions over much of what is proposed and discussed in this paper.
- David Sankel, Sergei Murzin, Bruno Cardoso Lopes, Dan Sarginson, and
  Bjarne Stroustrup for our prior work on [@P1371R3].
- Herb Sutter for valuable feedback and the work done in [@P2392R2].
- David Sankel, Sergei Murzin, Alex Chow, Yedidya Feldblum, and Jason Lucas for previous discussions.
- Everyone else who have had discussions about pattern matching and provided
  feedback in prior meetings and telecons!
