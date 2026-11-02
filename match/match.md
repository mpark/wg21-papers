---
title: "Pattern Matching with `match` and `case`"
document: D2688R7
date: today
audience: Evolution
author:
  - name: Michael Park
    email: <mcypark@gmail.com>
toc: true
toc-depth: 4
highlighting:
  keywords:
    cpp: ["match", "let", "inspect", "do_return", "is", "as"]
---

# Revision History {- .collapsed}

## R6 → R7 {- .unlisted #r6-to-r7}
  - Declaration-pattern viability now uses restricted ordinary
    initialization. Non-reference declarations admit same-type, base-class,
    and restricted pointer relationships; reference declarations require a
    reference-compatible subject.
  - Integral and enumeration value patterns use the operand compatibility
    rules of built-in three-way comparison and compare with built-in equality.
    For example, `true` does not match an `int`, and an enumeration cannot be
    matched by an integer label. Enumeration patterns do not invoke a
    user-defined `operator==`.
  - Predicate patterns use a parenthesized callee, suppressing
    argument-dependent lookup.
  - Declaration-versus-expression disambiguation follows the outer declarator
    form, preserving `T(x)` and `auto((x))` as expression patterns.
  - Redundant cases are now well-formed, with a recommended warning.
    Non-viable patterns remain ill-formed. A dependent pattern is rejected
    when no substitution can make it viable.
  - Usefulness now directs case instantiation using cumulative coverage,
    rather than only individual irrefutable cases.
  - Fixed declaration pattern packs may now be named, as in `[Types... values]`.
  - Pattern conditions protect the successful controlled statement from
    control-flow entry that would bypass matching and initialization.
  - The grammar restores optional guards for single-pattern tests, as in
    `match(value, case [int x, int y] if (x == y))`. This form was omitted
    from R6's grammar but remained supported by the prototype.
  - Match cases retain source-order priority, but matching operations may be
    reordered and equivalent occurrences may be coalesced. Their results may
    be retained across guard evaluation.
  - Variant's `alternative_traits` discriminator now converts to `size_t`,
    making it usable as a `switch` condition while retaining `.index<I>`.
  - Consolidate on *pattern viability* rather than alternating between
    viability and applicability. Viability is distinct from runtime matching,
    usefulness, and the validity of selected initialization.
  - Reorganize the matching rules under their corresponding pattern forms,
    and group viability, exhaustiveness, usefulness, case instantiation, and
    evaluation under Match Semantics.
  - Clarify phrasing and examples throughout, including protocol descriptions,
    required and residual domains, and implementation notes.

## R5 → R6 {- .unlisted #r5-to-r6}
  - Prior to the Hagenberg meeting in January 2025, further implementation
    work was completed.
    - Runtime code generation was fully implemented by Bruno Cardoso Lopes.
    - `match` expressions were implemented in dependent contexts.
    - Parsing was added for `$type-constraint$: $pattern$`.
    - An open type-indexed protocol was added for the
      `$type-id$: $pattern$` alternative pattern.
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
  - Updated the examples in [Appendix A](#comparison-tables) with [@P2392R3]
    syntax.
  - Match cases require `case`.
  - A multi-case match selection is now written with a prefix introducer,
    `match (E1, E2) { /* cases */ }`. One subject is matched directly. Multiple
    subjects form an unnamed product whose elements preserve the value
    categories of the corresponding expressions. In expression-only contexts
    the match selection is an expression. In a statement-or-expression context
    it is a match selection statement, each handler is an ordinary statement,
    and the match selection does not require a trailing semicolon.
  - Declaration patterns replace `let` patterns. Their restricted declarator
    supports ordinary pointer, reference, member-pointer, function-pointer,
    and array-reference forms, with a separate structured-binding form.
    Viability uses exact-match conversions plus direct derived-to-base
    reference binding. An omitted identifier checks the corresponding
    initialization without performing it. R5's combined `P let name` form is
    not retained; whole-value naming is deferred.
  - Add recursively composable or-patterns, written `P1 or P2`. Subpatterns
    may introduce the same names with independently deduced types; the selected
    subpattern determines the types used to instantiate the guard and handler.
  - A constant expression pattern first uses equality. When equality is not
    available, a callable constant can instead act as a predicate pattern.
  - Braces explicitly request alternative projection: `{ P }`, `{ T: P }`,
    `{ C: P }`, `{ .name: P }`, `{ .name }`, and `{}`. An alternative type can
    also provide parameterized names, such as variant's `{ .index<I>: P }` and
    `{ .index<I> }`. Here `C` is a type-constraint applied to the declared
    alternative type.
  - A declaration pattern, including one with an omitted name, applied
    directly to a polymorphic class object can perform a
    `dynamic_cast`-equivalent runtime cast. Pointer declarations remain static; a
    pointer is first dereferenced through its nullable `{ P }` projection
    before its object can be matched polymorphically.
  - The R5 optional pattern is removed. Parenthesized patterns are retained and
    generalized to group every pattern form. The unbraced `T: P` selector is
    replaced by the explicit braced form `{ T: P }`.
  - A single-pattern test is written `match(E1, E2, case P)`. The
    `case` keyword separates the subject list from the pattern, while the
    parentheses delimit both from the surrounding expression. No new
    operator-precedence level is needed. The test is ill-formed when its
    pattern is not viable; `requires` remains the way to ask about viability.
    R5's trailing guard is not retained on this form.
  - Match selection statements accept ordinary statements as handlers. Match
    selection expressions retain result-producing handlers and add null,
    `static_assert`, and jump handlers. A declaration preamble can introduce
    aliases, using declarations, and assertions shared by every case.
  - An expression handler can be marked `not return`. Such a handler is
    evaluated as a discarded-value expression and does not participate in
    result-type deduction.
  - Pattern conditions use `case P = subject` in `if`, `while`, and
    traditional `for` statements, and can be chained with `&&` and ordinary
    conditions.
  - Decomposition patterns and structured-binding declaration patterns support
    fixed and arity-inferred packs, including case-local pack names available
    to the guard and handler.
  - The proposed `alternative_traits` protocol supports closed indexed
    alternative types, named selectors, non-projectable states, and open
    type-indexed alternative types.
  - Non-exhaustiveness and redundant cases are language errors. Coverage
    distinguishes required states from residual states.
  - The Clang prototype now supports dependent case instantiation, runtime and
    constant evaluation, subject lifetime extension, projection reuse,
    structured-binding packs, CFG integration, and pattern-matrix analysis.

The most visible source changes are summarized below. These are representative
spellings rather than mechanical source transformations.

| Facility | R5 | R6 |
|---|---|---|
| Match selection | `value match { P => E; }` | `match (value) { case P => E; }` |
| Single-pattern test | `value match P` | `match(value, case P)` |
| Name introduction | `let value` | `auto&& value` or another declaration |
| Nullable projection | `? P` | `{ P }` |
| Empty nullable state | `_` after an irrefutable `? P` case | `{}` |
| Typed alternative | `T: P` | `{ T: P }` |
| Multiple subjects | an explicit tuple | `match (x, y)` with `[P, Q]` |

## R4 → R5 {- .unlisted}
  - Further progress on [Wording Status].
  - Update the description of [Alternative Pattern] from `std::cast` to ADL-`try_cast`.

## R3 → R4 {- .unlisted}
  - Submitted companion papers for LEWG
    - [@P3521R0]: Pattern Matching: Customization Point for Open Sum Types
    - [@P3527R0]: Pattern Matching: *variant-like* and `std::expected`
  - Further progress on [Wording Status].
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
    - Example: `$expr$ match $pattern$ if @[(]{.add}@ $condition$ @[)]{.add}@`
    - Added support for *init-stmt* and condition variables in match guards.
    - See [Guard Syntax] for the current design.
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
  - Started on [Wording Status]
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

# Draft Notes {- .collapsed}

These are working notes for R7 and are not part of the proposal.

- Audit the R6-to-R7 revision history once the R7 design is settled.
- Remove the temporary review-boundary horizontal rule before publishing R7.
- Continue to omit match init-statements and block-scope pattern declarations
  from R7. They are implemented as prototype extensions but are not currently
  part of this proposal.
- Expand [Integration Experience] with the Clang/LLVM migration experience
  and representative real examples from Clang/LLVM and Chromium.
- Add representative `alternative_traits` opt-ins from Folly, LLVM, and
  Thrift to [Integration Experience], showing how existing types can participate
  in pattern matching.
- Clarify which library components are proposed and how they relate to the
  language facility, including [Standard Specializations].
- Address the concerns raised by P3619R1 in [Design Decisions and Alternatives
  Considered].
- Complete the `alternative_traits` contract: lookup, header availability, a
  feature-test macro, malformed-specialization diagnostics, practical limits
  on the extent of `alternatives`, defaults for omitted members, discriminator
  mapping, and exception and cv/ref requirements.
- Re-audit prototype support for PCH and module serialization, complete CFG
  effects and cleanup, the experimental bytecode interpreter, AST import,
  indexing, clangd, refactoring, libclang, expression mangling, source-versus-
  semantic AST views, hostile protocol specializations, and large closed
  products. Unsupported paths should diagnose or preserve a valid opaque AST
  rather than erase syntax or crash.

# Introduction

This paper proposes pattern matching for C++29, further refining the design
presented in [@P2688R6].

[@P2688R5] was considered for C++26 at the February 2025 Hagenberg meeting but
did not reach consensus for forwarding to CWG. [@P2688R6] was a substantial
revision rather than merely a re-targeting for C++29. It retained first-match
semantics and recursive composition of patterns, while replacing `let` with
ordinary declarations, adopting prefix `match` for statement and expression
forms, making alternative matching explicit with braces, and requiring
exhaustiveness and redundancy diagnostics.

# The Proposal in Examples

Let's start with examples with light commentary. It will be a good test for
how intuitive the proposal is, without having to read the full specification.
This is intentionally lighter than what would be a tutorial.

## Using Pattern Matching

[The Rust Programming Language]: https://doc.rust-lang.org/book/ch06-02-match.html

The following coin example is adapted from [The Rust Programming Language] book,
Chapter 6.2:

```cpp
enum class Coin { Penny, Nickel, Dime, Quarter };

int value_in_cents(Coin coin) {
  return match (coin) {
    case Coin::Penny => 1;
    //   ^^^^^^^^^^^  value pattern
    case Coin::Nickel => 5;
    case Coin::Dime => 10;
    case Coin::Quarter => 25;
  };
}
```

This is a `match` expression, so the expression in the selected handler provides
its value. A *value pattern* such as `Coin::Penny` matches if the subject has
the same value. Exhaustiveness checking is required in general. For an `enum`,
every enumerator value is required to be covered. Therefore, omitting
the `Coin::Quarter` case is ill-formed:

> ```text
> error: match expression is not exhaustive; example of a missing case: Quarter
> ```

Next, let's consider a dice roll example from the same chapter:

```cpp
int dice_roll();

void take_turn() {
  match (dice_roll()) {
    case 3 => add_fancy_hat();
    case 7 => remove_fancy_hat();
    case int roll => move_player(roll);
    //   ^^^^^^^^  declaration pattern
  }
}
```

This is a `match` statement, so the statement in the selected handler is
executed. `dice_roll()` is evaluated exactly once. A *declaration pattern*
(`int roll`) matches every other result and initializes `roll` from it.

If every result other than `3` or `7` should simply be re-rolled, its value can
be ignored with a *wildcard pattern* (`_`):

```cpp
match (dice_roll()) {
  case 3 => add_fancy_hat();
  case 7 => remove_fancy_hat();
  case _ => reroll();
  //   ^  wildcard pattern
}
```

Patterns can also be combined with `or`. An *or-pattern* tries its alternatives
against the same subject from left to right and matches when one succeeds:

```cpp
match (dice_roll()) {
  case 1 or 2 => lose_turn();
  //   ^^^^^^  or-pattern
  case 3 => add_fancy_hat();
  case 7 => remove_fancy_hat();
  case int roll => move_player(roll);
}
```

Suppose now that we roll two dice and return them as a `std::pair`:

```cpp
std::pair<int, int> roll_two_dice();

match (roll_two_dice()) {
  case [1, 1] => snake_eyes();
  //   ^^^^^^  decomposition pattern
  case [6, 6] => boxcars();
  case [int r1, int r2] if (r1 == r2) => {
    play_doubles(r1);
  }
  case [int r1, int r2] => {
    move_player(r1 + r2);
  }
}
```

`[P1, P2]` is a *decomposition pattern*. It recursively matches the two
elements. After a pattern matches, if there is an `if` guard present,
the handler is taken if the guard evaluates to `true`. Otherwise,
the next match case is considered.

Alternatively, a `match` can match two separately produced values directly:

```cpp
match (dice_roll(), dice_roll()) {
  case [1, 1] => snake_eyes();
  case [6, 6] => boxcars();
  case [int r1, int r2] if (r1 == r2) => {
    play_doubles(r1);
  }
  case [int r1, int r2] => {
    move_player(r1 + r2);
  }
}
```

Multiple subjects form an unnamed type and are matched together.

Let's shift gears and look at alternative types. Suppose our die may roll off
the table, and its result therefore is a `std::optional`:

```cpp
std::optional<int> try_dice_roll();

match (try_dice_roll()) {
  case { int roll } => move_player(roll);
  //   ^^^^^^^^^^^^  alternative pattern
  case {} => roll_again();
}
```

`{ P }` projects the `int` inside the `optional`, if present, and recursively
applies `P` to it. In this example, `P` is the declaration pattern `int roll`.
`{}` matches the `optional`'s empty state.

A `std::variant` can have several different alternatives:

```cpp
using SearchResult = std::variant<File, Directory>;

void open(const SearchResult& result) {
  match (result) {
    case { const File& file } => open_file(file);
    case { const Directory& directory } => open_directory(directory);
  }
}
```

Each declaration pattern matches an alternative whose payload has
the corresponding type and introduces a name for that payload in the handler.

A `std::expected` result can be matched similarly to a `variant`:

```cpp
std::expected<int, std::string> parse_port(std::string_view text);

match (parse_port(text)) {
  case { int port } => connect(port);
  case { const std::string& message } => report(message);
}
```

Note that the value and error types of `expected` can be the same.
`std::expected<std::string, std::string>` in particular comes up often in
practice. In that case, *named selector*s can be used to distinguish the
alternatives:

```cpp
std::expected<std::string, std::string> read_file(std::string_view path);

auto result = read_file(path);

match (result) {
  case { .value: const auto& contents } => process(contents);
  //     ^^^^^^  named selector
  case { .error: const auto& message } => report(message);
}
```

A declaration pattern can use `dynamic_cast` semantics when applied to a
polymorphic class subject.

```cpp
struct Shape { virtual ~Shape() = default; };

struct Circle : Shape { double radius() const; };

struct Rectangle : Shape {
  double width() const;
  double height() const;
};

double compute_area(const Shape& shape) {
  return match (shape) {
    case const Circle& c => std::numbers::pi * c.radius() * c.radius();
    case const Rectangle& r => r.width() * r.height();
    case _ => throw std::invalid_argument("unknown shape");
  };
}
```

The wildcard covers other classes that may derive from `Shape`.

Patterns can also be used in boolean tests and control-flow conditions:

```cpp
SearchResult result = search(path);

// boolean-yielding single-pattern test expression
bool is_file = match(result, case { const File& });

// pattern condition
if (case { const Directory& directory } = result) {
  open_directory(directory);
}
```

`const File&` is a declaration pattern with an omitted name. It tests whether
the corresponding declaration could be initialized, but does not perform that
initialization.

A single-pattern test produces `bool` according to whether its pattern and
optional guard succeed.
A *pattern condition* additionally makes names introduced by its pattern
available in subsequent conditions and the successful branch.

## Customizing an Alternative Type

The standard-library types above opt into `std::alternative_traits`. Your custom
library alternative type can opt into the same protocol. Suppose
`my::Result<T, E>` has an expected-like interface with `has_value()`, `value()`,
and `error()`.

The smallest useful specialization advertises its two projected types,
identifies the active state via `index()`, and provides the projections
for each state via `get<>()`:

```cpp
template <class T, class E>
struct std::alternative_traits<my::Result<T, E>> {
  static constexpr std::alternative_info alternatives[] = {^^T, ^^E};
  static constexpr bool has_residual_states = false;

  static constexpr std::size_t index(const my::Result<T, E>& result) noexcept {
    return result.has_value() ? 0 : 1;
  }

  template <std::size_t I, class Self>
  static constexpr decltype(auto) get(Self&& self) noexcept {
    if constexpr (I == 0) return std::forward<Self>(self).value();
    else if constexpr (I == 1) return std::forward<Self>(self).error();
    else static_assert(false);
  }
};
```

Each element of `alternatives` describes one state. Here, `^^T` and `^^E`
construct `alternative_info` values that advertise projectable states with
declared types `T` and `E`.

This is enough to support the alternative pattern `{ P }` and exhaustiveness
checking. The protocol operations on the right are illustrative rather than a
specified lowering:

::: cmptable

### User Code {width=.4}

```cpp
my::Result<int, std::string> number =
  read_number();

match (number) {
  case { int v } => {
    use(v);
  }
  case { const std::string& e } => {
    report(e);
  }
}
```

### Illustrative Lowering {width=.6}

```cpp
my::Result<int, std::string> number = read_number();

using AltTraits = std::alternative_traits<decltype(number)>;
switch (AltTraits::index(number)) {
  case 0: {
    int v = AltTraits::get<0>(number);
    use(v);
    break;
  }
  case 1: {
    const std::string& e = AltTraits::get<1>(number);
    report(e);
    break;
  }
}
```

:::

The number of alternatives is the size of the `AltTraits::alternatives` array.
`has_residual_states` records whether runtime states may exist outside
that array. Its role in usefulness checking is discussed in
[Required and Residual Domains].

The `name` in `{ .name: P }` is looked up in the return type of `index()`.
Keeping the same `alternatives` and `has_residual_states`, we can replace
`index()` and `get<>()` with enum-based versions:

```cpp
enum class state : bool { value, error };

static constexpr state index(const my::Result<T, E>& result) noexcept {
  return result.has_value() ? state::value : state::error;
}

template <state State, class Self>
static constexpr decltype(auto) get(Self&& self) {
  if constexpr (State == state::value) {
    return std::forward<Self>(self).value();
  } else if constexpr (State == state::error) {
    return std::forward<Self>(self).error();
  } else {
    static_assert(false);
  }
}
```

The user can then write named selectors, even when both alternatives have
the same type:

```cpp
my::Result<std::string, std::string> file = read_file(path);

match (file) {
  case { .value: const auto& contents } => process(contents);
  case { .error: const auto& message } => report(message);
}
```

The corresponding projections use `get<state::value>(file)` and
`get<state::error>(file)` instead of numeric indices.

The complete protocol also describes empty states, canonical value states,
residual states, templated names, and open alternative types. Those facilities
are specified in [The `alternative_traits` Protocol].

# Motivation and Scope

C++ provides the operations underlying pattern matching through separate
language and library facilities: `switch` for integral and enumeration values,
`if` for arbitrary predicates, structured bindings for decomposing tuples,
`std::visit` for selecting alternatives of `std::variant`, and `dynamic_cast`
for class hierarchies. These facilities do not compose declaratively. Code
that needs more than one generally spreads its tests, decompositions,
declarations, and control flow across several statements.

This proposal brings those operations into one pattern language used by
selections, tests, and conditions. A pattern describes
what a value looks like and introduces names for the relevant pieces. A match
selection dispatches to the corresponding handler when that pattern
succeeds.

The design has two primary goals:

  - Use familiar C++ syntax such as `match (E) { /* cases */ }` and ordinary
    declarations, instead of dedicated syntax such as `let` and `? $pattern$`;
  - Increase safety by making non-exhaustive selections ill-formed and
    encouraging implementations to warn about redundant cases.

The paper also preserves the following directions from earlier EWG discussions:

  - Patterns compose recursively rather than forming a chain of separate
    matching operations. EWG expressed a preference for this direction at the
    Kona meeting in November 2022.
  - Pattern matching is available generally in the language. At the July 7, 2021
    EWG teleconference, EWG expressed support for matching outside a dedicated
    `inspect` construct (`match` in this paper).
  - Expressions retain their ordinary meaning. Earlier EWG feedback
    emphasized that declarations should visibly introduce names and that an
    identifier should not silently declare or shadow a variable merely because
    it appears in a pattern.

[@P2688R5] used `let` to make name introduction explicit. This paper retains that
distinction between declarations and expressions while using ordinary
declaration syntax to express type, ownership, references, and forwarding.
A bare identifier remains an expression that refers to an existing name.

The library portion introduces a new customization point,
`std::alternative_traits`, and standard specializations for nullable,
alternatives, type-erased, comparison-category, and calendar types.
[The `alternative_traits` Protocol] presents the protocol and representative
specializations. The full set of definitions will be a separate paper targeted
for LEWG.

Extractors, range patterns, named-member decomposition, matching types
themselves as subjects, and pattern combinators such as `and` and `not` remain
future work.

# Design Overview

The proposal introduces several constructs where pattern matching takes place.

Let's start with `match` selection, both *statement* and *expression* forms:

::: cmptable

### Match Selection Statement

```cpp
match ($subjects$) {
  case $pattern$ => $statement$
  // ...
}
```

### Match Selection Expression

```cpp
auto result = match ($subjects$) {
  case $pattern$ => $expr-or-braced-init-list~opt~$ ;
  // ...
};
```

:::

Match cases have source-order priority. A match selection selects the first
case whose pattern and guard, if present, succeed. Each subject expression is
evaluated exactly once. Cases do not fall through. Every match selection must
be exhaustive. Redundant cases are allowed, but implementations are encouraged
to warn on them.

A *match-test-expression* is a boolean expression that produces `true` if its
pattern and optional guard succeed, and `false` otherwise.

```cpp
match($subjects$, case $pattern$ $guard~opt~$)
```

It is ill-formed if the pattern is not viable for the subject(s). It does not
introduce names outside of its own scope.

A *pattern-condition* is a *condition* and can appear anywhere *condition* can
appear, except within a `switch`:

::: cmptable

### `if`

```cpp
if (case $P$ = $E$) {
  // ...
}
```

### `while`

```cpp
while (case $P$ = $E$) {
  // ...
}
```

### `for`

```cpp
for ($init$; case $P$ = $E$; $incr$) {
  // ...
}
```

:::

A pattern condition has the same matching semantics as
`match($subject$, case $pattern$)`, but keeps the subject alive through the
enclosing control statement.

Pattern conditions participate in a left-to-right `&&` chain. Names introduced
by one condition are available to subsequent conditions and the successful
controlled statement:

```cpp
if (case { const Directory& directory } = search(path) &&
    should_open(directory)) {
  open_directory(directory);
}
```

The patterns proposed are:

| Pattern | Form | Purpose |
|:---------------:|:----------------------------:|-----------------------------------------|
| Wildcard | `_` | Match and ignore the current subject |
| Value or predicate | `E` | Compare with a constant value, or invoke a predicate |
| Declaration | `T x`<br>`C auto x`<br>`T`<br>`auto [x, y]`<br>`auto [...xs]` | Test restricted declaration matching semantics, optionally introducing names |
| Parenthesized | `(P)` | Group a pattern |
| Or | `P1 or P2` | Match either pattern |
| Decomposition | `[]`<br>`[P@~1~@, /* ... */, P@~n~@]`<br>`[P@~1~@, ..., P@~n~@]`<br>`[P@~1~@, auto&& ...xs, P@~n~@]`<br>`[P@~1~@, auto&& ..., P@~n~@]`<br>`[xs...]`<br>`[Ts...]` | Recursively match structural elements, optionally consuming or expanding a pack |
| Alternative | `{ P }`<br>`{}`<br>`{ T: P }`<br>`{ C: P }`<br>`{ .name: P }`<br>`{ .name }` | Select an alternative and optionally project it |

Patterns are constructed recursively via composition. There are primary patterns
such as value pattern (e.g. `0`) and declaration pattern (e.g. `int x`), and
compound patterns such as decomposition pattern (e.g. `[P1, P2]`) that have
nested sub-patterns. For example, `[0, int x]` is a decomposition pattern with
nested sub-patterns `0` and `int x`.

Every pattern matches against its current subject. A single top-level subject
expression supplies the initial current subject directly. Multiple subject
expressions form an unnamed product, matched by a decomposition pattern.

A decomposition pattern obtains the elements of its current subject through
the structured-binding protocol and passes each to the corresponding nested
sub-pattern. As an example, for a `std::pair` with elements
`a` and `b` matched by pattern `[0, int x]`, the current subject of `[0, int x]`
is the whole `std::pair`, while the current subject of sub-pattern `0` is `a`,
and for `int x` it is `b`.

An alternative pattern `{ P }` selects an alternative and passes its
projection as the current subject for `P`. For class types, this uses
`std::alternative_traits`, which describes their states and projections.
Parentheses and or-patterns do not change the current subject.

For example:

```cpp
std::optional<std::pair<int, int>> point = /* ... */;

match (point) {
  case { [0, int y] } => on_y_axis(y);
  case { [int x, int y] } if (x == y) => on_diagonal(x);
  case {} => no_point();
  case _ => elsewhere();
}
```

In the first case, the braces project the `pair` when the `optional` is engaged,
and `[0, int y]` matches against that `pair`. `{}` matches the empty state, and
`_` handles any remaining value.

A declaration pattern always applies directly to its current subject. It does
not implicitly project an alternative. Thus `case auto&& whole` binds
the `optional` itself, while `case { auto&& payload }` binds the `pair` when
it is engaged.

Name introduction follows ordinary declaration syntax. `case x` refers to an
existing entity, while `case auto x` introduces a new `x`. Named declarations
initialize only after the complete pattern matches. Their names are
available in the guard and handler. Declaration matching uses restricted
ordinary initialization rather than general implicit conversion.
Declaration patterns can also match polymorphic class subjects using
`dynamic_cast` semantics.

The language directly supplies the matching domains for `bool`, enumeration
types, and pointers, including nullable projection for pointers.

An alternative pattern such as `{ auto x }` can give `x` different types for
different alternatives. Its case can be instantiated separately for those
alternatives. Coverage from earlier cases can determine which instantiations
are needed.

The following sections describe [Pattern Matching Constructs], [Patterns], and
[The `alternative_traits` Protocol]. [Match Semantics] covers checking, case
instantiation, and evaluation.

# Pattern Matching Constructs

This section describes the constructs that contain patterns.

The following is a simplified, informal overview of their grammar.
The `$pattern$` grammar is described in [Patterns].

First, the new constructs enter the existing grammar at these locations:

```diff
$selection-statement$:
    @`if constexpr`~opt~@ ( $init-statement~opt~$ $condition$ ) $statement$
    // ...
    @`switch`@ ( $init-statement~opt~$ $condition$ ) $statement$
+   $match-selection-statement$

$primary-expression$:
    $literal$
    // ...
    $splice-expression$
+   $match-selection-expression$
+   $match-test-expression$

$condition$:
    $expression$
    $condition-declaration$
+   $pattern-condition-chain$
```

Next, the grammar of the various `match` constructs:

```cpp
$match-selection-statement$:
    match constexpr$~opt~$ ( $expression-list$ ) {
        $match-preamble-declaration-seq~opt~$
        $attribute-specifier-seq~opt~$ case $pattern$ $guard~opt~$ => $statement$
        // ...
    }

$match-selection-expression$:
    match constexpr$~opt~$ ( $expression-list$ ) $trailing-return-type~opt~$ {
        $match-preamble-declaration-seq~opt~$
        $attribute-specifier-seq~opt~$ case $pattern$ $guard~opt~$ => $match-selection-expr-handler$
        // ...
    }

$match-test-expression$:
    match( $expression-list$ , case $pattern$ $guard~opt~$ )

$match-preamble-declaration-seq$:
    $match-preamble-declaration$
    $match-preamble-declaration-seq$ $match-preamble-declaration$

$match-preamble-declaration$:
    $using-declaration$
    $using-enum-declaration$
    $using-directive$
    $alias-declaration$
    $namespace-alias-definition$
    $static_assert-declaration$

$guard$:
    if ( $init-statement~opt~$ $condition$ )

$match-selection-expr-handler$:
    $expr-or-braced-init-list~opt~$ ;
    ! return $expression$ ;
    $static_assert-declaration$
    $jump-statement$
```

The subject *expression-list* is non-empty. Each *initializer-clause* must be
an *assignment-expression* rather than a *braced-init-list*. [Multiple Subjects]
describes how the subjects are matched.

Finally, the pattern condition chain:

```cpp
$pattern-condition$:
    case $pattern$ = $inclusive-or-expression$

$pattern-condition-chain$:
    $pattern-condition-operand$
    $pattern-condition-chain$ && $pattern-condition-operand$

$pattern-condition-operand$:
    $inclusive-or-expression$
    $pattern-condition$
```

`match` in these productions denotes an identifier token whose spelling is
`match`; it is not reserved as a keyword. A *pattern-condition-chain* contains
at least one *pattern-condition*. The remaining overlap with ordinary C++
syntax is resolved as described in [Contextual Parsing of `match`].

## Match Selection Statements and Expressions

In a statement-or-expression context, the prefix introduces a match selection
statement. Otherwise, in an expression context, it introduces a match
selection expression.

The parenthesized *expression-list* supplies the subject or subjects described
in [Multiple Subjects].

`match constexpr` requires the tests and guards used to select a case to be
constant expressions and discards the unselected handlers. Its detailed rules
are described in [`match constexpr`].

The optional preamble is a sequence of *using-declaration*s,
*using-enum-declaration*s, *using-directive*s, *alias-declaration*s,
*namespace-alias-definition*s, and *static_assert-declaration*s. It must appear
before the first case. Each declaration is in scope from its point of
declaration through the remainder of the match selection. A case does not make
its names visible to the preamble or to another case.

A match selection statement does not require a trailing semicolon.
Parentheses force expression form where a match selection statement would
otherwise be recognized.

For example:

```cpp
// expression
(match (value) -> int {
  case 0 => 1;
  case _ => -1;
});

// statement
match (value) {
  case 0 => record_zero();
  case _ => record_other();
}
```

## Handlers and Result Types

A match selection statement has no result type, and each handler is any
*statement*. This includes declaration statements, compound statements,
control statements, and jump statements. An expression used as a statement has
its value discarded in the ordinary way.

Only the selected handler is evaluated. Cases do not fall through.

A handler is a protected control-flow entry. A `goto` or enclosing `switch`
cannot jump directly to a label inside a handler and bypass pattern selection.
Jumps out perform ordinary cleanup. The `match` itself is not a target for an
unlabelled `break` or `continue`. These jumps keep their normal targets.

For a match selection expression, a handler can be:

- an *expr-or-braced-init-list* followed by `;`
- a null statement, written `=> ;`
- a `static_assert` declaration
- a jump statement where that action is valid
- a non-returning expression, written `not return expression`.

Result-type deduction follows function return-type deduction. Omitting the
trailing return type is equivalent to specifying `-> auto`. Each participating
handler must deduce the same type. Other placeholders, such as `decltype(auto)`,
use their ordinary deduction rules. A braced initializer cannot deduce a
placeholder result type.

A null handler and a successful `static_assert` handler contribute `void` and
require a `void` result.
A jump statement, a `not return` handler, and a handler discarded by
`match constexpr` do not participate in result-type deduction. If no handler
participates, an omitted result type defaults to `void`.

With an explicit non-placeholder result type other than `void`, each yielding
handler must initialize that type as a return statement would. The handler
expressions need not have the same type. With `-> void`, expression handlers
are evaluated as discarded-value expressions.

The match expression's value category follows its result type, as for a
function call.

A `not return` handler evaluates its expression as a discarded-value
expression. If the expression completes normally, the behavior is undefined.

[@P2806R5]{.title} would be used with `match` when a handler needs a statement
block that yields a value:

```cpp
return match (var) -> int {
  case { int x } => do {
    log(x);
    do_return x;
  };
  case _ => -1;
};
```

Result deduction is performed separately for each enclosing specialization:

```cpp
constexpr auto result(auto value) {
  return match (value) {
    case int integer  => integer;
    case string& text => text.size();
    case _ => static_assert(false, "unsupported type");
  };
}
```

The last case is instantiated only for types not covered by the earlier
declaration patterns, as described in [Case-Local Instantiation].

## Guards

A guard is introduced by `if` and requires parentheses. It can contain an
init-statement and a condition declaration:

```cpp
match (value) {
  case const Widget& widget if (auto status = validate(widget); status.ok()) => {
    process(widget, status);
  }
  case _ => reject();
}
```

A name introduced by a match case's pattern is visible in that case's guard
and handler, but not in another case. Declarations introduced by the guard's
init-statement or condition follow ordinary `if` scope rules and are visible
in the selected handler.

The coverage rules for guarded cases are described in
[Viability, Exhaustiveness, and Usefulness].

## Single-Pattern Tests and Pattern Conditions

A single-pattern test is:

```cpp
match($expression-list$, case $pattern$ $guard~opt~$)
```

Its subject *expression-list* follows the rules in
[Multiple Subjects].

The `case` keyword marks the final comma-separated operand as a pattern rather
than another subject. Pattern names are visible in the optional guard, but no
names introduced by the test are visible outside it.

Single-pattern tests and pattern conditions require their patterns to be
viable. A non-viable pattern makes the construct ill-formed rather than
producing `false`. In a dependent context, viability is checked after
substitution. [Strict Viability] discusses this choice and the corresponding
use of a *requires-expression* for detection.

For a well-formed test, each subject is evaluated once. The guard is evaluated
only if the pattern matches. The result is `true` if the pattern and optional
guard succeed, and `false` otherwise.

For example:

```cpp
bool equal = match(pair, case [int x, int y] if (x == y));
```

Pattern conditions can appear in `if`, `while`, and traditional `for`
statements, but not in `switch`:

```cpp
if (case pattern = subject) statement
while (case pattern = subject) statement
for (init-statement; case pattern = subject; expression) statement
```

Pattern conditions can participate in a left-to-right built-in conjunction:

```cpp
if (ready && case [int x, int y] = first &&
    x < y && case { string text } = second && !text.empty()) {
  use(x, y, text);
} else {
  // x, y, and text are not in scope
}
```

Names introduced by one pattern condition are visible in later `&&` elements
and the successful controlled statement, but not in `else`. In a traditional
`for`, they are also visible in the iteration expression. [Subject and Lifetime]
describes the lifetimes of these declarations and their hidden subjects.

A pattern name is introduced before its subject is parsed, so using the same
name on the right is self-initialization:

```cpp
int x = 42;

void test() {
  if (case int x = x) { }   // error: self-initialization
  if (case int x = ::x) { } // explicitly names the global object
}
```

The successful controlled statement of a pattern condition is a protected
control-flow entry. A `goto` or enclosing `switch` cannot jump directly to a
label inside it and bypass condition evaluation and initialization of its
pattern names.

The first top-level `=` separates the pattern from the subject. This is
unambiguous because an unparenthesized assignment expression is not a pattern.
The subject is an *inclusive-or-expression*, so a logical-and, logical-or,
conditional, or assignment expression must be parenthesized:

```cpp
if (case auto value = (ready ? first : second) && valid(value))
  use(value);
```

An `if` pattern guard is not accepted in this form. A subsequent `&&` condition
serves the purpose of a pattern guard.

`if constexpr (case P = E)` does not turn the pattern condition into a detection
operation. The `constexpr` applies after the condition has been formed.

## Contextual Parsing of `match`

`match` remains an identifier and can already name a type, function, or
object. A parser therefore recognizes a prefix match selection tentatively and
returns to ordinary C++ parsing if the prefix does not select
the match grammar. This classification does not build the subject, perform
overload resolution, or emit diagnostics.

For valid programs, the recognition flow is:

```
start at '@`match`@'
|
+- next token is '@`constexpr`@' => match selection
+- next token is not '@`(`@'     => ordinary parsing 
`- scan through the balanced non-empty '@`( tokens )`@'
   |
   +- no matching '@`)`@' => ordinary parsing
   +- next token is '@`{`@'
   |  |
   |  +- in $expr-only$ context => match selection expression
   |  `- in $stmt-or-expr$ context
   |     +- next token is '@`case`@', '@`[[`@', or a preamble declaration
   |     |  => match selection statement
   |     +- '@`match`@' is not a type name => match selection statement
   |     `- tentatively parse '@`( E )`@' as a $declarator$
   |        |
   |        +- is a $declarator$ => ordinary parsing
   |        +- not a $declarator$ => match selection statement
   |
   +- next token is '@`->`@'
   |  |
   |  +- in $stmt-or-expr$ context => ordinary parsing
   |  `- in $expr-only$ context
   |     +- tentatively parse $type-id$ followed by '@`{`@' => match selection expression
   |     `- otherwise => ordinary parsing
   |
   `- anything else => ordinary parsing
```

This algorithm is more complicated to describe than it is likely to be in
practice. An audit of Chromium and LLVM found no types named `match` and
hundreds of functions named `match`, mostly in LLVM matching libraries. It
found no existing statement or expression using either match-shaped
`match (...) {` or `match (...) ->` syntax. The ordinary function calls leave
the classifier before reaching the difficult declaration and trailing-result
type cases.

The tentative declarator branch preserves existing declarations such as:

```cpp
struct match { match(int); };

match first(0);
match (second) { 0 };
```

A single `[` does not commit to a match selection because a braced initializer
can begin with a lambda. `[[` does commit because it begins an attributed
match case.

A trailing result type is recognized only when a complete *type-id* is
followed by `{`. This preserves ordinary member access:

```cpp
return match (value) -> Result { case _ => Result{}; }; // match selection
return match(value)->result;                            // member access
```

The single-pattern form is simpler. A top-level comma followed by `case`
separates the subject list from the pattern:

```cpp
match(value, case a * b) // expression pattern
match(value, case T * x) // declaration pattern if T names a type
match(value, case a) * b // multiplication outside the test
```

## Multiple Subjects

Match selections and single-pattern tests can match several subjects.

For example:

```cpp
match (first, second) {
  case [0, int value] => use(value);
  case [int value, 0] => use(value);
  case [_, _]         => fallback();
}

bool both_zero = match(first, second, case [0, 0]);
```

One subject is matched directly. Several subjects form an unnamed,
exposition-only product whose elements preserve the original value categories.
The top-level pattern must therefore be a decomposition pattern, a
structured-binding declaration pattern, or a wildcard, including grouped and
or-pattern combinations of those forms. A declaration such as `auto whole`
cannot expose the unnamed product type.

A bit-field is represented by value because it cannot initialize a reference
member. A pack expansion retains the product interpretation even when it
expands to zero or one element:

```cpp
match (values...) {
  case [auto&& ...elements] => use(elements...);
}
```

In particular, a one-element expansion does not collapse to direct matching.
The extra decomposition level remains visible:

```cpp
constexpr int classify(auto... values) {
  return match (values...) {
    case [1, 1]   => 0; // two subjects
    case [[1, 1]] => 1; // one subject that is a two-element product
    case _        => 2;
  };
}

static_assert(classify(1, 1) == 0);
static_assert(classify(std::pair(1, 1)) == 1);
```

This preserves arity matching for every pack size: `[]`, `[_]`, and `[_, _]`
continue to distinguish zero, one, and two subjects.

An ordinary comma expression remains one subject when parenthesized:

```cpp
match ((first(), second())) {
  case P => action();
}
```

# Patterns

This section describes the individual patterns and their semantics in detail.

The following is a simplified, informal overview of their grammar:

```cpp
$pattern$:
    $or-pattern$

$or-pattern$:
    $primary-pattern$
    $or-pattern$ || $primary-pattern$

$primary-pattern$:
    _
    $inclusive-or-expression$
    $declaration-pattern$
    ( $pattern$ )
    [ $decomposition-pattern-list~opt~$ ]
    { $pattern$ }
    { $type-id$ : $pattern$ }
    { $type-constraint$ : $pattern$ }
    { $named-selector$ : $pattern$ }
    { $named-selector$ }
    { }

$named-selector$:
    . $identifier$
    . $simple-template-id$

$decomposition-pattern-list$:
    $decomposition-pattern-element$
    $decomposition-pattern-list$ , $decomposition-pattern-element$

$decomposition-pattern-element$:
    $pattern$
    ...
    $inclusive-or-expression$ ...
```

The pack forms are described in [Packs].

## Wildcard Pattern

> | `_`

A wildcard pattern always matches any *subject*.

An initial `_` is interpreted as a wildcard even if an outer declaration has
that name. To use such an identifier in an expression pattern, use an
unambiguous expression spelling such as `auto(_ + 1)` or `+_`.

The choice of `_` is discussed in [Wildcard and Value Patterns].

## Value and Predicate Patterns

> | `$inclusive-or-expression$`

Value and predicate patterns have the same form. The expression `$e$` is
required to be a constant expression as specified in [expr.const], e.g. a
literal, `constexpr` variable, enumerator, function, or `constexpr` function
object.

The grammar leaves top-level `or` to [Or-pattern] and reserves `and` for a
future extension.

Matching proceeds as follows:

Let `$s$` be the current subject and `$S$` denote `std::remove_cvref_t<decltype($s$)>`.

1. Let `$AT$` denote `std::alternative_traits<$S$>`. If `$AT$` is a complete type,
   consult [Advertised Value States] for further conditions.
   If `$e$` is not an advertised value, continue with the remaining steps.
2. Otherwise, if both `$s$` and `$e$` are of integral or enumeration types,
   apply the operand compatibility rules of the built-in three-way comparison.
   If those rules accept the operands, compare the converted operands with
   built-in equality. Otherwise, the pattern is not viable.
3. Otherwise, if `$s$ == $e$` is well-formed and contextually convertible to
   `bool`, use that comparison.
4. Otherwise, if the *call-expression* `($e$)($s$)` is well-formed and
   contextually convertible to `bool`, invoke `$e$` as a predicate.
   The parenthesized `($e$)` intentionally suppresses argument-dependent lookup.
5. Otherwise, the pattern is not viable.

The proposed `alternative_traits` specialization for `std::partial_ordering`
advertises its four values, making this `match` exhaustive without a wildcard.
Without the specialization, these value patterns would invoke `operator==` which
would not contribute to exhaustiveness coverage.

```cpp
std::string_view describe(std::partial_ordering order) {
  return match (order) -> std::string_view {
    case std::partial_ordering::less => "less";
    case std::partial_ordering::equivalent => "equivalent";
    case std::partial_ordering::greater => "greater";
    case std::partial_ordering::unordered => "unordered";
  };
}
```

See [Advertised Value States] for how a specialization advertises constant
values.

The second step uses the operand compatibility and conversion rules of built-in
`<=>`. It does not evaluate `<=>` or consider a user-defined overload. This
rejects comparisons between `bool` and any other integral type, as well as
comparisons involving narrowing conversions.

For example, `true` and `false` match only the `bool` alternative.
Neither pattern matches the `int` alternative:

```cpp
using V = std::variant<bool, int>;

int classify(const V& v) {
  return match (v) {
    case { true }       => 0;
    case { false }      => 1;
    case { int number } => number;
  };
}
```

In the second step, enumeration values are compared using built-in equality
rather than an overloaded `operator==`. This behavior is consistent with
`switch`. For example:

```cpp
enum Mode { Read, Write };

bool operator==(Mode, Mode); // not used by switch or match

int classify(Mode mode) {
  return match (mode) {
    case Read  => 0;
    case Write => 1;
  };
}
```

A guard can be used to explicitly invoke `operator==`:

```cpp
match (mode) {
  case Mode m if (m == Read) => selected();
  case _                     => other();
}
```

Unlike `switch`, an integer value pattern such as `case 1` cannot match against
an `enum` subject. This is also a result of following the built-in `<=>` rules.
The pattern must explicitly be a value of the enumeration type.

Equality has priority over invocation, so an ordinarily comparable constant
remains a value pattern even if its type also has a call operator.

Value and predicate patterns can be used together. Here, `"--help"` is compared
with `option` using ordinary equality, while `starts_with("-I")` produces a
predicate:

```cpp
constexpr auto starts_with(std::string_view prefix) {
  return [prefix](std::string_view text) {
    return text.starts_with(prefix);
  };
}

std::string_view classify(std::string_view option) {
  return match (option) -> std::string_view {
    case "--help" => "help";
    case starts_with("-I") => "include path";
    case _ => "other";
  };
}
```

Predicate patterns are particularly useful with classification APIs such as
reflection:

```cpp
consteval std::string_view classify(std::meta::info entity) {
  return match (entity) -> std::string_view {
    case std::meta::is_type => "type";
    case std::meta::is_variable => "variable";
    case std::meta::is_function => "function";
    case _ => "other";
  };
}

static_assert(classify(^^int) == "type");
```

Predicate patterns do not contribute to exhaustiveness, even when their
invocation can be constant-evaluated. Only the pattern expression is required
to be constant.

The use of ordinary expressions for value and predicate patterns is discussed
in [Wildcard and Value Patterns].

## Declaration Patterns

A declaration pattern first tests whether its declaration is viable for the
current subject. If the pattern matches and the declaration has a name, it is
copy-initialized from that subject:

```cpp
case int value
case const Widget& reference
case auto&& forwarded
case int Owner::* member
case int (*function)()
case int (&array)[5]
case std::integral auto integer
case auto&& [first, second]
```

A declaration pattern does not take another pattern as an operand. A
structured-binding declaration can recursively introduce names for its
elements, but this paper has no spelling that simultaneously names a whole
value and matches that value with another pattern. Such a whole-value naming
pattern is discussed in [And-Pattern and Whole-Value Naming Patterns].

A declared name is introduced immediately for lookup, but using it from the
same pattern is ill-formed. Pattern names are results of a successful match and
are available to its guard and handler; they are not inputs to other parts of
the pattern.

Declaration patterns use ordinary declarator forms, with one rule preserving
functional casts as expression patterns. If the outer `$noptr-declarator$` is a
terminal `( $ptr-declarator$ )`, the result is an expression pattern. An outer
function or array suffix instead makes it declaration syntax. Parentheses
within the enclosed `$ptr-declarator$` are handled recursively:

```cpp
case T(value)          // expression pattern
case auto((value))     // expression pattern
case T* value          // declaration pattern
case R (*function)()   // declaration pattern
case R ((*function))() // declaration pattern
case T (&array)[N]     // declaration pattern
```

A functional cast such as `auto(R(*function)())` forces the expression
interpretation.

The resulting declaration must declare a variable. For example,
`T(function)()` has declaration syntax but is ill-formed because it declares a
function. The grammar also admits structured-binding declarations, but not
storage-class forms such as `static` and `thread_local`. The disambiguation is
discussed further in
[Declaration-Pattern Syntax](#declaration-pattern-syntax).

At the start of a pattern, `[[` is interpreted as an attribute only when a
complete attribute can continue a declaration pattern. Otherwise, it begins
a nested decomposition pattern.

### Viability Versus Failed Initialization

There are three possible outcomes for a named declaration pattern:

1. It is not viable for its current subject.
2. It is viable and initialization succeeds.
3. It is viable, but the selected initialization is ill-formed.

Reference binding can produce (1):

```cpp
template <class T>
int classify(variant<T> value) {
  return match (std::move(value)) {
    case { T& reference } => 1;
    case _                => 2;
  };
}
```

For an ordinary `variant<T>`, projecting from `std::move(value)` produces
`T&&`. The `T&` declaration is not viable, so its case is omitted for that
specialization and the wildcard is selected.

Unless an instantiation is skipped by the coverage rules in
[Case-Local Instantiation], (3) is an error rather than a failed match:

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

Silently choosing the wildcard case in the second call would turn an ownership
error into different program behavior.

### Omitted-Name Declaration Patterns

A declaration pattern can omit its identifier. It has the same viability
and well-formedness requirements as the corresponding named declaration,
including access, deleted constructors, and reference binding, but does not
perform the initialization:

```cpp
case Widget          // checks whether `Widget _` would be valid
case Widget _        // initializes and destroys an ignored object
case const Widget&   // checks whether the reference could bind
case std::integral auto
case [auto&&, auto&&]
```

Because the initialization is not evaluated, no object is created or
destroyed, the subject cannot be moved from, and the hypothetical operation
does not contribute to the exception specification. Invalid initializations
are diagnosed as described in [Viability Versus Failed Initialization].

`void` and cv-`void` are explicitly supported. This matters for dependent
`void` expressions and `expected<void, E>` projections.

The identifier can also be omitted from a constrained placeholder declaration:

```cpp
case std::integral auto
case std::ranges::viewable_range auto&&
```

### Static Declaration Matching

Declaration-pattern viability has more restrictive conditions than ordinary
declaration initialization. The high-level motivation is that we do not want
`case { bool b }` to match all of the alternatives of
`variant<bool, int, float>`. The proposed rule takes inspiration from exception
handler matching semantics in [except.handle]/3. For example:

```cpp
try {
  throw 42;
} catch (bool b) {
  // ...
} catch (int i) {
  // ...
}
```

Even though `bool b = 42;` would be well-formed, the `catch (bool b)` does not
catch the `42`. Since exception handler matching is also first-match, allowing
arbitrary implicit conversions would mean that earlier handlers end up matching
more than intended. As such, we introduce similar restrictions to declaration
patterns.

Let `$E$` be the current subject expression and `$D$` the declared type after
placeholder deduction, if any. The declaration is statically viable when the
implicit conversion sequence for copy-initializing `$D$` from `$E$` is a
standard conversion sequence and one of the following holds:

1. `$D$` is not a reference type and, after removing top-level cv-qualifiers,
   `$D$` is the subject type or an unambiguous base class of the subject type.
2. `$D$` is not a reference type, `$D$` and the subject are pointer or
   pointer-to-member types, and, after any lvalue-to-rvalue conversion, they
   differ only by the permitted standard pointer, function-pointer, and
   qualification conversions.
3. `$D$` is a reference type and the type referred to by `$D$` is
   reference-compatible with the type of `$E$` as specified in [dcl.init.ref].

Base-class accessibility and initialization are checked in the context of the
`match`. Requiring the subject itself to have pointer or pointer-to-member type
excludes conversion from `std::nullptr_t`, integer null pointer constants,
array-to-pointer conversion, and function-to-pointer conversion. To match a
null pointer value, use `nullptr`. Arrays and functions can be captured by
corresponding reference declarations.

For example:

```cpp
int* pointer = nullptr; // ordinary initialization permits conversion

match (nullptr) {
  case int* p => use(p); // not viable: subject is std::nullptr_t
}
```

Promotions, numeric conversions, and user-defined conversions do not make a
declaration pattern viable.

Reference compatibility prevents a reference declaration from binding to a
temporary produced by converting the subject to another type. It does not
prevent materializing a prvalue of the same type. A non-reference declaration
instead produces a new value.

```cpp
match (42) {
  case const int& r => use(r); // binds to the materialized int
}
```

The permitted pointer conversions keep pointing to the same object, a base
subobject, or the same function. They do not invoke user code. For example,
a `const int*` declaration pattern can match an `int*` subject:

```cpp
match (pointer) {
  case const int* value => use(value);
}
```

As with a base-class declaration, a broader pointer declaration can make a
later narrower declaration redundant.

The derived-to-base case does not require a polymorphic type or perform a
runtime test. A reference binds the base subobject. A non-reference declaration
copies or moves that subobject and may slice. Accessibility is checked in the
context of the match, as it is for ordinary initialization.

If static declaration matching does not apply, a class declaration can use the
runtime polymorphic cast described in [Polymorphic Class Matching].

Cases remain source-ordered. Declaration viability does not rank or reorder
cases as an overload set would.

### Polymorphic Class Matching

A declaration pattern first tries [Static Declaration Matching]. If that
does not apply, a class declaration can apply the corresponding pointer-form
`dynamic_cast` to a polymorphic class subject:

```cpp
void draw(Shape& shape) {
  match (shape) {
    case Circle& circle       => draw_circle(circle);
    case Triangle& triangle   => draw_triangle(triangle);
    case Rectangle& rectangle => draw_rectangle(rectangle);
    case _                    => draw_unknown(shape);
  }
}
```

This includes casts to public derived targets, virtual inheritance, pointer
adjustment, and valid cross-casts. A failed cast is a non-match. After a
successful cast, the declaration's cv/ref spelling has its ordinary effect:
`Circle&` binds the adjusted object, while `Circle` copies or moves from it.
`auto&&` exactly matches the current `Shape` subject; it does not somehow
acquire the unknown most-derived type.

This is an open-world operation. If `Square` derives from `Rectangle` in
another translation unit or shared library, a `Square` passed as `Shape&` must
still match `Rectangle&`. Comparing exact dynamic types or vtable pointers is
not enough. Listing every currently known derived class is not exhaustive,
so a base-class or wildcard fallback is still required.

A generic declaration can consequently be exact in one instantiation and a
runtime-checked polymorphic cast in another:

```cpp
void dispatch(auto& value) {
  match (value) {
    case Circle& circle => use(circle);
    case _              => fallback(value);
  }
}

Circle circle;
dispatch(circle);                       // ordinary exact binding
dispatch(static_cast<Shape&>(circle));  // runtime polymorphic cast succeeds
```

A generic function can constrain the static types that it accepts:

```cpp
void dispatch_statically(auto& value) {
  match (value) {
    case std::same_as<Circle> auto& circle => use(circle);
    case _                                 => fallback(value);
  }
}
```

The constrained placeholder deduces `Circle` from a `Circle&` subject and
`Shape` from a `Shape&` subject. The latter fails the constraint rather than
requesting a runtime polymorphic cast.

Matching a type directly is discussed as a possible future extension.

Pointer declaration patterns do not perform runtime polymorphic casts.
To match a pointee's runtime type, first use an alternative pattern to project
the non-null state and then apply a class declaration pattern to that object.
[Pointer Subjects] discusses this choice.

## Parenthesized Pattern

> | `( $pattern$ )`

A parenthesized pattern groups any pattern. It has the same matching semantics
and introduces the same names as its nested pattern.

An opening `(` selects pattern grammar. The closing `)` ends that pattern,
which cannot be continued as a postfix or binary expression. An expression
beginning with `(` can instead be written inside a functional cast, such as
`auto((value) + 1)`.

```cpp
match (direction) {
  case (north or south) => vertical();
  case _ => horizontal();
}
```

Parentheses around `_` or `[P@~1~@, /* ... */, P@~n~@]` are not normally
useful when written directly, but permit uniform substitution and future
composition with other pattern operators.

The reasons for general pattern grouping are discussed in
[Parentheses and Or-pattern Syntax].

## Or-pattern

> | `$pattern$ or $pattern$`

An or-pattern applies every subpattern to the same subject from left to right
and succeeds on the first match:

```cpp
match (direction) {
  case Direction::north or Direction::south => vertical();
  case Direction::east or Direction::west   => horizontal();
}
```

It composes recursively, so several values can share one projection:

```cpp
match (response) {
  case { .error: timeout or cancelled } => retry();
  case _ => fail();
}
```

The punctuator `||` has the same grammatical meaning as the alternative token
`or`.
Parentheses still group a pattern, so matching the result of an ordinary
logical expression requires an unambiguous expression spelling:

```cpp
case first or second       => either_pattern();
case (first or second)     => grouped_pattern();
case bool(first || second) => boolean_expression();
```

Every subpattern must introduce the same ordered names and pack structure.
The corresponding declarations need not have the same type. The selected
subpattern determines their types, and the declaration, guard, and handler are
instantiated together for that subpattern:

```cpp
match (value) {
  case { int value } or { const std::string& value } => use(value);
}
```

Exactly one subpattern's named declarations are initialized. If its guard
fails, matching continues with the next source case, not with another
subpattern of the same or-pattern.

The choice of `or` and its interaction with expression syntax are discussed in
[Parentheses and Or-pattern Syntax].

## Decomposition Patterns

`[P@~1~@, /* ... */, P@~n~@]` decomposes the current subject using the
structured-binding rules, then matches each component recursively:

```cpp
match (point) {
  case [0, 0] => origin();
  case [int x, 0] => on_x_axis(x);
  case [0, int y] => on_y_axis(y);
  case [int x, int y] => elsewhere(x, y);
}
```

An expression beginning with `[` must use an unambiguous expression spelling,
such as `auto([] { return 1; }())`, rather than decomposition syntax.

A decomposition pattern does not impose an evaluation order between its nested
patterns. For `[1, 2]`, either nested pattern may be tested first.

Each component has the type and cv-qualification supplied by the
structured-binding rules. Its value category as the current subject of a
nested pattern is determined as follows:

- Array elements and non-reference data members are accessed through the
  current subject. They are lvalues when the subject is an lvalue and xvalues
  otherwise.
- Reference data members remain lvalues regardless of the subject's value
  category.
- For tuple-like decomposition, the reference initialized by `get<I>`
  determines the category. An lvalue reference supplies an lvalue subject,
  while an rvalue reference supplies an xvalue subject. A prvalue result is
  materialized as required by that reference initialization.

The unnamed product used for [Multiple Subjects] retains each subject's
individual value category. The motivation for this forwarding behavior is
discussed in [Decomposition and Forwarding].

Empty decomposition is the zero-element structural pattern:

```cpp
case [] => empty_product();
```

### Packs

At most one arity-inferred subpattern pack is permitted:

```cpp
case [auto&& first, auto&& ...middle, auto&& last]
case [auto&& first, auto&& ..., auto&& last]
case [auto&& first, ..., auto&& last]
```

The first form introduces a local pack name whose types are deduced
independently. The second is an omitted-name placeholder declaration pack. It
checks each declaration but performs no initialization. A bare `...` is a
wildcard pack and ignores an arity-inferred sequence of elements. This is
essentially the pack version of the wildcard pattern `_`. Each arity-inferred
pack can be empty, and its size is the decomposition arity minus the fixed
prefix and suffix.

An enclosing expression pack expands to a fixed number of value patterns:

```cpp
template <int... Values>
void classify(const auto& tup) {
  match (tup) {
    case [Values...] => exact_sequence();
    case _ => different();
  }
}
```

An enclosing type pack similarly expands to a fixed number of declaration
patterns. Following ordinary function parameter pack syntax, the declaration
pack can introduce a local pack name:

```cpp
template <typename... Types>
void classify(const auto& tup) {
  match (tup) {
    case [Types... values] => typed_sequence(values...);
    case _ => different();
  }
}
```

Omitting the name as `[Types...]` performs the same checks without initializing
the declarations. Both forms can expand to an empty sequence.

A declaration such as `Widget... xs` is ill-formed when `Widget` names a single
type rather than a type pack.

Declaration patterns can themselves contain structured-binding packs:

```cpp
case auto [...elements] => (... + elements);
```

Named declaration packs can be expanded in their case's guard and handler.

Subpattern packs are leaf patterns by design. They cannot apply an arbitrary
nested pattern repeatedly. For example, this does not match a tuple of
pair-like elements:

```cpp {.not_proposed}
case [...[auto x, auto y]] => use(x..., y...);
```

They are only permitted as decomposition-list elements, so they cannot be
parenthesized, used outside a decomposition pattern, or combined directly with
`or`. An or-pattern can still combine complete decomposition patterns
containing packs:

```cpp
case [0, auto&& ...values] or [auto&& ...values, 0] => use(values...);
case [auto&& ...values or _] => use(values...); // error
```

## Alternative Pattern

> | `{ $pattern$ }`
> | `{ $type-id$ : $pattern$ }`
> | `{ $type-constraint$ : $pattern$ }`
> | `{ . $identifier$ : $pattern$ }`
> | `{ . $identifier$ }`
> | `{ . $simple-template-id$ : $pattern$ }`
> | `{ . $simple-template-id$ }`
> | `{ }`

For an alternative type, braces request alternative selection. A projecting
form then applies its nested pattern to the selected projection. The following
sections describe how selection works for closed and open types.

### Alternative Projection

A bare `auto&` declaration binds the current subject. For a `variant`,
this binds the whole `variant`. Braces instead project the active alternative,
which is then recursively matched by the nested pattern.

For a polymorphic class that also provides `alternative_traits`, a bare
declaration uses the rules in [Declaration Patterns], including a runtime cast
when applicable. Braces instead request the alternative protocol.

```cpp
void consume_whole(variant<int, string>&);

void consume_payload(int&);
void consume_payload(string&);

variant<int, string> value;

match (value) {
  case auto& whole => consume_whole(whole);
}

match (value) {
  case { auto& payload } => consume_payload(payload);
}
```

The payload case and its handler are instantiated separately for `int` and
`string`, as described in [Case-Local Instantiation].

The projection performed by the braces can be illustrated with `std::visit`:

::: cmptable

#### Alternative Projection {width=.42}

```cpp
match (var) {
  case { P1 } => E1;
  case { P2 } => E2;
}
```

#### Illustrative Comparison {width=.58}

```cpp
std::visit([](auto& payload) {
  match (payload) {
    case P1 => E1;
    case P2 => E2;
  }
}, var);
```

:::

On the right, `std::visit` explicitly projects the alternative and `match`
applies `P1` and `P2` directly to that projection. Braces perform both steps
without requiring the user to write the generic visitor or call `std::visit`.

### Selectors

- `{ P }` considers each projectable state and applies `P` to its projection.
- `{ T: P }` considers each projectable state whose advertised alternative
  type is exactly `T`, then applies `P` to the selected projection. Repeated
  alternatives are considered independently. Selection is by the exact
  advertised type; `T` is not itself a declaration pattern.
- `{ C: P }`, where `C` is a type-constraint, considers each projectable state
  whose declared alternative type satisfies `C`, then applies `P` to its
  projection.
- `{ .name: P }` selects a named state and applies `P` to its projection.
- `{ .name }` selects a named state without requiring its projection.
- A provider can expose parameterized names. For example, variant provides
  `.index<I>` for each declared index `I`; `{ .index<I>: P }` applies `P` to
  that alternative's projection, while `{ .index<I> }` selects the state
  without requiring a projection.

Named projection chooses an advertised state before matching its projection:

```cpp
expected<int, Error> result;

match (result) {
  case { .value: int value }    => use(value);
  case { .error: Error& error } => report(error);
}
```

Type selectors distinguish alternatives when their behavior differs. When
alternatives share behavior, the selectors can be omitted and one nested
pattern can cover every projection for which it is viable:

::: cmptable

### Exact Type Selectors {width=.6}

```cpp
variant<tuple<int, int>, pair<int, int>> value;

match (value) {
  case { tuple<int, int>: auto& [x, y] } => use_tuple(x, y);
  case { pair<int, int>: auto& [x, y] } => use_pair(x, y);
}
```

### Shared Structural Pattern {width=.4}

```cpp
variant<tuple<int, int>, pair<int, int>> value;

match (value) {
  case { auto& [x, y] } => use_product(x, y);
}
```

:::

### Closed Alternative Types

For a closed alternative type, `{ P }` considers every projectable state for
which `P` is viable. At runtime, it tests the active state and uses the
corresponding case instantiation.

The `match` inside the generic lambda above is dependent. In a non-dependent
match, a projecting alternative pattern must be viable for at least one
advertised projection:

```cpp
variant<int, std::string> value;

match (value) {
  case { int i }         => use(i);
  case { std::string s } => use(s);
  case { double d }      => use(d); // error: matches no projectable state
}
```

The same case in a `match` on `variant<Ts...>` remains potentially viable
and is omitted from a specialization whose alternatives do not include
`double`:

```cpp
template <class... Ts>
void dependent_projection(variant<Ts...> value) {
  match (value) {
    case { int i }         => use(i);
    case { std::string s } => use(s);
    case { double d }      => use(d);
  }
}

dependent_projection(variant<int, std::string>{42}); // `double` case omitted
dependent_projection(variant<int, double>{2.5});     // `string` case omitted
```

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

The generic form `{ auto&& value }` considers each projectable state. Its guard
and handler are instantiated only for viable, useful case instantiations,
as described in [Case-Local Instantiation].

### Empty and Non-Projectable States

`{}` matches an advertised empty state, identified by `empty == true` in
`alternatives`. It does not match every non-projectable state:

```cpp
optional<int> value;

match (value) {
  case { int integer } => use(integer);
  case {}              => empty();
}
```

Raw pointers have a built-in null/non-null alternative model. The null state
is empty. For a non-void pointee, the non-null state projects the pointee by
dereferencing the subject:

```cpp
Widget* pointer = find_widget();

match (pointer) {
  case { Widget& widget } => use(widget);
  case {}                 => absent();
}
```

For a `void*`, the non-null state has type `void`. `{ void }` selects it without
dereferencing the pointer.

`nullptr` and `nullopt` retain ordinary value-pattern syntax. A closed
specialization can identify either value as the canonical label of an
advertised state. Such a pattern tests the subject's active state rather than
calling `operator==`, and participates in exhaustiveness analysis. The pointer
and `optional` models do so: `nullptr` and `{}` cover the same pointer state,
and `nullopt` and `{}` cover the same optional state.

A value-selected state is non-projectable but need not be empty. For example,
the connection states in [Advertised Value States] have constant labels but
are not selected by `{}`.

`expected<T, E>` is modeled as value/error, not value/empty. Both states are
projectable, including a successful state of type `void`. Such a state is not
empty:

```cpp
expected<void, Error> result;

match (result) {
  case { void } => completed();
  case { Error& error } => report(error);
}
```

The `visit` comparison above covers only advertised alternatives. The rare
valueless state of `variant` has no projection syntax and is not required for
exhaustiveness. A match can handle it with a whole-subject case; `visit` has
its own behavior:

```cpp
match (value) {
  case auto&& whole if (whole.valueless_by_exception()) => recover();
  case { auto&& alternative } => use(alternative);
}
```

### Open Alternative Types and `any`

An open alternative type such as `any` cannot enumerate all of its possible types. It
still uses braces to make the runtime access explicit:

```cpp
any value;

match (value) {
  case {}                     => empty();
  case { int: auto& integer } => use(integer);
  case { const string& text } => print(text);
  case _                      => unknown();
}
```

- A bare `case int integer` does not look inside the `any`; it tries to match
  the `any` object itself and fails.
- `{ T: P }` calls `try_cast<T>(a)`.
- A direct declaration such as `{ const string& text }` calls `try_init<const string&>(a)`.
- `{}` calls the optional `has_value` operation and matches when it returns
  `false`.
- `{ auto&& value }` and `{ _ }` are ill-formed because there is no C++ type
  for a generic projection of the open remainder.

The protocol for closed and open alternative types is described in
[The `alternative_traits` Protocol]. The syntax and alternatives considered
are discussed in [Alternative Projection and Polymorphic Casts].

---

# The `alternative_traits` Protocol

This section describes how a type advertises its states and supplies their
projections. The patterns that use this information are described in
[Alternative Pattern] and [Value and Predicate Patterns].

We need one protocol for closed alternative types such as `variant` and another form of
the same protocol for open alternative types such as `any`. The name
`alternative_traits`, as well as some of its member names, remains open to
change.

A specialization with a member named `alternatives` uses the closed indexed
protocol. Otherwise, it uses the open type-indexed protocol.

The protocol functions and the Boolean tests and projections obtained
from open-protocol result objects are user-provided matching operations under
[Matching Operation Order and Reuse]. Its validity requirements apply to every
specialization.

## Closed Indexed Protocol

A complete closed customization for the expected-like `my::Result<T, E>`
looks as follows:

```cpp
template <class T>
struct alternative_traits;

struct alternative_info {
  meta::info info;
  bool empty;

  consteval alternative_info(meta::info info = {}, bool empty = false);
};

template <class T, class E>
struct alternative_traits<my::Result<T, E>> {
  static constexpr alternative_info alternatives[] = {^^T, ^^E};
  static constexpr bool has_residual_states = false;

  enum class state : bool { value, error };

  static constexpr state index(my::Result<T, E> const& value) noexcept {
    return value.has_value() ? state::value : state::error;
  }

  template <state State, class Self>
  static constexpr decltype(auto) get(Self&& self) {
    if constexpr (State == state::value) {
      return std::forward<Self>(self).value();
    } else if constexpr (State == state::error) {
      return std::forward<Self>(self).error();
    } else {
      static_assert(false);
    }
  }
};
```

### States and Projections

The `alternatives` array describes the required state domain. Element `I`
describes state `I`. Its `info` is one of:

- null, for a state selected only by index or name;
- a reflected type, for a projectable state selected by `{ T: P }`; or
- a reflected constant value, for a state selected by that value pattern.

The `alternative_info` constructor canonicalizes reflected constant values.
A state is projectable if and only if its `info` reflects a type, including
`void`. It requires a compatible projection and must have `empty == false`.
States with null `info` and value-selected states are not projectable, even if
the specialization provides `get` for them. `{}` selects a state with
`empty == true`. Such a state can also advertise a value, as for `nullopt`, or
it can be anonymous.

The remaining members have the following contracts:

- `index(subject)` identifies the active state and is `noexcept`.
- `get<State>(subject)` provides the projection for a projectable state. It is
  called only when that state is active and preserves the cv-qualification and
  value category specified by the customization.
- `has_residual_states` states whether runtime states can exist outside the
  advertised set. Such states are residual rather than required.

### Named Selectors {#alternative-traits-named-selectors}

The type returned by `index(subject)` also provides named selectors. For a
scoped enumeration, `.name` names an enumerator. For a class type, `.name` or
`.name<I>` names a constant state value supplied by that type. An integral
discriminator provides no named selectors. All selectors for a projectable
state use its `get` operation.

Names do not introduce a second state machine. Plain names can be enumerators
in the discriminator type returned by `index`, and a type that wants synonyms
defines them directly.

```cpp
enum class state : bool {
  value = false, ok = false,
  error = true, err = true,
};
```

Because these names denote the same indexed states,
usefulness, exhaustiveness, and projection treat them identically:

```cpp
match (state_value) {
  case state::value => handle_value();
  case state::error => handle_error();
  case state::err => handle_err(); // warning: redundant
}
```

The first two cases are exhaustive because the enum's full value range is
`false` and `true`. Replacing `error` with `err` has the same coverage.

The same applies to named selectors. Both `.error` and `.err` select state true,
so `{ .err }` makes a later `.error` case redundant. Either name can select
the state without projection or select its projection with `: P`.

### Advertised Value States

An element can advertise a constant as the source-level label for its state.
The constant in `alternatives[I]` labels state `I`; `index(subject)` still
determines whether that state is active. A value pattern selects the state when
its constant has the same canonical type and value as the advertised constant.
The advertised constant is not compared with the subject or the discriminator,
and matching it does not invoke `operator==`.

A connection can expose a closed domain without making the connection itself
comparable with its state labels:

```cpp
namespace my {
  enum class ConnectionState { disconnected, connecting, connected };

  class Connection {
  public:
    ConnectionState state() const noexcept;
  };
}

template <>
struct std::alternative_traits<my::Connection> {
  static constexpr alternative_info alternatives[] = {
    ^^my::ConnectionState::disconnected,
    ^^my::ConnectionState::connecting,
    ^^my::ConnectionState::connected,
  };
  static constexpr bool has_residual_states = false;

  static constexpr my::ConnectionState
  index(const my::Connection& connection) noexcept {
    return connection.state();
  }
};
```

The advertised values can then be used directly and prove exhaustiveness:

```cpp
void monitor(const my::Connection& connection) {
  match (connection) {
    case my::ConnectionState::disconnected => wait_for_connection();
    case my::ConnectionState::connecting   => show_progress();
    case my::ConnectionState::connected    => begin_work();
  }
}
```

No `get` operation is provided because these states are value-selected and
non-projectable. If several states advertise the same canonical value, the
value pattern selects and covers all of them.

When a specialization does not advertise the pattern constant, matching
continues with the remaining rules in [Value and Predicate Patterns]. This
includes open specializations, which advertise no value states. Such matching
does not cover an advertised state for exhaustiveness analysis.

## Open Type-Indexed Protocol

An open alternative type omits the finite state list:

```cpp
template <>
struct alternative_traits<any> {
  static bool has_value(const any& value) noexcept;

  template <class T, class Self>
  static auto try_cast(Self&& self) noexcept;

  template <class T, class Self>
  static auto try_init(Self&& self) noexcept;
};
```

For `{ T: P }`, matching calls `try_cast<T>(subject)`, preserving `T` exactly.
For a direct declaration pattern `{ T name }`, matching instead calls
`try_init<T>(subject)`, again preserving `T` exactly. This distinction lets a
specialization interpret `T` as a selected type in the first form and as a
declaration type in the second. For example, `any` can reject the selector
`{ int&: P }` while supporting the declaration `{ int& value }`.

The result must be contextually convertible to `bool` and dereferenceable. It
is materialized once and tested as an lvalue. A false result is a non-match;
otherwise the result is dereferenced with the value category of the original
call expression and the projection is matched. This permits the result object
to preserve the subject's cv-qualification and value category.

No overlap is inferred between `try_cast<T>` and `try_init<T>`. They are
separate open views unless the specialization gives them equivalent behavior.

An open specialization can additionally provide `has_value(subject)`. If
present, `{}` calls that operation and matches when its result is contextually
false. The empty state is distinct from every successful `try_cast` and
`try_init`.

An open alternative type has no generic projection because it cannot give the unknown
remainder one static type. Consequently generic non-declaration `{ P }`, named
selectors, and indexed selectors are ill-formed. `{}` is ill-formed when the
specialization omits `has_value`. A top-level `_` handles all values not
recognized by preceding typed projections. It remains necessary for
exhaustiveness even when `has_value` is present.

For `any`, both operations can use the same small result type:

```cpp
template <>
struct alternative_traits<any> {
  template <class Self, class Pointer>
  struct result {
    Pointer pointer;

    explicit operator bool() const noexcept { return pointer != nullptr; }

    decltype(auto) operator*() && noexcept {
      return forward_like<Self>(*pointer);
    }
  };

  static bool has_value(const any& value) noexcept {
    return value.has_value();
  }

  template <class T, class Self>
  static auto try_cast(Self&& self) noexcept {
    auto* pointer = any_cast<T>(addressof(self));
    return result<Self, decltype(pointer)>{pointer};
  }

  template <class T, class Self>
  static auto try_init(Self&& self) noexcept {
    auto* pointer = any_cast<remove_reference_t<T>>(addressof(self));
    return result<Self, decltype(pointer)>{pointer};
  }
};
```

`try_cast` preserves the explicit selector. `try_init` removes only the
reference used by the declaration before querying `any_cast`; cv-qualification
continues to constrain the resulting projection.

The `exception_ptr_cast` proposed by [@P2927R3] makes the corresponding
`exception_ptr` specialization smaller:

```cpp
template <>
struct alternative_traits<exception_ptr> {
  static bool has_value(const exception_ptr& value) noexcept {
    return bool(value);
  }

  template <class T>
  static const auto* try_cast(const exception_ptr& value) noexcept {
    return exception_ptr_cast<T>(value);
  }

  template <class T>
  static const auto* try_init(const exception_ptr& value) noexcept {
    return exception_ptr_cast<remove_cvref_t<T>>(value);
  }
};
```

The prototype implements the `any` specialization. Its library does not yet
contain that facility, so the `exception_ptr` specialization remains a design
sketch.

## Standard Specializations

With both protocol forms established, the proposed standard specializations are:

| Subject | Model | Required states | Residual state |
|:--------------------:|-------------------------------|:--------------------------:|:------------------:|
| `T*` | built-in closed nullable type | null, value | none |
| `unique_ptr<T, D>` | closed nullable type | null, value | none |
| `shared_ptr<T>` | closed nullable type | null, value | none |
| `optional<T>` | closed nullable type | null, value | none |
| `expected<T, E>` | closed value-or-error type | value, error | none |
| `variant<Ts...>` | closed indexed alternative type | every declared index | valueless |
| `any` | open type-indexed alternative type | empty and selected types | open remainder |
| `exception_ptr` | open type-indexed alternative type | empty and selected types | open remainder |
| comparison category | closed value domain | every distinct result | none |
| `chrono::month` | finite value domain | the twelve named months | values outside the advertised domain |
| `chrono::weekday` | finite value domain | the seven named weekdays | values outside the advertised domain |

Raw pointers use built-in language semantics. We still provide an
`alternative_traits<T*>` specialization so that a smart pointer with exactly
the same state mapping can explicitly reuse it. Merely looking pointer-like
does not opt a user-defined type into an exhaustive two-state promise.
The non-array `unique_ptr` and `shared_ptr` specializations inherit this model.

`variant` uses its index and a projection whose precondition is the selected
index. `optional` advertises null index 0 and value index 1.
`expected` advertises value index 0 and error index 1. A binary alternative type
with named states can use a `bool`-backed enumeration as its index type.

The built-in pointer behavior is equivalent to the following specialization.
Again, the specialization exists for explicit reuse; the compiler does not
need it to recognize a raw pointer:

```cpp
template <class T>
struct alternative_traits<T*> {
  static constexpr alternative_info alternatives[] = {
    {meta::reflect_constant(nullptr), /*empty=*/true},
    ^^T,
  };
  static constexpr bool has_residual_states = false;

  enum class state : bool { null = false, value = true };

  static constexpr state index(auto const& value) noexcept {
    return value ? state::value : state::null;
  }

  template <state State, class Self>
    requires (State == state::value)
  static constexpr decltype(auto) get(Self&& self) noexcept {
    if constexpr (is_void_v<T>)
      return;
    else
      return *std::forward<Self>(self);
  }

};
```

```cpp
template <class T>
struct alternative_traits<optional<T>> {
  static constexpr alternative_info alternatives[] = {
    {^^nullopt, /*empty=*/true},
    ^^T,
  };

  enum class state : bool { null = false, value = true };

  static constexpr state index(optional<T> const& value) noexcept {
    return value.has_value() ? state::value : state::null;
  }

  template <state State, class Self>
    requires (State == state::value)
  static constexpr decltype(auto) get(Self&& self) noexcept {
    return *std::forward<Self>(self);
  }
};
```

The pointer specialization templates the parameter of `index` so that a smart
pointer with the same state mapping can inherit the implementation. Its `get`
operation follows the built-in projection rules described in
[Empty and Non-Projectable States].

`optional` defines its own specialization because its null state is spelled
`nullopt`. An ordinary `case 0` still asks whether an engaged `optional<int>`
contains zero.

`expected` advertises two projectable states, including `void` for a successful
`expected<void, E>`:

```cpp
template <class T, class E>
struct alternative_traits<expected<T, E>> {
  static constexpr alternative_info alternatives[] = {^^T, ^^E};
  static constexpr bool has_residual_states = false;

  enum class state : bool { value = false, error = true };

  static constexpr state index(expected<T, E> const& value) noexcept {
    return value.has_value() ? state::value : state::error;
  }

  template <state State, class Self>
  static constexpr decltype(auto) get(Self&& self) {
    if constexpr (State == state::value)
      return *std::forward<Self>(self);
    else
      return std::forward<Self>(self).error();
  }
};
```

Both names provide a `state` value. `{ .value: P }` projects the value and
`{ .error: P }` projects the error. `expected` does not expose `.index<I>`;
its state names are the better interface. It exposes only `value` and `error`,
without synonyms such as `err`.

Variant advertises every declared index, exposes those indices through the
parameterized name `.index<I>`, and has a residual valueless state:

```cpp
template <class... Types>
struct alternative_traits<variant<Types...>> {
  static constexpr alternative_info alternatives[] = { ^^Types... };
  static constexpr bool has_residual_states = true;

  struct state {
    size_t value;

    template <size_t I>
    static constexpr size_t index = I;

    constexpr operator size_t() const noexcept { return value; }
  };

  static constexpr state index(variant<Types...> const& value) noexcept {
    return {value.index()};
  }

  template <size_t I, class Self>
  static constexpr decltype(auto) get(Self&& self) noexcept {
    return /* unchecked projection of alternative I */;
  }
};
```

The discriminator is a class so that it can provide the parameterized selector
`.index<I>`. Its conversion to `size_t` makes it directly comparable with those
selector values and usable as the condition of a `switch`. The selected index
is passed directly to `get<I>`.

`.index<I>` exists because `variant`'s discriminator provides a variable
template mapping `I` to its state, not because positional selection is
implicit in every `alternative_traits` specialization. Since the language has
already checked and saved the index, the standard-library specialization can
use a private operation with that precondition without adding a new public
`variant` API.

# Match Semantics

Individual pattern forms specify how they match their current subjects. This
section describes how a complete match is checked, instantiated, and
evaluated.

## Viability, Exhaustiveness, and Usefulness

Viability, exhaustiveness, and usefulness answer different questions. A
pattern is *viable* for a subject when the static matching requirements of its
pattern form are satisfied. Viability is independent of the subject's runtime
value and preceding cases. A case in a non-dependent match whose pattern is
not viable is ill-formed:

```cpp
variant<int, string> value;

match (value) {
  case { char character } => use(character); // error: not viable
  case _                  => fallback();
}
```

Viability does not imply that a selected declaration's initialization is
well-formed, as described in [Viability Versus Failed Initialization]. Guards
and handlers are checked separately as described in [Case-Local Instantiation].

Coverage from a preceding case cannot turn a non-viable pattern into a
redundant one. In a dependent match, a pattern is ill-formed only when it can be
established that no substitution can make it viable. Otherwise, case
instantiations for which it is not viable are omitted as described in
[Dependent Case Matching]. A dependent or opaque matching operation is
considered potentially viable unless the pattern can be proven
non-viable without evaluating that operation.

Exhaustiveness asks whether the cases cover every required value in the
subject's domain. A non-exhaustive match selection is ill-formed:

```cpp
bool value;

match (value) {
  case true => yes();
}; // error: example of a missing case: false
```

Usefulness additionally considers the coverage of preceding unguarded cases.
A viable case that cannot be selected is redundant. Such a source case is
well-formed, and implementations should warn:

```cpp
match (value) {
  case true  => yes();
  case false => no();
  case _     => impossible();
}; // warning: redundant case
```

Usefulness also affects case instantiation, as described in [Case-Local
Instantiation]. A source case can be useful overall even when some of its
case instantiations are not.

Guarded cases do not contribute coverage, even when a guard is manifestly
`true`. This keeps coverage independent of arbitrary constant evaluation and
avoids changing exhaustiveness when a guard expression is refactored. A guarded
case can nevertheless be redundant when preceding unguarded cases cover its
pattern.

### Required and Residual Domains

Required states and residual states answer different questions. Every
advertised state is required, and covering every required state is sufficient
for exhaustiveness. `has_residual_states` does not change that rule. Instead,
it says whether runtime states may remain after the advertised states have been
covered. Those residual states participate in usefulness even though they are
not required for exhaustiveness.

An advertised domain can also be narrower than the return type of its
discriminator. Exhaustiveness is checked against the advertised states, not
every value of that return type. [Integration Experience] illustrates this
distinction with Clang's `DeclContext`.

For example, `expected<T, E>` advertises its value and error states and sets
`has_residual_states` to `false`. After both states have been covered, there is
nothing left for a wildcard to match:

```cpp
void match_expected(std::expected<int, std::string> result) {
  match (result) {
    case { int value } => use(value);
    case { std::string error } => report(error);
    case _ => ; // warning: redundant case
  }
}
```

`variant<Ts...>` also requires only its advertised alternatives for
exhaustiveness, but sets `has_residual_states` to `true` for
`valueless_by_exception`. A wildcard following every advertised alternative
therefore remains useful:

```cpp
void match_variant(std::variant<int, std::string> value) {
  match (value) {
    case { int i } => use(i);
    case { std::string s } => use(s);
    case _ => ; // may cover a residual state
  }
}
```

Both selections would remain exhaustive without their wildcard. The difference
is that only the `expected` wildcard is redundant and should produce a warning.

More generally:

- `bool` requires `true` and `false`.
- integer types require their full value domain.
- an enum requires each distinct declared enumerator value, regardless of
  attributes on the enumerators. Other legal values in its underlying range
  are residual unless explicit constants cover them.
- `variant` requires each advertised index; valueless-by-exception is residual.
- exhaustive closed traits such as `optional` and `expected` require every
  advertised state and have no residual state.
- an open alternative type requires a top-level wildcard; typed projections cannot prove
  coverage of its open domain.

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

## Dependence and Case Instantiation

### Dependent Case Matching

A dependent match selection can contain a case whose pattern is viable in one
specialization and not another:

```cpp
template <class T>
int classify_value(T value) {
  return match (value) {
    case int         => 0;
    case std::string => 1;
    case _           => 2;
  };
}
```

For `T` equal to `int`, the `std::string` case is omitted; for `T` equal to
`std::string`, the `int` case is omitted. Each pattern can be viable in another
specialization.

The same rule applies recursively after alternative projection:

```cpp
template <class V>
int classify_variant(V value) {
  return match (value) {
    case { int }         => 0;
    case { std::string } => 1;
    case { char }        => 2;
  };
}
```

For `variant<int, std::string>`, the `char` case is not instantiated. It remains
potentially viable because another specialization could contain `char`. The
same case on a non-dependent `variant<int, std::string>` is ill-formed because
its pattern is not viable.

As shown in [Viability Versus Failed Initialization], reference binding can
also make a pattern viable only in some specializations. This does not make a
`T&` pattern generally non-viable for an rvalue alternative type. In C++26,
`optional<T&>` is valid and dereferencing it produces `T&` even when
the `optional` itself is an rvalue:

```cpp
template <class T>
int classify(optional<T> value) {
  return match (std::move(value)) {
    case { T& reference } => 1;
    case _                => 2;
  };
}

int value = 42;
classify(optional<int>{42});     // 2
classify(optional<int&>{value}); // 1
```

This permissiveness is specific to dependent matching. In the corresponding
non-dependent match on an rvalue `optional<int>`, `{ int& }` cannot match any
projectable state and is diagnosed even when a later wildcard is present.

Some dependent patterns are nevertheless provably non-viable. A built-in
array has a fixed, non-customizable decomposition arity:

```cpp
template <class T>
int classify(T (&value)[2]) {
  return match (value) {
    case [T first, T second, T third] => 1;
    case _                            => 2;
  };
}
```

No substitution can make this three-element pattern match the two-element
array, so the program is ill-formed. By contrast, `{ char }` is potentially
viable for a dependent `variant<T>` because `T` can be `char`.

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

### Case-Local Instantiation

For a non-dependent closed subject, a generic projection such as `{ auto x }`
introduces alternative dependence only when `alternatives` advertises more
than one projectable state. A single projectable state leaves the declaration,
guard, and handler non-dependent:

| Subject | Projectable states | Case context for `{ auto x }` |
| ------- | ------------------ | ----------------------------- |
| `optional<int>` | 1 | Non-dependent |
| `variant<int>` | 1 | Non-dependent |
| `variant<int, int>` | 2 | Alternative-dependent |
| `variant<int, string>` | 2 | Alternative-dependent |

The count is of entries whose `info` reflects a type, as described in
[States and Projections], not distinct types or return types inferred from
`get<>()`. Repeated alternatives remain separate even when their projections
have the same type. This rule does not remove dependence inherited from an
enclosing template or an outer alternative projection.

In a dependent match selection, the preamble is instantiated once for the
enclosing specialization, before any viable source case is instantiated
for alternative projections. It is not duplicated for each such case
instantiation.

The pattern declarations, guard, and handler form one syntactically bounded
case instantiation context. Each instantiation separately handles result
deduction, `decltype`, constraints, local statics, diagnostics, and
structured-binding packs.

An earlier case can determine which later case instantiations are needed:

```cpp
variant<int, string, vector<int>> value;

auto result = match (value) {
  case { int integer } => integer;
  case { auto&& data } => static_cast<int>(data.size());
};
```

The second handler is instantiated for `string` and `vector<int>`, not for
`int`. This gives us the useful instantiation behavior of an overloaded visitor
without turning the cases into an overload set.

Coverage is cumulative. Several refutable patterns can together make a later
case instantiation useless:

```cpp
variant<bool, string> value;

auto result = match (value) {
  case { true }        => 1;
  case { false }       => 0;
  case { auto&& data } => static_cast<int>(data.size());
};
```

The third handler is instantiated for `string`, but not for `bool`. The first
two patterns together cover the `bool` alternative.

We also check coverage before specializing a candidate's pattern, since
specialization itself can be ill-formed.

A *candidate domain* is a conservative upper bound on the values represented
by one potential case instantiation before its pattern is specialized. It
retains the alternative state and structural path that identify the candidate,
while treating pattern constraints not needed to identify it as wildcards. It
is not necessarily a type. Candidate domains distinguish repeated alternatives
of the same type, empty states, and paths through products and nested
alternatives.

If the preceding unguarded patterns cover the entire candidate domain, its
pattern is not specialized, and its guard and handler are not instantiated.
Otherwise, the pattern is specialized and then checked for usefulness before
its guard and handler are instantiated. A case instantiation that is not
useful does not instantiate its guard or handler.

If usefulness cannot be determined, the guard and handler are instantiated.

## Match Evaluation

### Subject and Lifetime

- Each subject expression is evaluated exactly once.
- Multiple subject expressions are indeterminately sequenced, as for function
  arguments. Their evaluation order is unspecified.
- An lvalue subject continues to denote the original object.
- A prvalue subject is materialized in hidden storage.
- Its original value category is retained when it is passed to a projection
  operation. The projection operation determines the category of its result.
- In a match selection expression, the hidden subject survives through the containing
  full-expression. In a match statement it survives through the statement.
- In an `if` pattern condition, the hidden subject survives through the entire
  `if` statement, including the `else` path.
- In a `while` or traditional `for` pattern condition, it survives through the
  current condition evaluation and iteration, including the `for` iteration
  expression. It is destroyed before the next condition evaluation.

Objects declared by pattern conditions remain alive through the successful
controlled statement and any `for` iteration expression. If a later `&&`
operand fails, those objects are destroyed before entering `else` or leaving
the loop. This does not shorten the hidden subjects' lifetimes. Their names
have the scope described in [Single-Pattern Tests and Pattern Conditions].

A match case does not introduce a function-return boundary. A selected
reference result is diagnosed according to how the complete match selection
expression is used.

### Case Selection and Initialization

Match cases have source-order priority. The selected case is the first one whose
complete pattern matches and whose guard, if present, evaluates to `true`.

Once a case's pattern matches:

1. Named declarations initialize in source order.
2. The guard *init-statement* and *condition* are evaluated.
3. On success, the handler is evaluated.
4. On guard failure, case-local declarations are destroyed and matching
   continues with later cases.

Delaying declaration initialization until the complete pattern matches
prevents an early by-value declaration from moving out of the subject before a
later nested pattern succeeds:

```cpp
match (std::move(subject)) {
  case [Widget value, 0] => use(value);
  case _                 => fallback();
}
```

If the second component is not zero, `value` is not initialized.

A failed guard does not undo side effects. However, a guarded named declaration
pattern is ill-formed if its initialization invokes a non-trivial move
constructor. Otherwise, merely testing a case could consume the subject before
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
unguarded cases, where successful pattern selection cannot continue to a later
case. An omitted-name declaration pattern has no initialization and is
therefore not subject to the guarded-move restriction.

### Matching Operation Order and Reuse

Source-order case priority does not prescribe one sequence of matching
operations. Their relative order is unspecified except where a pattern imposes
an order. For an alternative pattern, its state or cast result is tested
before projection. The projection is then matched against the nested pattern.

The following matching operations can be shared:

- closed alternative discriminators and selected projections;
- tuple-like `get<I>`;
- open alternative calls, Boolean tests, and successful projections;
- runtime-checked polymorphic casts and their adjusted pointers;
- built-in comparisons used by value patterns that require no user-defined
  conversion.

Two occurrences are equivalent when they apply the same operation, including
the same state or type arguments, to the same subject or retained projection.
An implementation can evaluate them separately or reuse one occurrence's
materialized result for others.

As with copy elision in [class.copy.elision], reuse is permitted even when
omitting another evaluation changes observable side effects. When its result
is not shared, a source occurrence is evaluated at most once.

User-provided matching operations must remain valid when their source
occurrences are evaluated separately. In particular, evaluating an operation
cannot consume state needed by a later occurrence. Such operations can
otherwise have side effects. Within the bounds above, the number of their
evaluations is unspecified.

A retained materialized result remains alive through its last use. This does
not extend the lifetime of an object to which the result refers.

Distinct built-in value comparisons on one subject can be combined into one
multiway test even though they are not equivalent occurrences.

A matching operation for a later case can be performed before an earlier
case's guard. For example:

```cpp
void guard_side_effect(int value) {
  auto bad_guard = [&value] { value = 3; return false; };
  match (value) {
    case 1 => one();
    case 2 if (bad_guard()) => two();
    case 3 => three();
    case _ => other();
  }
}
```

If `value` is initially `2`, an implementation may first use a `switch` to
dispatch among `1`, `2`, and `3`, and then evaluate `bad_guard`. The assignment
to `3` does not revise that earlier dispatch, so this evaluation calls
`other()`. Another permitted evaluation tests the pattern `3` after the guard
and calls `three()`. Either handler may therefore be called when a guard
modifies data examined by a later pattern.

Predicate invocations and value comparisons that call a user-defined operator
or conversion function are not shareable. Each source occurrence is evaluated
separately when its case is considered. Named declaration initializations and
guards occur once, and only after their case's complete pattern matches.

A failed guard does not require discarding a retained result or repeating a
matching operation. If user code invalidates an object referred to by a
retained projection, using that projection later has the usual C++ consequences.

### Unmatched Residual Execution

Exhaustiveness normally rules out unmatched required states. We still need a
rule for residual states:

- an unmatched void-yielding match falls through;
- an unmatched non-void match terminates;
- an unmatched execution cannot succeed during constant evaluation.

This handles `variant::valueless_by_exception()` without forcing that rare
state into the ordinary projection syntax.

### `match constexpr`

`match constexpr` requires the operations and guards used to select a case to
be constant expressions. Like `if constexpr`, it discards the unselected
handlers. It does not make an invalid pattern into a failed match.

```cpp
template <Format format>
auto parse(std::string_view input) {
  return match constexpr (format) {
    case Format::text   => parse_text(input);
    case Format::binary => parse_binary(input);
    case _ => static_assert(false, "unsupported format");
  };
}
```

# Design Decisions and Alternatives Considered

This section explains the choices behind the rules in the preceding sections
and discusses alternatives to those choices.

## Match Selection Syntax

### Declaration Preamble

Cases often need names that are useful only within that match selection.
Without a preamble, we have to repeat those declarations or put them in a
wider scope. Enumerator imports are the most direct example:

```cpp
match (token.kind()) {
  using enum token_kind;
  using result_type = parse_result;
  static_assert(sizeof(result_type) <= 2 * sizeof(void*));

  case identifier => result_type::identifier();
  case number     => result_type::number();
  case _          => result_type::invalid();
}
```

We allow namespace aliases, type aliases, using declarations, using directives,
and `static_assert`. These affect compile-time interpretation and require no
runtime execution when control enters the match selection. The preamble gives
them the narrowest useful scope while making the names available to every
guard and handler.

All preamble declarations come before the cases. Allowing declarations between
cases would make visibility depend on case order even though control does not
flow from one case to the next. Putting them first gives every case the same
environment and leaves case order relevant only to matching.

We do not allow ordinary object declarations. If we did, we would have to say
whether initialization happens before or after subject evaluation, whether it
happens when no case can match, and how the object's lifetime interacts with a
selected handler or an escaping statement:

```cpp {.not_proposed}
match (value) {
  Widget helper = make_helper(); // not a preamble declaration
  case P => use(helper);
}
```

Such state can already be declared in the enclosing block. A name-only preamble
also avoids creating a second init-statement mechanism with different
control-flow rules.

We also leave `consteval` blocks out of this proposal. They permit much more
than introducing names or checking an invariant, and we do not yet have a
match-specific use that justifies importing their statement and scope rules.

### Statement and Expression Forms

R5 used one postfix expression form. Even when its result was discarded, that
form still performed result deduction, diagnosed unused handler values, and
required a semicolon after a braced construct:

```cpp {.not_proposed}
value match {
  case 0 => zero();
  case _ => other();
};
```

This proposal gives the prefix form a contextual split instead. In a direct
statement context it is a match selection statement; the right operand of each
`=>` is an ordinary statement and the closing brace needs no semicolon:

```cpp
match (value) {
  case 0 => zero();
  case _ => other();
}
```

In an expression-only context it is a match selection expression with normal
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
expression. [Contextual Parsing of `match`] describes that distinction and how
we preserve ordinary declarations and calls named `match`.

The corresponding single-pattern Boolean test is
`match(E1, E2, case P)`. It uses the same subject and pattern rules as a
match selection and does not introduce a separate `is` expression.

### Why not `switch`?

A viable alternative would extend `switch` with pattern cases rather than add
a new `match` construct:

```cpp {.not_proposed}
switch (result) {
  case { int value } => use(value);
  case { std::string error } => report(error);
}
```

This would not be a small generalization of existing case labels. A `switch`
is a statement whose condition is converted to an integral or enumeration
type, including the promotions required by `switch`. Its cases are
control-flow labels. They can be stacked, execution can fall through, and an
unlabelled `break` targets the `switch`. A `switch` need not be exhaustive.
Existing programs depend on these properties.

A match selection can be a statement or expression and does not require its
subject to be converted to an integral type. Pattern declarations initialize
only after their patterns match. Handlers do not fall through, and jumps
cannot enter a handler without matching its pattern. A match selection must
be exhaustive, and implementations should warn about redundant cases.

An arrow form could select the new semantics and prohibit mixing with old
case labels. That would keep existing code working, but `switch` would then
have two meanings. The reader would need to inspect the body to know which
one is being used. A separate `match` introducer makes the distinction apparent
at the start and leaves existing `switch` semantics unchanged.

Multiple subjects provide a separate compatibility problem. `switch (a, b)`
already contains a comma expression and switches on `b`. Reinterpreting it as
a product of two subjects would change existing programs. `match (a, b)` has
that meaning without ambiguity.

`switch` remains the appropriate construct for its existing use cases. An
implementation is free to lower suitable value patterns to a `switch`.

## Handler and Case Syntax

### Statement Handlers

A match selection statement can use the ordinary *statement* grammar directly
for its handlers:

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
result-type deduction. Match selection expressions retain their narrower,
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
`break`. A match case has none of those properties. Cases never fall through,
or-patterns replace stacked labels, and an unlabelled `break` in a handler
continues to target an enclosing loop or `switch`. The colon also becomes
visually dense next to alternative selectors:

```cpp
case { .value: int value }: consume(value);
```

Using `=>` keeps the case boundary and non-fallthrough meaning uniform between
match selection statements and expressions. It also lets a case be moved
between the two forms without changing its separator. The tradeoff is that the
grammar to the right of the same token depends on whether the enclosing match
selection is a statement or an expression. That dependence already exists for
the match selection itself and is explicit in [Pattern Matching Constructs].

The control-flow rules are described in [Handlers and Result Types].

### Non-Returning Expression Handlers

A non-returning case in a match selection expression should not participate in
result-type deduction:

```cpp
return match (status) -> int {
  case fatal => not return std::terminate();
  case _     => 42;
};
```

`not return` is a handler action, parallel to `return expression`. In the
grammar it is spelled `! return expression`, following the `if ! consteval`
precedent established by [@P1938R3]. Its evaluation rules are described in
[Handlers and Result Types].

The action follows `=>` because it describes only the selected handler. An
attribute before `case` would appear to describe the whole match case,
including a pattern or guard that can fail. `[[noreturn]]` would additionally
make an essential type-system property look like an ignorable attribute.

An exception-enabled workaround is `throw (std::terminate(), 0)`: the throw
expression contributes no result type, while the comma expression supplies an
otherwise unreachable operand. This is both obscure and unavailable under
`-fno-exceptions`. The general diverging-expression model in [@P3549R0] is the
better solution. `not return` is deliberately provisional and should be
removed if that proposal is adopted for C++29.

### Case Introducers

R5 allowed a pattern to begin a case directly. We now require `case`. It gives
the parser a reliable recovery point and makes empty and statement handlers
easier to parse. It also leaves more room to extend the pattern grammar later.

The introducer separates attributes on a match case from attributes on a
declaration pattern:

```cpp
[[likely]] case [[maybe_unused]] int value => use(value);
```

It also makes the beginning of each case easy to find in a larger selection
and gives the feature one repeated form: `case P` appears in match selections,
single-pattern tests, and pattern conditions.

The introducer also helps distinguish a match selection from an ordinary
declaration such as `match (value) { 0 };`. [Contextual Parsing of `match`]
discusses this ambiguity and the corresponding codebase audit.

### The `=>` Separator

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
`->` has the same issue, `:` is already heavily used by alternative names and
labels, and a new token would be unfamiliar.

## Wildcard and Value Patterns

### `_` as the Wildcard

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

### Expressions as Patterns

Without expression patterns, the facility could not replace even the simplest
`switch`. Restricting the syntax to literals would still exclude named
constants and enumerators:

```cpp
enum class color { red, green, blue };
constexpr int protocol_version = 7;

match (value) {
  case color::red        => handle_red();
  case protocol_version  => handle_current_version();
  case _                 => fallback();
}
```

Once literals, unqualified names, qualified names, and constant expressions
are allowed, we have to distinguish an expression that refers to an existing
name from a declaration that introduces a new one. This paper does not make a
bare identifier introduce a name. Expressions and declarations keep their
ordinary C++ meaning.

Expression patterns also provide a constrained predicate facility. Advertised
states and structural integral or enumeration values are handled first. For
other values, we try equality before invoking the pattern. This ordering matters
because generic call operators are frequently unconstrained: an invocation
expression can appear well-formed even when instantiating its body would fail.
It also ensures that adding callability to an equality-comparable value does not
change the meaning of existing patterns.

Both operations are meaningful for a few types. For example,
`reference_wrapper<F>` can compare with `F` and invoke `F`. Such a pattern uses
equality. A lambda or a declaration pattern with a guard requests predicate
semantics unambiguously.

## Parentheses and Or-pattern Syntax

Functional casts provide an expression spelling when the leading tokens would
otherwise select pattern grammar, as described in [Wildcard Pattern],
[Parenthesized Pattern], and [Decomposition Patterns]:

```cpp
case (north or south)         // parenthesized or-pattern
case (_)                      // parenthesized wildcard pattern
case ([int x, int y])         // parenthesized decomposition pattern
case (Widget value)           // parenthesized declaration pattern

case int(value)               // functional-cast expression pattern
case auto(value)              // placeholder functional-cast expression pattern
case auto(_ + 1)              // expression using an outer `_`
case auto((value)++)          // postfix expression pattern
case auto((int)value)         // C-style cast expression pattern
case auto([] { return 1; }()) // lambda-call expression pattern
case auto(({ int x = 1; x; })) // GNU statement-expression pattern
```

General grouping lets a macro or future pattern abstraction wrap an arbitrary
pattern without knowing its outer grammar:

```cpp
#define GROUP_PATTERN(...) (__VA_ARGS__)

match (value) {
  case GROUP_PATTERN(0 or 1) => small();
  case GROUP_PATTERN([int x, int y]) => pair(x, y);
  case GROUP_PATTERN(_) => fallback();
}
```

These explicit expression spellings preserve grouping of `(A or B)` while
still permitting logical-or, an outer `_`, and lambda invocations as
expression patterns.

The cross-language comparison in [Pattern Combinators] shows that recursively
composable or-patterns and general pattern grouping are both common. Grouping
becomes especially important when an or-pattern is combined with a
whole-value naming or another future pattern operator.

This paper uses `or`, rather than `|`, because bitwise-or expressions are
already common case values. Production LLVM and Chromium contain many cases
such as `case Read | Write`. Preserving that meaning gives a useful visual
distinction:

```cpp
case Read | Write  => combined_value();
case Read or Write => either_value();
```

### Pattern Combinators

General or-patterns are provided by Rust, Scala, Haskell as an extension, F#,
OCaml, Python, and C#. Swift and Java can group alternatives in a case but do
not provide the same recursively composable operation.

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
| C++ (this paper) | Yes, `P1 or P2` | No | No | Yes |

## Declaration Patterns {#declaration-pattern-syntax}

R5's `let` provided a simple name-introduction model. But "why does C++ need
`let`?" was
by far the most common first question. C++ declarations
already express copies, moves, references, forwarding, constraints, and
`decltype`, and those distinctions matter when a pattern introduces a name.

Declaration patterns are more familiar:

```cpp
case const string& text
case auto&& value
case std::integral auto integer
```

This comes with more rules. We have to specify copying, moving, reference
binding, deleted constructors, explicit constructors, and conversions. I
believe that is better than introducing a second declaration language for C++.

### Declaration Syntax

The disambiguation in [Declaration Patterns] preserves familiar functional
casts such as `T(x)`, `T()`, `bool(x)`, and `auto(x)` without excluding
array-reference and function-pointer declarations. It reaches the same result
as the *nofun-type-id* direction in CWG issue 2228 for `(T())`, while still
allowing `(T value)` to group a declaration pattern.

A placeholder functional cast supplies an explicit escape where declaration
syntax would otherwise win:

```cpp
case R(*function)()        // declaration pattern
case auto(R(*function)())  // expression pattern
```

The `[[` ambiguity also occurs between attributes and nested structured
bindings. [Declaration Patterns] describes how it is resolved for patterns.

The distinction between a whole subject and its projected payload is discussed
in [Alternative Projection and Polymorphic Casts].

### Restricted Initialization

Declarations use source-ordered first-match semantics rather than
forming an overload set. Conversion-ranked initialization would make this
surprising:

```cpp
variant<int, double> value;

match (value) {
  case { int integer } => use(integer);
  case { double real } => use(real);
}
```

If arbitrary conversions were admitted, the `int` declaration could consume a
`double` and make the second case dead. This paper instead uses
[Static Declaration Matching] and lets usefulness analysis diagnose
domination among the conversions that remain.

Exception handlers provide precedent for using a restricted set of structural
type relationships in source-ordered selection rather than general implicit
conversion. They are not the specification model. Exception matching operates
on an exception object, has special rules for pointer-reference handlers,
requires public bases independently of context, and permits `std::nullptr_t`
to match pointer handlers. Those properties are not appropriate for a
declaration initialized from an existing expression.

In particular, permitting reference initialization when the referred-to and
subject types are not reference-compatible would make source order silently
replace overload ranking:

```cpp {.not_proposed}
match (short_value) {
  case const int& value   => use_integer(value);
  case const short& value => use_short(value);
}
```

The first case would consume every `short` by binding to a converted `int`
temporary. The same issue is more surprising after alternative projection:

```cpp {.not_proposed}
variant<short, string> value;

match (value) {
  case { const int& converted }  => use(converted);
  case { const short& original } => use(original); // unreachable for short
  case { const string& text }    => use(text);
}
```

### Viability and Initialization

The distinction between viability and initialization follows ordinary
overload resolution:

```cpp
struct Job {
  Job(const Job&) = delete;
};

void select(int&);
void select(Job);
void select(...);

void examples(Job& job) {
  select(0);   // selects `select(...)`: `int&` is not viable
  select(job); // error: `select(Job)` is selected, but copying fails
}
```

A declaration pattern follows the same two stages. A reference that cannot
bind makes the pattern non-viable; a selected by-value declaration whose
copy is deleted is an error rather than a failed match.

### Copies and Moves

A named by-value declaration really copies or moves. Allowing only
reference declarations would simplify failed cases and permit more projection
reuse, but it would prevent a case from naturally consuming its subject.
`auto value` copies an lvalue and moves from an rvalue. `auto&& value` is the
forwarding spelling. A guarded declaration cannot invoke a non-trivial move
constructor before testing the guard; initialize a reference and move in the handler
instead. An omitted-name declaration pattern only checks whether that
initialization would be well-formed.

## Decomposition and Forwarding

A structured-binding name is an lvalue expression, regardless of the value
category used to initialize the structured binding. Its special `decltype`
rule preserves the referenced type, but not that original value category.
Consequently, neither `decltype((x))` nor `std::forward_like<Tuple>(x)` is a
general forwarding spelling for a binding `x`:

```cpp
template <typename Tuple>
decltype(auto) naive_forward_binding(Tuple&& tuple) {
  auto&& [x] = std::forward<Tuple>(tuple);
  return std::forward_like<Tuple>(x);
}
```

For `std::tuple<int&>`, this produces `const int&` from a const lvalue tuple
and `int&&` from an rvalue tuple. Both should remain `int&`. The forwarding
rules in [Decomposition Patterns] provide this behavior directly, so users do
not need to reconstruct it from a structured-binding name.

## Alternative Projection and Polymorphic Casts

A declaration pattern should have one meaning. Given
`variant<int, string> value`, `auto&& selected` cannot simultaneously name
the variant and whichever alternative is active. This proposal makes the
projection visible:

```cpp
match (value) {
  case auto&& whole       => consume(whole);
  case { auto&& payload } => consume(payload);
}
```

The first case makes the second unreachable. Braces, not the declaration's
spelling, request alternative projection.

The same distinction applies recursively. `[int x, int y]` decomposes its
current subject; `{ [int x, int y] }` first selects an alternative and then
decomposes its payload. This keeps every nested pattern independent of how its
subject was obtained.

R5's `? P` combined a nullable test and dereference. This proposal replaces it
with `{ P }` and `{}`, using the same alternative model as `variant` and
`expected`.
R5's unbraced `T: P` becomes `{ T: P }`. The braces perform alternative
selection, `T` selects an exactly advertised type, and `P` matches the
projection. Variant's `.index<I>` is the corresponding opt-in escape hatch for
duplicate types.

Braces are required for open alternative types such as `any` as well. Otherwise an
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

We also considered one implicit `as` operation for testing, conversion, and
name introduction. The conversion problem is the same as described in
[Restricted Initialization].

### Polymorphic Cast Syntax

We considered requiring braces for runtime polymorphic casts:

```cpp
match (shape) {
  case { Circle& circle } => draw(circle);
  case _                  => draw_unknown(shape);
}
```

The argument for braces is straightforward:

- a bare declaration would always retain ordinary static meaning;
- braces would visibly mark every runtime operation, including `variant`,
  `any`, and polymorphic casts; and
- a representation changed from a class hierarchy to a closed alternative type
  could preserve more match case syntax.

It also suggested a concise recursive selector such as
`{ Circle: auto&& [x, y] }`, combining a polymorphic cast and decomposition.

The object reached by a successful polymorphic cast is not a value stored
inside its source object. The adjusted reference still denotes a subobject of
the same most-derived object. Declaration-shaped runtime polymorphic casts are
also familiar from other languages.

`variant` provides the generic payload projection described in
[Alternative Projection]. There is no way to give that projection the unknown
most-derived type of an open class hierarchy.

In the code we looked at, a successful cast was normally followed by member
access or function calls. Immediately decomposing the derived object was rare,
and often would not work because the class has base classes or private state.

Braces would make some migrations between a hierarchy and a `variant` easier.
We found little evidence for such migrations, and they generally require other
ownership and API changes anyway.

There is one real loss: without braces there is no direct
polymorphic-cast-and-subpattern form. The resulting object has to be named and
then inspected in the handler. We did not find enough examples of this to
justify putting braces on every polymorphic case.

The strongest argument for braces remains the generic example in
[Polymorphic Class Matching], where a small type change
introduces a runtime cast.

This may seem surprising, but a generic use of `typeid` similarly changes from
static to dynamic behavior based on its instantiated operand type.
`typeid(expression)` observes the dynamic type only when the expression is a
glvalue of polymorphic class type:

```cpp
const std::type_info& get_type_info(auto& value) { return typeid(value); }

int integer;
Circle another_circle;
get_type_info(integer);                              // static type `int`
get_type_info(static_cast<Shape&>(another_circle));  // dynamic type `Circle`
```

We think the direct object syntax is worth that cost. Compiler diagnostics and
AST dumps should still make the runtime cast visible.

### Pointer Subjects

Applying runtime polymorphic matching to pointer declarations would make null
pointers difficult to interpret. Consider an ordinary generic pointer match:

```cpp
template <class T>
int classify(T* pointer) {
  return match (pointer) {
    case int* value    => value ? 1 : 2;
    case double* value => value ? 3 : 4;
    case _             => 5;
  };
}
```

This is static dispatch on `T`. `classify<int>(nullptr)` should select the
`int*` case and initialize `value` with a null pointer.

Now what should `Circle*` mean when the subject is a `Shape*`?
`dynamic_cast<Circle*>(pointer)` returns null when the object is not a `Circle`,
but it also returns null when `pointer` is null. If that is a successful match,
we enter a `Circle*` case with a null pointer. If it is a failed match, an exact
`Shape*` declaration and a runtime-checked `Circle*` declaration behave
differently for null despite looking the same. In a template, the same pattern
could also change from static type selection to a nullable runtime test as `T`
changes.

We therefore do not perform runtime polymorphic casts from one pointer type to
another. Pointer declarations admit the restricted static pointer relationships
in [Static Declaration Matching], but no runtime downcast. To test the
pointee's runtime type, first match the non-null state and then match the
resulting object:

```cpp
void draw_shape(Shape* shape) {
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
pointer is itself stored inside another alternative type, both projections are
visible:

```cpp
variant<Shape*, int> value;

match (value) {
  case { { Circle& circle } } => draw_circle(circle);
  case { int integer }        => use(integer);
  case _                      => other();
}
```

For a known `Shape*` subject, a bare `Circle*` pattern is not viable and is
ill-formed. In a dependent match it follows the general rules for a
potentially viable declaration case; it does not acquire runtime
polymorphic pointer-cast semantics:

```cpp
template <class T>
int match_pointer(T* pointer) {
  return match (pointer) {
    case Circle* circle => 1;
    case _              => 0;
  };
}

Circle circle;
match_pointer(&circle);                    // 1: exact Circle* declaration
match_pointer(static_cast<Shape*>(&circle)); // 0: no polymorphic pointer cast
```

This difference is intentional. `{ Circle& }` asks about the runtime type of
the pointee. References do not have the null problem because a reference always
denotes an object.

## Strict Viability

We considered making an invalid dependent single-pattern test evaluate to
`false`. This is convenient for shape detection, but combines two questions:

- can the operation be formed?
- does this runtime value match?

C++ normally answers the first with `requires` and the second with a Boolean
expression. We keep those questions separate. This also prevents a typo in a
required pattern condition from silently selecting `else`.

```cpp
requires { match(E, case P); } // Is the pattern test well-formed?
match(E, case P)               // Does this value match?
```

A simple requirement checks whether the pattern test is well-formed without
evaluating the subject. This includes viability and any required declaration
initialization:

```cpp
template <class T>
concept is_two_element = requires (T& value) {
  match(value, case [_, _]);
};

static_assert(is_two_element<std::pair<int, double>>);
static_assert(!is_two_element<int>);
```

Dependent match selections behave differently: a non-viable source case is
discarded for that specialization. A well-formed unguarded single-pattern test is
therefore equivalent in value to:

```cpp
(match (E) { case P => true; case _ => false; })
```

An unguarded test with an irrefutable pattern makes the alternative appear
especially tempting. Once such a pattern is viable, it always matches, so
`false` would uniquely mean that the pattern was not viable. The expression
would nevertheless remain an evaluated context: `match(do_work(), case P)`
evaluates `do_work()` and any required matching operations. By contrast,
`requires { match(do_work(), case P); }` asks whether the test is well-formed
and does not call `do_work()`. We retain that separation even for irrefutable
patterns.

An explicit `match requires` mode was also considered. It makes generic
structural dispatch convenient, but gives us two nearly identical forms of
`match`. It also does not remove the need to distinguish a non-viable case
from a selected declaration whose initialization is invalid. We keep
single-pattern tests strict and handle dependent match cases separately.

This changes the strict static-condition rule explored in R5. That rule caught
mistakes such as a string literal in a character match:

```cpp
template <class Operator>
void evaluate(const Operator& op) {
  match (op.kind()) {
    case '+' => add();
    case '-' => subtract();
    case "/" => divide(); // probably meant '/'
    case _   => unknown();
  }
}
```

If `op.kind()` is dependent, the `"/"` case does not apply when the result is
`char`. This behavior is needed for generic cases over a dependent alternative
type, but it does make this typo harder to find. A strict single-pattern test
and an explicit `requires` expression can still ask whether a pattern is valid.
We should discuss whether dependent match selections also need an opt-in strict
mode.

## Multiple Subjects and Single-Pattern Tests

Prefix syntax provides a natural boundary for matching several values. The
product model described in [Multiple Subjects] keeps arity matching uniform
for every pack size, including zero- and one-element expansions.

The corresponding Boolean test is:

```cpp
match(value, case P)
match(first, second, case [P, Q])
```

The comma before `case` ends the subject list, and the closing parenthesis ends
the pattern. This gives both sides an explicit boundary:

```cpp
match(value, case A or B) || ready
```

The `or` is an or-pattern and `||` is an ordinary logical operator. Logical
expressions used as value patterns remain explicit, for example
`match(value, case bool(A || B))`.

R5 instead used the postfix test `value match P`. Once `or` became an
or-pattern, `value match A or B` could mean either one pattern or a logical
disjunction. It also needed a new operator precedence and did not extend
naturally to several subjects. Dropping `case` or writing `value match
(case P)` retained those problems.

We also considered `match(value; case P)` and `match(value) { case P }`. The
semicolon is a strong parser boundary but unfamiliar in the common one-subject
form. The handler-less match selection looks incomplete and gives braces a second
set of exhaustiveness and result rules. `match(value, case P)` reads like a
function call while `case` remains an unambiguous pattern introducer.

A pattern condition remains a separate facility because it makes its declared
names available in later `&&` conditions and the successful controlled
statement:

```cpp
if (case int value = input)
  use(value);

bool is_integer = match(input, case int);
```

## Pattern Contexts

Rust uses patterns in selections, conditions, declarations, function and
closure parameters, and iteration. The following table compares those
contexts with this proposal and existing C++ facilities:

| Context | Rust | C++ with this proposal |
|---------|------|------------------------|
| Selection | `match $E$ { /* cases */ }` | `match ($E$) { /* cases */ }` as a statement or expression |
| Boolean test | `matches!($E$, $P$)` macro | `match($E$, case $P$)` |
| Conditional binding | `if let $P$ = $E$`, `while let $P$ = $E$` | Pattern conditions in `if`, `while`, and traditional `for` |
| Unconditional binding | `let $P$ = $E$;` | Ordinary declarations and structured bindings |
| Binding with an early exit | `let $P$ = $E$ else { /* exits */ };` | No standalone counterpart in this proposal |
| Function and closure parameters | Irrefutable patterns | Ordinary parameters, with structured bindings in the body |
| Iteration | `for $P$ in $E$` | Range-based `for` declarations, including structured bindings |

Rust requires irrefutable patterns in ordinary `let` declarations, parameters,
and `for` bindings. These are primarily used to introduce names and decompose
values. C++ already has declarations and structured bindings for those uses:

```cpp
auto&& [first, second] = pair;

for (auto&& [key, value] : entries)
  use(key, value);
```

[Pattern Matching Constructs] covers selections, tests, and conditional
bindings. We could also allow standalone pattern declarations:

```cpp {.not_proposed}
case P = E;
case P = E else S;
```

The main use case for `case P = E;` is destructuring, which is already
supported by structured bindings. Allowing arbitrary patterns here would also
require us to decide what happens when a pattern fails.

`case P = E else S;` provides an early exit when the pattern fails, while
keeping the declared names in scope afterward. A pattern condition instead
keeps its names within the successful controlled statement and later `&&`
conditions. The standalone form is useful, but a bit more novel in C++. It can
be added later, so we leave it out of this revision. Both standalone forms are
implemented as prototype extensions, but are not proposed here.

# Deferred Extensions

This proposal deliberately leaves the following facilities for later work.
Their syntax and interaction with introduced names should not be fixed
accidentally by this paper.

## Relational and Range Patterns

Patterns such as `< 0`, `1..10`, or a general range test would make numeric
classification substantially more expressive. They also raise questions about
open and closed endpoints, floating-point values, overloaded comparisons, and
exhaustiveness. This proposal retains ordinary predicate objects for these
cases.

## And-Pattern and Whole-Value Naming Patterns

An and-pattern could apply several predicates to the same subject:

```cpp
case std::meta::is_function and std::meta::is_deleted =>
  handle_deleted_function();
```

It could also name a whole value selected by another pattern:

```cpp
case (Direction::North or Direction::South) and auto direction =>
  use(direction);
```

The prototype implements both forms. Its and-pattern matches both subpatterns
against the same subject, from left to right, and covers the intersection of
their matching domains. `and` binds more tightly than `or`. Declarations from
a successful left subpattern are initialized before the right subpattern is
tested, then destroyed if it fails. As with declarations initialized before a
guard, a left subpattern cannot perform a non-trivial move. Names become
available to the guard and handler after the complete pattern succeeds; they
are not inputs to another subpattern.

Our LLVM migration did not find a compelling use for and-patterns. They are
attractive, but R7 does not need them. A future proposal can revisit the
prototype's choices together rather than making them part of this revision.

This paper makes `P and Q` ill-formed, reserving that syntax for such an
extension. A logical-and expression can still be written unambiguously as
`bool(P && Q)`. R7 includes only `or`.

Other languages instead provide dedicated whole-value naming forms such as
Rust's `name @ P` and OCaml's `P as name`.

## Extractors and Sequence Patterns

Extractors could permit user-defined structural views that are not naturally
modeled as alternative types or structured bindings. Dynamic slice and
sequence patterns would similarly extend decomposition beyond statically known
arity. Neither is needed for the product and alternative model proposed here.

## Further Customization

The alternative protocol proposed here uses reflection to describe states, but
runtime discrimination still uses `index(subject)` and projection uses `get`.
A fully reflection-driven projection protocol remains possible future work.

# Implementation Experience

We have implemented the proposal in Clang. The implementation is available at
<https://github.com/mpark/llvm-project/tree/p2688-pattern-matching> and on
[Compiler Explorer](https://godbolt.org) as
`x86-64 clang (pattern matching - P2688)`{.default}. It is enabled with
`-fpattern-matching`.

## What Is Implemented

- Parsing and AST representation for match expressions, cases, patterns, and
  pattern conditions.
- Declaration, type, value, decomposition, alternative, pointer, and
  polymorphic object patterns, including closed and open protocols, recursive
  type selectors, and parameterized selectors such as variant's `.index<I>`.
- Dependent semantic case instantiation, including case-local packs and
  alternative-dependent types.
- Constant evaluation and runtime code generation, including decision-tree
  planning for nested patterns and coalesced switch dispatch for suitable
  closed discriminators and built-in integral value patterns.
- Subject evaluation and lifetime extension.
- Multiple-subject products, including dependent packs and preservation of
  each subject's value category.
- Projection reuse, including discriminator caching.
- Structured-binding and subpattern packs.
- Arbitrary statement handlers for match selection statements, and result deduction,
  null handlers, `static_assert`, non-returning expression handlers, jump
  actions, and `do` expressions for match selection expressions.
- Pattern-matrix exhaustiveness and usefulness diagnostics with source-like
  witnesses.
- CFG and several analysis integrations.

## Integration Experience

Clang's `DeclContext::getDeclKind()` returns `Decl::Kind`, but only some values
of that enumeration identify `DeclContext` classes. The historical
`DeclContextPrinter` switched on this value and used an unreachable default:

```cpp
switch (DC->getDeclKind()) {
  case Decl::Namespace: // ...
  case Decl::CXXRecord: // ...
  // ...
  default:
    llvm_unreachable("a decl that inherits DeclContext isn't handled");
}
```

The switch omitted `ClassTemplateSpecializationDecl` and
`ClassTemplatePartialSpecializationDecl`, causing a runtime crash. LLVM commit
[`eebc494a577a`](https://github.com/llvm/llvm-project/commit/eebc494a577adb3d67a778c6fa1488299016ee88)
added both cases. A generated `alternative_traits<DeclContext>` lists the
concrete `DeclContext` classes. A match is checked against that list, rather
than every value of `Decl::Kind`. Either omission can then be diagnosed as a
non-exhaustiveness error without requiring a wildcard, as described in
[Required and Residual Domains].

## Implementation Notes

### Parsing Selections and Patterns

The prototype implements [Contextual Parsing of `match`] with
`isPrefixMatchSelection`. It scans the balanced subject list, uses Clang's
existing tentative declarator and type-id facilities only in the ambiguous
cases, restores the parser, and then runs either the ordinary parser or the
match-selection parser normally. Diagnostic recovery can recognize additional
ill-formed match-shaped input without changing the classification of valid
programs.

The token following the subject can be arbitrarily far from `match`. C++
already requires this kind of decision for declarations and expressions:

```cpp
T (*****x) = y;   // declaration
T (*****x) == y;  // expression
```

A production parser can avoid repeated work in deeply nested cases by caching
matching delimiters. For malformed programs, the implementation can run the
real trailing-return-type parser tentatively, including normal recovery and
typo correction, and then rewind to issue a match-specific diagnostic.
Similarly, a top-level `=>` in a declaration-shaped body can support a focused
missing-`case` diagnostic without changing the grammatical classification.

Declaration patterns use `TryParseDeclarationPatternSyntax` for the
disambiguation described in [Declaration Patterns], then the ordinary
declarator parser. The `[[` probe is shared with nested structured-binding
parsing.

### Source Cases and Case Instantiations

One source case can produce several differently typed case instantiations. The
prototype initially tried to mutate and replay source AST nodes; that model was
fragile under later tree transformations. It now separates source cases from
`MatchCaseInstantiation` objects. The wording needs to describe the resulting
case-local instantiation semantics without exposing those implementation
objects.

The prototype currently represents the multiple-subject product as an
implicit anonymous `CXXRecordDecl` with reference fields, and records its
identity in `Sema` so recursive decomposition can restore each element's value
category. That is sufficient for experimentation, but a production
implementation should use a durable AST representation or marker. The current
registry is not suitable for serialization, module import, or AST cloning in a
different semantic context.

### Exhaustiveness Checking

[@P2211R0] previously developed Maranget-based exhaustiveness checking for
C++ pattern matching. This proposal extends the model with
`std::alternative_traits`, redundancy diagnostics, and case-local
instantiation.

The prototype's coverage analysis uses an adapted Maranget/Rust
pattern-matrix algorithm. This analysis is separate from runtime decision-tree
lowering. The standard should specify the observable behavior rather than
refer to either implementation algorithm.

The same matrix is built incrementally during dependent case instantiation,
as described in [Case-Local Instantiation]. One analysis determines which case
instantiations are needed, reports redundant cases, and checks final
exhaustiveness.

### Decision-Tree Lowering

Runtime code generation separates planning from emission. After semantic
analysis produces the case instantiations, `MatchDecisionTree` represents
their remaining tests as rows and columns. For example, consider two integer
subjects:

```cpp
match (first, second) {
  case [1, _] => one();
  case [_, 2] => two();
  case [_, _] => other();
}
```

Each case contributes a row, and each subject has a column:

| Case | `first` | `second` |
|------|---------|----------|
| `one()` | `1` | No test |
| `two()` | No test | `2` |
| `other()` | No test | No test |

The wildcard contributes no test. The planner keeps rows in source order and
stores only columns that have tests. Decomposition exposes columns for its
components, and a successful alternative test exposes columns for the selected
payload.

The planner considers branchable columns in the first remaining row. It follows
the first-clause strategy and greedy approach to limiting duplication described
by [Jules Jacobs](https://julesjacobs.com/notes/patternmatching/patternmatching.pdf).
The prototype uses the heuristic from [Yorick Peterse's
implementation](https://gitlab.com/yorickpeterse/pattern-matching-in-rust/-/tree/main/jacobs2021):
choose the first-row column whose subject is tested most frequently across the
remaining rows.

The emitter currently handles the resulting plan as follows:

| Planned operation | Current lowering |
|---|---|
| Closed alternatives on one discriminator | One cached discriminator, with consecutive tests coalesced into a switch for integral or enumeration discriminator types |
| Compatible consecutive built-in integral values on one subject | A coalesced switch when the ordinary comparison conversions agree |
| Open projections, type tests, and polymorphic casts | Shared binary tests with projection materialized only on success |
| Nested decomposition and multiple subjects | Recursive tests on structural subject paths |
| Compatible unguarded case instantiations | A shared handler, with same-typed reference bindings merged by PHIs |
| Remaining tests and declarations | Ordered candidate emission |

Guard evaluation and reuse follow [Case Selection and Initialization] and
[Matching Operation Order and Reuse]. The frontend emits the dispatch directly,
rather than obtaining it by inlining `std::visit`. Library-defined
discriminators and projections can still require inlining for efficient code.

The prototype builds a tree, not a fully shared DAG. Rows that do not test the
selected subject can occur in both subtrees, so some tests may be duplicated.

### Dynamic Class Matching

Polymorphic declaration patterns use the `dynamic_cast` semantics described in
[Polymorphic Class Matching], including open-world derived
classes and pointer adjustment. Reuse follows [Matching Operation Order and
Reuse]. The compiler can reuse repeated targets, derive a base match from a
successful more-derived match, use final-class fast paths, and employ LTO or
profile-guided caches while preserving those semantics.

### Caching Discriminators and Projections

A discriminator can often be shared more broadly than a projected object. In
a product match, a sibling alternative discriminator may be independent of an
earlier alternative selection, while its projected reference is created only
inside a particular dominated branch. The prototype therefore distinguishes
cache identity for discriminators from cache identity for selected projections.

# Wording Status

The wording in [@P2688R5] describes the R5 design and is not reproduced here as
if it described this revision. The grammar and semantic rules in this paper
serve as its design specification. Complete wording remains to be written.

The intended wording work includes the lexical treatment of `=>`, match
selection statements and expressions, pattern grammar and semantics, scope,
dependence, constant evaluation, and the `alternative_traits` library protocol.

# Appendix A: Four-Way Comparison Tables {#comparison-tables}

The following are 4-way comparison tables between C++23, [@P1371R3], [@P2392R3],
and this paper.

## Matching Integrals

::: cmptable

### C++23
```cpp
switch (x) {
  case 0: std::println("got zero"); break;
  case 1: std::println("got one"); break;
  default: std::println("don't care");
}
```

### P1371R3
```cpp
inspect (x) {
  0 => std::println("got zero");
  1 => std::println("got one");
  __ => std::println("don't care");
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (x) {
  is 0 => std::println("got zero");
  is 1 => std::println("got one");
  is _ => std::println("don't care");
};
```

### This Paper
```cpp
match (x) {
  case 0 => std::println("got zero");
  case 1 => std::println("got one");
  case _ => std::println("don't care");
}
```

:::

## Matching Strings

::: cmptable

### C++23
```cpp
if (s == "foo") {
  std::println("got foo");
} else if (s == "bar") {
  std::println("got bar");
} else {
  std::println("don't care");
}
```

### P1371R3
```cpp
inspect (s) {
  "foo" => std::println("got foo");
  "bar" => std::println("got bar");
  __ => std::println("don't care");
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (s) {
  is "foo" => std::println("got foo");
  is "bar" => std::println("got bar");
  is _ => std::println("don't care");
};
```

### This Paper
```cpp
match (s) {
  case "foo" => std::println("got foo");
  case "bar" => std::println("got bar");
  case _ => std::println("don't care");
}
```

:::

## Matching Tuples

::: cmptable

### C++23
```cpp
auto&& [x, y] = p;
if (x == 0 && y == 0) {
  std::println("on origin");
} else if (x == 0) {
  std::println("on y-axis at {}", y);
} else if (y == 0) {
  std::println("on x-axis at {}", x);
} else {
  std::println("at {}, {}", x, y);
}
```

### P1371R3
```cpp
inspect (p) {
  [0, 0] => std::println("on origin");
  [0, y] => std::println("on y-axis at {}", y);
  [x, 0] => std::println("on x-axis at {}", x);
  [x, y] => std::println("at {}, {}", x, y);
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (p) {
  is [0, 0] =>
    std::println("on origin");
  is [0, _ y] =>
    std::println("on y-axis at {}", y);
  is [_ x, 0] =>
    std::println("on x-axis at {}", x);
  is [x, y] =>
    std::println("at {}, {}", x, y);
};
```

### This Paper
```cpp
match (p) {
  case [0, 0] =>
    std::println("on origin");
  case [0, int y] =>
    std::println("on y-axis at {}", y);
  case [int x, 0] =>
    std::println("on x-axis at {}", x);
  case [int x, int y] =>
    std::println("at {}, {}", x, y);
}
```

:::

## Matching Variants

::: cmptable

### C++23
```cpp
struct visitor {
  void operator()(int32_t i32) const {
    std::println("got int32: {}", i32);
  }
  void operator()(int64_t i64) const {
    std::println("got int64: {}", i64);
  }
  void operator()(float f) const {
    std::println("got float: {}", f);
  }
  void operator()(double d) const {
    std::println("got double: {}", d);
  }
};
std::visit(visitor{}, v);
```

### P1371R3
```cpp
inspect (v) {
  <int32_t> i32 =>
    std::println("got int32: {}", i32);
  <int64_t> i64 =>
    std::println("got int64: {}", i64);
  <float> f =>
    std::println("got float: {}", f);
  <double> d =>
    std::println("got double: {}", d);
};
```

:::

::: cmptable

### P2392R3
```cpp
inspect (v) {
  as int32_t i32 =>
    std::println("got int32: {}", i32);
  as int64_t i32 =>
    std::println("got int64: {}", i64);
  as float f =>
    std::println("got float: {}", f);
  as double d =>
    std::println("got double: {}", d);
};
```

### This Paper
```cpp
match (v) {
  case { int32_t i32 } =>
    std::println("got int32: {}", i32);
  case { int64_t i64 } =>
    std::println("got int64: {}", i64);
  case { float f } =>
    std::println("got float: {}", f);
  case { double d } =>
    std::println("got double: {}", d);
}
```

:::

## Matching Variant Alternatives with Concepts

This example matches variant alternatives using concepts.

::: cmptable

### C++23
```cpp
struct visitor {
  void operator()(
      std::integral auto i) const {
    std::println("got integral: {}", i);
  }
  void operator()(
      std::floating_point auto f) const {
    std::println("got float: {}", f);
  }
};
std::visit(visitor{}, v);
```

### P1371R3
```cpp
inspect (v) {
  <std::integral> i =>
    std::println("got integral: {}", i);
  <std::floating_point> f =>
    std::println("got float: {}", f);
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
    std::println("got integral: {}", i);
  case { std::floating_point auto f } =>
    std::println("got float: {}", f);
}
```

:::

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
    case _ => throw UnknownShape{};
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
  case { Move: auto& [x, y] } => // ...
  case { Write: auto& [text] } => // ...
  case { ChangeColor: [{ Rgb: auto& [r, g, b] }] } => // ...
  case { ChangeColor: [{ Hsv: auto& [h, s, v] }] } => // ...
}
```

:::

This example is adapted from
[Destructuring Nested Structs and Enums](https://doc.rust-lang.org/book/ch18-03-pattern-syntax.html#destructuring-nested-structs-and-enums)
in the Rust documentation.

# Acknowledgements

Thank you to all of the following folks:

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
