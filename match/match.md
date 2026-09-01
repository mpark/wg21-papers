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

## R5 → R6 {- .unlisted}
  - Prior to the Hagenberg meeting in January 2025, further implementation
    work was completed.
    - Runtime code generation was fully implemented by Bruno Cardoso Lopes.
    - Handling of `match` expressions in dependent contexts
    - Parsing of `@*type-constraint*@: @*pattern*@` syntax
    - `try_cast` protocol for the `@*type-id*@: @*pattern*@` alternative pattern.
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
  - Match cases require `case`; an unguarded top-level wildcard can also be
    written `default`.
  - Declaration patterns replace `let` bindings. The identifier may be
    omitted, but the declaration is still initialized.
  - Braces explicitly request choice projection: `{ P }`, `{ T: P }`,
    `{ C: P }`, `{ index: P }`, `{ .name: P }`, and `{}`. Here `C` is a
    type-constraint applied to the declared alternative type. The same braces
    request built-in polymorphic refinement, so a bare declaration or type
    pattern remains purely static.
  - The R5 optional and parenthesized patterns are removed. Its unbraced
    `T: P` selector is replaced by the explicit braced form `{ T: P }`.
  - A single-pattern test is written `subject match case P`.
  - Binding-producing conditions use `case P = subject`; range-for additionally
    supports `case P : range` with filtering semantics.
  - The proposed `alternative_traits` protocol supports closed indexed
    choices, named views, non-projectable states, and open type-erased choices.
  - Non-exhaustiveness and redundant cases are language errors. Coverage
    distinguishes required states from residual states.
  - The Clang prototype now supports dependent case instantiation, runtime and
    constant evaluation, subject lifetime extension, projection reuse,
    structured-binding packs, CFG integration, and pattern-matrix analysis.

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
    - See [Require Parentheses on Match Guards] for details.
  - Removed support for matching multiple values.
    - This paper now relies on `std::tuple` facilities, with room for the feature
      to be added separately in the future.
    - See [Matching Multiple Values] for details.
  - Added a section on [Note on the Implication Operator].
  - Added a section on [Lifetime Extension of Match Subject].
  - At the EWG Telecon in October 2024,  the following poll was taken:

    > Poll: [@P2688R2] - Pattern Matching: EWG likes direction of the paper.
    >
    >  SF   F   N   A   SA
    > ---- --- --- --- ----
    >  13   3   1   0   1

## R1 → R2 {- .unlisted}
  - Gained further [Implementation Experience]
  - Started on [Proposed Wording]
  - Defined [Operator Precedence of `match`]
  - Decided against proposing a reflection-based tuple-like and variant-like protocols.
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

# Introduction

This paper continues the evolution of a composable pattern-matching facility for
C++ centered on the `match` expression. This revision preserves the
expression-oriented and composable foundation of [@P2688R5], while revising
how patterns introduce names and simplifying the set of patterns.

[@P2688R5] was considered for C++26 at the February 2025 Hagenberg meeting, but
did not reach consensus for forwarding to CWG. This revision therefore targets
C++29. However, it is not merely a retargeting of [@P2688R5].

The principal changes are:

  - `let` patterns are replaced by ordinary declaration syntax.
  - Generalized alternative-matching syntax `{ ... }` supports types such as
    `T*`, `std::optional`, `std::variant`, `std::expected`, `std::any`, and
    polymorphic types. Library and user-defined alternative types participate
    through a single customization point: `std::alternative_traits`.
  - Dedicated optional and parenthesized patterns are removed.
  - Non-exhaustive and redundant cases are diagnosed as errors.

The primary form is a selection expression:

```cpp
@*expression*@ match {
    case @*pattern~1~*@ => @*handler~1~*@;
    case @*pattern~2~*@ => @*handler~2~*@;
    ...
};
```

Every pattern is applied to a subject. A nested pattern's subject is supplied
by its enclosing pattern. A declaration pattern initializes a declaration from
its subject. A decomposition pattern supplies components as subjects to nested
patterns, while an alternative pattern selects an alternative and, when present,
supplies it as the subject of a nested pattern.

For an exactly matching subject, declaration syntax determines whether to create
a new object or to initialize a reference (possibly a forwarding reference):

```cpp
case Widget val
case const Widget& ref
case Widget&& rref
case auto&& fwd
```

A declaration pattern applies directly to its subject. An alternative pattern
explicitly enters a runtime layer of an alternative type such as `std::variant`:

```cpp
std::variant<int, std::string> v;

v match {
  case { int i } => print(i);
  case { const std::string& s } => print(s);
};
```

Pointers and polymorphic types use built-in language rules. Library and
user-defined alternative types participate through the proposed
`std::alternative_traits` customization point.

A Boolean single-pattern match is performed with `match case`:

```cpp
@*expression*@ match case @*pattern*@
```

Unlike [@P2688R5], this form does not make names declared by the pattern
available in the surrounding scope.

A pattern condition that makes declared names available to its controlled
statement is instead written:

```cpp
if (case @*pattern*@ = @*expression*@) {
  // names introduced in the pattern are available here
}
```

R6 proposes five composable pattern forms:

| Pattern | Examples | Meaning |
|---|---|---|
| Wildcard | `_` | Matches and ignores its subject. |
| Value | `42`, `"hello"`, `some_constant` | Compares an expression with its subject. |
| Declaration or type | `int value`, `const Widget&`, `auto x` | Initializes an object or reference from an exactly matching subject; the identifier may be omitted. |
| Decomposition | `[0, auto y]` | Decomposes its subject and applies nested patterns to its components. |
| Alternative | `{ int value }`, `{ .error: Error& error }`, `{}` | Selects an advertised alternative and, when present, applies a nested pattern to its projection. |

Decomposition and alternative patterns provide subjects for their nested
patterns, allowing the five forms to compose recursively.

This deliberately small set is informed by a survey of real-world usage in
production C++. The design has also evolved with committee feedback and related
papers such as [@P2392R3]{.title}, [@P3332R0]{.title}, and [@P3619R1]{.title}.

# Motivation and Scope

C++ already provides many of the operations with which programmers manually
assemble pattern matching. This is typically done by combining `switch` and
`if` statements, structured-binding declarations, `std::visit` with overloaded
lambdas or `if constexpr`, and chains of `dynamic_cast`.

Pattern matching offers a mechanism to compose these operations in a form that
visually describes the shape of the value being matched. This reduces the
scaffolding needed to tease values apart and keeps the operation being expressed
at the center of the code.

The driving motivations for the changes in this revision are:

  1. Make pattern matching feel natural in C++ by using ordinary expressions and
     declarations instead of dedicated syntax such as `let` and `? @*pattern*@`.
  2. Focus on a small, composable set of patterns supported by evidence from
     real-world production C++.
  3. Improve safety by requiring diagnostics for non-exhaustive selections and
     redundant cases.

R6 also preserves the following established design decisions from earlier EWG
discussions:

  - Patterns compose recursively rather than forming a chain of separate
    matching operations. EWG expressed a preference for this direction at the
    Kona meeting in November 2022.
  - Pattern matching is available both in selection expressions and in ordinary
    control-flow conditions. At the July 7, 2021 EWG teleconference, EWG
    expressed support for matching outside a dedicated `inspect` construct.
  - Expressions retain their ordinary meaning. Earlier EWG feedback
    emphasized that declarations should visibly introduce names and that an
    identifier should not silently declare or shadow a variable merely because
    it appears in a pattern.

[@P2688R5] used `let` to make name introduction explicit. R6 retains that
distinction between declarations and expressions while using ordinary
declaration syntax to express type, ownership, references, and forwarding.
A bare identifier remains an expression that refers to an existing name.

R6 covers the `match` selection expression, a boolean-yielding single-pattern
test, and pattern conditions. It specifies the five pattern forms described in
the introduction and their composition over product types, nullable types,
closed and open alternative types, and polymorphic types. It also specifies
participation by user-defined alternative types through `alternative_traits`
and the behavior of patterns with respect to templates, evaluation, lifetime,
exhaustiveness, and usefulness.

Predicates, extractors, range patterns, named-member decomposition, matching
types themselves as subjects, pattern combinators such as `and` and `or`, and
multiple-subject matching are deferred to future work.

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
x match {
  case 0 => std::print("got zero");
  case 1 => std::print("got one");
  default => std::print("don't care");
};
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
s match {
  case "foo" => std::print("got foo");
  case "bar" => std::print("got bar");
  default => std::print("don't care");
};
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
p match {
  case [0, 0] =>
    std::print("on origin");
  case [0, int y] =>
    std::print("on y-axis at {}", y);
  case [int x, 0] =>
    std::print("on x-axis at {}", x);
  case [int x, int y] =>
    std::print("at {}, {}", x, y);
};
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
v match {
  case { int32_t i32 } =>
    std::print("got int32: {}", i32);
  case { int64_t i64 } =>
    std::print("got int64: {}", i64);
  case { float f } =>
    std::print("got float: {}", f);
  case { double d } =>
    std::print("got double: {}", d);
};
```

:::

\pagebreak

This example is matching the variant alternatives using concepts.

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
v match {
  case { std::integral auto i } =>
    std::print("got integral: {}", i);
  case { std::floating_point auto f } =>
    std::print("got float: {}", f);
};
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
  return shape match {
    case { Circle: const auto& [r] } => 3.14 * r * r;
    case { Rectangle: const auto& [w, h] } => w * h;
    case _ => throw UnknownShape{};  // required
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
cmd match {
  case { Quit } => // ...
  case { Move: auto& [x, y] } => use(x, y);
  case { Write: auto& [text] } => use(text);
  case { ChangeColor: [{ Rgb: auto& [r, g, b] }] } => use(r, g, b);
  case { ChangeColor: [{ Hsv: auto& [h, s, v] }] } => use(h, s, v);
};
```

:::

Example from [Destructuring Nested Structs and Enums](https://doc.rust-lang.org/book/ch18-03-pattern-syntax.html#destructuring-nested-structs-and-enums) section from Rust documentation.

R6 retains the recursive operation of the R5 selector but places it inside the
explicit projection boundary. This permits nominal selection and structural
matching to compose without making a bare declaration implicitly inspect a
choice.

\pagebreak

# Evidence from Existing C++

R6 is informed by a broad, non-exhaustive survey of large production C++
codebases. The recurring forms were:

| Existing form | Operation being expressed |
|---|---|
| `std::visit(overloaded{...})` | Dispatch by active alternative and bind it |
| `get_if` / `holds_alternative` chains | Ordered runtime type dispatch |
| `switch (v.index())` plus `get<I>` | Dispatch by state, then project |
| `has_value()` / `hasError()` branches | Split value, empty, and error states |
| `dynamic_cast` chains | Refine a polymorphic object |
| Generic visitor plus an inner value test | Apply one pattern across alternatives |
| Nested tests over tuple members | Compose type, value, and structure tests |

The dominant variant use case binds a concrete payload type. Generic payload
handling and structural matching across alternatives occur less often, but are
important capabilities for a language with closed generic sum types.

## Values and enums

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
value match {
  case 0 => zero();
  case 1 => one();
  default => other();
};
```

Unlike `switch`, the same syntax composes with class values, projections, and
decomposition. Unlike a visitor, it retains source-ordered value coverage and
supports exhaustiveness diagnostics.

## Replacing visitor ceremony

The following example is representative of code that normalizes several
variant alternatives into one result type:

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
return std::move(input) match -> ResultValue {
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

The braces say that these declarations bind projected payloads. The final
declaration is instantiated for every projected type not handled earlier and
preserves the payload's value category.

## One structural pattern across several alternatives

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
return input match -> RecordView {
  case { [auto&& first, auto&& second] }
    => records().lookup(first, second);

  case { reference_wrapper<const Record> ref }
    => ref.get().view();

  case { _ }
    => throw invalid_argument("unsupported record reference");
};
```

The same case can match a `pair`, `tuple`, array, or user-defined decomposable
alternative with the required shape.

## Applying one value pattern across alternatives

This example is representative of numeric telemetry aggregation:

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
  return item.second match {
    case { 0 } => true;
    default    => false;
  };
});
```

This is a central reason `{ P }` cannot merely mean "declare a payload of type
`T`". Projection and the child pattern are independent, composable operations.

## Optional and expected states

An optional value currently requires a test followed by a projection:

```cpp
auto value = parseIntegerText(input);
if (!value.has_value()) {
  throw ParseError(fieldName, "expected an integer");
}
return std::move(*value);
```

Pattern matching exposes both advertised states:

```cpp
return parseIntegerText(input) match -> string {
  case { string value }
    => std::move(value);

  case {}
    => throw ParseError(fieldName, "expected an integer");
};
```

Expected-like types naturally use named states:

```cpp
loadResources() match {
  case { .value: auto&& resources }
    => context.resources = std::move(resources);

  case { .error: const string& error }
    => return unexpected(format_error(error));
};
```

`{}` is not a magic spelling for `nullopt`; it means an advertised state with
no projection. Named states come from the choice provider.

## Matching representation shape

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
  return value match {
    case { [_, _, _] } => true;
    case { [_, _] }    => false;
  };
}
```

Selecting the delta component composes type, structure, and binding:

```cpp
const T* delta() const {
  return value match -> const T* {
    case { [DeltaMode, const auto& delta] }
      => &delta;

    case { [DeltaMode, const auto& delta, _] }
      => &delta;

    case { [ClobberMode, _, const auto& delta] }
      => &delta;

    default => nullptr;
  };
}
```

## Matching several values

R6 does not add a separate multi-subject grammar. Existing product facilities
compose with patterns. Code that merges two compact-or-expanded keyed
representations commonly contains a nested matrix of
`holds_alternative` and `get_if` tests. The state space can instead be made
explicit by matching a tuple of references:

```cpp
using SingleEntry = pair<Key, Values>;
using EntryMap = folly::F14FastMap<Key, Values>;
using Entries = variant<monostate, SingleEntry, EntryMap>;

void merge(Entries& destination, Entries&& source) {
  forward_as_tuple(std::move(source), destination) match {
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
  };
}
```

The syntax exposes the Cartesian state matrix without adding a second meaning
for commas in the `match` grammar.

## Visitor replacement is not purely mechanical

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
value match {
  case { 0 } => zero();
  case { _ } => other(); // also handles nonzero int
};
```

The faithful rewrite explicitly covers the rest of the `int` alternative:

```cpp
value match {
  case { 0 }   => zero();
  case { int } => ;
  case { _ }   => other();
};
```

This distinction is a consequence of composable first-match patterns, not a
defect to hide behind overload-resolution terminology.


# Design Overview

The overall idea is to introduce a single `match` construct that can be used to
perform a single pattern test or a selection of pattern matches.

```cpp
@*expression*@ match {
  case @*pattern*@ => @*handler*@;
  // ...
}
```

Every pattern applies to a current subject. A declaration pattern binds that
subject using ordinary C++ declaration semantics:

```cpp
constexpr int x = 42;

@*expression*@ match {
  case x => ...           // match against the existing `x`
  case int x => ...       // introduce a new `x` by value
  case const int& x => ...// introduce a reference
}
```

Braces explicitly enter a runtime projection or refinement layer:

```cpp
variant<int, string> value;

value match {
  case auto&& whole => inspect(whole);
  case { int integer } => use(integer);
  case { const string& text } => print(text);
};
```

The first case dominates in this illustrative example. Its purpose is to show
that `auto&& whole` binds the `variant`, while `{ auto&& payload }` would bind
its active alternative.

The same distinction applies to polymorphic classes:

```cpp
Shape& shape = get_shape();

shape match {
  case { Circle& refined } => draw(refined); // dynamic_cast
  case _                   => draw_unknown(shape);
};

Circle circle;
circle match {
  case Circle& exact => static_circle(exact); // ordinary exact binding
};
```

A bare declaration never silently acquires runtime behavior from the static
type of its subject.

On the right of `=>`, R6 supports expressions, a null statement, direct
`static_assert`, and jump actions. A `do` expression [@P2806R2] provides a
statement block that yields a value.

The following is used to match a value against a single pattern.

```cpp
@*expression*@ match case @*pattern*@
```

The Boolean form does not export bindings. A pattern-first condition does:

```cpp
if (case [0, int foo] = @*expr*@) {
  // `foo` is available here
} else {
  // but not here
}
```

An optional guard can be added to a selection case:

```cpp
std::pair<int, int> fetch(int id);

bool is_acceptable(int id, int abs_limit) {
  return fetch(id) match {
    case [int min, int max]
      if (-abs_limit <= min && max <= abs_limit) => true;
    default => false;
  };
}
```

## Syntax Overview

This is an informal overview of the syntax proposed in this paper.
See [](#expr-match) for the formal grammar.

```cpp
// Single pattern test; does not export bindings.
@*expression*@ match case @*pattern*@

// Binding-producing direct condition.
case @*pattern*@ = @*inclusive-or-expression*@

// Selection pattern match
@*expression*@ match @`constexpr`*~opt~*@ @*trailing-return-type~opt~*@ {
    @*attribute-specifier-seq~opt~*@ case @*pattern*@ @*guard~opt~*@ => @*expression*@ ;
    @*attribute-specifier-seq~opt~*@ case @*pattern*@ @*guard~opt~*@ => ;
    @*attribute-specifier-seq~opt~*@ case @*pattern*@ @*guard~opt~*@ => @*jump-statement*@
    @*attribute-specifier-seq~opt~*@ default => @*handler*@ ;
}

@*guard*@:
    if ( @*init-statement~opt~*@ @*condition*@ )

@*pattern*@:
    _
    @*constant-expression*@
    @*declaration-pattern*@
    @*type-pattern*@
    { @*pattern*@ }
    { . @*identifier*@ : @*pattern*@ }
    { . @*identifier*@ }
    { }
    [ @*pattern-list~opt~*@ ]
```

The following pattern-specification subsections are being revised
incrementally. Sections for R5 patterns that R6 removes are retained and marked
as such until the corresponding wording changes are complete.

## Pattern Specifications

### Wildcard Pattern

> | `_`

A wildcard pattern always matches any *subject*.

```cpp
int v = 42;
v match {
    case _ => std::print("ignored");
//  ^  wildcard pattern
};
```

This paper reattempts for `_` to be the wildcard pattern.
See [Wildcard Pattern Syntax] for further discussion.

- Matching Condition: None

### Declaration and Type Patterns (R6)

> | `@*for-range-declaration-with-optional-identifier*@`

A declaration pattern initializes a declaration from the current subject. Its
grammar follows a *for-range-declaration*: one declarator, no initializer, and
no storage-class forms such as `static` or `thread_local`.

```cpp
value match {
  case Widget object => consume(object);
  case const Widget& reference => inspect(reference);
  case auto&& forwarded => pass(std::forward<decltype(forwarded)>(forwarded));
  case std::integral auto integer => use(integer);
};
```

Applicability is restricted to exact-match standard conversion sequences.
Ordinary initialization then determines copying, moving, reference binding,
constraints, accessibility, and destruction.

The identifier can be omitted. The resulting type pattern performs the same
initialization as the corresponding named declaration, but does not provide a
name for the initialized entity:

```cpp
case int
case const Widget&
case auto&&
case std::integral auto
```

`void` and cv-`void` are additionally accepted as type patterns for dependent
void expressions and void projections.

### Let Pattern (R5; removed in R6)

::: note
This subsection records the R5 design. R6 replaces `let` with [Declaration and
Type Patterns (R6)].
:::

> | `let @*let-binding*@`

A let pattern always matches any *subject*. The *let-binding*
is either an *identifier* or a structured bindings pattern.

```cpp
int v = 42;
v match {
    let x => std::print("ignored");
//  ^^^^^  let pattern
};
```

`let` can be used to introduce new names individually, or all-in-one.

```cpp
let x           // x is new
[a, let y]      // a is old, y is new
[let x, b]      // x is new, b is old
let [x, y]      // x and y are both new
let [x, [y, z]] // x, y, z are all new
```

> | `@*match-pattern*@ let @*let-binding*@`

A `let` pattern can appear after a *match-pattern* to create bindings to the
value that was matched with *match-pattern*.

```cpp
int i = 42;
i match {
  42 => // match 42
  let x => // bind name
  42 let x => // match 42 and bind name at the same time
};

std::pair p = {0, 0};
p match {
  [0, let y] => // match and bind a piece
  let whole => // bind whole pair
  [0, let y] let whole => // do both
};
```

### Constant Pattern

> | `@*constant-expression*@`

A constant pattern tests the value of `@*subject*@` against the value of the
constant pattern. The constant pattern can be any `@*constant-expression*@`,
such as literals, `constexpr` variables, or values of an `enum`.

- Matching Condition: `bool(@*subject*@ == @*constant-expression*@);`

### Parenthesized Pattern (R5; removed in R6)

::: note
R6 has no parenthesized-pattern node. Parentheses retain their ordinary
expression role and disambiguate expression patterns from declarations.
:::

> | `( @*pattern*@ )`

A parenthesized pattern is used to group non-delimited patterns.

- Matching Condition: `@*subject*@ match @*pattern*@`

Example:

```cpp
void f(const Shape* s) {
    s match {
        ? (Circle: let c) => // ...
        ? (Rectangle: let r) => // ...
        _ => // ...
    };
}
```

```cpp
std::optional<int> maybe_int();

void f() {
    maybe_int() match {
        (? let i) let o => // i is int, o is the whole optional
        _ => // ...
    };
}
```

### Alternative Pattern (R6)

> | `{ @*pattern*@ }`
> | `{ @*type-pattern*@ : @*pattern*@ }`
> | `{ @*type-constraint*@ : @*pattern*@ }`
> | `{ @*constant-expression*@ : @*pattern*@ }`
> | `{ . @*identifier*@ : @*pattern*@ }`
> | `{ . @*identifier*@ }`
> | `{ }`

For a choice type, braces enter the projection layer advertised by that type.
For a polymorphic class, a type-directed braced pattern instead performs
runtime refinement with `dynamic_cast` semantics.

- `{ P }` considers each projectable state and applies `P` to its projection.
- `{ T: P }` considers each projectable state for which type pattern `T` is
  applicable, then applies `P` to the selected or refined projection. Repeated
  alternatives are considered independently.
- `{ C: P }`, where `C` is a type-constraint, considers each projectable state
  whose declared alternative type satisfies `C`, then applies `P` to its
  projection.
- `{ I: P }`, where `I` is an integral constant expression, selects positional
  state `I` of a closed choice and applies `P` to its projection.
- `{ .name: P }` selects a named state and applies `P` to its projection.
- `{ .name }` selects a named non-projectable state.
- `{}` matches an advertised state for which no projection exists.

```cpp
optional<int> value;

value match {
  case { int integer } => use(integer);
  case {} => empty();
};
```

```cpp
expected<int, Error> result;

result match {
  case { .value: int value } => use(value);
  case { .error: Error& error } => report(error);
};
```

```cpp
variant<int, tuple<int, int>, pair<int, int>> value;

value match {
  case { int: 0 } => zero();
  case { int: auto integer } => use(integer);
  case { tuple<int, int>: [auto x, auto y] } => use_tuple(x, y);
  case { pair<int, int>: [auto x, auto y] } => use_pair(x, y);
};
```

```cpp
variant<int, long, double> number;

number match {
  case { std::integral: auto value } => use_integer(value);
  case { std::same_as<double>: auto value } => use_double(value);
};
```

Unlike `std::integral auto`, the `std::integral` before `:` does not declare an
unnamed object or imply a placeholder type. It constrains the declared
alternative type supplied by `alternative_traits`.

The protocol for closed and open choices is described in
[Discussion on Variant-like Types].

### Optional Pattern (R5; removed in R6)

::: note
This subsection records the R5 `? P` design. R6 represents nullable types as
choice types and uses `{ P }` and `{}`.
:::

> | `? @*pattern*@`

An optional pattern tests pointer-like objects. It matches if `@*subject*@`
contextually converts to `true` and `*@*subject*@` matches `@*pattern*@`.

- Matching Condition: `bool(@*subject*@) && *@*subject*@ match @*pattern*@`

### Alternative Pattern (R5; replaced in R6)

::: note
This subsection records the R5 `T: P` design and its `try_cast` protocol. R6
uses [Alternative Pattern (R6)] and declaration patterns. Its recursive
operation is retained by the braced `{ T: P }` form described above.
:::

> | `@*type-id*@ : @*pattern*@`
> | `@*type-constraint*@ : @*pattern*@`

An alternative pattern tests sum type objects such as `variant`, `any`, and
polymorphic types.

Let `s` be *subject*, `S` be `std::remove_cvref_t<decltype(@*subject*@)>`.

**Case 1**: Variant-like

An alternative pattern matches if the `variant`-like object stores a value of
type *type-id* or the value of type satisfies *type-constraint*, and the stored
value matches *pattern*.

If `std::variant_size<S>` is well-formed and `std::variant_size<S>::value` is
an integral, let `I` be the value of `s.index()`. An alternative pattern
matches if `std::variant_alternative_t<I, S>` is *type-id* or if it satisfies
*type-constraint*, and *pattern* matches `get<I>(s)`.

**Case 2**: Casts

If `auto* p = try_cast<@*type-id*@>(s)` is well-formed, alternative pattern
matches if `p` contextually converts to `true` and `*p` matches *pattern*.

A `try_cast` customization point is proposed in [@P3521R0], rather than using
`any_cast`. Since `any` has an implicit constructor from anything, overloading
`any_cast` which takes `const any&` will likely cause a problem.
Moreover, [@P2927R2] is in the process of introducing `std::exception_ptr_cast`.

```cpp
template <typename T>
const T* try_cast(const std::any& a) noexcept {
  return std::any_cast<T>(&a);
}

template <typename T>
T* try_cast(std::any& a) noexcept {
  return std::any_cast<T>(&a);
}

const T* try_cast(const std::exception_ptr& p) noexcept {
  return std::exception_ptr_cast<T>(p); // P2927R2
}
```

**Case 3**: Polymorphic Types

This is listed as a separate case in case it's needed for optimization
flexibility. In principle though, the following specializations of
`try_cast` should provide the desired semantics.

```cpp
template <typename T, typename U>
requires requires { std::is_polymorphic_v<U>; }
const T* try_cast(const U& u) noexcept {
  return dynamic_cast<const T*>(&u);
}

template <typename T, typename U>
requires requires { std::is_polymorphic_v<U>; }
T* try_cast(U& u) noexcept {
  return dynamic_cast<T*>(&u);
}
```

### Structured Bindings Pattern

> | ``[ @*pattern~`0`{.default}~*@ , @...@ , @*pattern~`N`~*@ ]``

Given the following structured binding declaration:

``auto&& [ @*e~`0`{.default}~*@, @...@, @*e~`N`~*@ ] = @*subject*@ ;``

Let *e~i~* be a unique exposition-only identifier if *pattern~i~* is a *pattern*
and an ellipsis (`...`) if *pattern~i~* is an ellipsis (`...`). Structured
bindings pattern matches *subject* if *e~i~* matches *pattern~i~* for all *i*
where *e~i~* is an identifier.

## Scope of Bindings

The scope of the bindings introduced by `let` are as follows:

* If the *pattern* is left of `=>`, the scope of the binding is the corresponding handler.
* If the *pattern* is in `@*expression*@ match @*pattern*@ @*guard~opt~*@`,
  the scope of the binding is the expression including the optional guard, unless:
* If a *match-test-expression* is the direct *condition* of an `if` statement,
  the scope of the binding is the *then* substatement of the `if` statement.
* If a *match-test-expression* is the direct *condition* of a `for`, or `while`
  statement, the scope of the binding is the substatement of `for` or `while` statement.

Example:

```cpp
bool b1 = e1 match [0, let x] if (x > 1);
// x not available here.

bool b2 = e2 match [let x]; // not a redeclaration
// x not available here.

if (e3 match (? let elem)) {
  // elem available here
} else {
  // elem not available here
}

while (queue.next() match (? let elem)) {
  // elem available here
}
```

## Lifetime Extension of Match Subject

The lifetime of the subject of a `match` expression follows the typical lifetime
rules as per any other expression, except:

Temporary objects may be created by the subject of a *match-test-expression*.
If the *match-test-expression* is a direct *condition* of an `if`, `for` or `while`,
and if such temporary objects would otherwise be destroyed at the end of
the *match-test-expression* full-expression, the objects persist for the lifetime
of a hypothetical condition variable `auto&& temp = subject;`. For example,

```cpp
std::optional<Item> next();

if (next() match (? let elem)) {
  // ...
} // temporary destroyed here

while (next() match (? let elem)) {
  // ...
} // next destroyed at the end of each iteration
```

The proposed solution here is such that rules are consistent with
the *for-range-initializer* of a range-based `for`.

The following is an example similar to Example 2 in [stmt.ranged]{.sref}:

```cpp
using T = std::optional<int>;
const T& f(const T& t) { return t; }
T g();

void foo() {
  if (f(g()) match (? let elem)) {}     // OK, lifetime of return value of g() extended
  const T& r = f(g());                  // dangling reference
}
```

## Static and Dynamic Conditions

Every *pattern* has a corresponding condition which is tested against
the *subject* to determine whether the *pattern* matches the *subject*.

For example, the constant pattern `0` has a condition that it matches if
`@*subject*@ == 0` is true. However, there are static and dynamic dimensions
to which this condition can be applied. These dimensions are defined here.

### Static Conditions

Static conditions are the static requirements of a pattern. The patterns being
introduced in this paper have dynamic behavior, and therefore their static
conditions are the validity of a *pattern*'s match condition.

See [Static Type Checking with Constraint Pattern] for an example where
this isn't the case.

The main question is, are these static requirements checked or tested?
Going back to the constant pattern `0`, its static condition is whether
`@*subject*@ == 0` is a valid expression.

```cpp
void f1(int x) {
  x match {
    0 => // ...
    _ => // ...
  };
}
```

In this example, whether `x == 0` is a valid expression is checked at
compile-time. If `x` is a `std::string` for example, the program is ill-formed.

```cpp
void f2(std::string x) {
  x match {
    0 => // ill-formed
    _ => // ...
  };
}
```

This behavior is likely to be pretty obvious to folks. But what if `x` were
a templated parameter instead?

```cpp
void f3(auto x) {
  x match {
    0 => // fine here
    _ => // ...
  };
}

f3("hello"s); // proposed: ill-formed
```

This paper proposes that this example be ill-formed at the instantiation site.
While a model that treats `0` as a no-match would be doable, I believe it'll be
better and safer as an opt-in feature. For `f3<std::string>` to have different
type-checking behavior than `f2` would be novel and likely lead to subtle bugs.

This means that static conditions of patterns are always checked and enforced at
compile-time. See [More on Static Conditions] for further design discussions,
and [Testing the Static Conditions with `match requires`] which suggests
an extension to explicitly treat the static conditions as compile-time tests
rather than checks.

The semantics for this was not precisely defined in [@P1371R3], and [@P2392R2]
proposes for `f3("hello"s)` to be well-formed and `0` is a no-match.

### Dynamic Conditions

Dynamic conditions are more obvious and straight-forward. The constant pattern
`0` matches if `@*subject*@ == 0` is true. But true when?

This paper proposes that `match` tests the dynamic condition at runtime, (think
`if`) and `match constexpr` tests it at compile-time (think `if constexpr`).

::: cmptable

## `match`

```cpp
void f(int x) {
  x match {
    0 => // ...
    1 => // ...
    _ => // ...
  };
}
```

## `match constexpr`

```cpp
template <std::size_t I>
const auto& get(const S& s) {
  return I match constexpr -> const auto& {
    0 => s.foo();
    1 => s.bar();
    _ => static_assert(false);
  };
}
```

:::

# R6 Syntax Details

## Selection expressions

The selection form is:

```cpp
subject match constexpr(opt) trailing-return-type(opt) {
  attribute-specifier-seq(opt) case pattern guard(opt) => handler;
  attribute-specifier-seq(opt) default => handler;
}
```

For example:

```cpp
value match -> int {
  [[likely]] case 0 => 1;
  case int x if (x > 0) => x;
  [[unlikely]] default => -1;
};
```

`default` is exactly an unguarded top-level `case _`. It is not a pattern, so
it cannot be nested, used by a single-pattern expression, or given a guard.
Source order remains significant; `default` is not implicitly tested last.

## Single-pattern forms

The ordinary Boolean expression is:

```cpp
subject match case pattern
```

It does not export bindings. A non-viable pattern makes the expression
ill-formed.

The binding-producing condition forms are:

```cpp
if (case pattern = subject) statement
while (case pattern = subject) statement
for (init-statement; case pattern = subject; expression) statement
for (case pattern : range) statement
```

Direct conditions can participate in a left-to-right built-in conjunction:

```cpp
if (ready && case [int x, int y] = first &&
    x < y && case { string text } = second && !text.empty()) {
  use(x, y, text);
}
```

The first top-level `=` separates the pattern from the subject. Assignment
expression patterns therefore require parentheses. A trailing pattern guard is
not accepted in this form; a later `&&` condition is the guard.

The range-for form filters: an element for which the pattern does not match is
skipped.

## Guards

A selection-case guard is introduced by `if` and requires parentheses. It can
contain an init-statement and a condition declaration:

```cpp
value match {
  case Widget widget
    if (auto status = validate(widget); status.ok())
      => consume(widget, status);

  default => reject();
};
```

Pattern bindings are visible in the guard. A guard init-statement declaration
is visible in the guard condition and selected handler. Neither is visible in
later cases.

Guarded cases do not contribute to exhaustiveness, even when a guard is
manifestly `true`. This keeps coverage independent of arbitrary constant
evaluation and avoids changing exhaustiveness when a guard expression is
refactored.

## Precedence and parsing

`match` has precedence between the pointer-to-member and multiplicative
operators, following the direction selected in R5 and the precedent discussed
for [@P2392R3]. Consequently:

```cpp
*pointer match { /* ... */ }       // (*pointer) match ...
object.*member match { /* ... */ } // (object.*member) match ...
a + b match { /* ... */ }          // a + (b match ...)
```

Parentheses select a larger subject when needed:

```cpp
(a + b) match { /* ... */ }
```

Declaration, type, and expression patterns intentionally occupy one syntactic
position. The design uses these disambiguation rules:

- A complete type pattern takes precedence over an expression interpretation,
  following the `sizeof` and `typeid` family of ambiguities.
- Declaration-versus-expression ambiguity otherwise follows ordinary
  block-scope declaration rules, restricted to one for-range-style declarator.
- Parentheses force the ordinary expression interpretation where applicable;
  there is no parenthesized-pattern AST node.
- In `case P = E`, the first top-level `=` terminates the pattern.
- In a direct condition, each ordinary Boolean element and each case subject
  is an *inclusive-or-expression*. A top-level `&&` separates condition
  elements; assignment, conditional expressions, and `||` require
  parentheses.
- Parsing proceeds left-to-right. A later `&& case` does not retroactively
  change an overloaded `operator&&` contained wholly within an earlier ordinary
  expression.

Malformed patterns recover at the case boundary and suppress follow-on
exhaustiveness diagnostics.

## Handlers

A handler can be:

- an expression;
- a null statement, written `=> ;`;
- a `static_assert` declaration;
- `break`, `continue`, `return`, or `co_return` where that action is valid.

The `do` expression composes with match when a handler needs a statement block
that yields a value:

```cpp
value match -> int {
  case int x => do {
    log(x);
    do_return x;
  };

  default => static_assert(false, "unsupported specialization");
};
```


# Pattern Model

## The current subject

Every pattern is interpreted against one current subject:

- a declaration or type pattern applies directly to it;
- `[P1, P2]` decomposes it and gives each child a component subject;
- `{ P }` requests a runtime projection or refinement and applies `P` to the
  resulting subject;
- `{ T: P }` selects or refines a projected type before applying `P`;
- `{ C: P }` selects a projected alternative whose declared type satisfies
  type-constraint `C`;
- `{ I: P }` selects positional state `I` of a closed choice;
- `{ .name: P }` first selects a named state;
- `_` ignores it without performing projection.

This model avoids saying that a declaration sometimes binds an object and
sometimes implicitly enters a `variant`. The declaration always does the same
thing; braces change the current subject.

## Wildcard and value patterns

`_` matches every value in its current domain and introduces no binding.

This is distinct from a C++26 placeholder variable inside a declaration
pattern:

```cpp
case _      // ignores the subject; performs no declaration initialization
case auto _ // initializes an unnamed by-value declaration
```

The latter can copy, move, throw, and run a destructor. The wildcard cannot.

A value pattern compares its constant expression with the current subject.
The comparison must be well-formed for the relevant semantic subject. Value
patterns compose with choice projection and decomposition:

```cpp
value match {
  case 0          => zero();
  case [0, _]     => on_y_axis();
  case { [_, 0] } => on_x_axis_payload();
};
```

Parentheses have their ordinary expression meaning. R6 has no separate
parenthesized-pattern node.

## Declaration patterns

A declaration pattern is a real declaration initialized from the current
subject:

```cpp
case Widget value
case const Widget& reference
case auto&& forwarded
case std::integral auto integer
```

The declaration grammar follows the restrictions of a
*for-range-declaration*: one declarator, no initializer, and no storage-class
forms such as `static` or `thread_local`.

The ordinary rules determine:

- by-value copy and move construction;
- reference binding and cv-qualification;
- forwarding-reference deduction;
- constraints on placeholder types;
- `decltype` of the introduced name;
- accessibility, deleted functions, and destruction.

Applicability is restricted to standard conversion sequences with exact-match
rank: identity, lvalue transformations, qualification adjustment, and function
pointer conversion. Promotions, conversion-rank standard conversions, and
user-defined conversions do not make a declaration pattern applicable.

The pattern language is ordered, not overloaded. The first matching case wins.
Overload ranking is used only to define the permitted conversion category, not
to reorder cases.

For a closed choice, every written declaration must be applicable to at least
one alternative unless dependence makes it potentially useful:

```cpp
variant<int, double> value;

value match {
  case { int integer } => use(integer);
  case { double real }  => use(real);
  case { char byte }    => use(byte); // error: not useful
};
```

Qualification adjustment can intentionally make one earlier case cover several
alternatives:

```cpp
variant<int*, const int*> pointer;

pointer match {
  case { const int* value } => inspect(value); // can cover both alternatives
  case { int* value }       => mutate(value);  // error if fully dominated
};
```

The usefulness diagnostic is the remedy for source-order mistakes; the
language does not reorder these cases as an overload set would.

### Applicability versus failed initialization

A declaration pattern has three relevant outcomes:

1. It is not applicable to the semantic subject.
2. It is applicable and initialization succeeds.
3. It is applicable, but the selected initialization is ill-formed.

Only the first outcome can omit a dependent semantic case. The third is an
error. This follows overload resolution: after a by-value overload has been
selected, failure to perform its copy does not retry an ellipsis fallback.

```cpp
struct Job {
  Job(Job&&) = default;
  Job(const Job&) = delete;
};

void process(auto&& value) {
  std::forward<decltype(value)>(value) match {
    case Job job => execute(std::move(job));
    default      => report_unsupported();
  };
}

Job job;
process(Job{}); // moves
process(job);   // error: selected Job initialization requires a copy
```

Silently choosing `default` in the second call would turn an ownership error
into different program behavior.

## Type patterns

A declaration pattern can omit its identifier. Such a type pattern has the
same initialization semantics as the corresponding named declaration pattern:

```cpp
case int
case const Widget&
case auto&&
case std::integral auto
case [auto&&, auto&&]
```

The initialization is performed even though its result cannot be named. An
object initialized by the declaration has the same lifetime as one introduced
by the corresponding named declaration, and initialization and destruction
have the same side effects. Deleted or inaccessible constructors still make
the pattern invalid.

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

## Decomposition patterns

`[P1, P2, ...]` applies ordinary structured-binding decomposition to the
current subject and recursively matches each component:

```cpp
point match {
  case [0, 0] => origin();
  case [int x, 0] => on_x_axis(x);
  case [0, int y] => on_y_axis(y);
  case [int x, int y] => elsewhere(x, y);
};
```

Empty decomposition is the zero-element structural pattern:

```cpp
case [] => empty_product();
```

One arity-inferred subpattern pack is permitted:

```cpp
case [auto&& first, auto&& ...middle, auto&& last]
case [auto&& first, ..._, auto&& last]
```

The first form binds a local pack; the second ignores the consumed elements.
The pack can be empty. Its size is the decomposition arity minus the fixed
prefix and suffix.

Declaration patterns can themselves contain structured-binding packs:

```cpp
case auto [...elements] => (... + elements);
```

The declaration, guard, and handler form an implicit template region in which
the pack is expanded.

# Runtime Type and Choice Matching

## Static matching and polymorphic refinement

A bare declaration or type pattern performs only ordinary static exact
matching. Runtime refinement of a polymorphic class is explicitly requested by
braces and has the semantics of the corresponding pointer-form
`dynamic_cast`:

```cpp
void draw(Shape& shape) {
  shape match {
    case { Circle& circle }       => draw_circle(circle);
    case { Triangle& triangle }   => draw_triangle(triangle);
    case { Rectangle& rectangle } => draw_rectangle(rectangle);
    default                       => draw_unknown(shape);
  };
}
```

The semantics include public downcasts, virtual inheritance, pointer
adjustment, and valid cross-casts. A failed cast is a non-match.

Pointer subjects first use the nullable projection model. The projected object
can then be refined polymorphically:

```cpp
void inspect(Shape* shape) {
  shape match {
    case { Circle& circle } => mutate(&circle);
    case {}                 => null_shape();
    default                 => other_shape();
  };
}
```

The relation is open-world. If `Square` derives from `Rectangle` in another
translation unit or shared library, a `Square` object passed as `Shape&` must
still match `Rectangle&`. Exact dynamic type or vptr equality is insufficient.

The explicit marker prevents one source pattern from changing between static
matching and runtime refinement as a template is instantiated:

```cpp
void inspect(auto& value) {
  value match {
    case { Circle& circle } => use(circle);
    default                 => fallback(value);
  };
}

Circle circle;
inspect(circle);                       // refinement succeeds trivially
inspect(static_cast<Shape&>(circle));  // runtime downcast succeeds
```

To require only a static match, omit the braces. Static type subjects are a
separate future facility; R6 does not propose a syntax such as
`T match { case int => ... }`.

## Why runtime projection and refinement are explicit

Without a projection marker, this declaration is ambiguous in intent:

```cpp
variant<int, string> value;
case auto&& selected
```

It could bind the `variant` or its active payload. R6 gives it only the normal
declaration meaning: it binds the `variant`. Braces enter the choice:

```cpp
case auto&& whole       // the variant object
case { auto&& payload } // the active payload
```

The same marker prevents declaration syntax from changing meaning when a
template argument changes from a concrete derived type to a polymorphic base.
`Circle& circle` is always a static declaration pattern;
`{ Circle& circle }` is the runtime-refining form.

The same rule applies to structure:

```cpp
variant<int, tuple<int, int>, pair<int, int>, array<int, 2>> value;

value match {
  case { int integer }       => scalar(integer);
  case { [int x, int y] }    => coordinates(x, y);
  case auto&& whole          => inspect_unmatched_choice(whole);
};
```

It would be too surprising for `[int x, int y]` to decompose the whole object
for one subject type but silently enter a choice for another.

## Closed choices

For a closed choice, `{ P }` considers each advertised projectable state for
which `P` is viable. Runtime matching tests the active state and applies the
corresponding semantic instantiation of `P`.

A pattern may cover more than one index:

```cpp
variant<int, int> value;

value match {
  case { const int& integer } => use(integer); // covers both indices
};
```

Qualification adjustments can likewise make one declaration applicable to
several alternatives. Usefulness operates on the actual indices and nested
value coverage, not only on the written type.

`{ auto&& value }` is a generic projected case. Its declaration, guard, and
handler are checked separately for every retained projected type.

## Named and non-projectable states

Named projection chooses an advertised state before matching its projection:

```cpp
expected<int, Error> result;

result match {
  case { .value: int value }    => use(value);
  case { .error: Error& error } => report(error);
};
```

`{}` matches advertised states for which no projection exists:

```cpp
optional<int> value;

value match {
  case { int integer } => use(integer);
  case {}              => empty();
};
```

The `.name:` spelling is confined to braces. A bare `name: P` would make
ordinary identifier lookup unexpectedly consult a trait. The leading dot also
leaves `[.x: P, .y: Q]` available for future named aggregate decomposition.

`expected<T, E>` is modeled as value/error, not value/empty. Both states are
projectable, including a `void` projection for `expected<void, E>`.

Raw pointers have a built-in null/non-null choice model:

```cpp
pointer match {
  case { Widget& widget } => use(widget);
  case {}                 => absent();
};
```

`nullptr` and `nullopt` remain ordinary value patterns on the whole current
subject. They can test runtime equality, but do not by themselves claim
coverage of an advertised empty state. `{}` or a named state such as `.none`
is the state-oriented spelling used by exhaustiveness analysis.

The rare valueless state of `variant` is residual and has no projection syntax.
Code that cares about it can test the whole object first:

```cpp
value match {
  case auto&& whole if (whole.valueless_by_exception()) => recover();
  case { auto&& alternative } => use(alternative);
};
```

## Open choices and `any`

An erased open choice cannot enumerate all projected types, but it still uses
braces to make runtime projection explicit:

```cpp
any value;

value match {
  case { int integer }       => use(integer);
  case { const string& text } => print(text);
  case { _ }                 => unknown_nonempty();
  case {}                    => empty();
};
```

A naked `case int integer` does not inspect `any`; it tests the `any` object
itself. `{ auto&& value }` is ill-formed for an open erased choice because it
cannot expose an unknown runtime type as one statically typed binding.

# The `alternative_traits` Protocol

The protocol name and some member names remain provisional. The current design
has closed and open forms.

## Closed indexed protocol

```cpp
template<class T>
struct alternative_traits;

template<class Provider>
struct alternative_name {
  using provider = Provider;
  size_t index;

  consteval alternative_name(size_t index) : index(index) {}
};

template<>
struct alternative_traits<choice> {
  static constexpr size_t size = /* advertised states */;

  // Optional; defaults to true.
  static constexpr bool is_exhaustive = true;

  template<auto I>
    requires /* state I is projectable */
  using type = /* declared alternative type */;

  static constexpr auto index(choice const&) noexcept;

  template<auto I, class Self>
    requires /* state I is projectable */
  static constexpr decltype(auto) get(Self&&);

  struct names {
    using AT = alternative_traits;
    static constexpr alternative_name<AT> value = 0;
    static constexpr alternative_name<AT> error = 1;
  };
};
```

The protocol laws are:

- `size` advertises a finite state set.
- `type<I>` names the declared alternative type for each projectable state.
  Its absence denotes a non-projectable state.
- `index(subject)` identifies the active state and is `noexcept`.
- State `I` is projectable when both `type<I>` and `get<I>(subject)` are
  well-formed. `type<I>` may be `void`; an absent `type<I>` denotes a
  non-projectable state.
- `get<I>` has the precondition that `index(subject) == I` and preserves the
  subject's cv/ref category as defined by the provider.
- `is_exhaustive == false` means runtime states can exist outside the
  advertised set. Those states are residual rather than required.
- A member of `names` maps source syntax to a provider and one advertised
  state.

An implementation caches the discriminator and calls `get<I>` only after
selecting `I`. A standard-library specialization can therefore use a private
unchecked projection mechanism; the public protocol does not expose that
implementation detail.

## Standard models

| Subject | Model | Required states | Residual state |
|---|---|---|---|
| `T*` | built-in closed choice | null, non-null | none |
| `optional<T>` | closed choice | empty, value | none |
| `expected<T, E>` | closed named choice | value, error | none |
| `variant<Ts...>` | closed indexed choice | every declared index | valueless |
| `any` | open type-indexed choice | empty and unknown non-empty remainder | none |

Raw pointers use built-in semantics. A library `alternative_traits<T*>`
specialization can mirror that model so explicitly opted-in nullable types,
such as `optional`, selected smart pointers, and an additional named view of
`expected`, can reuse it. User-defined pointer-like syntax alone does not opt a
type into an exhaustive two-state promise.

`variant` uses its index and an unchecked projection whose precondition is the
selected index. `optional` advertises empty index 0 and value index 1.
`expected` advertises value index 0 and error index 1. The actual index type can
be `bool` for a binary provider.

The intended models can be sketched as follows. Raw pointers use equivalent
built-in compiler behavior; their specialization exists as a reusable provider
for explicitly opted-in nullable library types:

```cpp
template<class T>
struct alternative_traits<T*> {
  using AT = alternative_traits;

  static constexpr size_t size = 2;
  static constexpr bool is_exhaustive = true;

  template<size_t I>
    requires (I == 1 && !is_void_v<T>)
  using type = T;

  static constexpr bool index(auto const& value) noexcept {
    return value ? true : false;
  }

  template<bool HasValue, class Self>
    requires (HasValue && !is_void_v<T>)
  static constexpr decltype(auto) get(Self&& self) noexcept {
    return *std::forward<Self>(self);
  }

  struct names {
    static constexpr alternative_name<AT> none = 0;
    static constexpr alternative_name<AT> some = 1;
  };
};

template<class T>
struct alternative_traits<optional<T>> : alternative_traits<T*> {};
```

The pointer provider's `index` parameter is templated so that an inheriting
nullable type can reuse its state partition. The `get` return type is formed
from dereference so that the provider preserves the subject's actual cv/ref
projection. `void*` does not participate in the built-in pointer model because
there is no non-null value projection.

Expected advertises two projectable states, including `void` for a successful
`expected<void, E>`:

```cpp
template<class T, class E>
struct alternative_traits<expected<T, E>> {
  using AT = alternative_traits;

  static constexpr size_t size = 2;
  static constexpr bool is_exhaustive = true;

  template<size_t I>
    requires (I < size)
  using type = conditional_t<I == 0, T, E>;

  static constexpr size_t index(expected<T, E> const& value) noexcept {
    return value.has_value() ? 0 : 1;
  }

  template<size_t I, class Self>
    requires (I < size)
  static constexpr decltype(auto) get(Self&& self) {
    if constexpr (I == 0)
      return *std::forward<Self>(self);
    else
      return std::forward<Self>(self).error();
  }

  struct names : alternative_traits<T*>::names {
    static constexpr alternative_name<AT> value = 0;
    static constexpr alternative_name<AT> error = 1;
  };
};
```

Variant advertises every declared index and a residual valueless state:

```cpp
template<class... Types>
struct alternative_traits<variant<Types...>> {
  static constexpr size_t size = sizeof...(Types);
  static constexpr bool is_exhaustive = false;

  template<size_t I>
  using type = Types...[I];

  static constexpr size_t index(variant<Types...> const& value) noexcept {
    return value.index();
  }

  template<size_t I, class Self>
  static constexpr decltype(auto) get(Self&& self) noexcept {
    return /* unchecked projection of alternative I */;
  }
};
```

The unchecked operation is exposition-only. The protocol precondition and the
language's retained discriminator permit the standard-library specialization
to use its private unchecked access without exposing that operation as a new
public `variant` API.

Multiple named views are permitted operationally. Each provider has its own
discriminator and projections. Exhaustiveness can be proven by complete
coverage of one provider; partial overlap between different providers is
treated conservatively as maybe useful.

## Open type-indexed protocol

An open choice omits `size`:

```cpp
template<>
struct alternative_traits<any> {
  template<class T, class Self>
  static auto try_cast(Self&& self) noexcept;

  static bool has_value(any const&) noexcept; // optional
};
```

For `{ T value }`, matching requests
`try_cast<remove_cvref_t<T>>(subject)`. A null pointer is a non-match. The
successful pointee is forwarded like the subject before ordinary declaration
initialization is checked.

`has_value` enables `{}` for empty and `{ _ }` for the unknown non-empty
remainder. Without `has_value`, `{}` is ill-formed.

# Scope and Conditions

Names introduced by a source pattern are visible in that case's guard and
handler. They are not visible in later cases.

A name is introduced immediately for lookup, preserving the R5 rule, but a
reference from within the same pattern to a name introduced by that pattern is
ill-formed. This avoids silently changing an expression pattern from an outer
name to an earlier sibling binding.

`subject match case P` never exports names. In a direct condition, names are
available in later `&&` elements and the successful controlled statement, but
not in `else`:

```cpp
if (case [int x, int y] = value && x < y) {
  use(x, y);
} else {
  // x and y are not in scope
}
```

The direct condition is strict. `P` must be viable after substitution; a
non-viable pattern is not converted to `false`. Static detection uses a
requires-expression:

```cpp
if constexpr (requires { value match case [_, _]; }) {
  // a two-element decomposition is viable
}
```

`if constexpr (case P = E)` retains the same viability requirement. The
`constexpr` controls selection after the condition has been formed; it does not
turn the condition into a detection operation.

The subject of `case P = E` is parsed after the pattern binding has been
introduced. Consequently, a same-named use denotes self-initialization and is
ill-formed:

```cpp
int x = 42;
if (case int x = x) { }   // error
if (case int x = ::x) { } // explicitly names an outer object
```

Range-for follows ordinary range-for lookup instead: the range initializer is
outside the scope of the element binding.

# Templates and Case Instantiation

## Strict single-pattern matching

For a viable pattern, `E match case P` has the same value behavior as:

```cpp
E match {
  case P  => true;
  default => false;
}
```

The equivalence is not a well-formedness transformation. A non-viable `P`
makes the single-pattern expression ill-formed, even where a dependent
selection with multiple cases could omit that semantic case.

This separates two questions:

```cpp
requires { E match case P; } // is P viable?
E match case P               // given viability, does this value match?
```

An irrefutable viable pattern always produces `true`, but still evaluates its
subject and any required projections or declarations. It is not operationally
equivalent to the unevaluated requirement.

## Dependent case matching

A source case can be inapplicable in one specialization and applicable in
another:

```cpp
template<class V>
int classify(V value) {
  return value match {
    case { int }    => 0;
    case { string } => 1;
    case { char }   => 2;
  };
}
```

For `variant<int, string>`, the `char` semantic candidate is absent, but the
source case remains maybe useful because another specialization can contain
`char`. By contrast, a non-dependent `variant<int, string>` with the same
`char` case is ill-formed because the case is not useful.

Exhaustiveness is checked for each concrete specialization:

```cpp
constexpr size_t arity(auto value) {
  return value match {
    case auto&& [...elements] => sizeof...(elements);
  };
}

static_assert(arity(tuple(1, 2)) == 2);
// arity(0); // error: the instantiated match is not exhaustive
```

## Implicit template regions

A generic projected case produces one semantic case instantiation for each
retained projected type:

```cpp
variant<int, string> value;

value match {
  case { auto&& alternative } => use(alternative);
};
```

The declaration, guard, and handler form an implicit template region. Result
deduction, `decltype`, constraints, local statics, diagnostics, and structured
binding packs are evaluated in the corresponding semantic instantiation.

An earlier unguarded irrefutable semantic case closes only its own domain and
prevents later handlers for that domain from being instantiated:

```cpp
variant<int, string, vector<int>> value;

auto result = value match {
  case { int integer } => integer;
  case { auto&& data }  => static_cast<int>(data.size());
};
```

The second handler is instantiated for `string` and `vector<int>`, not for
`int`. This is analogous to an overloaded visitor, without turning match cases
into an overload set.

The foundational instantiation rule uses individual irrefutability, not the
union of several refutable cases. Usefulness can diagnose a later case as
redundant without retroactively suppressing its handler instantiation based on
the complete pattern matrix.

# Exhaustiveness and Usefulness

Non-exhaustiveness and redundancy are hard errors, not optional warnings:

```cpp
bool value;

value match {
  case true => yes();
}; // error: example of a missing case: false
```

```cpp
value match {
  case true  => yes();
  case false => no();
  default    => impossible();
}; // error: redundant case
```

Guarded cases are useful but do not contribute coverage because their guards
can fail.

The implementation follows the Maranget/Rust pattern-matrix model. The
specification must define stable language behavior rather than incorporating
one implementation algorithm by reference. A candidate is classified as:

- useful;
- maybe useful because dependence or opacity prevents a final answer; or
- not useful.

Conservative `maybe useful` is the compatibility mechanism for dependent and
open cases.

## Required and residual domains

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

## Subject and lifetime

- The subject expression is evaluated exactly once.
- An lvalue subject continues to denote the original object.
- A prvalue subject is materialized in hidden storage.
- Its original value category is retained for projections.
- In an ordinary match expression, the hidden subject survives through the
  containing full-expression.
- In a direct condition, the hidden subject survives through the controlled
  statement, including the `else` path, using the same lifetime-extension
  machinery as condition variables and C++23 range-for.

A selection case is not an invented function-return boundary. A selected
reference result is analyzed according to the enclosing use of the complete
match expression.

## Pattern tests and declarations

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
std::move(subject) match {
  case [Widget value, 0] => use(value);
  default                => fallback();
};
```

If the second component is not zero, `value` is not initialized.

A failed guard does not roll back side effects:

```cpp
std::move(value) match {
  case Widget first if (false) => unreachable();
  case Widget second           => observe_moved_from(second);
};
```

The second case can observe the moved-from subject. This is dangerous but
follows ordinary C++ initialization and RAII; restricting declarations to
references would remove important ownership-transfer use cases.

## Projection reuse

An implementation may retain or recompute equivalent projection operations
within one match, including:

- closed-choice discriminators and selected projections;
- tuple-like `get<I>`;
- open-choice `try_cast<T>` and `has_value`;
- polymorphic runtime refinement and its adjusted pointer.

Expression comparisons, declaration initialization, and guards occur at each
source occurrence and are not merged. Operations belonging solely to cases
after the selected case are not speculated.

A failed guard is not a cache barrier. If a guard mutates the subject, a later
equivalent projection may reuse retained state or recompute it; code that
invalidates a retained reference has ordinary C++ consequences.

Closed-provider `index(subject)` is required to be `noexcept`, permitting the
discriminator to be retained and used by a switch or decision tree. The
physical lowering is not specified.

## Unmatched execution

Static exhaustiveness normally rules out required unmatched states. At runtime:

- an unmatched void-yielding match falls through;
- an unmatched non-void match terminates;
- an unmatched execution cannot succeed during constant evaluation.

This rule handles residual states such as `variant::valueless_by_exception()`
without forcing that rare state into ordinary projection syntax.

# Result Types and `match constexpr`

Handlers retained in one semantic specialization must have a consistent result
type unless an explicit trailing return type supplies the conversion target.
A discarded handler does not contribute to deduction.

```cpp
constexpr auto result(auto value) {
  return value match {
    case int integer   => integer;
    case string& text  => text.size();
    default => static_assert(false, "unsupported type");
  };
}
```

The assertion is instantiated only for a specialization not closed by an
earlier unguarded irrefutable case.

`match constexpr` requires selected pattern conditions and guards to be
constant expressions and discards unselected handlers in the style of
`if constexpr`. It does not change pattern viability or turn direct conditions
into detection operations.


# R6 Design Rationale and Alternatives

## Why one `match` expression

Earlier `inspect` designs explored a construct that was a statement or an
expression depending on context. C++ has no general precedent for choosing
between those two grammatical categories after parsing the same construct,
and that choice would force the introducer to be an unconditional keyword.

P2688 instead has one expression form. A selection can appear as an expression
statement when its value is unused:

```cpp
value match {
  case 0 => zero();
  default => other();
};
```

or in an expression-only context:

```cpp
int result = value match {
  case 0 => 1;
  default => 2;
};
```

The same operator also supports a single-pattern Boolean test. R6 adds `case`
to make that form read as `E match case P`, but retains the unified model
rather than introducing a separate `is` expression with different pattern
semantics.

## Why selection cases require `case`

R5 allowed a pattern to begin a selection case directly. Requiring `case` provides a
stable recovery point, distinguishes case attributes from declaration
attributes inside a pattern, makes empty and direct-statement handlers easier
to parse, and reserves room for the pattern grammar to grow without repeatedly
reopening the surrounding match grammar.

It also aligns the selection form with `switch` while retaining source-ordered
pattern semantics. `default` is provided only as the familiar spelling of an
unguarded top-level wildcard.

## Why `_` is the wildcard

R6 retains `_` as the wildcard spelling. This follows [@P2392R2] and the broad
language precedent in Python, Rust, Scala, Swift, C#, Erlang, Prolog, Haskell,
OCaml, and others. [@P1371R3] used `__`, following [@P1110R0], while
[@P1469R0] proposed restricting `_` as an identifier in structured bindings.

The wildcard remains distinct from a C++26 placeholder variable:

```cpp
value match {
  case _      => ignore_without_initialization();
  case auto _ => initialize_an_unnamed_object();
};
```

The special interpretation means that a bare `_` cannot refer to an outer
variable in pattern position:

```cpp
int _ = 42;

value match {
  case _ => always_matches();
};
```

An ordinary expression can still perform that comparison through a guard:

```cpp
value match {
  case auto&& current if (current == _) => equal_to_outer_underscore();
  default => different();
};
```

This is a small language-specific cost for using the universally recognizable
wildcard spelling.

## Why expressions are patterns

Without expression patterns, the facility could not replace even the simplest
`switch`. Restricting the syntax to literals would still exclude named
constants and enumerators:

```cpp
enum class color { red, green, blue };
constexpr int protocol_version = 7;

value match {
  case color::red        => handle_red();
  case protocol_version  => handle_current_version();
  default                => fallback();
};
```

Once literals, unqualified names, qualified names, and constant expressions
are admitted, the language must distinguish an expression referring to an
existing name from a declaration introducing a new one. R6 does not reinterpret
a bare identifier as a binding. It parses expressions and declarations using
their ordinary C++ roles.

## Why declarations instead of `let`

R5's `let` provided one intentionally simple binding model, but "why does C++
need `let`?" was the most frequent first reaction. Real code overwhelmingly
wants to bind a typed payload, and C++ declarations already express ownership,
cv-qualification, references, forwarding, constraints, and `decltype`.

Declaration patterns are more familiar:

```cpp
case const string& text
case auto&& value
case std::integral auto integer
```

The cost is semantic weight. Copying, moving, reference binding, deleted
constructors, explicit constructors, and conversions must all be specified.
R6 accepts that cost rather than introducing a second C++ binding language.

Several questions that were hypothetical in R5 become explicit design rules
in R6.

First, `auto value` binds the current subject, not an implicitly selected
payload:

```cpp
variant<int, string> value;

value match {
  case auto&& whole       => inspect(whole);
  case { auto&& payload } => inspect(payload);
};
```

The first case dominates in this illustrative example. Its purpose is to show
that braces, not the declaration's spelling, request choice projection.

Second, declarations use source-ordered first-match semantics rather than
forming an overload set. Conversion-ranked initialization would make this
surprising:

```cpp
variant<int, double> value;

value match {
  case { int integer } => use(integer);
  case { double real }  => use(real);
};
```

If arbitrary conversions were admitted, the `int` declaration could consume a
`double` and make the second case dead. R6 instead uses the exact-match rank and
lets usefulness analysis diagnose domination among the conversions that
remain.

Third, by-value declarations are real ownership operations. Given an rvalue
subject, `auto value` can move; given an lvalue, it copies. `auto&& value` is
the forwarding spelling. This is familiar C++ even though it means a failed
guard can leave a later case observing a moved-from subject.

## Removed R5 pattern forms

The R5 `? P` pattern combined nullable testing and dereference in one dedicated
spelling. R6 instead models nullable types as choices, so `{ P }` and `{}`
compose with the same protocol as `variant` and `expected`.

The R5 unbraced `T: P` selector made variant selection concise but did not
resolve whole-object versus payload matching for `auto`. R6 keeps its recursive
operation as `{ T: P }`: braces make projection explicit, `T` selects or
refines the projected type, and `P` recursively matches the resulting current
subject. `{ I: P }` supplies the corresponding positional escape hatch for
duplicate or otherwise indistinguishable alternative types.

The R5 parenthesized pattern is removed. Parentheses retain their normal role
for expression patterns and grammar disambiguation.

## Why projection is explicit

Making `int value` implicitly inspect `variant<int, double>` appears familiar,
but making `[int x, int y]` silently inspect
`variant<pair<int, int>, tuple<int, int>>` is substantially more magical. It
also leaves `auto&& value` irreducibly ambiguous between the whole object and
the active alternative.

Braces assign one composable meaning to the transition into a choice. This is
the principal syntax cost of R6 and the mechanism that keeps declarations
ordinary.

## Why first match rather than overload resolution

Actual overload resolution over alternatives would make ordering largely
irrelevant and permit conversions that are dangerous for closed sums:

```cpp
variant<int, double> value;

value match {
  case { int integer } => use(integer);
  case { double real }  => use(real);
};
```

If conversion-ranked initialization were allowed, the first case could consume
both alternatives and make the second dead regardless of source intent. R6
uses source-ordered first match and restricts declaration applicability to
exact-match conversion rank. Exhaustiveness then diagnoses genuinely useless
cases.

## Why not one implicit `as` operation

[@P2392R3] places type testing, conversion, and binding behind an `as`
spelling. That is attractive for simple examples but gives one syntax several
different jobs. In particular, conversion-based matching over
`variant<int, double>` can make an `int` case accept a `double` alternative and
render a later `double` case ineffective.

C# declaration patterns are a useful precedent for runtime refinement of an
object, but C++ additionally has closed generic sum types whose active payload
can be handled without naming its type. A naked declaration therefore cannot
unambiguously mean both "bind this object" and "enter this object's active
alternative".

R6 separates the operations instead:

```cpp
case int value       // statically bind the current subject
case { int value }   // runtime-project or refine, then bind the result
```

The exact-match restriction prevents ordinary numeric conversions from
silently changing closed-choice dispatch.

## Why `any` also requires braces

Allowing a naked `int value` to inspect `any` would make a simple declaration
silently perform runtime type erasure. Braces make `any`, `variant`,
user-defined choices, and polymorphic classes share the same visible runtime
boundary. The mechanism differs by subject: `any` uses its open-choice
protocol, while polymorphic classes retain `dynamic_cast` semantics.

## Why non-viability is not `false`

An earlier model made a non-viable dependent single-pattern test evaluate to
`false`. This was convenient for shape detection but conflated two questions:

- can the operation be formed?
- does this runtime value match?

C++ normally answers the first with `requires` and the second with a Boolean
expression. R6 follows that separation. This also prevents a typo in a required
pattern condition from silently selecting `else`.

An explicit `match requires` mode was explored for dependent cases. It makes
structural generic dispatch convenient, but creates two nearly identical match
forms and does not remove the need to distinguish inapplicability from failure
of a selected declaration initialization. R6 instead gives dependent case
matching its own case-instantiation rules and keeps required single-pattern
conditions strict.

This is a deliberate change from the strict static-condition rule explored in
R5. That rule caught mistakes such as a string literal in a character match:

```cpp
template<class Operator>
void evaluate(const Operator& op) {
  op.kind() match {
    case '+' => add();
    case '-' => subtract();
    case "/" => divide(); // probably meant '/'
    default => unknown();
  };
}
```

If `op.kind()` is dependent, R6's case-instantiation model can classify
the erroneous case as inapplicable for a specialization whose result is
`char`. That flexibility is necessary for generic projected cases over a
dependent choice, but it weakens typo detection. The strict single-pattern
form and an explicit `requires` expression retain a way to ask the viability
question. Whether dependent case matching needs an additional opt-in
strict mode remains a design question worth presenting to EWG.

## Why by-value patterns remain permitted

Reference-only declarations would simplify failed-case mutation and permit more
aggressive projection reuse, but would prevent a selection case from naturally
consuming its subject. C++ already exposes moved-from states and does not roll
back failed control-flow conditions. R6 keeps by-value declarations and makes
their ordering explicit.

## Why guards require parentheses

`match` binds more tightly than ordinary binary operators. Without delimiters,
a guard such as:

```cpp
value match case [int x, int y] if x == y
```

could be read according to operator precedence as though only `x` were the
guard and `== y` followed the complete match. Requiring parentheses makes the
boundary explicit:

```cpp
value match {
  case [int x, int y] if (x == y) => equal(x);
  default => different();
};
```

It also admits the full condition grammar, including init-statements and
condition declarations, without inventing another unparenthesized expression
boundary. The pattern-first direct condition uses a different solution:
top-level `&&` separates later conditions, so it does not accept a case-style
trailing guard.

## Why there is no multi-subject grammar

Earlier revisions explored matching a braced list directly:

```cpp
// Not proposed.
{a, b} match {
  case [0, 0] => origin();
  default => elsewhere();
};
```

At block scope, the leading `{` introduces a compound statement. Wrapping the
form in parentheses collides with the long-standing GNU statement-expression
extension accepted by Clang and GCC. A parenthesized comma-list alternative
would retain surprising interactions with the comma operator and unary
operators.

C++ already has explicit product constructors whose value categories are
clear:

```cpp
std::forward_as_tuple(lhs, rhs) match {
  case [P1, P2] => first();
  case [P3, P4] => second();
};
```

R6 therefore continues the R3 decision not to add a second multi-subject
grammar. This does not prevent a future tuple-expression facility from being
used as a match subject.

## Operator precedence

R6 retains R5's placement between pointer-to-member and multiplicative
operators. The simple rule is that `match` binds more tightly than every binary
operator except pointer-to-member:

| Input | Parse |
|---|---|
| `*a match { ... }` | `(*a) match { ... }` |
| `a.*b match { ... }` | `(a.*b) match { ... }` |
| `a * b match { ... }` | `a * (b match { ... })` |
| `a + b match { ... }` | `a + (b match { ... })` |
| `a <=> b match { ... }` | `a <=> (b match { ... })` |
| `a == b match { ... }` | `a == (b match { ... })` |
| `a && b match { ... }` | `a && (b match { ... })` |

Matching the result of a binary expression therefore requires parentheses:

```cpp
(a + b) match {
  case 0 => zero();
  default => nonzero();
};

(a <=> b) match {
  case strong_ordering::less    => less();
  case strong_ordering::equal   => equal();
  case strong_ordering::greater => greater();
};
```

Placing `match` between spaceship and relational operators was considered. It
would make arithmetic and `<=>` subjects shorter, but creates a less uniform
rule and can make a parenthesized subexpression unexpectedly absorb an outer
operator. The selected precedence is easier to state and asks users to
parenthesize binary subjects.

## The `=>` separator

[@P2971R2] proposes an implication operator using the same token. If that work
is adopted, `=>` should remain the case separator in the syntactically delimited
match-case context. An implication expression can still be used as a pattern by
parenthesizing it:

```cpp
value match {
  case condition => consequence => handler();
  case (condition => consequence) => matched_implication();
};
```

The first line parses as a pattern `condition` followed by an implication
expression handler. This follows the general rule that a rare expression which
conflicts with the pattern boundary can be parenthesized. `->`, `:`, and a new
token such as `~>` were considered, but do not offer a compelling improvement:
`->` has the same issue, `:` is already heavily used by choice names and
labels, and a new token would be unfamiliar.

## Deferred pattern facilities

The following remain strong candidates for later work:

- static type subjects, including reflection values;
- named aggregate decomposition such as `[.x: P, .y: Q]`;
- or-patterns and range patterns;
- whole-value binding combined with a nested pattern;
- dynamic slice and sequence patterns;
- a generalized irrefutable declaration such as
  `attribute-seq auto attribute-seq case P = E`.

Nested structured bindings are being developed separately. They are useful
independently of pattern matching and provide the declaration analogue of
recursive structural patterns.

## Generalized irrefutable declarations

A declaration such as:

```cpp
[[declaration_attribute]]
auto [[type_attribute]] case P = expression;
```

would provide an unambiguous boundary between declaration specifiers and a
general pattern. As a standalone declaration, `P` would have to be statically
irrefutable. Nested structured bindings already cover the common recursive
product case, while refutable value, alternative, dynamic-type, and guarded
patterns belong naturally in `if (case P = E)` or `match`.

The remaining unique benefit is mostly one-statement mixed binding, such as a
copy for one component and a reference for another. That does not currently
justify another declaration form, so the syntax is reserved for future work.

## Other extensions considered

### Pattern combinators

Or-patterns can merge cases that have the same behavior:

```cpp
direction match {
  case 'N' => vertical();
  case 'S' => vertical();
  case 'E' => horizontal();
  case 'W' => horizontal();
};
```

A future combinator could express the grouping directly:

```cpp
direction match {
  case or('N', 'S') => vertical();
  case or('E', 'W') => horizontal();
};
```

The difficult part is not the spelling but binding semantics. Every branch of
an or-pattern must introduce a compatible set of names, types, and value
categories. R6 leaves that design independent rather than weakening
composition to avoid it.

### Named aggregate decomposition

Positional decomposition is awkward when only a few members matter or when
layout order is not the semantic interface. A future extension could use
designators:

```cpp
point match {
  case [.x: 0, .y: 0] => origin();
  case [.x: int x, .y: int y] => use(x, y);
};
```

The leading dot is intentionally parallel to designated initialization. It is
also why named choice alternatives use `{ .name: P }`: the braces distinguish
choice-state lookup from future member lookup in square brackets.

### Typed recursive choice selection

R5's `T: P` could both select a nominal alternative and recursively match its
payload. R6 retains that operation inside the explicit projection boundary:

```cpp
command match {
  case { ChangeColor: [{ Rgb: [auto r, auto g, auto b] }] } =>
    use_rgb(r, g, b);
  case { ChangeColor: [{ Hsv: [auto h, auto s, auto v] }] } =>
    use_hsv(h, s, v);
};
```

For closed choices, a type selector considers each projectable state whose
projection admits `T`; duplicate matching states produce separate semantic
case instantiations. For an open choice, `T` supplies the requested cast type.
For a polymorphic current subject, it requests `dynamic_cast`-equivalent
refinement before matching `P`.

An expression selector is positional rather than a value test:

```cpp
variant<int, int> value;

value match {
  case { 0: auto first } => use_first(first);
  case { 1: auto second } => use_second(second);
};
```

The selector shall be an integral constant expression in range for the closed
choice, and the selected state shall be projectable. Open choices have no
positional index selector.

### Static type subjects

Static dispatch does not need to overload value declaration patterns. A type
subject could instead use ordinary type patterns:

```cpp
T match {
  case int => integral_case();
  case double => floating_case();
  default => fallback();
};
```

C++26 reflection suggests an additional spelling over reflections:

```cpp
^^T match {
  case ^^int => integral_case();
  case ^^double => floating_case();
  default => fallback();
};
```

The lookup, constraint, and reflection models should be designed together.
R6 does not need static type subjects to provide dependent value matching.

### Reflection-based customization

Earlier revisions considered replacing tuple-like and variant-like library
protocols with reflection-based maps. For example, an encapsulated record
could advertise reflected accessors rather than `tuple_size`, `tuple_element`,
and `get<I>` specializations. A closed choice could similarly advertise
reflected alternatives.

That direction may eventually produce a more declarative protocol, but it
should be informed by deployed C++26 reflection practice. R6 therefore uses
existing structured-binding machinery for products and a conventional traits
protocol for choices.


# Design Decisions and Discussions

::: note
This section preserves the detailed design record from R5. Where R6 changes a
conclusion, the current direction is described in [R6 Design Rationale and
Alternatives] and the R5 discussion below remains as history and motivation.
The examples in this section are being updated incrementally.
:::

## Unified `match` Expression

The `match` expression presented in this paper unifies the syntax for a single
pattern match and a selection of pattern matches. Namely,
`@*expr*@ match @*pattern*@` and `@*expr*@ match { ... }`.

The single pattern match `@*expr*@ match @*pattern*@` is very similar to
`@*expr*@ is @*pattern*@` introduced in [@P2392R2].

Early attempts at pattern matching with `inspect` also explored the idea of
being a statement and an expression depending on its context. In short, if it
appears in an expression-only context (e.g. `int x = inspect { ... };`) then
it's an expression. If it appears in a context where a statement or an expression
can appear (e.g. `{ inspect { ... } }`), then it's interpreted as a statement.

Having to differentiate between the statement-form and expression-form was
a novel situation with no other precedent in the language. Additionally,
whatever the keyword, it would've needed to be a *full* keyword. Maybe `inspect`
would've been okay, but something like `match` was not even a possibility.

With this approach, `match` is feasible as a context-sensitive keyword, and
and there is only an expression-form, which simplifies the design.

## Wildcard Pattern Syntax

This paper proposes `_` as the syntax for wildcard patterns. Note that this
is different from bindings that are introduced with the name `_`.

For example,

```cpp
e match {
    _ => // ...
//  ^ this is a wildcard
    let [_, _] => // ...
//       ^  ^ these are bindings
};
```

In the bindings case, the semantics are the same as [@P2169R4], which was
accepted for C++26. That is, a single declaration of `_` is usable but a use
after a redeclaration is ill-formed.

In the wildcard case, it is a special rule in that `_` can be an existing
variable. For example,

```cpp
int i = 101;
int _ = 202;

i match {
    _ => // 101 != 202 but _ is a wildcard, so this matches.
};
```

The recommended workaround is to use a guard:

```cpp
int i = 101;
int _ = 202;

i match {
    let x if (x == _) => // ...
};
```

- [@P1371R3] proposed `__` which was also the syntax recommended in [@P1110R0].
- [@P1469R0] proposed disallowing use of `_` as an identifier in the context
  of structured bindings, but this was rejected by EWG.
- [@P2392R2] proposed `_` as well.

This is a relatively small cost to get `_` as the wildcard pattern, given the
prevalence and scope of adoption of `_` across the industry.
Languages such as Python, Rust, Scala, Swift, C#, Erlang, Prolog, Haskell, OCaml
and many others already use `_`. Pattern matching facilities across different
languages do vary, but I'm not aware of *any* language that disagree on `_`.

## Why We Want Expressions in Patterns

If expressions are not supported at all, this would mean we couldn't do some of
the most simple operations that `switch` can handle. We should be able to at
the very least match integrals, strings, and enums.

So we need to allow expressions at least in *some* capacity. Let's say for
example we only allow literals. This would give us matching for integral and
string literals, but we wouldn't be able to match against `constexpr` variables
of integrals and strings.

It also doesn't get us enums, since enum values are not literals. We need
unqualified names to be able to access `enum` values, and qualified names
to be able to access `enum class` values.

At this point, we already basically have *primary-expression*. The question of
how to handle referring to existing names vs introducing new names have to be
addressed. Only allowing *primary-expression* rather than *constant-expression*
might still be useful or needed to avoid further grammar complications, but
the fundamental issue of existing vs new names I don't think could nor should
be avoided.


## Exploration of Variable Declaration Syntax for Alternative Pattern

The proposed syntax in this paper is

```cpp
@*type-id*@ : @*pattern*@
@*type-constraint*@ : @*pattern*@
```

Here's a simple example:

```cpp
std::variant<int, bool, std::string> parse(std::string_view);

parse(some_input) match {
  int: let i => // ...
  bool: let b => // ...
  std::string: let s => // ...
};
```

This looks more like `case` labels where the alternatives are listed and
the appropriate one is chosen. The corresponding value is then matched
with a nested pattern.

The absolute minimal syntax would be `std::string s`, which is rather
appealing but ultimately not what is proposed.

An example using this syntax might be something like:

```cpp
std::variant<int, bool, std::string> parse(std::string_view);

parse(some_input) match {
  int i => // ...
  bool b => // ...
  std::string s => // ...
};
```

**Question 1**: What **are** `i`, `b`, and `s`?

They certainly look like variable declarations, and I think it'll be too
surprising for them to be anything else. So let's for now assume that they
are variable declarations. In this case, they should probably used as a
general way to introduce new names within a pattern for binding purposes.
We want patterns to compose, so this applies to nested patterns as well,
but at the top-level this might look like:

```cpp
int parse_int(std::string_view);

parse_int(some_input) match {
  0 => // ...
  1 => // ...
  auto i => // use `i` which is `int` returned by `parse_int`
            // not 0 or 1
}
```

**Question 2**: How do you disambiguate `auto x` between `variant` itself vs
the alternative inside?

`std::variant` is a very unique sum type, in that you are able to handle the
"catch-all" case where you can generically access the value inside of it.

::: cmptable

## C++23

```cpp
std::visit(
  overload(
    [](int i) { /* ... */ },
    [](auto x) { /* ... */ }),
  parse(some_input));
```

## Variable Declaration Approach

```cpp
parse(some_input) match { // not proposed
  int i => // ...
  auto x => // ...
};
```

:::

In the variable declaration approach, what would `auto x` be? Is it the unhandled
alternatives of the variant, or is it the variant itself? Recall that in
the `parse_int` example from above, `auto i` was a binding to the whole value!

Note that for polymorphic types we could actually make this work since there's
no way to generically operate on the runtime value of a polymorphic type anyway.

```cpp
struct Shape { virtual ~Shape() = default; };
struct Circle : Shape { int radius; };
struct Rectangle : Shape { int width, height; };

const Shape& get_shape();

get_shape() match {
  const Circle& c => // runtime downcast to `Circle`.
  const auto& s => // `s` can't generically be `Triangle` or `Rectangle` anyway.
};
```

This is what C# does for example:

```c#
Shape get_shape();

get_shape() switch {
  Circle c => // runtime downcast to `Circle`
  var s => // `s` is the whole shape.
};
```

While this syntax would work for polymorphic types specifically, there is a
general desire to unify the handling of sum types like `variant` and
polymorphic types. For example, [@P2411R0] points out:

> The ‘is’-and-‘as’ notation [P2392] is cleaner and more general than the
[P1371] and successors notation. For example, it eliminates the need to use
the different notation styles for variant, optional, and any access. Uniform
notation is the backbone of generic programming.

[@P1371R3] already had uniform notation at least for `variant`, `any` and
polymorphic types, but regardless, the point is that using syntax that works
only for polymorphic types but not `variant` is not desired.

**Question 3**: Initialization? Conversions? First-match? Best-match?

Going back to the first example:

```cpp
std::variant<int, bool, std::string> parse(std::string_view);

parse(some_input) match {
  int i => // ...
  bool b => // ...
  std::string s => // ...
};
```

Are these variable declarations initialized by direct-initialization,
copy-initialization, list-initialization, something else? Having to answer
this question isn't necessarily a blocker, but one needs to be chosen.

Regardless of the answer though, there's no initialization form that disallows
conversions in general. If these have first-match semantics (the only form of
matching that has been proposed so far), `int i` would match if the variant
is in the `bool` state, since all of these are valid:

```cpp
int i1(true); // direct
int i2 = true; // copy
int i3{true}; // list
int i4 = {true}; // copy-list
```

On the other hand, best-match semantics would introduce significant complexity.
Value-matching needs to consider becoming best-match, and this would likely
mean evaluating more than necessary in order to compute a score to best-match
with. If value-matching remained first-match, then we would have best-match
semantics weaved info first-match semantics. This is likely very difficult for
users.

Note that even with best-match semantics, allowing conversions makes code like
this difficult to diagnose missing cases:

```cpp
parse(some_input) match {
  int i => // ...
  std::string s => // ...
  // maybe missing bool case? it is covered by `int` though...
};
```

**Question 4**: How do we match against an existing value?

Variable declaration syntax isn't conducive to referring to an existing value.
Suppose there is a constexpr value `batch_size` that we want to match against.
`int batch_size` wouldn't work since that would be introducing a new variable.
`batch_size` could be annotated somehow, but annotating existing names rather
than the new names has already been attempted.

More generally, variable declaration syntax isn't conducive to composition.

---

With this paper, the first example would be written as:
 
```cpp
std::variant<int, bool, std::string> parse(std::string_view);

parse(some_input) match {
  int: let i => // ...
  bool: let b => // ...
  std::string: let s => // ...
};
```

1. `i`, `b`, and `s` are bindings, introduced by `let`.
2. How do you disambiguate `auto x` between `variant` itself vs the alternative inside?

With this paper, `let x` binds the whole value, whereas `auto: let x` binds to the value
inside the variant. The following is an example of `let x` binding the whole value:

```cpp
int parse_int(std::string_view);

parse_int(some_input) match {
  0 => // ...
  1 => // ...
  let i => // use `i` which is `int` returned by `parse_int`
           // not 0 or 1
}
```

The following is an example of `auto: let x` where we bind the alternative
inside the variant.

::: cmptable

```cpp
std::visit(
  overload(
    [](int i) { /* ... */ },
    [](auto x) { /* ... */ }),
  parse(some_input));
```

```cpp
parse(some_input) match {
  int: let i => // ...
  auto: let x => // x is bool or string
};
```

:::

3. Initialization? Conversions? First-match? Best-match?

Initialization and conversions are dictated by the rules and principles of
bindings as introduced by structured bindings.

The problem of first-match vs best-match is solved by requiring an
**exact-match** for alternative types. With exact-match, first-match
and best-match become equivalent.

::: cmptable

## Variable Declaration Approach

```cpp
parse(some_input) match {
  int i => // ...
  std::string s => // ...
  // missing bool case, but covered by `int`.
};
```

## This Paper

```cpp
parse(some_input) match {
  int: let i => // ...
  std::string: let s => // ...
  // error: missing bool case
};
```

:::

To be precise, the type to the left of the `:` is used to match an alternative
**as declared**. This is similar to how `std::get` works. For example:

```cpp
void f(std::variant<const int, std::string> v) {
  v match {
    const int: let i => // `const int` is required here.
    std::string: let s => // ...
  };
}
```

## Discussion on Variant-like Types

We have a few variant-like facilities: `optional`, `expected`, and `variant`.
Type-based alternative matching for `std::variant` seems pretty obvious.

```cpp
void f(std::variant<int, std::string> v) {
  v match {
    int: let i => // ...
    std::string: let s => // ...
  };
}
```

The `int` and `string` are the states that a `variant<int, std::string>` can be
in, and facilities such as `holds_alternative<int>` and `get<int>` clearly
provide type-based access to `variant`.

Of course, in general there's more to it. The `variant` could be in a
valueless-by-exception state, or we can have `std::variant<T, T>`.
Let's table these for now.

The `? @*pattern*@` specifically supports the pointer-like usage pattern,
so we can write:

```cpp
void f(int* p) {
  p match {
    ? let i => // ...
    nullptr => // ...
  };
}
```

`optional` and `expected` are "`variant`-like" in that they have "one-of" states.
However, their interfaces are not `std::variant`-like at all. They carry much
more semantic implications. `optional<T>` behaves more like `T` than
`variant<std::nullopt_t, T>` would. `expected<T, E>` behaves more like `T` than
`E`, and again, more like `T` than `variant<T, E>` would. Their interfaces are
also pointer-like rather than `std::variant`-like.

Given this, it seems natural enough to match on an `optional` like this:

```cpp
void f(std::optional<int> o) {
  o match {
    ? let i => // ...
    std::nullopt => // ...
  };
}
```

A `std::variant`-like approach would look like this:

```cpp
void f(std::optional<int> o) {
  o match {
    int: let i => // ...
    std::nullopt_t: _ => // ...
  };
}
```

Here, if we changed `std::optional<int>` to say, a `std::optional<double>`
the `int: let i` pattern would be ill-formed, whereas the `?` would continue
to work. This is consistent with the usage of `optional` today:

```cpp
void f(std::optional<int> o) {
  // no mention of `int` in the below usage.
  if (o) {
    use(*o);
  } else {
    // ...
  }
}
```

**Open Question**: For exhaustiveness checking purposes, matching with `?` then
`_` will always be sufficient. But this means `?` will need to be matched first.
For types like `T*` and `unique_ptr`, it should be possible to say matching with
`?` and `nullptr` is exhaustive, and `nullptr` can be matched first as well.
For `optional` though, the null state is `std::nullopt`. To use `nullptr` for
this seems wrong, given that `optional` design explicitly introduced `nullopt`
over using `nullptr` itself. The solution in [@P2392R2] is to introduce
`is void`, but this seems problematic at least for `expected<void, error>`
where the question becomes ambiguous.

But `expected<T, E>` gets more tricky. The "no value" case is not just
some sentinel type/value, but is some type `E` retrieved by `.error()`.

```cpp
void f(std::expected<int, parse_error> e) {
  e match {
    ? let i => // ...
    // How do we match and access `.error()` ?
  };
}
```

So perhaps a `variant`-like approach would be better here:

```cpp
void f(std::expected<int, parse_error> e) {
  e match {
    int: let i => // ...
    parse_error: let err => // ...
  };
}
```

This seems simple and clean enough. Similar to `variant` however, we can have
`expected<T, T>`. Unlike `variant` though, it actually goes out of its way
to store a `std::unexpected<T>` as the error state to distinguish the two.
It's conceivable to use this unexpected type to support `expected<T, T>`:

```cpp
void f(std::expected<int, int> e) {
  e match {
    int: let i => // ...
    std::unexpected<int>: let err => // distinguish
  };
}
```

But that would really hinder the by-far more common use cases:

```cpp
void f(std::expected<int, parse_error> e) {
  e match {
    int: let i => // ...
    std::unexpected<parse_error>: let err => // yuck
  };
}
```

It was considered to allow matching `std::expected<T, T>` with `T` and
`std::unexpected<T>` while matching `std::expected<T, E>` with `T` and `E`.
But it's a bit weird for `std::unexpected<E>` to then not work at all, and
also weird for `err` in `std::unexpected<E>: let err` to not be a binding to
a `std::unexpected<E>`, but rather a binding to a `E`. A reference to the
underlying `std::unexpected<E>` is also not an interface that `std::expected`
exposes. Furthermore, this wouldn't solve the problem of `variant<T, T>` in a
consistent manner. At best it'd be a special case for `std::expected`.

Ideally, `value` and `error` would be **names** associated to the **types** `T`
and `E`, such that they can be used even when `T` and `E` are the same, and are
stable even when `T` and `E` changes.

This is essentially how the `Result` type in Rust is defined, as well as
many other languages that provide similar functionalities.

```rust
enum Result<T, E> {
  Ok(T),
  Err(E),
}
```

This is matched like this:

```rust
match parse(some_input) {
  Ok(v) => // use `v`
  Err(err) => // use `err`
}
```

A few approaches were considered to emulate this "name-based" dispatch.

1. Introduce a parallel `enum class` with the desired names.

```cpp
enum class expected_state { value, error };

template <typename T, typename E>
class expected {
  // ...

  expected_state index() const {
    return has_value() ? expected_state::value : expected_state::error;
  }

  template <expected_state S>
  auto&& get(this auto&& self) {
    if constexpr (S == expected_state::value) {
      return *std::forward<decltype(self)>(self);
    } else if constexpr (S == expected_state::error) {
      return std::forward<decltype(self)>(self).error();
    } else {
      static_assert(false);
    }
  }
};

template <typename T, typename E>
struct variant_size<expected<T, E>> : std::integral_constant<std::size_t, 2> {};

template <typename T, typename E>
struct variant_alternative<(std::size_t)expected_state::value, expected<T, E>> {
  using type = T;
};

template <typename T, typename E>
struct variant_alternative<(std::size_t)expected_state::error, expected<T, E>> {
  using type = E;
};
```

The usage would need to be something along the lines of:

```cpp
std::expected<int, parse_error> parse(std::string_view sv);

void f() {
  parse(some_input) match {
    using enum std::expected_state;
    value: let v => // ...
    error: let err => // ...
  };
}
```

While the introduction of `std::expected_state` seems a bit odd on first glance,
it actually doesn't seem any more odd than other related helper types such
as `std::in_place_t`, `std::unexpect_t`, `std::unexpected`, etc.

2. Use the existing tag types

We already have tag types, and they roughly correspond with the various states.
For example, `std::expected` uses `std::in_place_t` and `std::unexpect_t`.

```cpp
void f(std::expected<int, parse_error> e) {
  e match {
    std::in_place_t: let v => // ...
    std::unexpect_t: let err => // ...
  };
}
```

The names `std::in_place_t` and `std::unexpect_t` are terrible substitute for
`value` and `error`. We'd be better off with just using the types directly,
and not fully supporting the `std::expected<T, T>` case.

3. Use the reflection of the accessors as the tags

This idea would be to come up with a new variant-like protocol using reflection.
If a type let's say were to advertise its alternatives through
`std::vector<std::meta::info>`, and we use those as the tags for dispatching...

```cpp
template <typename T, typename E>
struct expected {
  static consteval std::vector<std::meta::info> alternatives() {
    return { ^value, ^error };
  }

  constexpr const T& value() const&;
  constexpr const E& error() const& noexcept;
  // other qualified versions...
};
```

With this, perhaps we could pull off something like:

```cpp
void f(std::expected<int, parse_error> e) {
  e match {
    e.value: let v => // ...
    e.error: let err => // ...
  };
}
```

I think this is a very interesting direction for both tuple-like and
variant-like protocols, but I haven't been able to flesh out the details.
See [Reflection-based Tuple-like and Variant-like Customization Points].

In the end, the suggested path for now is:

::: cmptable

## `T*`
```cpp
ptr match {
  ? let x => // ...
  nullptr => // ...
};
```

## `std::optional<T>`
```cpp
opt match {
  ? let x => // ...
  std::nullopt => // ...
};
```

:::

::: cmptable

## `std::expected<T, E>`
```cpp
e match {
  T: let v => // ...
  E: let err => // ...
};
```

## `std::variant<T, U>`
```cpp
v match {
  T: let t => // ...
  U: let u => // ...
};
```

:::

## Reflection-based Tuple-like and Variant-like Customization Points

"Tuple-like" customization today involves specializing `std::tuple_size`,
`std::tuple_element`, and implementing a `get<I>` function. Section 2.3.6
"Cleaner form for structured bindings' "tuple-like" customization" from
[@P2392R2] has a good summary of the problem.

It also also says:

> If we want to go further, then as Bjarne Stroustrup points out,
> the logical minimum is something like this, which can be viewed as a jump
> table (similar to a vtbl) – the most general form, ideally provided by the
> class author:
>
> ```cpp
>   structure_map (EncapsulatedRect) { topLeft, width, height };
> ```

and as Bjarne Stroustrup points out in [@P2411R0]:

> The mapping from an encapsulating type to a set of values used by pattern
> matching must be simple and declarative. The use of `get<>()` for structured
> binding is an expert-only mess. Any code-based, as opposed to declarative,
> mapping will have such problems in use and complicate optimization. We can do
> much better. 

Perhaps this problem can be tackled with reflection.

```cpp
struct EcapsulatedRect {
  static consteval std::vector<std::meta::info> elements() {
    return { ^topLeft, ^width, ^height };
  };

  Point topLeft() const;
  int width() const;
  int height() const;
};
```

The advantage of this is that we can put data members as well as member
functions into `elements` as opaque reflections and apply them when needed.

Similarly, it seems feasible for there to be a reflection-based variant-like
protocol as well.

```cpp
template <typename... Ts>
struct variant {
  static consteval std::vector<std::meta::info> alternatives() {
    return { ^Ts... };
  };

  // ...
};
```

Note that for tuple-like protocol, even if we were to come up with something
better, I think we'll still have to continue supporting the current protocol.
There are types written that opted into that protocol that use structured
bindings and `std::apply` and other things today.

Variant-like protocol is actually a different story. Unlike tuple-like protocol,
The variant helpers such as `std::variant_size`, `std::variant_alternative` are
solely used by `std::variant`. `std::visit`, the only thing that might already
be using a "variant-like protocol" does not support non-`std::variant`s.
It does support types that directly inherit from `std::variant` [@P2162R2],
but they work by being converted into `std::variant` beforehand.

As such, there's a bigger opportunity for variant-like protocol to not bless
the existing set of facilities but to come up with something better.

**Update R2**: This paper proposes to go with the existing facilities for now.
While this direction is interesting, it is likely better to gain experience
with reflection in C++26 before really coming up with a solution to supersede
the existing facilities.

## More on Static Conditions

This is an elaboration of the discussion from [Static Conditions].
The question is: how are the requirements and validity of patterns handled?
The proposed solution in this paper is for the static conditions to always
be checked. For templates, this means the they are checked at instantiation.

Another approach is for some patterns to allow to be invalid if the *subject*
is a dependent value. Since in this case, the pattern **can be** valid under
some instantiations.

This can be made to work, and would certainly useful. As the default behavior
however, it seems like it will likely cause subtle bugs.

Consider an example like this:

```cpp
template <typename Operator>
void f(const Operator& op) {
  op.kind() match {
    '+' => // ...
    '-' => // ...
    '*' => // ...
    "/" => // ...
    _ => throw UnknownOperator{};
  };
}
```

Let's say `op.kind()` returns a `char`, but we can't be sure of that since `op`
is templated. With the approach in this proposal, the typo of `"/"`
(should be `'/'`!) will be detected as a compile-time error. In a model where
a pattern can be invalid because the *subject* is dependent, this will likely
be well-formed, fallthrough to the `_` case, and throw an exception at runtime.

It's true that this function should probably be better constrained using concepts,
but the reality is that this kind of code is extremely prevalent today.
Note that just using `if`, we would have been provided this safety:

```cpp
template <typename Operator>
void f(const Operator& op) {
  if (op.kind() == '+') {
    // ...
  } else if (op.kind() == '-') {
    // ...
  } else if (op.kind() == '*') {
    // ...
  } else if (op.kind() == "/") { // error: comparison between pointer and integer
    // ...
  } else {
    throw UnknownOperator{};
  }
}
```

[Testing the Static Conditions with `match requires`] is described as a future
extension where users can explicitly opt in to relax this requirement on
*static conditions*.

## Operator Precedence of `match`

### Proposed Solution: Between Pointer-to-member and Multiplicative Operator

The proposed solution in this paper is for `match` to have a precedence between
pointer-to-member operators [expr.mptr.oper]{.sref} and multiplicative operators
[expr.mul]{.sref}. This is consistent with the approach proposed for the `is`
operator in [@P2392R2], and similar to the precedence of C# `switch` expression.

::: cmptable

## Input

```cpp
*@*a*@ match { /* ... */ }
@*a*@.*@*b*@ match { /* ... */ }
@*a*@ * @*b*@ match { /* ... */ }
@*a*@ + @*b*@ match { /* ... */ }
@*a*@ << @*b*@ match { /* ... */ }
@*a*@ <=> @*b*@ match { /* ... */ }
@*a*@ < @*b*@ match { /* ... */ }
@*a*@ == @*b*@ match { /* ... */ }
@*a*@ & @*b*@ match { /* ... */ }
@*a*@ && @*b*@ match { /* ... */ }
```

## Parsed

```cpp
(*@*a*@) match { /* ... */ }
(@*a*@.*@*b*@) match { /* ... */ }
@*a*@ * (@*b*@ match { /* ... */ })
@*a*@ + (@*b*@ match { /* ... */ })
@*a*@ << (@*b*@ match { /* ... */ })
@*a*@ <=> (@*b*@ match { /* ... */ })
@*a*@ < (@*b*@ match { /* ... */ })
@*a*@ == (@*b*@ match { /* ... */ })
@*a*@ & (@*b*@ match { /* ... */ })
@*a*@ && (@*b*@ match { /* ... */ })
```

:::

::: cmptable

## Input

```cpp
*@*a*@ match @*c*@
@*a*@.*@*b*@ match @*c*@
@*a*@ * @*b*@ match @*c*@
@*a*@ + @*b*@ match @*c*@
@*a*@ << @*b*@ match @*c*@
@*a*@ <=> @*b*@ match @*c*@
@*a*@ < @*b*@ match @*c*@
@*a*@ == @*b*@ match @*c*@
@*a*@ & @*b*@ match @*c*@
@*a*@ && @*b*@ match @*c*@
```

## Parsed

```cpp
(*@*a*@) match @*c*@
(@*a*@.*@*b*@) match @*c*@
@*a*@ * (@*b*@ match @*c*@)
@*a*@ + (@*b*@ match @*c*@)
@*a*@ << (@*b*@ match @*c*@)
@*a*@ <=> (@*b*@ match @*c*@)
@*a*@ < (@*b*@ match @*c*@)
@*a*@ == (@*b*@ match @*c*@)
@*a*@ & (@*b*@ match @*c*@)
@*a*@ && (@*b*@ match @*c*@)
```

:::

The main advantage of this approach is that the model is quite simple. The main idea is
"`match` binds tighter than any binary operator except pointer-to-member."
Pointer-to-member operators are excluded since many folks expect it to bind tighter than
they actually do.

There are a couple of other advantages worth mentioning. One is that this approach still
reads as expected with parentheses. Consider the following example:

```cpp
@*a*@ * (@*b*@ + @*c*@) match {
  0 => // ...
  1 => // ...
  _ => // ...
}
```

Here, I'd argue that `(@*b*@ + @*c*@)` looks like the match subject, and with this
precedence it is indeed the match subject.

Another advantage is that (though perhaps silly) it's typically less work to add
parentheses around the subject rather than around the whole `match`.

For example, given:

```cpp
@*a*@ + @*b*@ match {
  0 => // ...
  1 => // ...
  _ => // ...
}
```

Parenthesizing the subject is typically less work:

```cpp
(@*a*@ + @*b*@) match {
  0 => // ...
  1 => // ...
  _ => // ...
}
```

Compared to having to add them around the whole `match` like this:

```cpp
@*a*@ + (@*b*@ match {
  0 => // ...
  1 => // ...
  _ => // ...
})
```

The disadvantages of this approach is basically that if the desired semantics are
to match against the result of `@*a*@ + @*b*@`, parentheses are required.

```cpp
(@*a*@ + @*b*@) match {
  0 => // ...
  1 => // ...
  _ => // ...
}
```

Similarly, another use case is to match against the result of `<=>`,
which also need parentheses:

```cpp
(@*a*@ <=> @*b*@) match {
  std::strong_ordering::equal => // ...
  std::strong_ordering::less => // ...
  std::strong_ordering::greater => // ...
}
```

Another disadvantage is the deviation from `==` in the `@*expr*@ match @*expr*@` form:

::: cmptable

## Input

```cpp
@*a*@ + @*b*@ == @*c*@
@*a*@ + @*b*@ match @*c*@
```

## Parsed

```cpp
(@*a*@ + @*b*@) == @*c*@
@*a*@ + (@*b*@ match @*c*@)
```

:::

Despite the disadvantages, this paper proposes the simplified model, and users
are expected to "parenthesize binary expressions".

### Alternative Considered: Between Spaceship and Relational Operator

This approach is to have the `match` precedence between the three-way
comparison operator [expr.spaceship]{.sref} and relational operators
[expr.rel]{.sref}.

The main idea here is that `<=>` and above, e.g. `*`, `+`, etc yield interesting
values to match, whereas `<` and below, e.g. `==`, `&`, etc yield a boolean
values which are typically less interesting.

This approach addresses some of the disadvantages mentioned in the previous section.

```cpp
@*a*@ + @*b*@ match {
  0 => // ...
  1 => // ...
  _ => // ...
}
```

```cpp
@*a*@ <=> @*b*@ match {
  std::strong_ordering::equal => // ...
  std::strong_ordering::less => // ...
  std::strong_ordering::greater => // ...
}
```

The disadvantage here is that the above examples may give a "false sense of
security". If one wants to match on the result of say, `@*a*@ < @*b*@`,
parentheses are still required:

```cpp
(@*a*@ < @*b*@) match {
  true => ...
  false => ...
}
```

However, these use cases are likely to be less common than the above cases.
Furthermore, we do not want to go much lower than this. Examples such as
`@*a*@ == @*b*@ && @*x*@ match { /* ... */ }` are relatively common, and
the desired parsing is `(@*a*@ == @*b*@) && (@*x*@ match { /* ... */ })`.
Especially for the `@*expr*@ match @*expr*@` form, given
`@*a*@ && @*b*@ match @*c*@` it's more likely we want `@*a*@ && (@*b*@ match @*c*@)`.

As mentioned in the previous section, this approach could cause some confusion
in the face of parenthesized expressions. For example,

```cpp
@*a*@ * (@*b*@ + @*c*@) match {
  // ...
}
```

This would parse as

```cpp
(@*a*@ * (@*b*@ + @*c*@)) match {
  // ...
}
```

which could be surprising.

::: cmptable

## Input

```cpp
*@*a*@ match { /* ... */ }
@*a*@.*@*b*@ match { /* ... */ }
@*a*@ * @*b*@ match { /* ... */ }
@*a*@ + @*b*@ match { /* ... */ }
@*a*@ << @*b*@ match { /* ... */ }
@*a*@ <=> @*b*@ match { /* ... */ }
@*a*@ < @*b*@ match { /* ... */ }
@*a*@ == @*b*@ match { /* ... */ }
@*a*@ & @*b*@ match { /* ... */ }
@*a*@ && @*b*@ match { /* ... */ }
```

## Parsed

```cpp
(*@*a*@) match { /* ... */ }
(@*a*@.*@*b*@) match { /* ... */ }
(@*a*@ * @*b*@) match { /* ... */ }
(@*a*@ + @*b*@) match { /* ... */ }
(@*a*@ << @*b*@) match { /* ... */ }
(@*a*@ <=> @*b*@) match { /* ... */ }
@*a*@ < (@*b*@ match { /* ... */ })
@*a*@ == (@*b*@ match { /* ... */ })
@*a*@ & (@*b*@ match { /* ... */ })
@*a*@ && (@*b*@ match { /* ... */ })
```

:::

::: cmptable

## Input

```cpp
*@*a*@ match @*c*@
@*a*@.*@*b*@ match @*c*@
@*a*@ * @*b*@ match @*c*@
@*a*@ + @*b*@ match @*c*@
@*a*@ << @*b*@ match @*c*@
@*a*@ <=> @*b*@ match @*c*@
@*a*@ < @*b*@ match @*c*@
@*a*@ == @*b*@ match @*c*@
@*a*@ & @*b*@ match @*c*@
@*a*@ && @*b*@ match @*c*@
```

## Parsed

```cpp
(*@*a*@) match @*c*@
(@*a*@.*@*b*@) match @*c*@
(@*a*@ * @*b*@) match @*c*@
(@*a*@ + @*b*@) match @*c*@
(@*a*@ << @*b*@) match @*c*@
(@*a*@ <=> @*b*@) match @*c*@
@*a*@ < (@*b*@ match @*c*@)
@*a*@ == (@*b*@ match @*c*@)
@*a*@ & (@*b*@ match @*c*@)
@*a*@ && (@*b*@ match @*c*@)
```

:::

While this makes `match` more consistent with `==`, e.g. for `+`, but
there remain deviations.

::: cmptable

## Input

```cpp
@*a*@ + @*b*@ == @*c*@
@*a*@ + @*b*@ match @*c*@
@*a*@ < @*b*@ == @*c*@
@*a*@ < @*b*@ match @*c*@
```

## Parsed

```cpp
(@*a*@ + @*b*@) == @*c*@
(@*a*@ + @*b*@) match @*c*@
(@*a*@ < @*b*@) == @*c*@
@*a*@ < (@*b*@ match @*c*@)
```

:::

Lastly, a code search for `match` on boolean values in Rust code on GitHub
showed that this use case is actually quite popular. This was a bit of a
surprise, as Rust already supports `if` expressions which could be used for
the same purpose. This finding also weakened the assumption the main argument
behind the approach.

## Require Parentheses on Match Guards

As discussed in [Operator Precedence of `match`], this paper proposes `match` to
bind tighter than all binary operators except pointer-to-member.

```cpp
1 + 2 match 3 + 4
// parsed as:
1 + (2 match 3) + 4
```

Consider adding a match guard to this expression. Pre-R3 of this paper,
match guards did not require parentheses.

```cpp
bool b = p match let [x, y] if x == y;
```

If we apply the same precedence however, this would be parsed as:

```cpp
bool b = p match let [x, y] if x == y;
// parsed as:
bool b = (p match let [x, y] if x) == y;
```

This is considerably worse than the `match` scenario since it's much more likely for
match guard conditions to be boolean expressions involving logical operators.

The resolution of this in R3 is to require parentheses around the `if` like so:

```cpp
bool b = p match let [x, y] if (x == y);
```

Combining this with subsequent logical operators is unambiguous and easier to read:

```cpp
bool b = p match let [x, y] if (x == y) && pred();
// parsed as:
bool b = (p match let [x, y] if (x == y)) && pred();
```

The match guard inside of match select expressions do not have this problem,
since it is delimited by `=>`. However, the proposed solution is to keep
the two consistent, along with the rest of the language.

```cpp
p match {
  let [x, y] if (x == y) => // parens around `if` required.
  _ => // ...
}
```

This approach also makes it easier to bring match guards up to parity with
the existing `if` features such as condition variables and init-statements.

```cpp
p match {
  let [x, y] if (bool b = x == y) => // `b` available here
  let [x, y] if (auto a = f(x, y); g(a)) =>
    // init-stmt for `a`, guard condition is `g(a)`.
  _ => // ...
}
```

## Matching Multiple Values

In R3, the decision is to remove explicit support for matching multiple values.
The proposal instead relies on existing `std::tuple` facilities such as `std::tie`,
`std::forward_as_tuple`, and `std::tuple` construction using class template
argument deduction.

### Problem with the *braced-init-list* Syntax

In previous versions of the proposal, the proposed syntax was to use
*braced-init-list* like so:

```cpp
int f(int a, int b) {
  return {a, b} match { // produces an implicit struct that can be
    [1, 2] => 0; // matched with the structured bindings pattern.
    let [x, y] => 1;
  };
}
```

There is a major drawback however at *statement-or-expression* contexts
such as block scope:

```cpp
void f(int a, int b) {
  {a, b} match { // the `{` introduces a compound statement
    [0, 0] => [] { std::print("on origin"); }();
    _ => [] { std::print("not on origin"); }();
  };
}
```

The suggested workaround for this problem was instead to parenthesize
the whole expression:

```cpp
void f(int a, int b) {
  ({a, b} match { // kick us into expression-only syntax.
    [0, 0] => [] { std::print("on origin"); }();
    _ => [] { std::print("not on origin"); }();
  });
}
```

However, during implementation I encountered another issue where the `({` actually
introduces a [Statement Expression](https://gcc.gnu.org/onlinedocs/gcc/Statement-Exprs.html)
in GCC and Clang. This is a very old and prevalent extension, that GCC and Clang
both have enabled by default.

Unlike in block-scope, This problem is not limited to *statement-or-expression*
contexts, but anywhere within an expression:

```cpp
bool f(int a, int b) {
  return !({a, b} match [0, 0]); // the `({` introduces a statement-expression
}
```

A possible disambiguation strategy has been suggested by Daveed Vandevoorde
where upon encountering the `({`, we can find the matching `}` and check if
the subsequent token is a `)` (statement-expression) or `match` (pattern match).

However, there are 3 main reasons this proposal still drops the feature.

  1. We have alternative solutions that work today using `std::tuple` facilities.
  2. This syntax can be added later. Consider an example like this:

     ```cpp
     x = {1, 2} match {
       [0, 0] => 0;
       _ => 1;
     };
     ```

     If this were to be parsed like this without the feature:
     ```cpp
     (x = {1, 2}) match {
       [0, 0] => 0;
       _ => 1;
     };
     ```

     This would be problematic, as it wouldn't be able to become the desired parse later.
     However, given the operator precedence of `match`, this should be ill-formed in
     the initial proposal, similar to how `x = {1, 2} + foo` is ill-formed today.

  3. The block-scope limitation is really unfortunate, and is the core reason why
     *braced-init-list* currently only appear in right side of structures.
     e.g. `return {1, 2};`, `co_yield {1, 2};`, `foo += {1, 2}`, etc.
     
     If this direction were to be taken, it seems it should be taken with consideration
     of other expressions as well. Considering relevant examples such as `({1, 2} + foo)`.

### Rejected Idea: Using Parentheses for Matching Multiple Values

Using parentheses instead of *braced-init-list* for matching multiple values was
also explored. This was an exciting possibility since it did not have the same
limitations at block scope:

```cpp
void f(int a, int b) {
  (a, b) match { // this is good! -- not proposed
    [0, 0] => [] { std::print("on origin"); }();
    _ => [] { std::print("not on origin"); }();
  };
}
```

A single parenthesized expression is still just that value:

```cpp
void f(int a, int b) {
  (a) match { // this is still just a parenthesized expression,
    1 => 0;   // so structured bindings pattern cannot be used.
    _ => 1;
  };
}
```

This is a bit awkward, since the *braced-init-list* did not have such oddity:

```cpp
void f(int a, int b) {
  bool _ = {a} match [1];       // braces always produces an implicit struct
  bool _ = {a, b} match [1, 2]; // so structured bindings pattern are always used.
  bool _ = (a) match 1;         // parentheses are always parenthesized expressions.
  bool _ = (a, b) match 1;      // effectively `b match 1` using comma operator.

  bool _ = (a) match 1;         // only multi-value parens introduce an implicit struct
  bool _ = (a, b) match [1, 2]; // so structured bindings pattern are sometimes used.
}
```

While this seemed like an acceptable trade-off given the value of the functionality,
the situation became more complicated with unary operators applied.

```cpp
void f(int a, int b) {
  -(a, b) match { // effectively `-b match { ... }`
    1 => 0;
    _ => 1;
  };
}
```

The suggested semantics in this case was for `-(a, b)` to maintain its meaning today,
that is, effectively `-b`. Similarly, `(a, b)++ match { ... }` would be effectively
`b++ match { ... }`. This makes the grammar and its interpretation rather complicated.
Several implementation concerns were raised as well.

## Note on the Implication Operator

[@P2971R2] proposes an `operator=>` which would introduce the same token `=>`,
and would allow expressions that look like `x => y`. It has been raised that
this may conflict with pattern matching's use of `=>`. While this is true,
I don't consider it to be a showstopper either way.

If EWG desires to adopt [@P2971R2], my proposed resolution for pattern matching
is to interpret `=>` as a pattern matching token in pattern matching context.
This is consistent with the treatment of other rare expressions that conflict
with patterns in this proposal.

```cpp
x match {
  _ => // wildcard, NOT a reference to an `_` in scope.
  let [x] => // structured bindings pattern with 1 element,
             // NOT an array-access into a variable `let`.
  a => b => c; // parsed as `a => (b => c);`
  (a => b) => c; // match against the result of `(a => b)`.
};
```

I suspect the desire to use the result of `a => b` as a pattern to be quite rare.

Another consideration is to use a different separation token for pattern matching.
Eight other languages that provide pattern matching and their separation tokens
were considered. Haskell, OCaml, and Java use `->`, Rust, Scala, and C# use `=>`,
Python and Swift use `:`.

`->` would present the exact same problem as `=>`. `:` may be visually confusing
given use cases such as

```cpp
v match {
  int: let i: 0;
  std::string: let s: 1;
};
```

compared to:

```cpp
v match {
  int: let i => 0;
  std::string: let s => 1;
};
```

A brand new token such as `~>` could work as well, though much less preferred.

# Future Extension Exploration

The following lists patterns and features excluded from this paper, but
could still be useful future extensions.

## Static Type Checking with Constraint Pattern

A constraint pattern could be used to perform static type checks.

> *type-constraint*

The static condition of a constraint pattern would be that
`decltype(@*subject*@)` satisfies the *type-constraint*.

For example, 

```cpp
void f(auto p) {
  p match {
    [std::convertible_to<int>, 0] => // statically check that first elem converts to int.
    // ...
  };
}
```

If used with structured bindings, this becomes very similar to the static type
checking proposed in [@P0480R1].

```cpp
auto [std::same_as<std::string> a, std::same_as<int> b] = f();
```

The syntax changes would be:

```diff
  @*match-pattern*@
      // ...
+     @*type-constraint*@
```

```diff
  @*binding-pattern*@
      // ...
+     @*type-constraint*@ @*identifier*@
```

## Testing the Static Conditions with `match requires`

The sections [Static Conditions] and [More on Static Conditions] described
what static conditions are. They also described why by default, `match` and
`match constexpr` should both always check the static conditions.

`match requires` (or some other spelling) would offer a way to test the static
conditions instead.

::: cmptable

## `match requires`

```cpp
void f(auto x) {
  x match requires { // not proposed
    0 => // ...
    "hello" => // ...
    _ => // ...
  };
}

f("hello"s); // fine, skips 0
```

## `if constexpr (requires { ... })`

```cpp
void f(auto x) {
  if constexpr (requires { x == 0; }) {
    if (x == 0) {
      // ...
      goto done;
    }
  }
  if constexpr (requires { x == "hello"; }) {
    if (x == "hello") {
      // ...
      goto done;
    }
  }
  // ...
  done:;
}
```

:::

Using the constraint pattern from [Static Type Checking with Constraint Pattern],
we can perform a sequence of static type tests.

```cpp
void f(auto x) {
  x match requires { // not proposed
    std::same_as<bool> => // ...
    std::integral => // ...
    std::same_as<std::string_view> => // ...
    std::range => // ...
  };
}
```

Using the `let` pattern, we can even bind names to each of these:

```cpp
void f(auto x) {
  x match requires { // not proposed
    std::same_as<bool> let b => // ...
    std::integral let i => // ...
    std::same_as<std::string_view> let sv => // ...
    std::range let r => // ...
  };
}
```

Another example with structured bindings patterns:

```cpp
void f(auto x) {
  x match requires { // not proposed
    let [x] => // ...
    let [x, y] => // ...
    let [x, y, z] => // ...
    let [...xs] => // ...
  };
}
```

Rather than the static condition (matching size requirement) of structured
bindings pattern being checked, they are `if constexpr` tested instead.

::: cmptable

## `match`

```cpp
if (@*condition*@) {
  // ...
}
```

## `match constexpr`

```cpp
// match constexpr
if constexpr (@*condition*@) {
  // ...
}
```

:::

::: cmptable

## `match requires` (not proposed)

```cpp
if constexpr (requires { @*condition*@ ; }) {
  if (@*condition*@) {
    // ...
  }
}
```

## `match requires constexpr` (not proposed)

```cpp
if constexpr (requires { @*condition*@ ; }) {
  if constexpr (@*condition*@) {
    // ...
  }
}
```

:::

## Pattern Combinators

Pattern combinators provide a way to succinctly combine multiple patterns.

> | ``or ( @*pattern-`0`{.default}*@ , @...@ , @*pattern-`N`*@ )``
> | ``and ( @*pattern-`0`{.default}*@ , @...@ , @*pattern-`N`*@ )``

Example:

::: cmptable

## This Paper

```cpp
direction match {
  'N' => f();
  'E' => g();
  'S' => f();
  'W' => g();
};
```

## With `or`:

```cpp
direction match {
  or('N', 'S') => f();
  or('E', 'W') => g();
};
```

---

```cpp
e match {
  A: let a => f();
  B: let b => f();
  C: let c => g();
};
```

```cpp
e match {
  or(
    A: let a,
    B: let b
  ) => f();
  C: let c => g();
};
```

:::

## Designator Support for Structured Bindings

This would extend structured bindings to allow designators (i.e. `.field_name`)
to match on that field.

```diff
  @*match-pattern*@
      // ...
+     [ @*designator-`0`{.default}*@ : @*pattern-`0`{.default}*@ , @...@ , @*designator-`N`*@ : @*pattern-`N`*@ ]
```

```diff
  @*binding-pattern*@
      // ...
+     [ @*designator-`0`{.default}*@ : @*binding-pattern-`0`{.default}*@ , @...@ @*designator-`N`*@ : @*binding-pattern-N*@ ]
```

Example:

```cpp
  return scope match {
    GlobalScope: _ => Cxx::Scope::global_();
    NamespaceScope: [.fact: let f] => Cxx::Scope::namespace_(f);
    ClassScope: [.fact: let f] => Cxx::Scope::recordWithAccess(f, access(acs));
    LocalScope: [.fact: let f] => Cxx::Scope::local(f);
//              ^^^^^^^^^^^^^^
  };
```

## Value-based discriminators

This would extend the alternative pattern to allow value-based discriminators.

```diff
  @*discriminator*@:
      @*type-id*@
      @*type-constraint*@
+     @*constant-expression*@
```

From [Discussion on Variant-like Types], the example of `enum` values `value`
and `error`:

```cpp
enum class expected_state { value, error };

std::expected<int, parse_error> parse(std::string_view sv);

void f() {
  parse(some_input) match {
    using enum std::expected_state;
    value: let v => // ...
    error: let err => // ...
  };
}
```

::: cmptable

## `variant<T, T>`

```cpp
void f(variant<int, int> v) {
  v match {
    0: let first => // ...
    1: let second => // ...
  };
}
```

## `expected<T, T>`

```cpp
void f(expected<int, int> e) {
  e match {
    0: let value => // ...
    1: let error => // ...
  };
}
```

:::

# Implementation Experience

A Clang-based implementation is available at <https://github.com/mpark/llvm-project/tree/p2688-pattern-matching>
(with option `-fpattern-matching`) and available on [Compiler Explorer](https://godbolt.org)
under `x86-64 clang (pattern matching - P2688)`{.default}.

## What is implemented

- Parsing and AST representation for match expressions, cases, patterns, and
  direct conditions.
- Declaration, type, value, decomposition, closed/open choice, pointer, and
  braced polymorphic patterns, including recursive type and positional choice
  selectors.
- Dependent semantic case instantiation and implicit template regions.
- Constant evaluation and runtime code generation.
- Subject evaluation and lifetime extension.
- Projection reuse, including discriminator caching.
- Structured-binding and subpattern packs.
- Result deduction, null handlers, `static_assert`, jump actions, and `do`
  expressions.
- Pattern-matrix exhaustiveness and usefulness diagnostics with source-like
  witnesses.
- CFG and several analysis integrations.

## Architectural lessons

### Parsing the operator and patterns

Clang parses an initial cast-expression and then folds binary operators by
precedence. The prototype adds `match` at its selected precedence and decides
between a selection, `match constexpr`, a trailing return type, and a
single-pattern test after consuming the contextual keyword.

R6's required `case` gives every case a reliable recovery point. Inside a
pattern, however, expressions and declarations intentionally share one
position. The parser uses C++'s existing simple-declaration classifier, with a
for-range-style declarator whose identifier may be omitted, before falling
back to expression parsing. Parentheses force the expression path.

Attributes need additional care because `[[` can begin either an attribute or
a nested decomposition pattern. The prototype only attempts the declaration
attribute interpretation when skipping the attributes leaves a viable simple
declaration; otherwise `[` begins structural pattern parsing. This is a
localized tentative classification, not a parse-and-rebuild of an entire
pattern.

`case P = E` introduces another deliberate boundary. The first top-level `=`
terminates the pattern, and direct-condition operands stop at top-level `&&`.
This is why assignment and logical-or subjects require parentheses in that
form.

### Source cases and semantic instantiations

One source case can produce several differently typed semantic instances. The
prototype initially tried to mutate and replay source AST nodes; that model was
fragile under later tree transformations. It now separates source cases from
`MatchCaseInstantiation` objects. The standard needs an explicit implicit
template-region model even though it does not expose those implementation
objects.

### Choice dispatch should remain semantic

At `-O2`, direct language matches already optimize into switches, merged
destinations, or a single direct call when the discriminator becomes known.
Compared with `std::visit`, the language form avoids a library abstraction
barrier that can make inlining depend sensitively on visitor size and dispatch
strategy.

The frontend should preserve an alternative-dispatch operation containing the
discriminator, unchecked projections, guards, handlers, and exhaustiveness
information. A later lowering can choose:

| Situation | Possible lowering |
|---|---|
| Constant discriminator | Emit only the selected alternative |
| Small dispatch | Direct switch or branch tree |
| Cases sharing behavior | Merge destinations |
| Skewed profile | Hot direct cases plus cold fallback |
| Large unpredictable dispatch | Jump table or outlined thunk matrix |
| Multiple choices | Decision DAG; flatten only profitable products |

The current prototype lowers through ordinary branches and relies on LLVM
optimization. A dedicated decision-DAG lowering remains future work.

### Dynamic class matching

Braced polymorphic refinement must retain the semantics of an ordered sequence
of `dynamic_cast` refinements, including open-world derived classes and pointer
adjustment. The
compiler can nevertheless common repeated targets, derive base matches from a
successful more-derived result, use final-class fast paths, and employ LTO or
profile-guided caches while preserving that relation.

### Projection reuse is not one cache

A discriminator can often be shared more broadly than a projected object. In
a product match, a sibling choice index may be independent of an earlier
alternative selection, while its projected reference is created only inside a
particular dominated branch. The prototype therefore distinguishes cache
identity for discriminators from cache identity for selected projections.

## Known implementation gaps

- Polymorphic refinement does not yet implement every valid cross-cast.
- The precedence for a class that is both polymorphic and an
  `alternative_traits` model still needs a final design rule.
- Modules and complete tooling support remain deferred.
- Some direct loop conditions that require case instantiation are still more
  restricted than `if`.
- The parser still uses tentative type parsing in places where a dedicated
  syntactic classifier would be cleaner.
- Debug information and AST presentation for synthetic declarations and
  implicit template regions need production-quality design.
- The current lowering does not preserve a first-class match decision DAG into
  LLVM IR.


The following is the implementation status recorded by R5. It is retained as
historical context; the R6 status above supersedes it:

  - **Lexing**
    - `=>` is added as a new token
    - `match`, `let`, and `_` added as context-sensitive keywords

  - **Parsing**
    - Structure
      - Match test: `pm-expression match pattern`
      - Match selection: `pm-expression match { pattern => expr; ... }`
      - Match constexpr: `expr match constexpr { ... }`
      - Trailing return type: `expr match -> int { ... }`
      - Match cases: `pattern => expr;`, `pattern => jump-stmt;`, `pattern => {a, b};`
      - Match case guards: `pattern if ( condition ) => expr;`
      - Match test guards: `pair match let [x, y] if (x == y)`
    - Patterns
      - All of the proposed patterns: Wildcard, Constant, Parenthesized, Optional, Alternative, and Structured Bindings.
      - _Missing_: "match-and-bind" (e.g. `[0, 1] let whole`)

  - **Semantic Analysis**
    - Type deduction: `auto f(char c) { return c match { 'a' => 0; 'b' => 1; }; }`
    - AST Construction
    - Type checking
    - Inject bindings into the enclosing control statement. e.g. `if (expr match [0, let x]) { /* x available here */ }`
    - Dependent contexts (i.e. handling inside templates)
    - _Missing_: For alternative pattern `@*type-constraint*@: pattern`, where `pattern` needs to be dependent.

  - **Code Gen**
    - Most of constant evaluation has been implemented.
      - _Missing_: Handling jump-statements for constant evaluation
      - _Missing_: Injecting a stack where necessary (template arguments, default arguments, etc)
    - Runtime code generation has been implemented.

## Parsing the `match` operator

::: note
This subsection records the R5 parser architecture. The R6 parser retains the
same precedence integration but recognizes `case`, declaration patterns,
choice braces, and direct conditions as described above.
:::

Broadly speaking, in Clang, expressions are first parsed as a *cast-expression* with `ParseCastExpression`,
then `ParseRHSOfBinaryExpression` looks ahead to see if there is an infix operator. If it finds an operator,
it folds a sequence of RHS into LHS based on the associativity and precedence of the discovered operators.

The implementation first adds a `prec::Match` into the operator precedence table, then there are changes made
to `ParseRHSOfBinaryExpression` to detect the upcoming `match` token. After we encounter a `match` token,
if we have a `constexpr`, `->` or a `{` token, we have a match select expression `@*expr*@ match { ... }`,
otherwise we assume match test expression `@*expr*@ match @*pattern*@`.

In the case of a match test expression, care is taken such that if `@*pattern*@` turns out to be an expression,
we correctly parse it as *pm-expression*. This mostly just falls out of correct placement of `prec::Match`
in the operator precedence table.

## Parsing the Parenthesized Pattern

::: note
This subsection is retained as the R5 parsing record. R6 removes the
parenthesized-pattern AST node and uses parentheses only for ordinary
expressions and disambiguation.
:::

For other patterns, the proposed solution is such that a leading pattern token takes us into pattern parsing.
For example, `_` is a wildcard pattern, and it is so even if there is a variable named `_` in scope.
On the other hand, `*_` is an expression that dereferences a variable `_`, because `*` takes us into expression
parsing. Finally, `_ + 1` produces an error along the lines of `"expected '=>' after wildcard pattern"`.
The leading `_` takes us into pattern parsing, even though `_ + 1` could be a valid expression.

```cpp
expr match {
  _ => // wildcard pattern
  *_ => // dereference
  _ + 1 => // error: expected '=>' after wildcard pattern
  let => // error: expected identifier or '[' after 'let'
  let x => // let pattern
  let [x] => // SB pattern
}
```

Now, without parenthesized pattern, a `(` would take us into expression parsing. It was considered to drop the
parenthesized pattern for this simplicity. However, it's difficult to ignore that there is virtually no language
that provide pattern matching without parenthesized patterns. Having them now I believe will also be better
down the road in evolving the set of available patterns.

It turns out, the difficulty of parsing parenthesized pattern is not much harder than the difficulty
of parsing parenthesized expressions. We already have parenthesized expressions of the form `( @*expression*@ )`,
but this is a bit of a simplification as we also have cast expressions such as `(int)x`. We already can't just
recurse into a `ParseExpression` upon seeing a `(`.

Even worse, the expression parsing today requires looking *past* the `)` to determine how to parse the expression.
Given `(T())`, we don't yet know whether the `T()` is a function type or a constructor call.
In fact it changes based on what comes next.

```cpp
(T()) * x  // T() is a function type.    Cast of *x to T()
(T()) / x  // T() is a constructor call. Same as T() / x
```

This involves blindly storing everything until the `)`, tentatively parsing what follows as a cast expression,
then deciding what the `T()` means based on whether the cast expression parsing attempt succeeded or not.
`* x` is a cast expression, so `T()` is a type, `/ x` is not a cast expression, so `T()` is an expression.

Equipped with that monstrosity, Clang basically tries to parse an expression that starts with `(` such as
cast expression and fold expression, along with extensions such as statement expressions and compound literals.
If that fails, it proceeds to parse `( @*expression*@ )`.

For parenthesized patterns, the steps are similar:

1. If the token after the `(` is a `_`, `?`, `let`, or `[`, parse it a a pattern.
2. Otherwise, try parsing it as expression that starts with `(`.
3. Otherwise, parse it as `( @*pattern*@ )`.
4. If the resulting pattern inside of the parenthesized pattern is an expression, convert it into
   an parenthesized expression and proceed parsing. (i.e. postfix, then RHS of binary operator)
   This handles situations like `(x) + y => // ...` so that we can proceed to parse the `+ y`
   with a parenthesized expression of `(x)`.

# Open Questions Before Wording

The following decisions should be explicit before R6 wording is finalized:

1. Confirm the precise exact-match conversion and reference-binding rules for
   declaration and type patterns, including bit-fields, arrays, and functions.
2. Finalize the `alternative_traits` names, malformed-specialization behavior,
   header availability, and provider-coherence rules.
3. Finish the implicit template-region model for lookup, captures, local
   statics, diagnostics, and result deduction.
4. Specify projection ordering and reuse latitude precisely enough for guards
   that mutate or invalidate the subject.
5. Resolve enumerator policy for `[[maybe_unused]]`, unavailable enumerators,
   and duplicate values.
6. Decide whether all direct `while`, C-style `for`, and filtering range-for
   forms belong in the first standard revision.
7. Determine whether the generalized irrefutable declaration spelling
   `auto case P = E` has sufficient motivating use beyond nested structured
   bindings and `if (case P = E)`.
8. Complete wording for handlers, unmatched execution, and reference-valued
   results.
9. Confirm whether `default` justifies a second spelling for an unguarded
    top-level wildcard.
10. Reconcile wildcard `_`, declaration-pattern placeholder variables, and
    unnamed structured-binding packs without implying that their initialization
    behavior is interchangeable.


# Proposed Polls

The following polls are expected to be split as the design is reviewed:

1. Forward the expression-oriented, composable `match` facility described in
   P2688R6 toward C++29.
2. Use declaration patterns for binding and explicit braces for choice
   projection.
3. Require non-exhaustiveness and redundant cases to be diagnosed as errors.
4. Support the closed and open `alternative_traits` customization model.
5. Support the strict single-pattern expression and binding-producing direct
   condition forms.


# Proposed Wording

::: note
This section currently preserves the R5 proposed wording as the baseline for
the R6 wording revision. It is intentionally retained rather than summarized
or deleted. The wording below still uses the R5 `let`, optional, alternative,
and parenthesized patterns and is not yet the proposed R6 wording.
:::

## [lex.name]{.sref} Identifiers {- .unlisted}

Add to [lex.name]{.sref}/2, Table 4:

> [2]{.pnum} The identifiers in Table 4 have a special meaning when appearing in
> a certain context. When referred to in the grammar, these identifiers are used
> explicitly rather than using the *identifier* grammar production. Unless otherwise
> specified, any ambiguity as to whether a given *identifier* has a special meaning
> is resolved to interpret the token as a regular *identifier*.
>
> \centering{Table 4: Identifiers with special meaning [tab:lex.name.special]}
>
> -------  --------  --------  ----------  ---------------  ------------- -----------
> `final`  `import`  `module`  `override`  [`match`]{.add}  [`let`]{.add} [`_`]{.add}
> -------  --------  --------  ----------  ---------------  ------------- -----------

## [lex.operators]{.sref} Operators and punctuators {- .unlisted}

Add to [lex.operators]{.sref}/1:

> [1]{.pnum} The lexical representation of C++ programs includes a number of
> preprocessing tokens that are used in the syntax of the preprocessor or are
> converted into tokens for operators and punctuators:
>
> ```diff
>  @*preprocessing-op-or-punc*@:
>      @*preprocessing-operator*@
>      @*operator-or-punctuator*@
>
>  @*preprocessing-operator*@: @one of@
>      #        ##       %:       %:%:
>
>  @*operator-or-punctuator*@: @one of@
>      {        }        [        ]        (        )
>      <:       :>       <%       %>       ;        :        ...
>      ?        ::       .        .*       ->       ->*      ~
>      !        +        -        *        /        %        ^        &        |
>      =        +=       -=       *=       /=       %=       ^=       &=       |=
>      ==       !=       <        >        <=       >=       <=>      &&       ||
>      <<       >>       <<=      >>=      ++       --       ,        @[=>]{.add}@
>      and      or       xor      not      bitand   bitor    compl
>      and_eq   or_eq    xor_eq   not_eq
> ```

### [basic.pre]{.sref} Preamble {- .unlisted}

[5]{.pnum} Every name is introduced by a declaration, which is a

  - [5.1]{.pnum} *name-declaration*, *block-declaration*, or *member-declaration*
    ([dcl.pre]{- .sref}, [class.mem]{- .sref}),
  - [(...)]{.pnum} [...]
  - [5.14]{.pnum} implicit declaration of an injected-class-name ([class.pre]{- .sref}).

::: add
  - [5.14+1]{.pnum} *identifier*s in a let pattern [expr.pattern.let]
:::

### [basic.scope.pdecl]{.sref} Point of declaration {- .unlisted}

[(...)]{.pnum} [...]

[14]{.pnum} The locus of a *namespace-definition* with an *identifier* is
immediately after the *identifier*.

[An identifier is invented for an *unnamed-namespace-definition* ([namespace.unnamed]{- .sref}).]{.note}

::: add
[14+1]{.pnum} The locus of the declaration of a let pattern ([expr.pattern.let])
is immediately after the *identifier* or *let-sb-list* of the let pattern.
:::

[15]{.pnum}

::: note
Friend declarations can introduce functions or classes that belong to the nearest
enclosing namespace or block scope, but they do not bind names anywhere
([class.friend]{- .sref}). Function declarations at block scope and variable
declarations with the extern specifier at block scope declare entities that
belong to the nearest enclosing namespace, but they do not bind names in it.
:::

[16]{.pnum} [For point of instantiation of a template, see [temp.point]{- .sref}.]{.note}

### [basic.scope.block]{.sref} Block scope {- .unlisted}

[1]{.pnum} Each

  - [1.1]{.pnum} selection or iteration statement
    ([stmt.select]{- .sref}, [stmt.iter]{- .sref}),
  - [1.2]{.pnum} substatement of such a statement,
  - [1.3]{.pnum} *handler* ([except.pre]{- .sref}), or
  - [1.4]{.pnum} compound statement ([stmt.block]{- .sref}) that is not
    the *compound-statement* of a *handler*[, or]{.add}

::: add
  - [1.4+1]{.pnum} *match-test-condition* or *match-case*
:::

introduces a *block scope* that includes that statement [or]{.rm}[,]{.add}
*handler*[, *match-test-condition*, or *match-case*]{.add}.

### [expr.mul]{.sref} Multiplicative operators {- .unlisted}

Change [expr.mul]{.sref}/1:

> [1]{.pnum} The multiplicative operators `*`, `/`, and `%` group left-to-right.
>
> ```diff
>   @*multiplicative-expression*@:
> -     @*pm-expression*@
> +     @*match-expression*@
>       @*multiplicative-expression*@ * @*pm-expression*@
>       @*multiplicative-expression*@ / @*pm-expression*@
>       @*multiplicative-expression*@ % @*pm-expression*@
> ```

Add a new section after [expr.mptr.oper]{.sref}:

::: add

### 7.6.4+1 [expr.match] Pattern matching expression {#expr-match - .unlisted}

#### 7.6.4+1.1 [expr.match.general] General {- .unlisted}

[1]{.pnum} Pattern matching expression groups left-to-right.

```
  @*match-expression*@:
      @*pm-expression*@
      @*match-test-expression*@
      @*match-select-expression*@

  @*match-test-expression*@:
      @*pm-expression*@ match @*match-test-condition*@

  @*match-test-condition*@:
      @*match-test-pattern*@ @*match-guard~opt~*@

  @*match-test-pattern*@:
      @*let-pattern*@
      @*match-test-matching-pattern*@ @*let-pattern~opt~*@

  @*match-test-matching-pattern*@:
      _
      @*pm-expression*@
      ( @*match-case-pattern*@ )
      ? @*match-test-pattern*@
      @*discriminator*@ : @*match-test-pattern*@
      [ @*match-case-pattern-list*@ ]

  @*match-select-expression*@:
      @*pm-expression*@ match constexpr@*~opt~*@ @*trailing-return-type~opt~*@ { @*match-case-seq*@ }

  @*match-case-seq*@:
      @*match-case*@ @*match-case-seq~opt~*@

  @*match-case*@:
      @*match-case-condition*@ => @*expr-or-braced-init-list~opt~*@ ;
      @*match-case-condition*@ => @*escape-statement*@ ;

  @*match-case-condition*@:
      @*match-case-pattern*@ @*match-guard~opt~*@

  @*match-case-pattern*@:
      @*let-pattern*@
      @*match-case-matching-pattern*@ @*let-pattern~opt~*@

  @*match-case-matching-pattern*@:
      _
      @*constant-expression*@
      ( @*match-case-pattern*@ )
      ? @*match-case-pattern*@
      @*discriminator*@ : @*match-case-pattern*@
      [ @*match-case-pattern-list*@ ]

  @*match-case-pattern-list*@:
      @*match-case-pattern*@
      @*match-case-pattern-list*@ , @*match-case-pattern*@

  @*let-pattern*@:
      let @*identifier*@
      let [ @*let-sb-list*@ ]

  @*let-sb*@:
      @*sb-identifier*@
      [ @*let-sb-list*@ ]

  @*let-sb-list*@:
      @*let-sb*@
      @*let-sb-list*@ , @*let-sb*@

  @*discriminator*@:
      @*type-id*@
      @*type-constraint*@

  @*match-guard*@:
      if ( @*init-statement~opt~*@ @*condition*@ )
```

[#]{.pnum} A pattern matching expression provides a concise way to compare a value against
a sequence of patterns and optional guards, and produce the corresponding expression.

[#]{.pnum} The *pm-expression* to the left of `match` is called the *subject expression*.

[#]{.pnum} The *expr-or-braced-init-list* or *escape-statement* to the right of `=>`
in a *match-case* is called its *operand*.

[#]{.pnum} A *pattern* is a construct in *match-test-pattern* or *match-case-pattern* with
a set of *matching conditions*, described in [expr.pattern].

[#]{.pnum} A pattern *matches* a value if the matching conditions of the pattern are
satisfied by the value.

[#]{.pnum} A *match-test-condition* or *match-case-condition* matches the subject expression
if the corresponding pattern matches the value of the subject expression and either there is
no *match-guard* or the *match-guard* evaluates to `true`.

[#]{.pnum} A *match-test-expression* is a prvalue of type `bool`. The result is `true`
if *match-test-condition* matches the subject expression and `false` otherwise.

[#]{.pnum} The type of a *match-select-expression* is the *trailing-return-type*.
If the *trailing-return-type* is not present, it is considered to be `-> auto`.
If the *trailing-return-type* contains a placeholder type, the type is deduced from
the operands of *match-case*s as described in [dcl.spec.auto]{.sref}.

[#]{.pnum} A *match-select-expression* is an lvalue if the result type is an lvalue
reference type or an rvalue reference to function type, an xvalue if the result type is
an rvalue reference to object type, and a prvalue otherwise.

[#]{.pnum} The result of the *match-select-expression* is the result of the possibly-converted
operand of the first *match-case* whose *match-case-condition* matches the value of the subject
expression. If the operand is an *escaping-statement*, control is transferred accordingly.
If no *match-case-condition* matches, the result depends on the result type. If the result type
is *cv* `void`, then the result is equivalent to not having an operand. Otherwise, the function
`std​::​terminate` is called ([except.terminate]{- .sref}).

#### 7.6.4+1.2 [expr.pattern] Patterns {- .unlisted}

[#]{.pnum} This section describes the matching conditions of patterns.

[#]{.pnum} Let *e* denote the value being matched against. The type of *e* is called `E`.

[`E` is never a reference type ([expr.prop]{- .sref}).]{.note}

#### 7.6.4+1.3 [expr.pattern.wildcard] Wildcard Pattern {- .unlisted}

> | `_`

[#]{.pnum} A wildcard pattern always matches *e*.

#### 7.6.4+1.4 [expr.pattern.let] Let Pattern {- .unlisted}

> | `let` *let-binding*

[#]{.pnum} The let pattern of form `let @*identifier*@` always matches *e*,
and introduces *identifier* as the name of an lvalue that refers to *e*.

[#]{.pnum} Otherwise, the let pattern is of form `let [ @*let-sb-list*@ ]`.
Let *BP~i~* denote the *i*^th^ *let-sb* in *let-sb-list*. The let pattern
introduces a structured bindings declaration defined as-if by:

```cpp
auto&& [ @*v~`0`{.default}~*@, @...@, @*v~`N-1`{.default}~*@ ] = @*e*@ ;
```

where *`v`~i~* is *BP~i~* if *BP~i~* is an *sb-identifier*, and a unique
exposition-only identifier otherwise. For each *BP~i~* that is of form
`[ @*let-sb-list*@ ]`, subsequent structured binding declarations are
introduced using the same process, with *`v`~i~* as the subject.

#### 7.6.4+1.5 [expr.pattern.const] Constant Pattern {- .unlisted}

[#]{.pnum} The constant pattern of form *pm-expression* or *constant-expression*
matches if `@*expression*@ == @*e*@` contextually converted `bool`, yields `true`.

[#]{.pnum} If the constant pattern is an *id-expression* that refers to
an *identifier* introduced by a let pattern, the program is ill-formed.

::: example
```cpp
struct S { int x, y; };
constexpr int c = 42;

void f() {
  S{} match [let c, c]; // error: 'c' refers to the name introduced by 'let c'.
  S{} match [let i, c] if (i < 0); // OK, 'c' refers to '::c'.
}
```
:::

#### 7.6.4+1.6 [expr.pattern.paren] Parenthesized Pattern {- .unlisted}

[#]{.pnum} The parenthesized pattern `( @*match-case-pattern*@ )` matches
if *match-case-pattern* matches *e*.

#### 7.6.4+1.7 [expr.pattern.optional] Optional Pattern {- .unlisted}

[#]{.pnum} Let *PATTERN* denote a *match-test-pattern* or *match-case-pattern*.

[#]{.pnum} The optional pattern `? @*PATTERN*@` matches if *e* contextually
converted to `bool`, yields `true`, and *PATTERN* matches `*@*e*@`.

#### 7.6.4+1.8 [expr.pattern.alternative] Alternative Pattern {- .unlisted}

[#]{.pnum} Let *PATTERN* denote a *match-test-pattern* or *match-case-pattern*.

[#]{.pnum} If the *qualified-id* `std::variant_size<E>` names a complete class type
with a member named `value`, the expression `std::variant_size<E>::value` shall be
a well-formed integral constant expression. Let `T`*~i~* be the type designated by
`std::variant_alternative<i, E>::type` where *i* is a prvalue of type
`std::size_t` for `0 ≤ @*i*@ < std::variant_size<E>::value`.

Let *j* be the values of *i* for which `T`*~i~*:

  - [#]{.pnum} is the same type as *type-id* if the alternative pattern is of form
    `@*type-id*@ : @*PATTERN*@`, or
  - [#]{.pnum} satisfies *type-constraint* if the alternative pattern is of form
    `@*type-constraint*@ : @*PATTERN*@`.

If there is no such *j*, the alternative pattern is ill-formed.

If a search for the name `index` in the scope of `E` ([class.member.lookup]{- .sref})
finds at least one a declaration that is a function, the index is `e.index()`.
Otherwise, the index is `index(e)`, where `index` undergoes argument-dependent
lookup ([basic.lookup.argdep]{- .sref}).

[Ordinary unqualified lookup is not performed.]{.note}

If a search for the name `get` in the scope of `E` ([class.member.lookup]{- .sref})
finds at least one declaration that is a function template whose first template
parameter is a non-type parameter, the initializer is `e.get<j>()`. Otherwise,
the initializer is `get<j>(e)`, where `get` undergoes argument-dependent lookup
([basic.lookup.argdep]{- .sref}). In either case, `get<j>` is interpreted as
a *template-id*.

[Ordinary unqualified lookup is not performed.]{.note}

In either case, *e* is an lvalue if the type of the entity *e* is an lvalue reference
and an xvalue otherwise. Let `U`*~j~* be the type designated by either `T`*~j~*`&` or
`T`*~j~*`&&`, where `U`*~j~* is an lvalue reference if the initializer is an lvalue
and an rvalue reference otherwise.

If the index has the same value as any *j*, a variable is introduced with a unique name
`r`*~j~* as follows:

```cpp
    U@*~j~*@ r@*~j~*@ = @*initializer*@ ;
```

The alternative pattern matches if *PATTERN* matches `r`*~j~* as its subject.

[#]{.pnum} Otherwise, if the alternative pattern is of form
`@*type-constraint*@ : @*PATTERN*@`, the program is ill-formed.

[#]{.pnum} Otherwise, if the expression `try_cast<@*type-id*@>(e)` is well-formed
where `try_cast` undergoes argument-dependent lookup ([basic.lookup.argdep]{- .sref}),
a variable is introduced with a unique name `p` as follows:

```cpp
    auto&& p = try_cast<@*type-id*@>(e);
```

The alternative pattern matches if `p` contextually converted to `bool`,
yields `true`, and *PATTERN* matches `*p`.

[Ordinary unqualified lookup is not performed.]{.note}

[#]{.pnum} Otherwise, `E` shall be a a polymorphic class type ([class.virtual]{- .sref}),
and `&@*e*@` should be of type `E*`. Let `U` be the type designated by either
`const @*type-id*@*` if *e* is const or `@*type-id*@*` otherwise, and *ep* be
a pointer to `e`. A variable is introduced with a unique name `p` as follows:

```cpp
    auto* p = dynamic_cast<U>(@*ep*@);
```

The alternative pattern matches if `p` contextually converted to `bool`,
yields `true`, and *PATTERN* matches `*p`.

#### 7.6.4+1.9 [expr.pattern.struct] Structured Pattern {- .unlisted}

[#]{.pnum} Let *MP~i~* denote the *i*^th^ *match-case-pattern* in *match-case-pattern-list*.
The structured pattern `[ @*match-case-pattern-list*@ ]` introduces a structured bindings
declaration defined as-if by:

```cpp
auto&& [ @*v~`0`{.default}~*@, @...@, @*v~`N-1`{.default}~*@ ] = @*S*@ ;
```

where each `v`*~i~* is a unique exposition-only identifier for each *MP~i~*.
The structured pattern matches if all *MP~i~* matches `v`*~i~* as its subject.

:::

### [stmt.jump.general]{.sref} General {- .unlisted}

> [1]{.pnum} Jump statements unconditionally transfer control.

```diff
jump-statement:
-    break ;
-    continue ;
-    return @*expr-or-braced-init-list*~opt~@ ;
-    @*coroutine-return-statement*@
+    @*escape-statement*@
     goto @*identifier*@ ;

+ escape-statement:
+    break ;
+    continue ;
+    return @*expr-or-braced-init-list*~opt~@ ;
+    @*coroutine-return-statement*@
```

### [dcl.spec.auto]{.sref} Placeholder type specifiers {- .unlisted}

#### [dcl.spec.auto.general]{.sref} General {- .unlisted}

::: add
 
[#]{.pnum} A placeholder type can appear in the *trailing-return-type* of
a pattern matching expression ([expr.match]).

[#]{.pnum} If a pattern matching expression ([expr.match]) with a declared
return type that contains a placeholder type has multiple non-discarded
*match-case*s, the return type is deduced for each such *match-case* as follows:

  - [#]{.pnum} If the operand of a *match-case* is an *escaping-statement* or
    a *throw-expression*, they are not considered.
  - [#]{.pnum} Otherwise, the return type is deduced as if the operand of
    the *match-case* (if any) is the operand of a `return` statement (if any) of
    a function with the declared return type.
  - [#]{.pnum} If the type deduced is not the same in each deduction,
    the program is ill-formed.

[#]{.pnum} If a pattern matching expression ([expr.match]) with a declared return type
that uses a placeholder type has no non-discarded *match-case*s, the return type is
deduced as though from a `return` statement with no operand at the closing brace of
the function body of a function with the declared return type.

:::

### [temp.dep.expr]{.sref} Type-dependent expressions {- .unlisted}

[3]{.pnum} An *id-expression* is type-dependent if it is a *template-id* that is not a concept-id and is dependent; or if its terminal name is

  - [(...)]{.pnum} [...]
  - [3.6]{.pnum} associated by name lookup with a pack,

    ::: example
    ```cpp
    struct C { };

    void g(...);            // #1

    template <typename T>
    void f() {
      C arr[1];
      auto [...e] = arr;
      g(e...);              // calls #2
    }

    void g(C);              // #2

    int main() {
      f<int>();
    }
    ```
    :::

::: add
  - [3.6+1]{.pnum} associated by name lookup with a let pattern in a pattern
    matching expression [expr.match] whose subject expression is type-dependent.
:::

  - [3.7]{.pnum} associated by name lookup with an entity captured by copy
    ([expr.prim.lambda.capture]{- .sref}) in a *lambda-expression* that has
    an explicit object parameter whose type is dependent ([dcl.fct]{- .sref}),
  - [(...)]{.pnum} [...]
  - [3.10]{.pnum} dependent,

[4]{.pnum} Expressions of the following forms are never type-dependent
(because the type of the expression cannot be dependent):

```diff
    @*literal*@
    sizeof @*unary-expression*@
    sizeof ( @*type-id*@ )
    sizeof ... ( @*identifier*@ )
    alignof ( @*type-id*@ )
    typeid ( @*expression*@ )
    typeid ( @*type-id*@ )
    ::@*~opt~*@ delete @*cast-expression*@
    ::@*~opt~*@ delete [ ] @*cast-expression*@
    throw @*assignment-expression~opt~*@
    noexcept ( @*expression*@ )
    @*requires-expression*@
+   @*match-test-expression*@
```

[For the standard library macro `offsetof`, see [support.types]{- .sref}.]{.note}

### [temp.dep.constexpr]{.sref} Value-dependent expressions {- .unlisted}

[2]{.pnum} An *id-expression* is value-dependent if

  - [2.1]{.pnum} it is a concept-id and any of its arguments are dependent
  - [(...)]{.pnum} [...]
  - [2.6]{.pnum} it names a potentially-constant variable ([expr.const]{- .sref})
    that is initialized with an expression that is value-dependent

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
