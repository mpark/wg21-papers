# P2688R6 Writing Notes

These notes are the working source of truth for revising P2688 from R5 to R6.
They are organized around what the paper needs to explain, justify, specify,
and validate. They are not proposed wording.

The implementation notes describe the `p2688-pattern-matching` branch audited
through 2026-08-25 at commit `84176bcf8ad4`. Commit hashes are deliberately not
used below as a design index because this branch is frequently rebased.

## How to Use These Notes

`P2688R6.md` is being maintained as an incremental revision of R5. Existing
motivation, comparisons, rationale, acknowledgements, and proposed wording are
retained while R6 changes are applied section by section. Obsolete `let`,
`? P`, `T: P`, and parenthesized-pattern material remains where useful as an
explicitly labeled R5 baseline until the adjacent R6 design or wording is
complete. These notes remain the detailed design and prototype audit from
which those edits are drawn.

The R6 paper should have three layers:

1. A short, example-driven explanation of the user model.
2. Detailed design rationale for declarations, projection, templates,
   exhaustiveness, and evaluation.
3. Wording and library customization that follow the same state model.

Implementation defects and tooling omissions belong in the prototype audit,
not in the main design narrative. The audit distinguishes wording blockers,
prototype correctness defects, engineering debt, and deliberately deferred
tooling.

Within the design sections, use these labels consistently:

- **Current direction** is the design R6 should present unless discussion
  changes it.
- **Open question** identifies a decision that the paper must expose or make.
- **Implementation evidence** records what the prototype taught us; it is not
  specification by accident.
- **Deferred work** is outside the intended R6 scope and should not obscure the
  core proposal.

### R6 discussion map

This is the short agenda from which the R6 design discussion should be seeded.
The detailed sections below contain the rationale, examples, alternatives, and
prototype evidence for each item.

| Area | Current direction | Discussion still needed |
|---|---|---|
| Current-subject declarations | A bare declaration pattern binds the current subject using exact-match initialization rules and never performs runtime refinement. | Nail down the exact conversion set, reference and bit-field behavior, arrays/functions, and constraints. |
| Explicit runtime projection | Braces enter a runtime projection or refinement layer. `{ P }`, `{ .name: P }`, and `{}` represent generic, named, and empty choice states; `{ T& x }` can also request built-in polymorphic refinement. | Decide whether a typed recursive selector is needed and finish wording for cross-casts, pointer adjustment, and open-world hierarchies. |
| `alternative_traits` | The protocol supports closed, open, and named views; raw pointers use equivalent built-in behavior. | Finalize the API, malformed-specialization diagnostics, `noexcept` requirements, header availability, and provider coherence. |
| Templates | A source arm can produce semantic instantiations for each applicable projected type. An inapplicable pattern may be omitted under the dependent-arm model, but an applicable declaration whose initialization is ill-formed is an error. Impossible, refutable, and irrefutable cases are distinguished. | Specify implicit template-region identity, lookup, captures, statics, diagnostics, dependent usefulness, and the exact applicability boundary. |
| Evaluation | Evaluate the subject once; use ordinary declaration initialization before a guard; permit equivalent projections to be reused. | Specify projection ordering and retention, mutation and invalidation effects, exceptions, cleanup, and lifetime precisely enough for portable reasoning. |
| Exhaustiveness | Non-exhaustiveness and redundancy are errors. Required and residual domains support enums and valueless variants. | Stabilize the normative usefulness model, dependent behavior, enum attributes, witness quality, and complexity expectations. |
| Single-pattern conditions | `E match case P` is a strict ordinary Boolean expression without outward bindings. `case P = E` introduces bindings in direct conditions and can participate in a left-to-right `&&` chain, while `case P : range` filters a range-for. All forms require viability. | Decide whether R6 should retain all forms and settle the remaining grammar and irrefutability diagnostics. |
| Handlers and results | Handlers include expressions, `=> ;`, direct `static_assert`, and jump actions, with `do` integration for statements that yield. | Complete result deduction, fallthrough, unmatched execution, and control-flow wording. |
| Larger pattern facilities | Named members, or-patterns, range patterns, whole-value binding, early-exit declarations, and eventually dynamic slice patterns are the strongest facilities suggested by Rust, Swift, and C#. | Decide which are R6 scope. Or-pattern spelling and binding semantics need focused design; named members and ranges have strong independent motivation. |

The prototype audit is supporting evidence for this agenda. Prototype
limitations should become either explicit implementation work or deliberate
design constraints, never silent normative choices.

### Audit of the current source material

The incremental R6 draft has incorporated:

- the post-R5 revision summary and C++29 targeting;
- declaration and type patterns;
- explicit choice projection and the current `alternative_traits` direction;
- strict single-pattern tests and binding-producing direct conditions;
- dependent case instantiation and implicit template regions;
- required/residual exhaustiveness;
- the evaluation and projection-reuse model;
- production examples and the visitor-rewrite caveat;
- current implementation experience and known gaps.

The paper still needs:

- final decisions for the open questions listed near its end;
- normative wording revised from the retained R5 baseline;
- a final library API review for `alternative_traits`;
- reconciliation with the nested structured-bindings paper once that design is
  assigned a paper number;
- updated Compiler Explorer links and implementation revision information;
- editorial tightening after the design review stabilizes.

The slides are closer to the current direction and provide useful real-world
examples. Their `any` protocol is stale (`type()`/`get<T>()` rather than
`try_cast<T>`/`has_value`), and they do not yet cover `case P = E`, the latest
lifetime work, or the condition-parser tradeoffs.

## R6 Thesis

R5 established a composable pattern language and a unified `match`
expression. R6 should preserve those foundations while making the common C++
use cases more familiar and making runtime projection explicit.

The central model is:

> A pattern matches the current subject. A declaration binds the current
> subject using ordinary C++ declaration semantics. Braces explicitly enter a
> runtime projection or refinement layer.

This separates four operations that earlier designs risked conflating:

- value matching, such as `0` or `Color::red`;
- binding the current subject, such as `auto&& value`;
- runtime refinement of the current subject, such as `{ Circle& circle }` from
  a polymorphic `Shape&`;
- projecting a state stored by a choice, such as `{ int value }` from a
  `variant` or `any`.

The design continues to require full pattern composition. Every pattern form
must remain usable as a child of decomposition and projection patterns.

## R5 to R6 Revision Summary

The revision-history section should lead with these changes.

### Surface language

- Match arms now require `case`:

  ```cpp
  value match {
    case 0 => zero();
    case _ => other();
  };
  ```

- `let` bindings are replaced by declaration patterns:

  ```cpp
  case auto&& value
  case Widget value
  case const Widget& value
  case std::integral auto value
  ```

- A type pattern has the viability semantics of a declaration pattern with its
  identifier omitted, but does not actually initialize an object:

  ```cpp
  case int
  case const Widget&
  case void
  ```

- Braces explicitly enter a runtime projection or refinement layer:

  ```cpp
  case { int value }
  case { auto&& alternative }
  case { auto&& [x, y] }
  ```

- Named projection and non-projectable state patterns are added:

  ```cpp
  case { .value: int value }
  case { .error: Error& error }
  case {}
  ```

- The R5 `? P` optional pattern is removed. Pointer and optional states use
  the same projection model as other choices.
- The R5 parenthesized pattern is removed. Parentheses retain ordinary
  expression meaning.
- The R5 unbraced `T: P` alternative selector is removed for now. A typed
  recursive selector remains an open composition question.
- The single-pattern expression now requires `case`:

  ```cpp
  value match case P
  ```

- A Swift-inspired direct condition spelling is also retained for R6
  exploration:

  ```cpp
  if (case P = value) {
    // bindings from P are available here
  }
  ```

### Semantic changes and additions

- Declaration patterns use ordinary C++ initialization and reference binding,
  restricted to overload-resolution exact-match conversion rank.
- Bare declaration and type patterns perform only static exact matching.
- Braced patterns can request built-in polymorphic refinement using
  `dynamic_cast` when the current subject is a polymorphic class glvalue.
- `variant`, `optional`, `expected`, and user-defined choices use a closed
  `alternative_traits` protocol.
- `any` and other open erased choices use an open `alternative_traits`
  protocol based on `try_cast<T>` and optional `has_value`.
- Raw pointers use a built-in two-state model. The library-provided
  `alternative_traits<T*>` mirrors that model only so selected nullable types
  can reuse it by inheritance; the compiler does not consult it for raw
  pointers.
- Non-exhaustiveness and redundant arms are hard language errors.
- Coverage distinguishes required states from residual states.
- The subject is evaluated once. Equivalent projections may be retained and
  reused under a specified implementation-latitude model.
- Generic projected arms have separate semantic instantiations for their
  viable projected types.
- Structured-binding packs are permitted in declaration patterns even when
  the enclosing function is not a template. The case declaration, guard, and
  handler form the implicit template region in which the pack is expanded.
  Direct `if`, `while`, and C-style `for` conditions also instantiate the
  controlled statement and `for` increment in that region.
- A decomposition can contain one arity-inferred subpattern pack. A
  declaration pack binds the consumed elements:

  ```cpp
  case [auto&& first, auto&& ...middle, auto&& last]
  ```

  A wildcard pack ignores them:

  ```cpp
  case [auto&& first, ..._, auto&& last]
  ```

  Its size is the decomposition arity minus the fixed prefix and suffix. A
  declaration pack's names form a local pack available to the guard and
  handler.
- Unguarded irrefutable arms suppress instantiation of later semantic arms in
  the domains they completely handle, independently of exhaustiveness.
- Single-pattern matching and dependent multi-arm matching intentionally have
  different invalid-pattern behavior.

### Implementation progress since R5

- Runtime code generation is implemented for the supported patterns.
- Dependent match expressions and alternative specialization are implemented.
- Constant evaluation, result typing, control-flow actions, subject lifetime,
  and projection reuse have substantial test coverage. CFG construction has
  branch-shape coverage, but the prototype audit below identifies missing
  pattern-evaluation effects.
- Exhaustiveness and usefulness checking use a pattern-matrix algorithm.
- Modules/PCH serialization and broad tooling integration remain deliberately
  outside the prototype scope.

R6 should also retain the history that the R5 C++26 forwarding poll did not
reach consensus and that the proposal now targets C++29.

## Evidence and Motivation

R6 should not begin from syntax alone. It should show the recurring C++ code
that the syntax is intended to replace.

### Findings from the code survey

A broad, non-exhaustive survey of large production C++ codebases found these
recurring forms:

| Existing form | Intended pattern operation |
|---|---|
| `std::visit(overloaded{...})` | Dispatch by active alternative and bind it |
| `get_if` / `holds_alternative` chains | First-match runtime type dispatch |
| `switch (v.index())` plus `get<I>` | Dispatch by state, then project |
| `has_value()` / `hasError()` branches | Split value, empty, and error states |
| `dynamic_cast` chains | Refine a polymorphic object |
| `visit([](auto x) { return x == 0; })` | Apply one value pattern across alternatives |
| nested `if` tests over tuple members | Compose type, value, and structure tests |

Most variant arms name and bind a concrete payload type. Generic projected
handling and structural matching across alternatives are less common, but
they are capabilities that C++'s closed generic sum types uniquely need.

The survey did not find enough static multi-dispatch code to justify making
runtime declaration syntax also carry a speculative static-dispatch model.
Static type subjects should be presented as a future extension instead.

### Core before-and-after examples

The paper should include real, adapted examples for at least these cases:

1. Replacing visitor ceremony:

   ```cpp
   return std::move(value) match -> Result {
     case { Foo foo }    => from_foo(foo);
     case { Bar bar }    => from_bar(bar);
     case { auto&& rest } => fallback(FWD(rest));
   };
   ```

2. Replacing a `get_if` chain:

   ```cpp
   filter match {
     case { InSetFilter& in }   => use(*in.attributeValues());
     case { RangeFilter& range } => use(*range.attributeValue());
   };
   ```

3. Applying one structural pattern to several alternatives:

   ```cpp
   using V = variant<tuple<int, int>, pair<int, int>, array<int, 2>>;

   value match {
     case { auto&& [x, y] } => use(x, y);
   };
   ```

4. Optional, expected, open choice, and polymorphic refinement.
5. Nested value patterns that are substantially clearer than a visitor plus
   an inner `if` chain.
6. Forwarding an alternative from an rvalue variant with `{ auto&& value }`.

The paper should be candid that typed payload binding is the dominant case.
The more general projection syntax is justified by composition and generic
payload handling, not by claiming that every match needs it.

### Real-world case studies

The following examples are fuzzed adaptations of production code. Names,
domains, and incidental implementation details have been changed while
preserving the control-flow and type-shape properties relevant to the design.

#### Configuration state represented by variant tuple shapes

The representation contains five alternatives:

```cpp
std::variant<
    tuple<UniformMode, T>,
    tuple<DeltaMode, T>,
    tuple<ClobberMode, T>,
    tuple<DeltaMode, T, T>,
    tuple<ClobberMode, T, T>>
    value_;
```

The original `hasSecondary` spells out one visitor overload for every
alternative:

```cpp
bool hasSecondary() const {
  struct Vis {
    bool operator()(const tuple<UniformMode, T>& /*unused*/) {
      return false;
    }
    bool operator()(const tuple<DeltaMode, T>& /*unused*/) {
      return false;
    }
    bool operator()(const tuple<DeltaMode, T, T>& /*unused*/) {
      return true;
    }
    bool operator()(const tuple<ClobberMode, T>& /*unused*/) {
      return false;
    }
    bool operator()(const tuple<ClobberMode, T, T>& /*unused*/) {
      return true;
    }
  };
  return std::visit(Vis{}, value_);
}
```

With pattern matching, tuple arity directly expresses the property:

```cpp
bool hasSecondary() const {
  return value_ match {
    case { [_, _, _] } => true;
    case { [_, _] }    => false;
  };
}
```

The original `delta` uses the class's following `unpack` adapter, which
combines `std::visit` and `std::apply`:

```cpp
template <class F>
auto unpack(F&& f) const {
  return std::visit(
      [&](auto&& tupleValue) {
        return std::apply(
            std::forward<F>(f),
            std::forward<decltype(tupleValue)>(tupleValue));
      },
      value_);
}
```

It then enumerates all five alternatives:

```cpp
const T* delta() const {
  struct Vis {
    const T* operator()(UniformMode /*_*/, const T& /*uniform*/) {
      return nullptr;
    }
    const T* operator()(DeltaMode /*_*/, const T& delta) {
      return &delta;
    }
    const T*
    operator()(DeltaMode /*_*/, const T& delta, const T& /* clobber */) {
      return &delta;
    }
    const T* operator()(ClobberMode /*_*/, const T& /* clobber */) {
      return nullptr;
    }
    const T*
    operator()(ClobberMode /*_*/, const T& /*clobber*/, const T& delta) {
      return &delta;
    }
  };
  return unpack(Vis{});
}
```

The pattern version states only the combinations that produce a Delta value:

```cpp
const T* delta() const {
  return value_ match -> const T* {
    case { [DeltaMode, auto const& delta] } =>
      &delta;

    case { [DeltaMode, auto const& delta, _] } =>
      &delta;

    case { [ClobberMode, _, auto const& delta] } =>
      &delta;

    case _ =>
      nullptr;
  };
}
```

This example combines closed-choice projection, structural decomposition,
type patterns, declaration patterns, and tuple arity. It describes the domain
states rather than encoding them as an overload set.

#### Merging compact and expanded keyed representations

The implementation stores no entries, one entry, or many entries as:

```cpp
using SingleEntry = std::pair<Key, Values>;
using EntryMap = folly::F14FastMap<Key, Values>;
using Entries = std::variant<std::monostate, SingleEntry, EntryMap>;
```

The complete original move overload is a conventional nested dispatch over
the source and destination representations:

```cpp
void mergeEntries(Entries& to, Entries&& from) {
  if (std::holds_alternative<std::monostate>(from)) {
    // no-op
  } else if (std::holds_alternative<std::monostate>(to)) {
    to = std::move(from);
  } else if (auto* from_pair = std::get_if<SingleEntry>(&from)) {
    if (auto* pair = std::get_if<SingleEntry>(&to)) {
      if (pair->first != from_pair->first) {
        EntryMap map;
        map.reserve(2);
        map.emplace(pair->first, std::move(pair->second));
        map.emplace(from_pair->first, std::move(from_pair->second));
        to = std::move(map);
      }
    } else if (auto* map = std::get_if<EntryMap>(&to)) {
      map->try_emplace(from_pair->first, std::move(from_pair->second));
    } else {
      folly::assume_unreachable();
    }
  } else if (auto* from_map = std::get_if<EntryMap>(&from)) {
    if (auto* pair = std::get_if<SingleEntry>(&to)) {
      from_map->insert_or_assign(pair->first, std::move(pair->second));
      to = std::move(*from_map);
    } else if (auto* map = std::get_if<EntryMap>(&to)) {
      for (auto&& [k, v] : *from_map) {
        map->try_emplace(k, std::move(v));
      }
    } else {
      folly::assume_unreachable();
    }
  }
}
```

Matching the source first and destination second exposes the operation as a
state matrix:

```cpp
void mergeEntries(Entries& to, Entries&& from) {
  std::forward_as_tuple(std::move(from), to) match {
    case [{ std::monostate }, _] =>
      ;

    case [{ auto&& value }, { std::monostate }] =>
      to = std::move(value);

    case [{ auto&& [fromKey, fromValue] },
          { auto&& [toKey, toValue] }] => do {
      if (toKey != fromKey) {
        EntryMap map;
        map.reserve(2);
        map.emplace(toKey, std::move(toValue));
        map.emplace(fromKey, std::move(fromValue));
        to = std::move(map);
      }
    };

    case [{ auto&& [key, value] },
          { EntryMap& map }] =>
      map.try_emplace(key, std::move(value));

    case [{ EntryMap&& map },
          { auto&& [key, value] }] => do {
      map.insert_or_assign(key, std::move(value));
      to = std::move(map);
    };

    case [{ EntryMap&& fromMap },
          { EntryMap& toMap }] => do {
      for (auto&& [key, value] : fromMap)
        toMap.try_emplace(key, std::move(value));
    };
  };
}
```

A corresponding `const Entries&` overload could copy from the source. A future
adaptation could investigate consolidating the copy and move forms with
forwarding declaration patterns, but the comparison above is deliberately
one-to-one.

This example combines matching multiple subjects, closed-choice projection,
structural decomposition, value-category preservation, first-match ordering,
and exhaustiveness over the source/destination Cartesian product.

### Visitor replacement is not always mechanical

Pattern fallback follows pattern coverage, not overload selection. This
visitor does nothing for a nonzero `int`; the generic overload is never
selected:

```cpp
visit(overload{
  [](int value) {
    if (value == 0)
      zero();
  },
  [](auto const&) {
    other();
  }
}, variant_value);
```

A naive pattern rewrite changes that behavior because `{ _ }` also covers a
nonzero `int`:

```cpp
variant_value match {
  case { 0 } => zero();
  case { _ } => other();
};
```

A faithful rewrite needs an explicit arm for the remainder of the `int`
alternative:

```cpp
variant_value match {
  case { 0 }   => zero();
  case { int } => void();
  case { _ }   => other();
};
```

R6 should include this example. It is an important consequence of composable
first-match semantics and prevents the paper from presenting `std::visit`
replacement as a purely syntactic transformation.

## Proposed User Model

### Informal syntax

The syntax overview should be rewritten around the following forms:

```cpp
// Multi-arm selection.
subject match constexpr(opt) trailing-return-type(opt) {
  attribute-specifier-seq(opt) case pattern guard(opt) => handler;
  attribute-specifier-seq(opt) default => handler;
  // ...
}

// General single-pattern Boolean expression.
subject match case pattern guard(opt)

// Direct selection/iteration condition. A trailing pattern guard is not
// permitted in these forms.
if (case pattern = subject) statement
while (case pattern = subject) statement
for (init; case pattern = subject; increment) statement

// Filtering range-for.
for (case pattern : range) statement
```

A handler is an expression, a null statement, a `static_assert` declaration,
or one of the supported jump statements (`break`, `continue`, `return`, and
`co_return`). A null statement is the concise spelling for an intentionally
empty void handler:

```cpp
value match {
  case 0 => ;
  case _ => consume(value);
};
```

Attributes before an arm introducer appertain to the arm. In particular,
`[[likely]]` and `[[unlikely]]` describe the likelihood that the arm is
selected, analogous to attributes on a `case` label in a `switch`. Attributes
within a declaration pattern remain declaration attributes:

```cpp
value match {
  [[likely]] case 0 => fast_path();
  case [[maybe_unused]] int copy => consume(copy);
  [[unlikely]] case _ => fallback();
};
```

Attribute-specific wording still determines whether any other statement
attribute can appertain to a match arm and what part of arm execution it
affects.

`default` is an alternate arm introducer with exactly the coverage and
first-match semantics of an unguarded top-level `case _`. It is not a pattern:
it cannot be nested, used by a single-pattern test, or given a guard. A guarded
catch-all remains `case _ if (condition)`. Keeping `default` unguarded makes it
a genuine fallback and avoids the switch-like implication that it is tested
out of source order. A later arm is rejected as redundant through the ordinary
usefulness rules, so no separate rule requires `default` to be last.

```cpp
value match {
  [[likely]] case 0 => fast_path();
  [[unlikely]] default => fallback();
};
```

R6 retains `match constexpr` with the R5 model: arm conditions are constant
expression conditions, and handlers after a selected arm are discarded in the
style of `if constexpr`. Discarded handlers do not participate in result type
deduction. A statically irrefutable pattern can select an arm without reading a
runtime subject, while a genuinely value-dependent pattern test or guard is
ill-formed unless it is a constant expression. Patterns in later source arms
still participate in usefulness and exhaustiveness analysis even though their
guards and handlers are discarded.

The currently supported pattern vocabulary is:

```cpp
_                       // wildcard
constant-expression     // expression/value pattern
declaration             // declaration pattern
type-id                 // type pattern
[P1, P2, ...]           // decomposition pattern; [] matches zero elements
{ P }                   // runtime projection or refinement
{ .name: P }            // named choice projection
{}                      // non-projectable advertised state
```

Declarations use the for-range-declaration restrictions: one declarator, no
initializer, and no storage-class forms that do not make sense for a pattern.
R6 also permits an empty structured-binding list, `auto [] = E`, as the
declaration analogue of a zero-arity decomposition pattern. The prototype
treats this as a C++29 facility and retains ordinary arity checking: it is
valid only when `E` decomposes into zero elements. Wording should update the
structured-binding grammar and choose the corresponding
`__cpp_structured_bindings` value.

R6 should also permit omitting the identifier of a structured-binding pack:

```cpp
auto [first, ..., last] = value;
auto [...] = value;

value match {
  case auto [first, ..., last] => use(first, last);
};
```

The unnamed pack still performs the ordinary binding initialization for every
element it consumes; it merely introduces no identifier. Unlike a named
structured-binding pack, it is therefore useful outside a template. This is
not wildcard decomposition and does not permit implementations to skip
observable `get<I>` calls.

### The current subject

Every nested pattern has a current subject:

- `P` applies directly to that subject.
- `[P1, P2]` decomposes it and gives each child a component subject.
- `{ P }` asks its alternative model for a projected subject and applies `P`
  to that projection.
- `{ .name: P }` first selects the named state.
- `_` ignores the current subject without projection.

This terminology should be used consistently in design and wording. It avoids
describing declarations as if they sometimes bind a whole object and
sometimes magically enter a variant.

## Declaration and Type Patterns

### Declaration grammar and initialization

A declaration pattern is a real declaration initialized from the current
subject:

```cpp
subject match {
  case Widget value       => consume(value);
  case const Widget& ref  => inspect(ref);
  case auto&& forwarded   => forward(FWD(forwarded));
};
```

The design should state:

- by-value declarations perform ordinary initialization;
- references follow ordinary reference binding and value-category rules;
- `auto&&` forwards according to the current subject;
- constrained placeholders are supported;
- cv-qualification and `decltype` have their ordinary declaration meaning;
- first matching arm wins; arms never form an overload set.

Viability is restricted to standard conversion sequences of exact-match rank:

- identity;
- lvalue transformations, including lvalue-to-rvalue, array-to-pointer, and
  function-to-pointer conversion;
- qualification adjustment;
- function-pointer conversion.

Promotions, conversion-rank standard conversions, and user-defined
conversions are not declaration-pattern matches.

The wording needs to use the actual overload-resolution and reference-binding
rules rather than an informal `remove_cvref_t` equality test. Examples should
cover pointers, cv-qualification, arrays, functions, bit-fields, forwarding
references, and constrained placeholders.

### Type patterns

A type pattern has declaration-pattern viability semantics with the identifier
omitted:

```cpp
subject match {
  case int      => integer_case();
  case double d => floating_case(d);
  case _        => fallback();
};
```

`void` and cv-`void` need explicit wording. They are important for dependent
void-valued expressions and `expected<void, E>`.

Type patterns compose:

```cpp
pair match {
  case [int, const string& text] => use(text);
};
```

The corresponding declaration initialization is checked completely but is not
performed. Thus `case Widget` requires the hypothetical initialization of a
`Widget` declaration from the current subject to be well-formed and to satisfy
the declaration-pattern exact-match rule. Deleted or inaccessible
constructors, invalid reference binding, inaccessible destruction, and other
declaration constraints still make the pattern invalid. No object is created,
no copy or move occurs, and no initialization or destruction side effects are
observable. Runtime refinement, when needed, is still evaluated to determine
whether the type pattern matches.

The prototype performs this complete hypothetical declaration check. In
particular, a non-copyable lvalue is rejected by `case Widget` even though no
runtime `Widget` object would be created by the type pattern.

### Omitted identifiers and bare type-constraints

Type patterns suggest generalizing declaration patterns to permit an omitted
identifier, including for constrained placeholder declarations:

```cpp
case std::integral auto
case std::ranges::viewable_range auto&&
```

These spellings have existing placeholder-deduction semantics. In particular,
the placeholder and its cv/ref form determine the type to which the constraint
is applied. `std::integral auto` tests the by-value deduced type. By contrast,
`std::ranges::viewable_range auto&&` preserves forwarding-reference deduction,
which is significant because `viewable_range` intentionally distinguishes
lvalue ranges, movable rvalue ranges, and views.

This makes a bare type-constraint such as `case std::integral` semantically
ambiguous. Treating it as an implicit `std::integral auto` favors concepts over
value types; treating it as an implicit `std::integral auto&&` favors concepts
designed for forwarding types. Applying it directly to `decltype((subject))`
would be a third rule and would make ordinary lvalue integers fail
`std::integral`. A concept declaration carries no metadata that identifies the
intended normalization.

The conservative R6 direction is therefore to support omitted identifiers in
constrained placeholder declaration patterns while reserving bare
type-constraints. If bare constraints are added, the paper must specify their
type transformation explicitly rather than presenting them as an obvious
consequence of the type-pattern grammar.

### Applicability is not initialization failure

Dependent arm specialization must not use the complete declaration
initialization as one undifferentiated SFINAE test. A declaration pattern has
at least three conceptually distinct outcomes for a projected subject:

1. **Not applicable.** The declared type cannot bind to the subject under the
   declaration-pattern exact-match rules, a required decomposition is absent,
   or another structural prerequisite is not satisfied.
2. **Applicable and well-formed.** The selector applies and ordinary
   declaration initialization succeeds.
3. **Applicable but ill-formed.** The selector applies, but the selected
   declaration cannot be initialized, for example because the required copy
   constructor is deleted or inaccessible.

Only the first outcome may make an arm absent in a model that supports
dependent arm omission. The third outcome is a hard error. This follows the
useful overload-resolution precedent: once overload resolution selects a
by-value overload, failure to perform the selected parameter initialization
does not cause overload resolution to retry an ellipsis or generic fallback.

For example:

```cpp
struct Job {
  Job(Job&&) = default;
  Job(const Job&) = delete;
};

template<class T>
void process(T&& value) {
  std::forward<T>(value) match {
    case Job job => execute(std::move(job));
    default      => report_unsupported();
  };
}

Job job;
process(Job{}); // selects the Job arm and moves
process(job);   // error: the selected Job initialization requires a copy
```

Silently omitting the `Job` arm for the lvalue specialization and selecting
`default` would turn an ownership error into different runtime behavior. The
same issue is more dangerous when a fallback means success:

```cpp
struct Failure {
  std::unique_ptr<Diagnostic> details;
};

template<class Result>
void finish_transaction(const Result& result) {
  result match {
    case { Failure failure } => rollback(failure);
    default                  => commit();
  };
}
```

For an error-state `expected<Receipt, Failure>`, the `Failure` state is an
applicable projection. Its by-value declaration then fails to copy and must be
diagnosed; it must not disappear and allow `commit()` to run.

Reference binding participates in applicability in the same way that it
participates in overload candidate viability. Thus `int&` is not applicable
to a `const int` subject; that is different from an exact by-value `Job`
selector whose subsequently required copy is deleted. Type patterns use the
same split, except that a successful initialization is checked hypothetically
and is not executed.

Many apparently surprising omissions therefore have direct overload-resolution
analogues. For example:

```cpp
void process(auto&& value) {
  std::forward<decltype(value)>(value) match {
    case Widget& widget => mutate(widget);
    default             => ignore();
  };
}
```

The `Widget&` arm accepts a non-const lvalue but is not applicable to a
`const Widget&` or a `Widget` xvalue. This is the same behavior as an overload
set containing `handle(Widget&)` and a generic `handle(auto&&)` fallback.

Alternative projection has the same precedent:

```cpp
void process(auto&& choice) {
  std::forward<decltype(choice)>(choice) match {
    case { std::string& text } => mutate(text);
    case { auto&& value }      => report_unhandled(value);
  };
}
```

A non-const lvalue `variant<string>` selects the first arm. A const lvalue or
an rvalue selects the generic arm, just as it would under
`visit(overloaded{[](string&), [](auto&&)})`. These cases are consequences of
an explicitly written generic fallback and are not strong objections to
implicit dependent applicability.

Structural applicability is less familiar and remains the sharper design
question:

```cpp
int process(auto value) {
  return value match {
    case auto&& [x, y, z] => combine(x, y, z);
    default               => fallback();
  };
}
```

A two-element subject silently selects `fallback()`. This can be intentional
generic shape dispatch, but it can also hide an arity typo or an API change
from a three-element to a two-element decomposition. A constrained-overload
analogy can be constructed, but it is less immediate from the source syntax
than the type and cv-reference examples. The choice between implicit omission
and an explicit `match requires` mode should be evaluated primarily against
these structural cases.

This distinction is independent of whether R6 keeps implicit dependent arm
omission or adopts explicit `match requires`. An opt-in detection form may
omit a genuinely inapplicable arm, but should not silently convert a failure
of an already applicable declaration initialization into fallback behavior.

### Static exact match and polymorphic refinement

An ordinary declaration/type pattern performs only static exact matching.
Braces explicitly request runtime refinement when the current subject is a
polymorphic class glvalue:

```cpp
Shape& shape = get_shape();

shape match {
  case { Circle& circle } => draw(circle);
  case { Square& square } => draw(square);
  case _                  => unknown(shape);
};
```

This is built-in language behavior, not an ADL `try_cast` protocol. A pointer
subject uses its nullable projection first, after which the pointee can be
refined with the same braced declaration:

```cpp
shape_pointer match {
  case { Circle& circle } => draw(circle);
  case {}                 => no_shape();
  case _                  => unknown(*shape_pointer);
};
```

Polymorphic refinement should use the success relation and adjusted-object
result of the corresponding built-in `dynamic_cast`. This includes public
downcasts, virtual inheritance, pointer adjustment, and valid cross-casts. A
failed refinement is a non-match rather than an exception; this can be
specified in terms of the pointer form of `dynamic_cast`, followed by binding
the declaration to the adjusted object while preserving the required cv/ref
and value-category semantics.

One precedence question remains for a class that is both polymorphic and an
`alternative_traits` model. The prototype currently gives a directly viable
polymorphic refinement such as `{ Derived& }` priority over generic choice
projection, while named forms necessarily select `alternative_traits`. R6
should either specify that priority or require a less overlapping spelling.

Pointer syntax also exposes the layering. A direct `Shape*` is first treated
as nullable, so `{ Circle& c }` means non-null, dereference, then refine. If a
closed choice first projects a `Shape*` payload, `{ Circle* c }` can instead
refine that projected pointer. Both are compositional, but examples should make
the distinction explicit.

This is deliberately an open-world relation, not an exact dynamic-type or
vptr-equality test:

```cpp
struct Shape { virtual ~Shape() = default; };
struct Rectangle : Shape {};

// This type can be defined in another translation unit or DSO.
struct Square : Rectangle {};

void draw_shape(Shape& shape) {
  shape match {
    case { Rectangle& rectangle } => draw(rectangle);
    case _                        => unknown(shape);
  };
}
```

Passing a `Square` to `draw_shape` must select the `Rectangle&` arm even if
`Square` was unknown when `draw_shape` was compiled. Consequently, enumerating
the derived types visible at one compilation point cannot prove an open
polymorphic match exhaustive. A base fallback or `_` remains necessary unless
a separate future facility establishes a closed world.

The prototype currently recognizes only a target class derived from the
static source class. It rejects a valid `dynamic_cast` cross-cast, such as
`A&` to `B&` when the dynamic object derives from both. That is an
implementation gap under this direction, not a desired restriction.

The paper must explain the static/runtime boundary directly. `typeid` is a
useful precedent for behavior that depends on whether the static type is
polymorphic, but it is not the matching mechanism.

The explicit braces prevent the same source pattern from changing between a
static exact match and runtime refinement in different specializations:

```cpp
void inspect(auto& value) {
  value match {
    case { Circle& circle } => use(circle);
    case _                  => fallback(value);
  };
}

Circle circle;
inspect(circle);                       // refinement succeeds trivially
inspect(static_cast<Shape&>(circle));  // runtime downcast succeeds
```

Omitting the braces requests only static declaration matching. A programmer
who wants static type dispatch without a value subject will need the future
type-subject facility.

### Optimizing polymorphic refinement

The semantic rule does not require emitting one source-ordered `dynamic_cast`
call per arm. A match exposes the complete ordered set of target types, which
permits several increasingly ambitious implementation strategies while
preserving `dynamic_cast` behavior:

1. **Frontend decision DAG and local commoning.** Perform a repeated target
   refinement once, retain its adjusted pointer, and reuse it across guards or
   later arms. A successful refinement to a more-derived target can satisfy a
   later base target by a static adjustment. Known target relationships can
   also prune impossible tests.
2. **Exact/final fast paths.** An effectively final target can be recognized
   with a direct vptr comparison. Several final leaf targets can share one
   vptr load and dispatch through comparisons or a switch, with a general
   fallback where needed.
3. **LTO closed-world dispatch.** If visibility and whole-program analysis
   prove the relevant hierarchy closed, build a table or switch from dynamic
   type and source-subobject identity to the earliest matching arm and pointer
   adjustment. This is an optimization conclusion, never a source-language
   assumption.
4. **Hybrid open-world dispatch.** Fast-path known or profiled dynamic types
   and fall back to general RTTI matching for an unknown type. This preserves
   the requirement that an externally defined `Square` still match
   `Rectangle&`.
5. **Multi-target RTTI support.** A future ABI helper could receive all target
   types, traverse an unknown object's RTTI graph once, and return the
   successful target set and adjusted pointers. The Itanium
   `__dynamic_cast` interface accepts one target, so this requires runtime/ABI
   work rather than merely different frontend syntax.
6. **PGO inline caches.** Cache common vptr-to-arm-and-adjustment results and
   use the ordinary open-world path on a miss.
7. **Higher-level IR.** Preserve a dynamic-match operation through CodeGen, or
   introduce an appropriate LLVM intrinsic, so LTO can choose among these
   strategies instead of rediscovering a sequence of unrelated cast calls.

For example:

```cpp
shape match {
  case { Square& square } if small(square) => draw_small(square);
  case { Square& square }                  => draw(square);
  case { Rectangle& rectangle }            => draw(rectangle);
  case _                                   => unknown(shape);
};
```

The two `Square&` arms need only one runtime refinement. If its guard fails,
the adjusted `Square*` can be retained; it also provides the `Rectangle`
subobject for the next arm. Guards and handlers still run in source order.

## Choice Projection

### Why braces are required

Without a projection marker, this is irreducibly ambiguous:

```cpp
variant<int, string> value;

value match {
  case auto&& x => use(x);
};
```

`x` could mean the `variant` object or its active payload. R6 assigns only one
meaning to the naked declaration: it binds the current subject, the `variant`.
Braces opt into payload projection:

```cpp
case auto&& whole => use(whole);
case { auto&& payload } => use(payload);
```

The same distinction prevents a decomposition pattern from silently entering
a choice:

```cpp
variant<int, tuple<int, int>, pair<int, int>, array<int, 2>> value;

value match {
  case { int i }         => scalar(i);
  case { auto&& [x, y] } => coordinates(x, y);
};
```

The braces are not merely decoration for a declaration. They are a composable
projection operator in the pattern language.

### Closed choices

For a closed choice, `{ P }` considers each projectable advertised state for
which `P` is viable. Runtime matching tests the retained or computed state
index and applies the corresponding semantic instantiation of `P`.

Examples:

```cpp
variant<int, double> value;

value match {
  case { const int& i } => use(i);
  case { double d }     => use(d);
};
```

Repeated and qualification-related alternatives are permitted. A pattern may
cover more than one index. Exhaustiveness and usefulness operate on indices
and nested value coverage, not only on type names.

`{ auto&& value }` is especially important: it denotes a generic arm whose
guard and handler are semantically checked for each viable projected type.

### Named and non-projectable states

Named projection selects one advertised state before applying its child:

```cpp
expected<int, Error> result;

result match {
  case { .value: int value }   => use(value);
  case { .error: Error& error } => report(error);
};
```

`{}` matches advertised states with no projection:

```cpp
optional<int> value;

value match {
  case { int i } => use(i);
  case {}        => empty();
};
```

`nullopt` and `nullptr` remain ordinary expression patterns. They do not cover
an empty alternative state for usefulness or exhaustiveness; use `{}` or the
appropriate named state such as `{ .none }` when state coverage matters.

The `.name:` spelling is intentionally confined to braces. A bare
`{ name: P }` would make ordinary identifier lookup unexpectedly consult a
trait first. `.name:` also leaves `[.x: P, .y: Q]` available for future named
aggregate decomposition without conflating aggregate member names with choice
state names.

### Standard models

R6 should present these models together:

| Subject | Model | Required states | Residual state |
|---|---|---|---|
| `T*` | built-in closed choice | null, non-null | none |
| `optional<T>` | closed choice | empty, value | none |
| `expected<T, E>` | closed named choice | value, error | none |
| `variant<Ts...>` | closed indexed choice | every declared index | valueless-by-exception |
| `any` | open type-indexed choice | empty if nullable, plus the unknown non-empty remainder | none |

`expected` is deliberately modeled as value/error, not as a pointer-like
value/empty abstraction. Thus both `T` and `E` are projectable, including a
`void` value projection for `expected<void, E>`.

Raw `void*` does not participate in the built-in pointer projection protocol.
There is no value projection that can be formed by dereference, and treating
both null and non-null states as non-projectable would make positional `{}`
match both. A reusable `alternative_traits<void*>` provider may still be named
indirectly by another type, but it does not opt raw `void*` into matching.

The valueless variant state is deliberately not given ordinary projection
syntax. Code that cares about this rare state can match the whole object with
a guard before projected arms:

```cpp
value match {
  case auto&& whole if (whole.valueless_by_exception()) => recover();
  case { auto&& alternative }                           => use(alternative);
};
```

### Open choices and `any`

An open erased choice cannot enumerate its projected types. It still requires
the braces that signal runtime projection:

```cpp
any value;

value match {
  case { int i }                => use(i);
  case { const string& text }   => use(text);
  case { _ }                    => unknown_nonempty();
  case {}                       => empty();
};
```

A naked `case int i` must not silently inspect `any`. The open protocol uses
`try_cast<T>` for typed projection and optionally `has_value` for an empty
state. `{ auto&& value }` is ill-formed because an erased open choice cannot
expose an unknown runtime type as one statically typed binding.

The R6 slides currently contain an older `type()`/`get<T>()` version of this
protocol. They must be updated to the current `try_cast<T>`/`has_value` model.

Matching an empty `any` as `void` was explored because `any::type()` returns
`typeid(void)` when empty. It was rejected: emptiness is not a projected
`void` value, and `{}` already expresses a non-projectable state consistently.

## `alternative_traits`

### Closed indexed protocol

The current prototype protocol has this shape:

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
  static constexpr size_t size = /* number of advertised states */;

  // Optional; defaults to true.
  static constexpr bool is_exhaustive = true;

  static constexpr size_t index(choice const&);

  template<size_t I, class Self>
    requires /* state I is projectable */
  static constexpr decltype(auto) get(Self&&);

  // Optional source names for { .name: P }.
  struct names {
    using AT = alternative_traits;
    static constexpr alternative_name<AT> value = 0, error = 1;
  };
};
```

The paper needs to specify these laws:

- `size` advertises `[0, size)`.
- State `I` is projectable for a particular subject when
  `Provider::get<I>(subject)` is well-formed. A valid `void` result is a void
  projection; absence of a viable `get<I>` makes the state non-projectable.
- `index(subject)` identifies the active state. Its result need not be
  `size_t`: a two-state provider can return `bool`, while larger providers
  normally return an unsigned index type.
- `index(subject)` is non-throwing. This permits the discriminator to be
  retained or evaluated eagerly within the projection-ordering rules.
- For an active projectable state, `get<I>(subject)` preserves the subject's
  cv/ref category as appropriate for that provider.
- `is_exhaustive == false` permits runtime states outside the advertised
  range. Those states are residual rather than required.
- A member of `names` is an `alternative_name<Provider>` whose stored `index`
  maps to an advertised state.

The names `alternative_traits`, `is_exhaustive`, and `alternative_name` remain
provisional. The paper should compare them with naming in existing standard
traits before wording is frozen.

### Named alternative providers

The R6 direction permits a type to expose more than one coherent named view.
A name is a typed descriptor rather than an integer found by an ad hoc
same-scope lookup:

```cpp
template<class Provider>
struct alternative_name {
  using provider = Provider;
  size_t index;
};
```

For `{ .name: P }`, the descriptor's `Provider` supplies `index`,
and `get<State>`. Named providers may be mixed operationally: each provider's
discriminator is evaluated and cached independently while subject storage is
shared. Usefulness and exhaustiveness are conservative across providers. A
single provider can prove complete coverage, and once preceding arms fully
cover any provider, every later arm is redundant. Partial overlap between
distinct providers is not inferred, so a partially overlapping arm is treated
as maybe useful. A whole-subject wildcard remains provider-neutral.

This permits `expected<T, E>` to offer either `value/error` or `some/none`
without requiring a canonical mapping between the two partitions:

```cpp
e match {
  case { .value: int value } => use(value);
  case { .error: E error }   => fail(error);
};

e match {
  case { .some: int value } => use(value);
  case { .none }            => absent();
};
```

Mixing `.value` with `.none`, or a named view with positional `{ P }`, is
well-formed. A complete provider view proves exhaustiveness, but partial arms
from different providers are not combined even when the programmer knows
that their physical runtime states cover the subject. This deliberately
avoids requiring a cross-provider coverage mapping in the first protocol.

### Open type-indexed protocol

A specialization without `size` describes an open choice:

```cpp
template<>
struct alternative_traits<any> {
  template<class T, class Self>
  static T* try_cast(Self&& self) noexcept;

  static bool has_value(any const& self) noexcept; // optional
};
```

The required rules are:

- `{ T value }` requests `try_cast<remove_cvref_t<T>>(subject)`.
- `try_cast` returns a pointer; null means no match.
- The successful pointee is forwarded like the subject before applying `P`.
- Declaration initialization after a successful cast is checked normally; an
  invalid reference or cv binding is an error, not a runtime no-match.
- `has_value` enables `{}` for empty and `{ _ }` for non-empty.
- Without `has_value`, `{}` is ill-formed and `{ _ }` covers the entire open
  non-empty remainder.

The protocol contract must address pointer lifetime, stability after mutation,
accessibility, exceptions, malformed specializations, and lookup.

### Standard specialization sketches

The paper should include concrete sketches, not only the abstract protocol.
The intended optional mapping is empty index 0 and value index 1:

```cpp
template<class T>
struct alternative_traits<T*> {
  using AT = alternative_traits;

  static constexpr size_t size = 2;
  static constexpr bool is_exhaustive = true;

  // Templated because this provider is reused with other nullable subjects.
  static constexpr bool index(auto const& self) noexcept {
    return self ? true : false;
  }

  template<bool HasValue, class Self>
    requires (HasValue && !is_void_v<T>)
  static constexpr decltype(auto) get(Self&& self) noexcept {
    return *FWD(self);
  }

  struct names {
    static constexpr alternative_name<AT> none = 0, some = 1;
  };
};

template<class T>
struct alternative_traits<optional<T>> : alternative_traits<T*> {};
```

Using `bool` carries the binary discriminator through the provider and allows
optimized matching on nullable types to retain the same condition shape as a
direct contextual conversion to `bool`. The generic protocol still numbers
states, and passing state `0` or `1` as the `get` template argument converts
to the provider's boolean NTTP.

The pointee constraint is intentional. The inherited nullable view of
`expected<void, E>` permits `.some` only as a state selector, not
`.some: void`. The primary expected provider still projects its value state as
`void`.

Expected advertises two projectable, named states. `T = void` remains a valid
projection type for the value state:

```cpp
template<class T, class E>
struct alternative_traits<expected<T, E>> {
  using AT = alternative_traits;

  static constexpr size_t size = 2;
  static constexpr bool is_exhaustive = true;

  struct names : alternative_traits<T*>::names {
    static constexpr alternative_name<AT> value = 0, error = 1;
  };

  static constexpr size_t index(expected<T, E> const& value) noexcept {
    return value.has_value() ? 0 : 1;
  }

  template<size_t I, class Self>
    requires (I < size)
  static constexpr decltype(auto) get(Self&& self) {
    if constexpr (I == 0)
      return *FWD(self);
    else
      return FWD(self).error();
  }
};
```

Variant is positional and has a residual valueless state:

```cpp
template<class... Types>
struct alternative_traits<variant<Types...>> {
  static constexpr size_t size = sizeof...(Types);
  static constexpr bool is_exhaustive = false;

  static constexpr size_t index(variant<Types...> const& value) noexcept {
    return value.index();
  }

  template<size_t I, class Self>
  static constexpr decltype(auto) get(Self&& self) noexcept {
    return __unchecked_get<I>(FWD(self)); // exposition only
  }
};
```

The closed-protocol contract for `get<I>` is:

- Mandates: `I < size`.
- Preconditions: `index(self) == I`.
- Returns: the projection for state `I`, preserving the cv-qualification and
  value category of `self` where the projected object permits it.

Pattern matching caches `index(self)` and calls `get<I>` only after selecting
state `I`. A standard-library specialization can therefore use its private
unchecked access mechanism; the public protocol does not expose or specify
that mechanism. Calling `get<I>` directly when its precondition is false has
undefined behavior.

Any uses the open protocol:

```cpp
template<>
struct alternative_traits<any> {
  template<class T, class Self>
  static auto try_cast(Self&& self) noexcept {
    return any_cast<T>(addressof(self));
  }

  static bool has_value(any const& value) noexcept {
    return value.has_value();
  }
};
```

Raw pointers use built-in language semantics and ignore
`alternative_traits<T*>`. That specialization mirrors the same state numbering
and operations as a reusable provider. `optional<T>` and the non-array forms of
`unique_ptr<T, D>` and `shared_ptr<T>` opt in explicitly by inheriting from it.
The array smart-pointer forms do not opt in because they have no unary `*`
projection. User-defined class types also opt in explicitly; merely providing
Boolean conversion and dereference does not adopt the protocol. This avoids
making the two-state
exhaustive semantic promise from syntax alone.

If a closed model advertises several non-projectable states, `{}` covers all
of them.

### Protocol alternatives explored

The following were explored and should be summarized rather than left as live
design branches:

- A reflection-valued `projection_type(size_t)` function was attractive but
  would make this proposal depend on reflection and was not implemented.
- Scoped-enum indices could make named states self-describing, but positional
  pack indexing remains natural for `variant`.
- Freely mixing multiple named views of one type, such as `value/error` with
  `some/none` for `expected`, requires cross-view coverage mappings for precise
  redundancy and exhaustiveness. The initial protocol permits mixing but
  analyzes each provider independently.
- Making every pointer-like type automatically participate would create
  accidental protocol adoption. Raw pointers and selected standard-library
  types receive explicit specializations; user-defined types opt in explicitly.
- A `type()`/`get<T>()` open protocol was explored for `any`. The prototype
  returned to pointer-form `try_cast<T>` because it combines the runtime test
  and safe access and matches `any_cast<T>(&value)`.

## Single-Pattern Conditions

### General expression form

The general form remains:

```cpp
subject match case P
```

It is an ordinary Boolean expression and never injects bindings into an
enclosing scope. `P` must be viable for the type of `subject`, including after
dependent substitution. Given a viable `P`, the expression is value-equivalent
to:

```cpp
subject match {
  case P       => true;
  default      => false;
}
```

The equivalence is not specified as an AST rewrite and does not extend to
well-formedness. A non-viable `P` makes the single-pattern expression
ill-formed even though the corresponding arm of a dependent multi-case match
can be omitted. Static shape detection therefore uses an explicit requirement:

```cpp
if constexpr (requires { value match case [_, _]; }) {
  // value has a viable two-element decomposition
}
```

Names introduced by `P` remain usable in the pattern's own guard, but do not
escape the expression.

### Patterns as partial relations

A useful specification model is that a pattern denotes a partial relation from
a subject to an environment of bindings. For a particular subject type, a
pattern can be:

- non-viable, so the relation is empty;
- viable and refutable, so only some subject values produce an environment; or
- viable and irrefutable, so every subject value produces an environment.

The selected model keeps viability and runtime matching separate. If
`V(E, P)` means that `P` is viable for `E`, and `M(E, P)` is the runtime match
relation defined when `V` holds, then:

- `requires { E match case P; }` reports `V`; and
- `E match case P` requires `V` and reports `M`.

Thus `true` means viable and matched, while `false` means viable and unmatched.
A non-viable pattern does not produce a Boolean value.

Irrefutability remains conditional on viability. If `P` is irrefutable
whenever viable, `E match case P` is always `true` when well-formed; the
corresponding static applicability test is still the requirement:

```cpp
template<class T>
int arity(T&& value) {
  if constexpr (requires { value match case [_, _]; })
    return 2;
  else
    return 0;
}
```

The distinction is operational as well as logical. `E match case P` evaluates
`E` and can evaluate projections or declaration-pattern initializations even
when a viable `P` is irrefutable. A `requires`-expression is unevaluated.
Consequently, the match expression is not a general replacement for a static
viability query merely because its Boolean result would be predetermined.

Patterns whose success depends on runtime state, such as `0`, a guarded
pattern, a nullable value projection, or a polymorphic refinement from a base
object, remain refutable after viability has been established. The paper should
distinguish conditional irrefutability from exhaustiveness over a runtime state
space.

Viability can be exposed directly as a constraint with a requires-expression:

```cpp
void use_two_ints(auto&& value)
  requires requires { value match case [int, int]; }
{
  auto&& [first, second] = value;
  use(first, second);
}
```

The constraint is satisfied exactly when the two-element decomposition and
both component patterns are viable. It does not evaluate `value` or test a
runtime component value.

The constraint proves decomposition and component-pattern viability, not every
operation in the body. In particular, `auto [first, second] = value` can also
require copying the enclosing tuple-like object. `auto&& [first, second] =
value` more directly consumes the property established above.

### Alternative considered: non-viability produces `false`

The prototype initially made a substitution-dependent non-viable pattern
produce `false`. That model totalizes the partial match relation as
`V(E, P) && M(E, P)`: `true` means viable and matched, while `false` can mean
either non-viable or viable and unmatched. It follows naturally from treating
the expression as a one-arm match with an implicit `default => false` and is
convenient for generic structural dispatch.

For a pattern that is irrefutable whenever viable, this collapses to `V(E, P)`
and appears to provide a direct applicability predicate. That benefit is
limited by evaluation semantics: the expression still evaluates `E` and can
perform projections, copies, moves, or other declaration initialization. It is
therefore only Boolean-equivalent to a viability query; it is not operationally
equivalent to the unevaluated `requires { E match case P; }`.

The model also prevents a requires-expression from distinguishing non-viability
from ordinary match failure, and differs from ordinary C++ expressions such as
`x == y`, where failed operation formation is not silently converted to
`false`. R6 instead keeps the single-pattern expression strict and uses
`requires` to ask the separate formation question.

### Pattern-first condition form

R6 should retain and explain the additional direct-condition spelling:

```cpp
if (case P = subject) statement
while (case P = subject) statement
for (init; case P = subject; increment) statement
```

Direct conditions can combine ordinary Boolean elements and additional pattern
conditions using the built-in `&&` operator:

```cpp
if (ready && case [int x, int y] = first &&
    x < y && case { std::string s } = second && !s.empty()) {
  use(x, y, s);
}
```

Evaluation is left-to-right with ordinary short-circuiting. A pattern binding
is in scope in every later condition element and in the successful controlled
statement, but not in `else`. The entire chain is one full-expression; a
binding constructed by an earlier element remains alive through later elements
and the selected statement, and is destroyed on any failed path before entering
`else`. The hidden subject holder has statement scope so a temporary subject
remains alive through either controlled substatement. For C-style `for`,
bindings are also visible in the increment expression.

Each ordinary element and each pattern subject is an
`inclusive-or-expression`. Consequently, top-level `&&` separates condition
elements, while `||`, assignment, and conditional expressions require
parentheses when used inside an element. The conjunction is always the
built-in Boolean `&&`; overloaded `operator&&` is not considered.

This form is intentionally direct-only. It is not accepted in `switch`, as a
general expression, or with an extra parenthesis layer such as
`if ((case P = subject))`.

These forms are strict: every `P` must be viable and well-formed for its subject,
including after dependent substitution. An incompatible pattern is an error;
it is not silently treated as `false`. Once formed, a refutable pattern is a
runtime condition and an irrefutable pattern is always true. Bindings are
available in the remainder of the successful condition chain and controlled
statement. A trailing pattern guard is not permitted; an ordinary later
condition element serves that role.

`constexpr` does not change these formation rules. In
`if constexpr (case P = E)`, `P` must still be viable; the match result must
additionally be a constant expression and ordinary
discarded-statement rules apply. In particular, `constexpr` does not turn this
declaration-looking condition into a detection operation.

Consequently, this form is not equivalent to a two-arm `match constexpr`.
Given a dependent subject, a non-viable `P` makes
`if constexpr (case P = E)` ill-formed. In
`E match constexpr { case P => E1; default => E2; }`, the same non-viable
semantic arm does not participate and the default arm can be selected.
`constexpr` controls static selection and handler instantiation; it does not
erase the distinction between a required pattern condition and an optional
match arm.

An alternative considered was to make `case P = E` the binding-producing form
of exactly the same partial relation as `E match case P`. Under that model it
would produce `true` only when the pattern is viable and the runtime value
matches, and `false` for either non-viability in a dependent substitution or an
ordinary failed value match. This would permit:

```cpp
template<class T>
void use_pair(T&& value) {
  if constexpr (case auto&& [first, second] = value) {
    use(first, second);
  }
}
```

Because the decomposition pattern is conditionally irrefutable, the condition
is a static applicability test: a viable decomposition retains the branch and
introduces the bindings, while a non-viable dependent specialization discards
the branch. For a refutable pattern, normal constant-expression requirements
still apply to its value test.

This unified model is powerful but declaration-looking syntax would then hide
a `requires`-like detection operation. It also conflicts with ordinary `if`
substatement semantics: a non-viable pattern would have to suppress the
successful substatement because its bindings do not exist, while an
irrefutable viable pattern raises the separate question of whether `else` is
still instantiated. Multi-case `match` already has semantic case-instantiation
regions that answer those questions, but an ordinary `if` does not. R6 instead
keeps the direct condition strict. The ordinary non-binding expression is also
strict; an explicit requires-expression performs applicability detection.

The first top-level `=` terminates the pattern. An assignment expression used
as the pattern must be parenthesized:

```cpp
if (case (existing = 4) = source = 4) {
  // pattern is (existing = 4), subject is (source = 4)
}
```

The point of declaration follows the `=` spelling rather than the older
expression-first form. A same-named use in the subject therefore denotes the
new pattern binding and is ill-formed:

```cpp
int x = 42;
if (case int x = x) { }   // error: pattern binding in its own subject
if (case int x = ::x) { } // OK: explicitly names the outer object
```

This deliberately differs from `subject match case int x`, where the subject
is parsed before the pattern, and from range-for lookup described below.

Simple declaration patterns are irrefutable whenever well-formed. Examples
should therefore motivate this syntax with refutable patterns:

```cpp
if (case 0 = value) { ... }
if (case [int x, 0] = pair) { ... }
if (case { int i } = variant_value) { ... }
if (case { Circle& circle } = shape) { ... }
```

Swift accepts irrefutable `if case` patterns but diagnoses that the condition
is always true. C++ should consider a corresponding diagnostic.

### Range filtering

A pattern in the for-range-declaration filters the input range:

```cpp
for (case { int value } : variants)
  use(value);
```

Elements that do not match are skipped. As in an ordinary range-for, the range
initializer is outside the scope of the element binding, so same-name lookup
finds an outer declaration:

```cpp
Range values;
for (case int values : values) {
  // the right-hand values denotes the outer range
}
```

The implementation showed that this syntax is not free sugar: declaration,
type, and expression patterns share prefixes; tentative type parsing must not
leave token annotations behind; pattern names need temporary lookup removal;
and source ranges need to preserve the reversed syntax. We are keeping it for
R6, but the guard spelling and final grammar need a dedicated review.

## Scope and Point of Declaration

Bindings introduced by a source pattern are immediately visible for name
lookup, preserving the R5 rule. A reference from within the same pattern to a
binding introduced by that pattern is ill-formed. This prevents an outer name
from silently changing meaning based on whether a sibling binding has already
appeared.

For a multi-arm match, bindings are available in the guard and handler for
that arm. `E match case P` never exports its bindings. In a direct
`case P = E` condition, bindings are available only in the successful
substatement. For `while` and C-style `for` direct conditions, they are
available in the controlled statement, and for `for` in the increment
expression. A range pattern binding is available in the loop body but not its
range initializer.

Guard init-statement declarations are available in the guard condition and
successful handler, but not later arms or `else`.

## Grammar and Disambiguation

Declaration, type, and expression patterns intentionally occupy the same
syntactic position. R6 needs explicit rules rather than relying on examples of
the prototype parser:

- A complete type pattern takes precedence over an expression interpretation,
  following the `sizeof`/`typeid` family of ambiguities.
- Parentheses force an expression interpretation where applicable. There is no
  separate parenthesized-pattern node.
- Declaration-versus-expression ambiguity otherwise follows block-scope C++
  rules, constrained to one for-range-style declarator.
- `[[` can begin declaration attributes or a nested decomposition pattern;
  tentative parsing must recognize a complete attributed declaration rather
  than relying on fixed token lookahead.
- Function and array declarators overlap expression syntax. Cases such as
  `T()`, `(T())`, function pointers, omitted type-pattern identifiers, and
  dependent qualified names need normative examples.
- In `case P = E`, the first top-level `=` is the separator and assignment
  expression patterns require parentheses.
- In a direct condition, top-level `&&` separates elements. Each ordinary
  element and each case subject is an `inclusive-or-expression`; richer
  expressions require parentheses.
- Parsing is incremental. An ordinary prefix is parsed with normal C++ operator
  semantics until a top-level `&& case` is encountered. The introducing `&&`
  and subsequent top-level `&&` operators in that case chain are built-in lazy
  conjunctions. In particular, a later case does not retroactively suppress an
  overloaded `&&` wholly within the ordinary prefix.
- Malformed patterns must recover at an arm boundary without producing
  misleading exhaustiveness diagnostics.

The implementation still needs syntactic tentative classification for two
genuine ambiguities created by the chosen grammar: leading declaration
attributes versus nested `[[P]]`, and a complete type-id versus a declaration
or expression. The type path currently performs a real `ParseTypeName` under
unannotated rollback to verify the pattern boundary; that should eventually be
replaced by a dedicated purely syntactic classifier. Declaration-versus-
expression classification reuses Clang's existing block-scope tentative parser.
These are implementation consequences, not proposed grammar rules.

## Templates and Dependence

### Single-pattern validity

A single-pattern test requires the pattern to be well-formed for its subject
type, including after dependent substitution:

```cpp
template<class T>
bool is_pair(T&& value) {
  if constexpr (requires { value match case [_, _]; })
    return value match case auto&& [first, second];
  else
    return false;
}
```

For a non-decomposable specialization, directly forming the match expression
would be ill-formed. Static branching uses a requirement:

```cpp
if constexpr (requires { value match case [_, _]; }) {
  // two-element decomposition is viable
}
```

For viable `P`, the value behavior of `E match case P` can be described by a
two-arm match. Its well-formedness deliberately differs from a dependent
multi-arm match, whose unavailable semantic arm can be omitted.

### Dependent multi-arm matching

A non-viable arm in a dependent multi-arm match can be discarded for one
specialization while remaining potentially useful for another:

```cpp
template<class V>
int classify(V value) {
  return value match {
    case { int }         => 0;
    case { string }      => 1;
    case { char }        => 2;
  };
}
```

For `variant<int, string>`, `{ char }` is not viable in that specialization,
but it is retained as maybe useful because another specialization may contain
`char`.

R6 needs precise immediate-context and substitution wording. Universally
redundant structure, such as duplicate dependent arms or an arm after an
unguarded wildcard, should still be diagnosable.

### Exhaustiveness is checked per specialization

Exhaustiveness of a dependent match is a property of each concrete template
specialization, not a requirement that the function template be valid for
every possible substitution:

```cpp
constexpr size_t arity(auto value) {
  return value match {
    case auto&& [...elements] => sizeof...(elements);
  };
}

static_assert(arity(tuple(1, 2)) == 2); // well-formed and exhaustive
// arity(0);                            // ill-formed: no case matches int
```

For a tuple specialization, the decomposition is viable and irrefutable, so a
wildcard arm is unnecessary. For `int`, that dependent candidate is absent
and exhaustiveness checking diagnoses the resulting uncovered integer domain.
The reported value, such as `0`, is an example witness; it does not imply that
only that value is missing.

Requiring a wildcard when the template is defined would effectively require
every unconstrained function template to be valid for every conceivable
substitution. That is not the C++ template model: an ordinary body such as
`return value.size();` is likewise valid for substitutions that provide
`size()` and ill-formed when instantiated otherwise. A wildcard is required
only when the author intends the match, and therefore the function template,
to support those otherwise incompatible specializations.

Diagnostic quality can still improve by noting that a dependent candidate was
discarded for the concrete subject type before presenting the exhaustiveness
witness.

### Implicit template regions

A generic projection can produce several differently typed semantic arms:

```cpp
variant<int, string> value;

value match {
  case { auto&& alternative } => use(alternative);
};
```

The source contains one arm, but its declaration, guard, and handler are
checked for each viable projected type. R6 needs a first-class semantic model
for this implicit template region:

- instantiation and diagnostic timing;
- return-type deduction;
- captures and local statics;
- `decltype`, constraints, and immediate contexts;
- identity when multiple alternatives have the same projected type;
- dependence and usefulness.

The prototype represents source patterns separately from
`MatchPatternInstantiation` objects. This is useful implementation evidence,
not yet sufficient specification.

Handler instantiation and result deduction should follow the `if constexpr`
model. A handler discarded as statically impossible or dominated for a
specialization is not instantiated and does not contribute to that
specialization's match result type. Consequently, one source match can have a
different result type in different specializations:

```cpp
constexpr auto result(auto value) {
  return value match {
    case int i        => i;          // int
    case string& text => text.size(); // size_t
    case _ => static_assert(false, "unsupported type");
  };
}
```

The fallback assertion is instantiated only for a subject type not handled by
an earlier irrefutable arm. This does not relax result consistency among arms
that remain runtime-reachable in one specialization. For example,
`case 0 => 1; case _ => 2.0;` still has conflicting `int` and `double` results
for an `int` subject. A null handler and a successful `static_assert` handler
contribute `void` to result deduction, just like `do {}`. A statically
discarded handler contributes nothing. A selected failing `static_assert`
makes that case instantiation ill-formed before it can produce a result.

Structured-binding packs use the same implicit-region model:

```cpp
constexpr int sum(tuple<int, int> value) {
  return value match {
    case auto [...elements] => (... + elements);
  };
}
```

An ordinary block-scope `auto [...elements] = value;` remains ill-formed
outside a template. A declaration pattern is different because the case has a
natural region to instantiate: the declaration is completed against the
current semantic subject, and uses of `elements` in the guard and handler are
expanded there.

This composes with generic choice projection. One source arm can instantiate
the pack with a different arity for each projected alternative:

```cpp
variant<tuple<int>, pair<int, int>> value;

value match {
  case { auto [...elements] } => use(elements...);
};
```

Arity-inferred subpattern packs extend that model to a pack in the pattern
list. A declaration pack binds every element it consumes:

```cpp
constexpr int sum(tuple<int, int, int, int> value) {
  return value match {
    case [auto&& first, auto&& ...middle, auto&& last] =>
      first + (... + middle) + last;
  };
}
```

A wildcard pack consumes the same elements without introducing bindings or
performing declaration initialization:

```cpp
value match {
  case [auto&& first, ..._, auto&& last] => use(first, last);
};
```

There may be at most one arity-inferred subpattern pack in a decomposition.
If the decomposition has `N` elements and there are `F` fixed child patterns,
the pack expands to `N - F` patterns; `N < F` is ill-formed. The pack can be
empty. Generic choice projection can instantiate the same source pack with a
different size for each viable alternative.

A declaration subpattern pack expands into ordinary declaration patterns, so
every child independently applies its type, constraint, cv-qualification, and
reference qualifier. A wildcard pack expands into ordinary wildcard patterns.
Both forms are distinct from `auto [...elements]`, which is one declaration
pattern containing a structured-binding pack.

An empty decomposition pattern is the zero-arity product pattern:

```cpp
empty match {
  case [] => handle_empty();
};
```

It is refutable by arity: applying `[]` to a subject that decomposes into one
or more elements is ill-formed under the same structural-arity rule as every
other decomposition pattern.

For an `if`, the prototype lowers the successful statement into the same
semantic case region, so a binding pack can be used by that statement. A loop
requires whole-statement lowering rather than merely expanding its condition:

```cpp
while (case P = subject) body;

// Conceptually:
while (true) {
  subject match {
    case P => body;
    case _ => break;
  };
}
```

The equivalent C-style `for` lowering must additionally preserve its
increment expression and the behavior of `continue`. This lowering is not yet
implemented; the prototype rejects binding packs, type-varying generic
projections, and other conditions requiring per-case instantiation in
`while`/`for` rather than retaining an invalid dependent body.

```cpp
variant<tuple<int>, tuple<int, int>> value;

value match {
  case { auto [...elements] } => (... + elements);
};
```

This remains one semantic arm per viable alternative. It does not create one
match arm per pack element. The specification needs to state that the
declaration pattern, guard, and handler are all within the same implicit
template region.

Specializing every source arm independently for every viable projected type
would reject an important visitor replacement:

```cpp
variant<int, string, vector<int>> value;

auto size_or_value = value match {
  case { int i }       => i;
  case { auto&& data } => static_cast<int>(data.size());
};
```

The intended reading is that `int` is handled completely by the first arm,
while both remaining alternatives provide `size()`. With overload-like
instantiation this is well-formed, just like:

```cpp
visit(overloaded{
  [](int i) { return i; },
  [](auto&& data) { return static_cast<int>(data.size()); },
}, value);
```

The prototype now gives this overload-like behavior without consulting the
full usefulness or exhaustiveness algorithm. It first checks and classifies
the specialized pattern, then omits the guard and handler when an earlier
unguarded irrefutable arm already closes that semantic domain.

### Semantic reachability without exhaustiveness

For each concrete subject specialization, and for each concrete projected
alternative path, pattern checking should classify a candidate semantic arm
as one of:

- **ill-formed**: ordinary non-dependent errors remain errors; substitution
  failure in the specified immediate context can instead make a dependent
  candidate absent;
- **impossible**: the pattern is well-formed but statically cannot match this
  semantic subject, so its guard and handler are not instantiated;
- **refutable**: the pattern can match some runtime values in this semantic
  domain;
- **irrefutable**: whenever control reaches the candidate in this semantic
  domain, the pattern matches.

An unguarded irrefutable semantic arm closes its domain. Later semantic arms
for that same domain are discarded before their declarations, guards, and
handlers are instantiated. A guard, including a guard known to be `true`, does
not close the domain under the conservative foundational rule.

Irrefutability is recursive and relative to the semantic domain being
instantiated:

- `_` and a viable ordinary binding are irrefutable;
- an exact type pattern is irrefutable, while a runtime cast is refutable;
- a decomposition is irrefutable when its shape is known and every child is
  irrefutable;
- a selected closed alternative is irrefutable within that selected index when
  its child is irrefutable;
- value patterns and open erased-type casts are refutable.

This gives the desired behavior for both dependent whole-subject matching and
closed alternatives:

```cpp
template<class T>
int size_or_value(T value) {
  return value match {
    case int i    => i;
    case auto&& x => static_cast<int>(x.size());
  };
}
```

For `T = int`, the first arm is irrefutable and the second handler is not
instantiated. For a class with `size()`, the `int` candidate is absent or
impossible and the generic handler is instantiated. Likewise, in the variant
example above, the first arm closes only the `int` index; the generic arm is
still instantiated for `string` and `vector<int>`.

This minimal rule deliberately does not combine several refutable patterns
into semantic coverage:

```cpp
bool value;
value match {
  case true  => 0;
  case false => 1;
  case auto&& x => x.invalid();
};
```

The pattern matrix can diagnose the third arm as redundant, but neither of the
first two arms individually closes the `bool` domain. The third handler is
therefore still instantiated. Suppressing it based on the union of `true` and
`false` would make the usefulness algorithm part of template-instantiation
semantics, which this design intentionally avoids.

Result-type deduction, dependence, lifetime analysis, AST traversal, constant
evaluation, CFG construction, and code generation operate on retained
semantic arms only. Coverage diagnostics may additionally retain lightweight
pattern-only records for candidates discarded before handler instantiation.

A generic projection forms an implicit template region even when the current
provider has only one projectable state. Otherwise its semantics would change
when another state is added, and a generic handler could be checked as ordinary
non-template code before viability is known. This applies both to multi-arm
matches and to direct single-pattern conditions.

## Exhaustiveness and Usefulness

### A separate normative diagnostic layer

Non-exhaustiveness and redundancy are hard errors. There is no
`-Wmatch-exhaustiveness` quality-of-implementation mode in the current R6
direction. However, this is layered on top of the matching and instantiation
semantics above. If the committee later chose warnings instead, that would
change diagnostics, not which semantic arms are instantiated or how a match
executes.

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
  case _     => impossible();
}; // error: redundant case
```

Guarded arms can be useful but do not contribute coverage, because their
guards may fail.

The unmatched execution rule is also independent of static exhaustiveness:

- falling through a `void` match has no effect;
- falling through a non-`void` match terminates at runtime and prevents a
  constant expression from succeeding.

Hard exhaustiveness normally prevents the second case for required states,
but the fallback remains necessary for residual states, implementation
robustness, and a possible warning-only policy.

### Algorithmic model

The prototype follows the Maranget/Rust pattern-matrix usefulness model. R6
should specify language behavior rather than merely referencing one compiler
implementation. The central arm classifications are:

- useful: known to cover a state not covered above;
- maybe useful: dependence or an opaque pattern prevents a final answer;
- not useful: cannot cover any state not already covered.

The specification must be stable enough that implementation improvements do
not unpredictably turn formerly valid programs into errors. Conservative
`maybe useful` is the compatibility mechanism for genuinely unknown dependent
or opaque cases.

### Required and residual domains

Coverage distinguishes:

- required states, which must be covered for exhaustiveness;
- residual states, which participate in usefulness but are not required.

Current domains:

- `bool`: `true` and `false` are required.
- integers: the full value domain is required; explicit constants and an
  integer-rest constructor are tracked.
- enums: distinct declared enumerator values are required. Other legal values
  in the enum's range are residual unless explicit constants cover them.
- `variant`: each advertised index is required;
  `valueless_by_exception()` is residual.
- exhaustive closed traits such as `optional` and `expected`: every
  advertised state is required and there is no residual runtime state.
- open traits: the unknown non-empty remainder is required coverage because no
  finite list of typed arms can prove an open domain complete. A nullable open
  trait also has a required empty state. Thus exhaustive `any` matching needs
  `{ _ }` and, when `has_value` is present, `{}` unless a whole-subject arm
  covers those states.

For enums, a wildcard is useful after all enumerators when legal unnamed
values remain. If enumerators or explicit constants cover the full legal enum
range, a trailing wildcard is redundant.

Enumerator policy still needs resolution:

- `[[maybe_unused]]` currently does not remove an enumerator from required
  coverage;
- unavailable enumerators are currently omitted, following `switch`, but a
  required wildcard may be more appropriate for hard exhaustiveness;
- duplicate-valued enumerators form one constructor.

### Diagnostics

Missing-case diagnostics should print source-like witness patterns that users
can paste into the match:

```text
false
{ string }
{ false }
{ _ }
{}
[{ int }, false]
```

Malformed patterns must suppress follow-on exhaustiveness diagnostics.

## Evaluation Model

### Subject and lifetime

- The subject expression is evaluated exactly once.
- An lvalue subject remains a reference to the original object.
- A prvalue subject is materialized in a hidden object.
- The original value category is retained when forming projections.
- For an ordinary match expression, the hidden subject survives through the
  containing full-expression.
- For a direct `if`, `while`, or `for` condition whose bindings are exposed to
  a controlled statement, the hidden subject has condition-variable-like
  lifetime through that statement.
- Default-argument temporaries use the same lifetime-extension mechanism as
  C++23 range-for.

A match arm is not an independent return-like lifetime boundary. The result
of a selected handler propagates through the match expression in the same way
as an operand propagates through `?:`, and lifetime diagnostics are determined
by the enclosing use of the complete match expression. In particular:

```cpp
auto&& dangling = temporary() match -> decltype(auto) {
  case auto&& value => project(value);
}; // warning: the subject temporary dies at the end of this full-expression

consume(temporary() match -> decltype(auto) {
  case auto&& value => project(value);
}); // valid: the projected reference is consumed in the full-expression

auto escape() -> Projected&& {
  return temporary() match -> decltype(auto) {
    case auto&& value => project(value);
  }; // C++26 error: an actual return would let the reference escape
}
```

This distinction matters after P2748R5: binding a function's returned
reference to a temporary is ill-formed in C++26, but using a reference to a
temporary before the end of its full-expression remains valid. The wording
must not model each handler as an invented function return, because that would
incorrectly reject the second example and turn the first example's ordinary
dangling warning into a hard error.

When a handler uses a nested `do` expression, the `do` boundary remains
return-like only for temporaries and locals created inside that `do`.
References to enclosing pattern bindings pass through it and are checked at
the enclosing match-expression use. This is the same distinction an IIFE
makes between its own locals and objects captured from an enclosing scope.

Declaration-pattern storage follows the corresponding ordinary declaration.
A by-value pattern variable is local to its arm, so allowing a reference to it
to escape diagnoses in the same way as returning a reference to a named local.
A reference pattern variable is only an alias: lifetime analysis passes through
the alias and diagnoses according to the underlying subject. These cases must
also preserve C++26's existing distinction between a named local (normally a
`-Wreturn-stack-address` diagnostic) and a temporary bound to a returned
reference (ill-formed after P2748R5).

### Arm ordering and declaration initialization

Arms are attempted in source order. Within one attempted arm, the conceptual
evaluation is:

1. Evaluate refutable child tests in source order, with short-circuiting.
2. After the complete pattern succeeds, initialize declaration bindings in
   source order.
3. Evaluate the guard init-statement and condition.
4. If the guard succeeds, evaluate the handler.
5. If the guard fails, destroy arm-local declarations and continue to the next
   arm.

This two-phase rule prevents an early declaration from moving out of a subject
before a later child pattern has established that the arm matches:

```cpp
std::move(subject) match {
  case [Widget value, 0] => use(value);
  case _                 => fallback();
};
```

If the second component is not zero, `value` is not initialized. Projection
operations needed to inspect the structure may already have run.

Non-throwing discriminator queries are an explicit exception to the physical
ordering above. A closed provider's `index(subject)` is required to be
`noexcept`; equivalent sibling discriminators may be evaluated eagerly when
their common structural subject becomes available, retained, and used by a
decision tree. This permits a product match to compute each choice index once
before dispatch without speculating operations that belong only to a later
source arm.

Every source declaration occurrence is fresh. Two guarded by-value arms can
copy or move twice. There is no rollback:

```cpp
std::move(value) match {
  case Widget first if (false) => unreachable();
  case Widget second           => observe_moved_from(second);
};
```

This is dangerous but consistent with C++ initialization and RAII. Restricting
patterns to references would remove important ownership-transfer use cases and
was rejected.

### Projection reuse latitude

The implementation may retain or recompute equivalent projection operations
within one match. Eligible operations include:

- closed-choice `index(subject)`;
- closed-choice `get<I>(subject)`;
- tuple-like `get<I>`;
- open-choice `try_cast<T>(subject)`;
- open-choice `has_value(subject)`;
- built-in polymorphic runtime refinement and its adjusted object pointer.

Expression comparisons, declaration initialization, and guards are evaluated
at each source occurrence and are not merged.

The specification must define equivalent projection paths and bound permitted
eager evaluation. Operations belonging only to arms after the selected arm
must not be evaluated speculatively.

Discriminator reuse and selected-value reuse have different identities. For a
product `(x, y)`, `y.index()` is independent of the selected alternative of
the sibling `x`, but a projected `get<I>(y)` variable initialized inside one
Cartesian branch cannot automatically be reused from another branch. The
prototype therefore keys discriminator caches by enclosing alternative choices
only, while selected projections additionally include preceding sibling
choices. A future decision-tree representation could place `get<I>(y)` at a
common dominated node and share more.

Retaining a class prvalue projection must not introduce an observable move
that ordinary direct initialization would elide. The prototype preserves the
original prvalue expression for by-value initialization rather than caching it
through a hidden object.

### Mutation, exceptions, and invalidation

A failed guard does not roll back side effects and is not a cache barrier. It
is unspecified whether a later equivalent projection or polymorphic
refinement reuses retained state or observes the mutated subject by
recomputing. In particular, an implementation may classify a polymorphic
subject once and retain adjusted pointers across failed guards.

If user code changes a variant's active alternative, a previously retained
index or projected reference can become stale or dangling. The resulting use
has ordinary C++ consequences; the match does not provide transactional or
snapshot semantics.

If projection, initialization, guard, or handler evaluation throws, ordinary
unwinding applies and no later arm is attempted.

The paper needs precise destruction ordering for hidden subjects, retained
projections, arm declarations, and class-valued or reference-valued results.

### Unmatched execution

- An unmatched non-void match expression terminates.
- An unmatched void-yielding match expression falls through.
- A residual `variant::valueless_by_exception()` state therefore falls through
  in a void match unless explicitly handled, and terminates in a non-void match.

## Alternatives Considered

R6 should summarize the important alternatives, especially where committee
feedback is likely to revisit them.

### `let` versus declarations

`let` had real advantages:

- it clearly distinguished a new binding from an existing expression;
- it did not imply copying, moving, cv/ref choices, or ordinary declaration
  initialization;
- `T: let value` cleanly separated state selection from binding;
- forwarding semantics could be defined uniformly.

The persistent usability objection was that `let` introduced a second binding
vocabulary and made the overwhelmingly common typed variant arm verbose:

```cpp
case int: let value
```

Declaration patterns make ownership and reference choices explicit using
existing C++ syntax:

```cpp
case int value
case const int& value
case auto&& value
```

The choice is not merely syntactic. It commits R6 to ordinary initialization,
including copies, moves, reference binding, constrained placeholders, and
associated lifetime hazards. The paper should present that cost directly.

### Implicit variant unwrapping

Making naked `int value` or `[int x, int y]` automatically inspect a `variant`
was rejected. It makes `auto&& value` ambiguous between the whole choice and
its payload and makes structural patterns silently change meaning based on the
subject's protocol participation.

Braces preserve a useful equivalence:

```cpp
value match {
  case { P1 } => A;
  case { P2 } => B;
};
```

is conceptually similar to visiting an active alternative and matching that
alternative against `P1` and `P2`, while retaining hard validation against the
closed set of alternatives.

### Overload resolution versus first match

Treating arms as actual overloads was explored. It is attractive for familiar
typed visitors but incompatible with general value-pattern composition and
source-order first-match semantics. R6 keeps first match and uses exact-match
viability for each declaration independently. Usefulness diagnoses shadowed
later arms.

### Static type dispatch

Using the same declaration syntax for static dispatch in templates and runtime
dispatch over variants or polymorphic objects produced context-dependent
meaning. Real-code searches found many direct `if constexpr` chains on a type
but little demand for static multi-dispatch over decomposed values.

A future type-subject form is cleaner:

```cpp
T match {
  case int    => ...;
  case double => ...;
  case _      => ...;
};
```

Reflection subjects such as `^^T` can be considered with the C++26 reflection
model. R6 should not overload value declaration patterns with this feature.

### Restricting polymorphic refinement for optimization

Exact-dynamic-type matching, final-only targets, flat hierarchies, and a
closed set of visible derived types would permit cheaper vptr-based dispatch.
They were rejected as the default semantics: `dynamic_cast` users expect an
arm for an intermediate base to accept further-derived objects, including
types defined in another translation unit. They would also lose valid virtual
inheritance adjustments and cross-casts.

The language should keep `dynamic_cast`-equivalent open-world semantics and
let implementations select the fast paths described under "Optimizing
polymorphic refinement." If exact dynamic type matching is later useful enough
to expose, it should receive distinct syntax rather than silently changing the
meaning of `case { Circle& circle }`.

### Runtime marker spellings

`as`, `is`, parentheses, square brackets, angle brackets, and an explicit
runtime keyword were explored. `is` and `as` carried P2392 conversion and
future-expression expectations. Parentheses suggested overloads. Square
brackets conflict with structural decomposition. Angle brackets have severe
C++ parsing costs. Braces provide one explicit runtime boundary for variants,
`any`, nullable projection, and polymorphic refinement. The underlying
mechanisms remain distinct, but a bare declaration never silently changes from
static binding to runtime dispatch.

### Optional and expected

The R5 `? P` form was concise but created a separate protocol and did not scale
to named error states. A shared projection model gives optional and pointer the
same `{ P }`/`{}` shape and models expected as value/error.

Treating expected's error as empty was rejected because real code frequently
needs the error payload and because `expected<T, E>` is naturally a two-payload
choice. The provider-carrying `alternative_name` protocol now permits an
additional `.some`/`.none` view without changing the primary value/error
partition; overlap between the views is deliberately opaque to partial
usefulness analysis.

### Bare declarations for `any`

Allowing naked `int value` to inspect `any` was rejected because it would
silently acquire runtime type-erasure behavior. Requiring `{ int value }`
makes that boundary explicit, just as `{ Circle& circle }` explicitly requests
polymorphic refinement.

### Guard constification and deferred initialization

The design explored constifying pattern variables in guards and delaying
declaration initialization until after a guard succeeds. Structured bindings
whose `get<I>` returns temporaries and guards that mutate the subject make a
separate const guard object difficult to reconcile with the handler's actual
binding. Contracts-style shallow constification does not solve reference and
projection invalidation.

R6 therefore uses ordinary declaration initialization before the guard, no
rollback, and no guard-specific cache barrier.

### Reference-only declaration patterns

Restricting declaration patterns to references would avoid some repeated-copy
and move hazards, but would prevent natural ownership transfer, explicit
copies, and familiar visitor replacements. C++ already permits moved-from
state to be observed. R6 keeps by-value patterns and should warn for especially
surprising guarded moves where practical.

### `match requires`

A separate `match requires` mode remains a credible alternative for making
substitution-dependent pattern viability explicit. Under that model,
`constexpr` and `requires` control orthogonal properties:

| Form | Arm with no viable semantic instantiation | Selection |
|---|---|---|
| `match` | error | runtime |
| `match constexpr` | error | compile time |
| `match requires` | omitted | runtime |
| `match constexpr requires` | omitted | compile time |

The exact modifier order is only illustrative. `constexpr` controls static
selection and discarded handlers; `requires` opts into treating a genuinely
inapplicable pattern as an absent arm. It does not suppress an initialization
error after the declaration selector has been found applicable. This is more
consistent with ordinary C++ than having every dependent match silently
perform a detection operation, and it makes a typo, deleted copy, or unintended
incompatibility fail instead of selecting a fallback.

The rule must not require an arm to be viable for every alternative of a
choice. In an ordinary `variant<int, string>` match, `{ int i }` and
`{ string s }` each cover a subset of the runtime domain and remain valid. The
strict error applies when a source arm has no viable semantic instantiation for
the instantiated subject.

The cost is visible in generic type and shape dispatch. Both examples would
need to opt in:

```cpp
template<class T>
void classify(T value) {
  value match requires {
    case int i         => use_int(i);
    case string s      => use_string(s);
    default            => fallback();
  };
}

template<class T>
void decompose(T value) {
  value match requires {
    case auto&& [x, y]    => use(x, y);
    case auto&& [x, y, z] => use(x, y, z);
  };
}
```

For `classify<int>`, the `string` arm is omitted; for a two-element tuple, the
three-element decomposition arm is omitted. The latter requires genuine
viability-based case instantiation because the unavailable pattern bindings do
not have types.

This model gives strict single-pattern tests a conventional detection spelling:

```cpp
if constexpr (requires { value match case [_, _]; }) {
  auto&& [x, y] = value;
}
```

The current prototype continues to provide implicit dependent viability for
multi-arm `match` and `match constexpr` while we evaluate its utility in real
examples. Single-pattern tests are strict and use an ordinary
requires-expression for detection. The explicit `match requires` model should
remain in the paper's alternatives considered discussion because it has a
clearer failure model for multi-arm matching.

### Pattern init-statements

The prototype briefly allowed an irrefutable pattern as an init-statement:

```cpp
if (case auto&& [x, y] = subject; x < y) {
  use(x);
} else {
  use(y);
}
```

This gave the bindings ordinary init-statement scope, including the condition
and both substatements. It also required a separate irrefutability rule,
special parser recovery, a dedicated match-selection AST mode, and additional
lifetime and control-flow behavior. The convenience did not justify making
`case P = E` serve as both a refutable condition and a declaration-like
init-statement. R6 rejects this form. Ordinary declarations remain available
as init-statements, and `case P = E` remains a direct condition only.

### Strict pattern conditions versus optional match arms

Making `case P = E` use the same partial-relation semantics as a match arm was
explored and rejected. The model was initially attractive because it allowed a
binding-producing static probe:

```cpp
if constexpr (case auto&& [first, second] = value) {
  use(first, second);
}
```

It exposed several surprising consequences:

- `false` could mean either that `P` was non-viable or that a viable refutable
  pattern failed its runtime test.
- A typo or unintended incompatibility in a dependent pattern could silently
  suppress the successful substatement.
- An ordinary `if` would have to suppress its successful substatement whenever
  `P` was non-viable because the pattern bindings would not exist.
- If the construct were exactly two-arm match sugar, a viable irrefutable
  pattern would also suppress `else`. If `else` remained an ordinary `if`
  substatement instead, the direct condition and the equivalent-looking match
  would instantiate different code.

For example, under normal multi-case specialization the fallback handler below
is not instantiated for `T = int`:

```cpp
template<class T>
void via_match(T value) {
  value match {
    case int i => use(i);
    default => static_assert(!same_as<T, int>);
  };
}
```

An ordinary non-`constexpr` `if` normally requires both substatements to be
well-formed. Giving `if (case int i = value)` the match behavior would quietly
add implicit case-instantiation semantics to `if`; retaining ordinary `if`
behavior would make the two spellings diverge.

The chosen split is therefore deliberate:

- `case P = E` requires viability and produces bindings for an ordinary
  pattern condition;
- `E match case P` requires viability and produces a non-binding runtime value
  predicate;
- a case in multi-arm `match` is optional within a semantic specialization, so
  a substitution-dependent non-viable arm does not participate.

This distinction survives `constexpr`. A non-viable `P` is an error in both
`if constexpr (case P = E)` and `if constexpr (E match case P)`, but it can be
skipped in a multi-arm `match constexpr` in favor of another arm. `constexpr`
controls selection and discarded handlers; it does not change required
single-pattern viability into optional arm participation.

One detailed question remains if direct `if constexpr (case P = E)` is added:
for a viable conditionally irrefutable pattern, determine whether only static
selection must be constant while binding initialization occurs on entry to the
selected substatement, or whether the complete declaration-like condition
must be a constant expression. The former resembles `match constexpr`; the
latter more closely resembles an existing `if constexpr` condition
declaration. The prototype currently rejects this form rather than choosing
implicitly.

### Unchecked projection and iterator matching

An unchecked dereference pattern such as `*{ P }` was considered for iterator
algorithms. The examples were not materially clearer than ordinary iterator
tests and introduced conflicts with expression dereference. It is not part of
R6.

### Parenthesized patterns and multiple subjects

Parenthesized patterns were removed so parentheses retain ordinary expression
meaning and can resolve type-versus-expression ambiguity. Matching multiple
values should continue to use an explicit tuple-like subject. Direct
multi-subject syntax remains deferred.

### Lessons from other languages

- C# demonstrates familiar declaration-shaped runtime type patterns, but its
  open class/union model does not provide `variant`'s generic active-payload
  operation. C++ therefore needs an explicit projection layer that C# does not.
- Rust and Maranget provide the basis for usefulness/exhaustiveness analysis.
  Rust's ownership patterns do not directly settle C++ copy/move and guard
  mutation semantics.
- Swift provides precedent for `if case P = E` and allows irrefutable patterns
  with an always-true diagnostic.
- Zig makes payload capture explicit for tagged unions, reinforcing the value
  of distinguishing choice projection from whole-object binding.

### Larger facilities suggested by other languages

The following facilities deserve explicit consideration even if they are not
all part of R6. They are larger additions to the pattern language rather than
minor spelling changes.

| Facility | Precedent | Potential C++ value | Main risk |
|---|---|---|---|
| Or-patterns | Rust `P1 | P2`; C# `P1 or P2`; Swift comma-separated case patterns | Combine enum values and recursively combine patterns without duplicating a handler. | Expression-pattern ambiguity, common binding identity, and disjunctive semantic specialization. |
| Whole-value or as-patterns | Rust `name @ P` | Bind the complete current subject while also matching its parts. | Finding declaration-shaped syntax and defining initialization without duplicating projections. |
| Named member patterns | C# property patterns; Rust struct patterns | Support forms such as `[.x: 0, .y: int y]` without positional coupling. | Aggregate lookup, access, bases, unions, bit-fields, duplicate names, and evolution of class layout. |
| Range patterns | Rust `0..=9`; C# relational patterns; Swift ranges | Let common numeric classifications participate in usefulness and exhaustiveness instead of hiding in guards. | Syntax, conversions, mixed signedness, floating point, and interval complexity. |
| Early-exit pattern declarations | Rust `let P = E else`; Swift `guard case P = E else` | Make a successful binding available after an early failure path without nesting. | Another scope/lifetime construct and overlap with direct pattern conditions. |
| Dynamic slice/list patterns | Rust slice patterns; C# list patterns | Extend fixed tuple decomposition to `span`, arrays of runtime length, and range-like objects. | A new projection protocol, traversal complexity, lifetime, repeated access, and pack typing. |
| Open-world exhaustiveness controls | Rust `#[non_exhaustive]`; Swift `@unknown default` | Express library evolution and distinguish required states from residual or future states. | Interaction with hard redundancy errors and separate-compilation guarantees. |
| User-defined extraction | Swift `~=`; C# `Deconstruct` and property patterns | Extend matching beyond built-in, tuple-like, and choice protocols. | Arbitrary user code makes applicability, exhaustiveness, ordering, and optimization difficult to specify. |

The current priority order is named member patterns, or-patterns, range
patterns, required-versus-residual/open-world coverage, whole-value binding,
early-exit declarations, and dynamic slice patterns. This is an agenda, not a
decision to include all of them in R6.

Several precedents should probably be rejected deliberately:

- Rust match ergonomics infer dereference and reference-binding modes. C++
  declaration patterns should continue to expose cv/ref behavior explicitly.
- C# `and` and `not` patterns add substantial binding and usefulness rules;
  guards cover most immediate uses. Their nested-pattern value should be
  demonstrated before adding them.
- Swift's broadly overloadable `~=` model is difficult to reconcile with hard,
  stable exhaustiveness diagnostics. Extensibility should remain protocol
  specific unless a stronger model is found.

### Or-pattern investigation

An or-pattern applies each child to the same current subject and denotes the
union of their matches. It must remain composable:

```cpp
// `OR` is a design placeholder, not proposed syntax.
case red OR green                         => primary();
case [0 OR 1, int value]                 => small_tag(value);
case [0, int value] OR [int value, 0]    => on_axis(value);
case { .error: timeout OR cancelled }    => retry();
```

Arm-level repeated labels or comma-separated source cases are insufficient:
they cannot express the nested examples and violate the requirement that every
pattern form compose recursively.

#### Syntax collision with expression patterns

Rust can reserve `|` inside its closed pattern grammar. C++ cannot do that
without a rule for expression patterns: `case A | B` already naturally means
compare the subject with the constant expression `A | B`, and bitmask values
make that a realistic use.

The strongest spelling candidates are:

1. `P1 | P2`, following Rust, with `(A | B)` forcing an expression pattern.
   This is compact and familiar to pattern-matching users, but makes the
   unparenthesized bitmask case mean something different.
2. `P1 || P2`, treating pattern alternation as C++ logical disjunction and
   preserving unparenthesized bitwise-or expression patterns. Parentheses
   would force a logical-or expression pattern. This fits C++ precedence more
   naturally, but visually resembles ordinary Boolean evaluation and the
   alternative token `or` is lexically the same operator.
3. An explicit form such as `oneof(P1, P2)`. This avoids operator ambiguity
   but requires a new reserved/contextual introducer and is comparatively
   heavy, especially when nested.

For either operator spelling, the parser needs a pattern-alternative grammar
whose expression-pattern production stops before the separator. Parentheses
remain the escape to the full expression grammar. Repeated `case` labels and
top-level comma alternatives should not be chosen merely because they are
easy to parse; they do not compose.

#### Runtime and coverage semantics

The expected semantic rules are:

1. Alternatives test the same current subject in source order and
   short-circuit after the first successful alternative.
2. Refutable tests complete before declarations from the selected alternative
   are initialized, preserving the existing two-phase arm model.
3. Exactly one logical set of bindings is initialized, from the selected
   alternative, and exactly once.
4. The arm guard is evaluated once after selection. If it fails, matching
   continues with the next source arm; it does not retry a later alternative
   of the same or-pattern.
5. Coverage is the union of child coverage. Each later child must be useful
   relative both to preceding source arms and earlier children of the same
   or-pattern.
6. An or-pattern is impossible when every child is impossible. It is fully
   irrefutable only when the union covers the complete runtime domain,
   including residual states; covering only the required domain is sufficient
   for exhaustiveness but not for runtime irrefutability.
7. Dependent alternatives retain the existing conservative `maybe useful`
   treatment until substitution establishes their applicability and coverage.

The guard rule is important. Naively lowering
`case P1 OR P2 if (guard) => handler` to two source arms would evaluate the
guard twice when `P1` matches and the guard fails but `P2` also matches. That
is not union-pattern behavior and can change side effects.

Projection reuse should follow the existing evaluation latitude. Equivalent
discriminators or projections may be retained across alternatives, but
expression comparisons remain source occurrences and are not merged.

#### Binding models

The language precedents expose three plausible levels:

- C# forbids variable declarations beneath an `or` pattern. Bindings outside
  it remain available, so `[0 OR 1, int value]` works. This is the simplest
  useful subset.
- Rust and Swift require every alternative to introduce a compatible binding
  interface. For C++, that should mean the same ordered names and pack shape,
  with corresponding declarations having the same canonical type, cv/ref,
  and compatible attributes after deduction. The selected alternative
  initializes one logical set of arm variables.
- The prototype's implicit-template-region machinery could theoretically
  permit alternatives to give the same name different types, for example
  `{ int value } OR { string value }`. That would instantiate the guard and
  handler separately for each alternative. It is powerful, but substantially
  more complex and should not be the baseline merely because the prototype
  can specialize generic choice arms.

A conservative implementation sequence is to prototype binding-free
or-patterns first, then add Rust/Swift-style same-interface bindings. The
different-type implicit-template extension should remain a separate design
question. Permanently forbidding all bindings would simplify the language but
would make recursive composition noticeably weaker.

#### Prototype impact

Adding a syntax node is mechanical but full semantic support is not:

- Add an `OrPattern` source node with child patterns and separator locations,
  plus printing, profiling, traversal, transformation, dumping, CFG, constant
  evaluation, and code-generation handling.
- Parse each alternative in a sibling binding scope. The current parser puts
  pattern declarations directly into the arm scope, so duplicate names would
  otherwise redeclare each other. After validating the binding interfaces,
  inject one canonical set for the guard and handler.
- Check each child against the same subject and preserve child-local semantic
  projections. Record which child succeeds so only its declaration
  initializers run.
- Extend semantic refutability from one conjunctive domain path to a union of
  domain paths. `true OR false` is irrefutable even though neither child is.
- Concatenate child coverage rows for exhaustiveness, but check them
  sequentially for internal redundancy. The current coverage conversion
  already returns multiple rows, but it does not compare rows from one source
  pattern against earlier rows of that same pattern.
- Specialize generic projections independently per or-pattern child. The
  current forced-choice machinery assumes choices in one pattern are
  conjunctive and enumerates their combinations. Applying that unchanged to
  disjunctive children would create unnecessary Cartesian instantiations and
  incorrect guard retry behavior.
- Represent the selected semantic child explicitly. The existing
  `MatchPatternInstantiation` can describe one specialized pattern tree, but a
  bound or-pattern needs branch-specific projection state feeding one logical
  binding/guard/handler region.
- Ensure CodeGen and the constant evaluator branch to a common
  declaration-initialization and guard region after selecting a child. A
  failed guard branches to the next source arm, never to another child.
- Add lifetime tests for by-value and reference bindings selected from
  different structural positions, and template tests for dependent
  applicability, packs, generic choice projection, and nested or-patterns.

The architectural issue is therefore not the Boolean disjunction itself. It
is representing disjunctive semantic instantiations and selected-branch
bindings without pretending they are repeated source arms or a Cartesian set
of conjunctive choice specializations. This work aligns with the longer-term
decision-DAG direction and should inform that representation rather than add a
second ad hoc expansion mechanism.

## Decisions Needed Before R6 Wording Is Final

These are design questions, not merely implementation work.

1. **Open: implicit template regions.** Finish the semantic identity and
   instantiation wording for generic projected arms. Preserve the
   impossible/refutable/irrefutable reachability layer independently of the
   pattern-matrix diagnostic layer.
2. **Direction chosen; wording open: projection evaluation latitude.** The
   subject is evaluated once, declaration initialization is ordinary C++, and
   implementations may retain or recompute equivalent projections. Specify
   equivalent paths, permitted eager evaluation, retention, recomputation,
   and mutation consequences.
3. **Open: dependent usefulness.** Distinguish substitution-dependent
   viability from universal redundancy without unstable diagnostics.
4. **Direction chosen; wording open: declaration exact-match
   and polymorphic boundary.** Bare declarations use exact-match semantics;
   braces request open-world refinement with built-in `dynamic_cast`
   semantics. Finish wording and examples for reference binding, decay, qualification,
   functions, arrays, bit-fields, concepts, duplicate alternatives,
   cross-casts, pointer adjustment, and open hierarchies. Define applicability
   separately from selected declaration initialization so that an applicable
   arm with a deleted or inaccessible copy is diagnosed rather than omitted.
   The prototype implements that distinction. Broaden polymorphic refinement
   beyond targets statically derived from the source type.
5. **Partially resolved: `alternative_traits` API.** Closed, open, named, and
   nullable models are implemented. Settle naming, lookup, coherence laws,
   exception requirements, malformed specializations, and header placement.
   Also settle precedence when the same class is both polymorphic and an
   `alternative_traits` model.
6. **Open: named-provider coherence.** Decide whether partial cross-provider
   overlap remains conservatively opaque, providers are locked per projected
   subject, or the protocol gains overlap metadata.
7. **Direction chosen; wording open: single-pattern conditions.** Both
   `E match case P` and `case P = E` require viability. The former is an
   ordinary non-binding Boolean expression; the latter introduces bindings in
   its successful controlled statement. Settle recovery, always-true
   diagnostics, whether both spellings should remain, and the precise
   constant-evaluation and binding-initialization model.
8. **Resolved: `match constexpr`.** R6 retains the R5 facility. Compile-time
   arm selection discards later guards and handlers, discarded handlers do not
   participate in result deduction, and dependent selection is deferred until
   instantiation. Static pattern validity and source-level coverage analysis
   still apply to later arms.
9. **Open: enum coverage policy.** Decide the effect of unavailable and
   `[[maybe_unused]]` enumerators.
10. **Deferred design decision: typed recursive selector.** Decide whether R6
    needs concise syntax for selecting a projected type and immediately
    matching it structurally. The R5 operation
    `ChangeColor: [Rgb: let [r, g, b]]` currently has no direct replacement;
    `{ Rgb: [auto r, auto g, auto b] }` is only an unimplemented candidate.
11. **Paper work: wildcard and identifier `_`.** Update the R5 discussion for
    declaration patterns and C++26 unnamed placeholder variables.
12. **Implementation direction chosen; wording open: handler and fallthrough
   model.** The prototype supports void fallthrough, non-void termination,
   null and `static_assert` handlers, and escaping jump actions. Reconfirm and
   specify their relationship to `do` expressions.
13. **Provisional: `default` arm introducer.** The prototype treats `default`
    exactly as an unguarded top-level `case _`, rejects a guard, and preserves
    the source spelling in the AST. Evaluate whether the familiarity and
    concise fallback spelling justify a second spelling for the same arm.
14. **Deferred but investigated: or-patterns.** Choose a spelling in the
    presence of arbitrary expression patterns, decide between binding-free and
    same-interface bindings, and represent disjunctive semantic
    instantiations without retrying an alternative after guard failure.

## Wording Rewrite Plan

The wording should be rewritten rather than patched around the R5 pattern
taxonomy.

### Core language sections

- Lexing/contextual keywords for `match` and `case`.
- Operator precedence and parsing of the `match` expression.
- Grammar for multi-arm match, `E match case P`, and direct `case P = E`
  conditions.
- Point of declaration and successful-branch scope.
- Subject materialization and lifetime extension.
- General pattern semantics and current-subject terminology.
- Separate subclauses for wildcard, expression, declaration, type,
  decomposition, generic projection, named projection, and empty projection.
- Guard sequencing and declaration initialization.
- Match result typing, jump handlers, void fallthrough, and unmatched
  non-void behavior.
- Template dependence, semantic domains, irrefutability, arm instantiation,
  and discarded non-viable or dominated arms.
- Exhaustiveness, usefulness, required states, residual states, and witnesses
  as a separate diagnostic layer.

### Library wording

- Declaration and primary template placement for `alternative_traits`.
- Closed and open protocol requirements.
- Standard specializations for `optional`, `expected`, `variant`, and `any`.
- A reusable `alternative_traits<T*>` provider that mirrors, but does not
  control, built-in raw-pointer matching, plus explicit inheritance-based
  opt-in for selected nullable library types.
- Feature-test macro and header availability.

### R5 wording to remove

- `let` and let-binding grammar.
- optional pattern `? P`.
- parenthesized pattern semantics.
- legacy `T: P` / type-constraint selector wording.
- generic ADL `try_cast` behavior for naked declaration patterns.
- wording that treats non-exhaustiveness as optional diagnostics.

## Suggested R6 Paper Structure

1. Revision history and one-page summary of changes.
2. Motivation from real C++ code and the R5 feedback.
3. The current-subject/projection mental model.
4. Syntax overview and a compact pattern table.
5. Declaration and type patterns.
6. Closed and open choice projection.
7. Composition examples: values, tuples, nested choices, and polymorphism.
8. Single-pattern conditions and scope.
9. Evaluation, initialization, forwarding, and lifetime.
10. Templates and implicit template regions.
11. Exhaustiveness and usefulness.
12. `alternative_traits` customization.
13. Design alternatives considered.
14. Implementation experience and remaining risk.
15. Proposed wording.

The comparison tables should be regenerated using the new syntax. Every R5
example should be checked, but R6 should prefer declaration forms where they
are natural and braces only where projection is intended.

## Example Checklist for the Paper

The final draft should contain tested examples for:

- integral, string, and enum value matching;
- arm attributes, including `[[likely]]` and `[[unlikely]]`;
- `default` as the concise unguarded top-level spelling of `case _`;
- wildcard and existing-expression patterns;
- by-value, lvalue-reference, const-reference, and forwarding-reference
  declarations;
- constrained placeholder declarations;
- arrays, aggregates, tuple-like decomposition, and nested decomposition;
- variant alternatives, repeated types, and qualification-related types;
- generic structural projection across tuple/pair/array alternatives;
- optional value and empty;
- raw pointer value and null;
- expected value/error and `expected<void, E>`;
- any typed, unknown non-empty, and empty states;
- polymorphic reference and pointer refinement;
- nested choice plus decomposition patterns;
- `E match case P`, direct `case P = E` conditions, rejected pattern
  init-statements, and filtering `for (case P : range)`;
- guards with init-statements;
- dependent viable and discarded arms;
- forwarding an rvalue alternative;
- a failed guarded by-value move followed by another arm;
- exhaustive and redundant bool, integer, enum, variant, optional, expected,
  and open-choice matches;
- void and non-void unmatched behavior;
- class-valued and reference-valued match results.

## Prototype Audit

This section records implementation evidence and remaining engineering work.
It is not a second specification. The useful implementation history is the
sequence of capabilities below; individual commit hashes are omitted because
the branch is routinely rebased.

### Prototype status snapshot

The prototype is functionally broad and the supported runtime and constant
evaluation paths pass the Clang suite. The latest validation has only the
known environment-specific libc++ GDB failure.

The original implementation audit now divides cleanly as follows.

**Completed audit work:**

- type patterns perform the complete hypothetical declaration check;
- singleton and multi-state generic projections use one semantic
  instantiation model;
- `match constexpr` performs compile-time arm selection and discards handlers;
- match expressions and all current patterns are printable;
- the abandoned variant-like `expected` API and speculative `exception_ptr`
  work have been removed;
- direct match conditions retain per-candidate bindings, controlled
  statements, and `for` increments, including structured-binding packs in
  `while` and C-style `for` conditions;
- CFG reachability recognizes whole-subject irrefutable conditions rather than
  inventing a false path.

**Open prototype correctness work:**

1. Reject or correctly serialize match ASTs in PCH and modules.
2. Represent pattern evaluation, cleanup, and exception edges in the CFG.
3. Validate and bound closed `alternative_traits::size` before iteration.
4. Implement match evaluation in the experimental bytecode interpreter, or
   clearly diagnose it as unsupported and rename the misleading tests.

**Open engineering work before presenting the prototype as complete:**

- consolidate the two single-pattern condition parser paths and remove dead
  parser state;
- add hostile and adversarial tests for protocols, nested transformations,
  projections, binding packs, mutation, exceptions, and nontrivial results;
- define source-versus-semantic AST ownership consistently across consumers;
- add a complexity budget and stress coverage for usefulness checking;
- rerun every published example and the complete test suites immediately
  before publication.

**R6 wording blockers exposed by the prototype:**

- implicit template-region identity and instantiation rules;
- projection evaluation latitude and mutation consequences;
- stable dependent usefulness and redundancy rules;
- the exact declaration-conversion, initialization-failure, and
  polymorphic-refinement boundaries;
- the final `alternative_traits` and named-provider coherence contract;
- the final single-pattern condition syntax;
- unavailable and `[[maybe_unused]]` enumerator policy;
- whether a typed recursive projected selector is required;
- complete wording for handlers, fallthrough, and unmatched execution.

### Implemented baseline

The prototype implements and has focused tests for:

- the current pattern vocabulary, multi-arm selection, and both single-pattern
  condition spellings;
- match-arm attributes and `default` arms preserved through semantic
  instantiation, AST traversal and printing, and likelihood-aware code
  generation;
- declaration, type, polymorphic, closed-choice, open-choice, decomposition,
  structured-binding-pack, and declaration-subpattern-pack patterns;
- separate source cases and semantic case instantiations for generic projected
  arms;
- semantic case-condition instantiations for direct `if`, `while`, and C-style
  `for` conditions, including interleaved `&&` chains, candidate-specific
  controlled statements and increments, structured-binding packs, and
  whole-subject irrefutability;
- impossible/refutable/irrefutable semantic classification and domain-local
  pruning before guard and handler instantiation;
- hard usefulness and exhaustiveness checking with source-like witnesses;
- runtime code generation and constant evaluation, including statement
  handlers and escaping control flow;
- scalar, complex, aggregate, and reference-valued results;
- subject-once evaluation, default-argument lifetime extension, retained value
  categories, and match-result lifetime propagation;
- projection and discriminator reuse;
- guards with init-statements, guarded-move warnings, null handlers, and direct
  `static_assert` handlers;
- explicit traversal for dependence, profiling, exception and side-effect
  analysis, lifetime analysis, AST dumping, and the principal CFG paths;
- library models for raw pointers, `optional`, `expected`, `variant`, smart
  pointers, and `any`.

The broad validation command is:

```sh
ninja check-clang check-cxx -C build-release
```

The known libc++ GDB `sect_index_data` failure is unrelated and also occurs on
upstream `main` in this environment.

The audit run on 2026-08-12 discovered 54,334 Clang tests: 53,015 passed, 27
failed as expected, 1,284 were unsupported, and 8 were skipped. The libc++ run
discovered 11,568 tests: 10,494 passed, 25 failed as expected, 1,048 were
unsupported, and only the known GDB pretty-printer test above failed.

### Open correctness and robustness defects

These should be fixed, or explicitly rejected with a controlled diagnostic,
before the prototype is described as complete.

1. **Serialized match ASTs are unusable.** The writer and reader have skeletal
   `MatchTestExpr` and `MatchSelectExpr` visitors that serialize none of the
   match-specific fields. Creating a PCH can appear to succeed, but forcing a
   deserialized constexpr match crashes Clang. If serialization remains out of
   scope, the prototype should reject match expressions in serialized ASTs
   rather than emit corrupt nodes.
2. **CFGs omit pattern evaluation.** The CFG models arm branches, explicit
   pattern declarations, guards, and handlers, but it does not add expression
   comparisons, `alternative_traits` calls, casts, hidden decomposition, or
   their cleanup and exception edges. For example, a call used as an
   expression pattern is absent from `debug.DumpCFG`. This can make analyzer
   results unsound.
3. **Malformed closed protocols can hang the compiler.** A negative
   `alternative_traits<T>::size` is accepted as an integer constant and then
   limited to `UINT_MAX`; projection discovery attempts billions of states.
   The implementation must validate representability, non-negativity, and a
   practical allocation/iteration bound before converting the value.
4. **The experimental bytecode constant interpreter cannot evaluate match
   expressions.** A basic constexpr match fails under
   `-fexperimental-new-constant-interpreter`. The files named
   `AST/ByteCode/cxx2c-match*.cpp` currently invoke only ordinary
   `-fsyntax-only`, so they do not test that interpreter.

### Resolved audit findings

- **Dependent candidate omission swallowed selected initialization errors.**
  Auto deduction, reference binding, exact-match selection, and decomposition
  arity are checked while determining applicability. Once the selector applies,
  declaration initialization and the corresponding hypothetical type-pattern
  check are performed outside candidate SFINAE. A deleted copy therefore
  diagnoses instead of erasing the arm and selecting a fallback. Tests cover a
  dependent whole-subject declaration, a projected `auto` declaration, and a
  projected identifier-less type pattern.
- **AST printing silently dropped matches.** `StmtPrinter` now
  prints source cases for match selections and recursively prints every
  current pattern kind, guards, statement handlers, and both single-pattern
  spellings. Tests cover named, generic, and empty projections, packs,
  declaration and type patterns, and `match constexpr`.
- **Type patterns skipped hypothetical declaration checking.** A
  type pattern now performs the complete declaration-initialization validity
  check, including deleted constructors and reference binding, without
  creating an object or emitting copy, move, destruction, or other runtime
  effects.
- **A failed generic projection over one advertised state could
  disappear silently.** Every generic projection now records and specializes
  its candidate set, including singleton sets. A singleton therefore uses the
  same implicit-generic-parameter model as a multi-state projection and
  consistently diagnoses a closed choice with no viable state.
- **`match constexpr` lacked constexpr arm selection.** Handler
  checking is deferred until selection, discarded handlers do not affect
  result deduction or instantiate `static_assert`, and later source patterns
  remain available to exhaustiveness analysis. Tests cover immediate and
  template-dependent selection, heterogeneous deduced results, irrefutable
  runtime subjects, and rejection of runtime-dependent tests and guards.
- **The abandoned R5 `expected` protocol and speculative `exception_ptr`
  protocol polluted the patch.** The variant-like `expected` API, its support
  headers and tests, and the commented-out `exception_ptr` experiment have
  been removed. `expected` now participates only through
  `alternative_traits`.
- **Direct match conditions lost implicit-template behavior or invented false
  CFG paths.** Conditions now retain per-candidate semantic instantiations for
  their pattern, later condition elements, controlled statement, and `for`
  increment. Binding packs work in `if`, `while`, and C-style `for`; chained
  conditions preserve left-to-right scope and cleanup; and CFG construction
  follows only the selected specialization of a known-true `if constexpr`.
- **Generic selection inside an unrelated template cloned outer declarations.**
  A match over a non-dependent closed choice inside an otherwise dependent
  function was specialized immediately with an empty template argument list.
  References to enclosing parameters and locals could consequently become
  zero-initialized internal globals, causing runtime null dereferences.
  Generic case expansion is now delayed until the enclosing declaration is
  instantiated, when the normal local-declaration mappings are available.

The stale `expected<int, int>` error-state constexpr assertion is now enabled,
so duplicate projected types are covered by the regular suite.

### Architectural risks

- `MatchPattern` is a parallel, non-`Stmt` syntax hierarchy while
  `MatchPatternInfo`, `MatchProjection`, and `MatchPatternInstantiation` carry
  executable semantic state. The source/semantic split is the right direction,
  but every AST consumer must opt in explicitly because match expressions have
  empty generic child ranges.
- Existing explicit traversal is not yet uniform. `RecursiveASTVisitor`
  traverses source cases, while the AST dumper presents semantic
  instantiations. `MatchTestExpr` dumping now includes its hidden holder and
  semantic condition instantiations, but the enclosing control statement also
  retains one representative body. The intended source versus semantic view
  should be defined per consumer instead of emerging from whichever accessor
  it happened to use.
- `MatchPatternInfo` is a wide record whose fields apply to disjoint pattern
  kinds. `MatchProjection` likewise represents alternative, cast, and
  decomposition projections through nullable fields. Their invariants are
  implicit. Kind-specific semantic records or checked constructors would make
  invalid states harder to form.
- Projection specialization and reuse are coordinated through mutable arrays
  of forced choices and two path vectors. This works for current nested and
  Cartesian tests, but the path identity is subtle and is duplicated across
  Sema, constant evaluation, and CodeGen assumptions. A first-class semantic
  decision representation would reduce that coupling.
- Match-result lifetime traversal suppresses duplicate findings by the raw
  source-location encoding of the retained expression. This avoids repeated
  diagnostics from semantic case instantiations, but locations are not unique
  semantic identities: implicit nodes can have invalid/shared locations, and
  macro expansions can deliberately share them. The deduplication key should
  identify the source arm and retained entity rather than relying on location
  alone.
- `MatchPatternState::get`, `MatchPatternInstantiation::find`, and projection
  cache lookup are linear scans. This is acceptable for the prototype, but the
  repeated scans multiply across alternatives and nested patterns.
- The usefulness implementation recursively specializes and copies pattern
  matrices without memoization or a complexity budget. Maranget-style
  usefulness has exponential worst cases; nested products of closed choices
  can therefore become a compile-time denial of service even when each
  individual `alternative_traits` has a reasonable `size`. Add stress tests,
  memoization where profitable, and a controlled complexity diagnostic.
- Parsing `case P = E` and `E match case P` duplicates specialization,
  binding-pack, scope-transfer, and projection-cache setup. The pattern-first
  form additionally mutates `IdResolver` to hide declarations while parsing
  the subject. A shared condition builder would reduce divergent fixes.
- Condition chains are now recognized incrementally by the ordinary binary-
  expression parser; the earlier reversible full-condition token scan has been
  removed. This also preserves ordinary overload resolution for `&&` operators
  before the first case condition.
- Pattern disambiguation still performs tentative classification for leading
  attributes, complete type-ids, and declaration-versus-expression ambiguity.
  Constrained placeholder declarations now retain their normal concept token
  annotation instead of rewinding and annotating again. The remaining probes
  should be measured and consolidated where possible; in particular, parsing a
  semantic type merely to test its endpoint is not an acceptable final parser
  architecture. The `Decomp` parser parameter is currently passed through but
  unused.
- Several helpers were copied from `SemaDeclCXX.cpp` to look up standard type
  traits. They should eventually become shared Sema utilities.
- Diagnostic usefulness state is stored on the mutable source `MatchCase`
  while executable and diagnostic instantiations are carried separately. That
  separation is valuable, but the state ownership should be made explicit
  before serialization and tooling support are added.

### Semantic and coverage risks

- The implicit-template-region model is implemented through ordinary
  `TreeTransform` machinery with an empty synthetic template argument list.
  It gives the intended specialization behavior, but the language model still
  needs wording for identity, instantiation context, captures, local statics,
  diagnostics, result deduction, and same-type duplicate alternatives.
- Semantic dominance intentionally considers only one earlier unguarded
  irrefutable arm. It does not union several refutable arms such as `true` and
  `false`, because that would make the usefulness algorithm control template
  instantiation. This boundary is important and needs normative treatment.
- A generic projection is specialized even when only one projected state is
  currently viable. A direct condition whose pattern becomes concrete during
  template instantiation likewise records a singleton semantic instantiation
  so its bindings, controlled statement, and `for` increment share one
  implicit template region. A standalone Boolean test records the specialized
  pattern and guard but has no controlled statement.
- Partial overlap between distinct named providers is opaque. Complete
  coverage through one provider is recognized, but partial arms from two views
  are not combined. The design must either retain that conservative rule,
  forbid provider mixing at one subject position, or add explicit overlap
  metadata.
- Dependent and opaque patterns are classified as maybe useful to avoid false
  redundancy errors. The standard must define a stable conservative boundary
  so implementation improvements do not unpredictably make accepted programs
  ill-formed.
- Enum coverage still needs a policy for unavailable and `[[maybe_unused]]`
  enumerators. Duplicate values already form one constructor, and legal
  unnamed values are useful residual coverage but are not required.
- Guard mutation can invalidate retained indices and projected references.
  The proposed evaluation latitude deliberately gives no snapshot or rollback
  guarantee, but equivalent paths and the limits on eager evaluation need
  precise wording.
- Structural decomposition creates one hidden structured binding before child
  tests. Adversarial tuple-like `get` implementations, prvalue projections,
  destruction ordering, and nested prefix/suffix binding packs need more tests.

### Condition and handler limitations

- Pattern-first direct conditions use a distinct `CaseConditionExpr` AST node,
  derived from `MatchTestExpr` to share pattern-test payload without conflating
  expression-first lookup or binding behavior. They are not rewritten into
  synthetic two-arm `MatchSelectExpr` nodes. The source `IfStmt`, `WhileStmt`,
  or `ForStmt` is retained, while each case element records viable semantic
  patterns, its continuation, the controlled-statement instantiation, and, for
  `for`, its increment. Code generation, constant evaluation, AST dumping, and
  CFG construction dispatch those semantic candidates directly. The enclosing
  statement currently retains one representative body; that source/semantic
  ownership model should be revisited before tooling or serialization is
  considered complete.
- Semantic expansion is currently deferred for every match test and every
  selection requiring generic case expansion when parsed in a dependent
  declaration context, even when the subject and pattern themselves are
  non-dependent. This avoids an empty-argument `TreeTransform` cloning
  references to enclosing function parameters or locals before the real
  template specialization exists, but can delay a non-dependent
  impossible-pattern diagnostic until specialization. A production model
  should preserve outer declaration identity while still checking genuinely
  non-dependent parts at template definition time.
- Both single-pattern spellings remain in the prototype. `case P = E` has
  attractive familiarity and useful binding scope, but its top-level `=`
  delimiter and self-initialization appearance still need focused syntax
  review. The prototype rejects a trailing pattern guard and rejects a
  same-named subject reference as self-reference. Direct pattern conditions in
  `if constexpr` now require strict pattern viability and constant-evaluate the
  complete match, including projections and declaration-pattern
  initialization. Deferred alternative specialization selects and instantiates
  only the successful candidate body. Code generation materializes the subject
  and selected bindings but emits no runtime discriminator or value-test
  control flow. The expression form `if constexpr (E match case P)` remains
  supported but does not export bindings. Both expression-first and
  pattern-first single-pattern forms now diagnose substitution-dependent
  non-viability. Explicit `requires` probes test applicability without
  evaluating the subject; direct tests report only viable runtime matches.
- Handler grammar now includes expressions, `=> ;`, direct `static_assert`,
  and selected jump statements. Wording must define their contribution to
  result deduction and control flow without treating every handler as an
  arbitrary statement.

### Code generation

- Closed alternatives currently lower to cached linear index tests. At `-O2`,
  a single `variant` match generally becomes the same switch or jump table as
  `std::visit`; at `-O0`, the linear frontend shape remains visible.
- `alternative_traits<variant>::get<I>` uses an unchecked private accessor.
  The protocol permits this because `get<I>` has the precondition that the
  cached active index is `I`. Using public checked access repeated the index
  test and produced substantially more `-O0` helper code.
- Raw and smart pointers and `optional` use dereference; `expected` uses
  dereference and `error()`. Open `any` and polymorphic casts necessarily
  combine their runtime check and projection.
- Product matches over multiple variants lower to nested direct branches.
  Discriminators are shared when their common structural subject dominates
  all uses, but selected typed projections remain branch-local. Larger
  products need code-size and runtime measurements.
- Polymorphic matching currently remains a source-ordered sequence of
  `dynamic_cast` operations. The intended semantics permit repeated-target
  commoning, final-type vptr fast paths, PGO caches, LTO tables with open-world
  fallback, and eventually a multi-target RTTI helper or higher-level IR. The
  prototype does not yet implement those strategies.
- Arm likelihood is currently attached to each generated pattern-test branch.
  For an irrefutable `case _` or `default`, that test is already known true;
  faithfully weighting the incoming fallback edge will require likelihood to
  participate in the eventual decision plan rather than only the final test.
- Aggregate result emission has a remaining destructor-handling TODO. Basic
  class-valued copy-elision and destruction probes pass, but nontrivial result
  destinations and exceptional paths need targeted tests.

#### Dispatch shape, inlining, and `std::visit`

The intended comparison is between an existing call to `std::visit` and a
direct language-level match at that call site. It is not a proposal to
reimplement `std::visit` internally using match syntax.

Existing `std::visit` implementations nevertheless provide useful evidence
about physical dispatch strategies. Their behavior is unusually sensitive to
inlining because switch and function-pointer-matrix implementations expose
different amounts of work to the inliner:

- A function-pointer matrix keeps visitor bodies out of line. The small array
  indexing operation is therefore relatively easy to inline. After inlining,
  constant propagation may see both construction of the variant and the
  resulting active index, select one function pointer, and eliminate every
  other alternative.
- A switch commonly contains the visitor bodies inside its cases. Exposing the
  discriminator may therefore require inlining the whole dispatch and every
  body. The inliner can reject that as too expensive, leaving the complete
  switch even when later constant propagation could have proved the active
  index.
- The result depends on the bodies. Similar switch cases may merge extremely
  well, while separately outlined matrix entries may inhibit that folding.
  Conversely, large unrelated bodies can favor the matrix because its selector
  remains small and independently inlineable.

The observed binary-size advantage of one strategy is therefore not
fundamental. A direct prototype experiment with a language match over a
16-way variant produced:

- a runtime-unknown discriminator optimized to an LLVM `switch` with direct
  calls; and
- a discriminator made known through ordinary constant propagation optimized
  to one direct call, with all other alternatives removed.

A direct match has no mandatory library helper between the source operation
and its handlers. Its semantic representation should expose an *alternative
dispatch* and postpone the physical choice. Conceptually, such an operation
retains:

- the discriminator;
- the unchecked projection associated with each alternative;
- ordered handlers and guards; and
- exhaustiveness information.

After inlining, constant propagation, and preferably profile propagation, the
implementation can select an appropriate lowering:

| Situation | Preferred lowering |
|---|---|
| Constant discriminator | Emit only the selected alternative |
| Small or readily inlinable dispatch | Direct switch or branch tree |
| Cases sharing behavior | Merge their destinations |
| Skewed profile | Direct hot cases with a cold fallback |
| Large unpredictable dispatch | Compact jump table or outlined thunk matrix |
| Multiple choices | Decision DAG; flatten only small dense products |

Outlining arbitrary match handlers is also harder than outlining ordinary
visitor call operators: handlers can capture locals, own cleanups, or throw.
Eligible handlers could eventually be outlined with an explicit context
pointer, but that should be a late profitability transformation rather than
the baseline semantic lowering.

### Deferred decision-DAG lowering

A semantic decision DAG remains the preferred optimization architecture. Sema
already knows the finite state sets, projection dependencies, semantic arm
instantiations, first-match ordering, and guards. That structure can feed an
ephemeral CodeGen plan, but a sufficiently high-level IR operation would allow
the final dispatch choice to occur after inlining, constant propagation, and
profile propagation instead of forcing LLVM IR to rediscover the match.

An eventual implementation should:

1. record explicit selections and dependencies per semantic case;
2. build an ephemeral CodeGen plan;
3. choose linear tests, nested switches, or bounded Cartesian dispatch using a
   code-size heuristic;
4. form typed `get<I>` projections only where `I` is known;
5. classify polymorphic subjects once where profitable, retain successful
   adjusted pointers, and reuse more-derived refinements for later base arms;
6. preserve source order for residual value tests and guards.

The baseline should be direct semantic switch or decision-DAG lowering, with
constant alternatives removed before generating all handlers. The
representation should preserve enough structure through inlining for later
case merging and profile-guided layout. Large-switch outlining or matrix
lowering can then be added for runtime-unpredictable cases where measurement
shows a benefit.

It must not unconditionally form a Cartesian product. Nested choices, open
choices, guards, overlapping providers, and multiple viable source arms all
require ordered residual testing.

### Tooling deliberately deferred

- complete modules and PCH serialization;
- AST import, indexing, clangd, refactoring, and source rewriting;
- libclang support;
- Itanium expression mangling;
- named aggregate decomposition support in tooling.

Until these are implemented, unsupported paths should diagnose or preserve a
valid opaque AST. They must not silently erase syntax or crash.

### Deferred language features

- type and reflection-value subjects;
- named aggregate decomposition such as `[.x: P, .y: Q]`;
- or-patterns, range patterns, and other combinators;
- whole-value/as-patterns and early-exit pattern declarations;
- dynamic slice/list patterns;
- direct multi-subject matching;
- strict full-domain enum exhaustiveness mode;
- typed recursive projected selectors;
- reflection-based protocol alternatives.

## R6 Completion Checklist

### Design and wording

1. Resolve the wording-blocking decisions listed above, especially implicit
   template regions, projection evaluation latitude, the exact declaration
   conversion boundary, and named-provider coherence.
2. Rewrite the R5 paper around the current-subject/projection model rather
   than patching the `let`, `? P`, `T: P`, and parenthesized-pattern wording.
3. Define usefulness conservatively and normatively enough that hard
   redundancy errors remain stable across implementations and releases.
4. Specify subject materialization, projection preconditions, declaration
   initialization, guards, destruction, result lifetime, and unmatched
   execution as one coherent evaluation model.
5. Finish the `alternative_traits` contract: lookup, headers, malformed
   specializations, `noexcept`, cv/ref forwarding, open-choice pointer
   lifetime, names, and provider mixing.
6. Regenerate the comparison tables and include composition examples for
   tuples, nested choices, polymorphic objects, optional, expected, any, and
   generic projected alternatives.

### Prototype before publication

1. [ ] Reject or correctly serialize match ASTs; add a forced-deserialization PCH
   test.
2. [ ] Make CFG construction include pattern/projection evaluation and cleanup or
   conservatively represent it as an opaque side-effecting operation.
3. [ ] Validate protocol `size` before iteration and add hostile-specialization
   tests.
4. [x] Implement AST printing and add round-trip-oriented tests.
5. [x] Make type patterns perform the complete hypothetical declaration
   initialization check without emitting initialization or destruction.
6. [x] Diagnose a generic projected arm with no viable state consistently when a
   closed choice has only one advertised state.
7. [x] Implement `match constexpr` with discarded-handler semantics, or remove it
   from the R6 grammar and prototype.
8. [x] Remove the abandoned `expected` variant-like API and its tests, retaining
   only the `alternative_traits<expected<T, E>>` model required by R6.
9. [ ] Implement match evaluation in the experimental bytecode interpreter, or
   clearly mark it unsupported and rename tests that currently imply bytecode
   coverage.
10. [ ] Consolidate the two condition parsing paths and remove dead parser
    state.
11. [ ] Add adversarial tests for nested transforms, duplicate projected types,
    binding-pack shapes, guard mutation, projection exceptions, aggregate
    results, and destructors.
12. [x] Re-enable the now-passing duplicate-type `expected<int, int>` constexpr
    assertion.
13. [x] Instantiate direct match conditions semantically, including candidate
    bodies, `for` increments, binding packs in loops, and CFG irrefutability.
14. [ ] Re-run every published example against the prototype.
15. [ ] Run the complete validation command immediately before publishing
    results. The latest development run passed `check-clang`; `check-cxx` had
    only the known upstream-reproducible GDB failure.

### Paper editing

1. Replace the introductory `let` narrative and rewrite the comparison tables.
2. Condense the declaration exploration into rationale ending at the adopted
   exact-match plus explicit-projection design.
3. Add dedicated sections for implicit template regions, exhaustiveness, and
   evaluation; these are central semantics, not implementation details.
4. Update the slides from `type()`/`get<T>()` to the open
   `try_cast<T>`/`has_value` protocol and include `case P = E`.
5. Keep alternatives considered separate from live design choices and keep
   prototype defects separate from wording blockers.

### Godbolt examples with folks

Zach: 

// Matching Integrals
// Example from https://isocpp.org/files/papers/P2688R2.html#matching-integrals

constexpr auto f1(int x) {
  return x match {
    case 0 => 101;
    case 1 => 202;
    case _ => -1;
  };
}

static_assert(f1(0) == 101);
static_assert(f1(1) == 202);
static_assert(f1(2) == -1);

// NOTE: could put attribute after pattern, before expr or after expr.
//       don't neceesarily need case for that.
// case is easier to spot in bigger examples
// a bit more grammar space if we want to `static case`

// Dependent subject
#include <cstddef>
#include <string>

using namespace std::string_literals;

constexpr std::size_t g(auto x) {
    return x match -> std::size_t {
        case int i => i;
        case const std::string& s => s.size();
        case _ => -1;
    };
}

static_assert(g(0) == 0);
static_assert(g("hello"s) == 5);
static_assert(g(0.0) == -1);

#include <tuple>

template <typename... Ts>
constexpr std::size_t g(std::tuple<Ts...> p) {
    return p match -> std::size_t {
        case [0, 0] => 0;
        case [0, 0, 0] => 1;
        case _ => -1;
    };
}

static_assert(g(std::tuple(0, 0)) == 0);
static_assert(g(std::tuple(0, 0, 0)) == 1);
static_assert(g(std::tuple(0, 1)) == -1);
static_assert(g(std::tuple(0, 1, 2, 3)) == -1);

// Matching Strings
// Example from https://isocpp.org/files/papers/P2688R2.html#matching-strings

#include <string_view>

constexpr auto f2(const std::string_view sv) {
  return sv match {
    case "foo" => 101;
    case "bar" => 202;
    case _ => -1;
  };
}

static_assert(f2("foo") == 101);
static_assert(f2("bar") == 202);
static_assert(f2("baz") == -1);

// Matching Optionals

#include <optional>

constexpr auto f3(const std::optional<int>& opt) {
  return opt match /* trussmebruh */ {
    // ? let i => i;
    // std::nullopt => -1;

    // case { auto i } => i;
    // case {} => -1;
    
    case { 42 } => -1;
    case { _ } => -3;
    case {} => -2;
    // case _ => unreachable();
  };
}

static_assert(f3(101) == -3);
static_assert(f3(42) == -1);
static_assert(f3(std::nullopt) == -2);

constexpr auto g3(const std::optional<std::pair<int, double>>& opt) {
  return opt match {
    // case ? let [i, d] => i;
    // case _ => -1;
    case { [1, 2.0] } => -2;
    case { auto&& [i, d] } => i + int(d);
    case {} => -1;
  };
}

static_assert(g3(std::pair(1, 2.0)) == -2);
static_assert(g3(std::pair(101, 1.1)) == 102);
static_assert(g3(std::nullopt) == -1);

/* map value_type referenced messed up?
void z(std::map<int, int> m) {
    for (auto const& [k, v] : m) {

    }
}
*/

// Matching Tuples
// Example from https://isocpp.org/files/papers/P2688R2.html#matching-tuples

#include <utility>

constexpr auto f4(const std::pair<int, int>& p) {
  return p match {
    case [0, 0] => 0;
    case [0, auto y] => y + 2;
    case [auto x, 0] => x + 4;
    case auto [x, y] => x * y;
  };
}

static_assert(f4({0, 0}) == 0);
static_assert(f4({0, 2}) == 4);
static_assert(f4({2, 0}) == 6);
static_assert(f4({2, 4}) == 8);

// Matching Variants
// Example from https://isocpp.org/files/papers/P2688R2.html#matching-variants

#include <variant>

constexpr auto f5(const std::variant<int, float, double>& v) {
  return v match {
    // int: let i => i;
    case { int i } => i;
    // std::floating_point: let f
    case { std::floating_point auto f } => int(f) + 2;
    // case { double d } => int(d) + 4;
  };
}

static_assert(f5(1) == 1);
static_assert(f5(2.f) == 4);
static_assert(f5(3.0) == 5);

constexpr auto f6(const std::variant<int, std::tuple<int, int>, std::pair<int, int>>& v) {
  return v match {
    // int: let i => i;
    case { int i } => i;
    // std::tuple<int, int>: let [x, y]
    // std::pair<int, int>: let [x, y]
    // or
    // two_tuple: let [x, y]
    case { auto&& [x, y] } => x + y;
    // auto: let alt => ...  -- std::visit([](auto&& alt) { ... }, v);
    // case { auto&& alt } => alt;
  };
}

// major potential changes
// 1. `let` becomes `decl pattern`
// 2. `T: pattern` becomes `{ P }`
// 3. exhaustiveness checking as hard errors
// 4. 

#if 0
template <class _Tp>
struct alternative_traits<optional<_Tp>> {
  static constexpr size_t size = 2;
  static constexpr bool is_exhaustive = true;

  template <size_t _Ip>
    requires(_Ip == 1)
  using projection_type = _Tp;

  static constexpr size_t index(const optional<_Tp>& __value) noexcept {
    return __value.has_value() ? 1 : 0;
  }

  template <size_t _Ip, class _Self>
    requires(_Ip == 1)
  static constexpr decltype(auto) get(_Self&& __self) noexcept {
    return *std::forward<_Self>(__self);
  }

  static consteval size_t index_of(nullopt_t) noexcept { return 0; }
};


template <class... _Types>
struct alternative_traits<variant<_Types...>> {
  static constexpr size_t size = sizeof...(_Types);
  static constexpr bool is_exhaustive = true;

  template <size_t _Ip>
  using projection_type = _Types...[_Ip];

  static constexpr size_t index(const variant<_Types...>& __value) noexcept {
    return __value.index();
  }

  template <size_t _Ip, class _Self>
  static constexpr decltype(auto) get(_Self&& __self) noexcept {
    return std::forward_like<_Self>(*std::get_if<_Ip>(std::addressof(__self)));
  }
};

#endif

enum E { A, B, C }; // [0,1,2,3]

int h(E e) {
  return e match {
    case A => 0;
    case B => 1;
    case C => 2;
    case _ if (true) => 4;
  };
}

struct Shape { virtual ~Shape() = 0; };
struct Circle : Shape { int c; };
struct Rectangle : Shape { int r; };

void rt(Shape const& s) {
    void(s match {
        case { Circle const& c } => c.c;
        case { Rectangle const& r } => r.r;
        case _ => 0;
    });
}

constexpr std::size_t sta(auto x) {
    return x match -> std::size_t {
        case int i => i;
        case const std::string& s => s.size();
        case _ => -1;
    };
}

template <typename S>
void rt2(S const& s) {
    static_assert(not std::is_polymorphic_v<S>);
    // typeid(s) --> this is static type of s if s is not polymorphic.
    //               if S is Shape, then dynamic type
    s match {
        case { Circle const& c } => c.c;
        case { Rectangle const& r } => r.r;
        case auto&& shape => 0;
    };
}

// { auto&& alt } => ...;
// auto&& v => ...;

#include <any>

void rt3(std::any a) {
    void(a match -> size_t {
        case { int i } => i;
        case { std::string s } => s.size();
        case _ => 0;
    });
}

// two axis
// 1. open vs closed. braces have been for closed so far (optional, variant, expected)
// 2. "value storage inside". `int` is stored inside `any`, `int` is not `any`.
//
// any ended up with braces because ultimately, looking at just `int i` which
// is definitely not polymorphic, we don't necessarily want that to have
// runtime fetching behavior.
//
// `any` to `int` is just never the "dynamic type" behavior that polymorphic types have

#if 0
template <>
struct alternative_traits<any> {
  // missing size makes it open instead of closed

  template <class _Tp, class _Self>
  static _Tp* cast(_Self&& __self) {
    return std::any_cast<_Tp>(&std::forward<_Self>(__self));
  }
};

template <>
struct alternative_traits<exception_ptr> {
  // missing size makes it open instead of closed

  template <class _Tp, class _Self>
  static _Tp* cast(_Self&& __self) {
    return std::exception_ptr_cast<_Tp>(std::forward<_Self>(__self));
  }
};

template <>
struct alternative_traits<MyThing> {
  // missing size makes it open instead of closed

  static const type_something& type(const MyThing& __value) noexcept {
    return __value.type();
  }

  template <typename T>
  static const type_something& compute_type_something() {
    return CTTI(T);
  }

  /*

  void f(MyThing mything) {
    mything match {
      T1 t1 => ...;
      T2 t2 => ...;
    };

    type_something ts = mything.type();
    if (ts == compute_type_something<T1>) {
      T1 t1 = 
    } else if (ts == compute_type_something<T2>) {
      T2 t2 = 
    }
  }

  */

  template <class _Tp, class _Self>
  static _Tp* cast(_Self&& __self) {
    return std::any_cast<_Tp>(&std::forward<_Self>(__self));
  }
};
#endif

// { void }
// {}

#include <expected>

void f(std::expected<void, std::string> e) {
    void(e match {
        case { void } => 0;
        case { std::string& s } => 1;
    });
}

#if 0
// general property
v match {
    { P1 } => E1;
    { P2 } => E2;
};

std::visit([](auto&& alt) {
    FWD(alt) match {
        P1 => E1;
        P2 => E2;
    };
}, v);
#endif

constexpr void zoo(double) {}
constexpr int zoo(int) { return 42; }

constexpr int foo(auto x) {
    return zoo(x) match {
        case void => 0;
        case int i => i;
    };
}

static_assert(foo(0.0) == 0);
static_assert(foo(0) == 42);

#if 0
template <class _Tp, class _Ep>
struct alternative_traits<expected<_Tp, _Ep>> {
  static constexpr size_t size = 2;
  static constexpr bool is_exhaustive = true;

  struct names {
    enum { value, error };
  };

  template <size_t _Ip>
  using projection_type = conditional_t<_Ip == names::value, _Tp, _Ep>;

  static constexpr size_t index(const expected<_Tp, _Ep>& __value) noexcept {
    return __value.has_value() ? names::value : names::error;
  }

  template <size_t _Ip, class _Self>
  static constexpr decltype(auto) get(_Self&& __self) {
    if constexpr (_Ip == names::value)
      return *std::forward<_Self>(__self);
    else
      return std::forward<_Self>(__self).error();
  }
};
#endif

int f(std::expected<int, std::string> e) {
    return e match -> size_t {
        // .NAME --> alternative_traits<decltype(e)>::names::NAME
        case { .value: int i } => i;
        case { .error: auto&& s } => s.size();
    };
}

// E match P --> yields a bool, just a single pattern match
// E match case P

// if (pair match case [0, auto&& y]) {
//   ...
// }

// if let (0, y) = pair {
//   ...
// }

// if (case [0, auto&& y] = pair) {
//   ...
// }

// f(pair match case [1, 2]);

// void f(auto x) {
//   return x match case int i;
// }
//
// E match {
//   case P => true;
//   case _ => false;
// };

// void f(auto x) {
//   return x match {
//     case int i => true;
//     case _ => false;
//   };
// }

// if constexpr (requires { E match case int i }) {
//   if (E match case int i) {
//     ...
//   }
// }

Agustin: https://godbolt.org/z/dKaETnf5x

```
// pattern:
//   _
//   constant-expression
//   decl-pattern
//   type-pattern
//   { pattern }
//   [ pattern... ]

// matching integrals
constexpr auto integral(int x) {
  return x match {
    case 0 => 101;
    case 1 => 202;
    case _ => -1;
  };
}

static_assert(integral(0) == 101);
static_assert(integral(1) == 202);
static_assert(integral(2) == -1);

#include <optional>

// optional matching with { P } and {}
constexpr auto opt(const std::optional<int>& o) {
  return o match {
    // ? let i => i;
    // _ => -1;
    case { auto i } => i;
    case {} => -1;
  };
}

static_assert(opt(42) == 42);
static_assert(opt(std::nullopt) == -1);

constexpr auto opt2(const std::optional<int>& o) {
  return o match {
    // other way around
    case {} => -2;
    case { auto i } => i;
  };
}

static_assert(opt2(45) == 45);
static_assert(opt2(std::nullopt) == -2);

#include <variant>

// variant matching with { P }
constexpr auto var(const std::variant<int, float, double>& v) {
  return v match {
    // int: let i => i;
    // float: let f => ...;
    // double: let d => ...;
    case { int i } => i;
    case { float f } => int(f) + 2;
    case { double d } => int(d) + 4;
  };
}

static_assert(var(1) == 1);
static_assert(var(2.f) == 4);
static_assert(var(3.0) == 7);

constexpr auto var2(const std::variant<int, float, double>& v) {
  return v match {
    // int: let i => i;
    // std::floating_point: let f
    case { int i } => i;
    case { std::floating_point auto f } => int(f) + 2;
  };
}

static_assert(var2(1) == 1);
static_assert(var2(2.f) == 4);
static_assert(var2(3.0) == 5);

#include <tuple>
#include <utility>

constexpr auto var2(const std::variant<int, std::tuple<int, int>, std::pair<int, int>>& v) {
  return v match {
    // int: let i => i;
    // std::tuple<int, int>: let [x, y]
    // std::pair<int, int>: let [x, y]
    case { int i } => i;
    case { auto&& [x, y] } => x + y;
  };
}

// Dependent subject
#include <cstddef>
#include <string>

using namespace std::string_literals;

constexpr std::size_t dep(auto x) {
    return x match -> std::size_t {
        case int i => i;
        case const std::string& s => s.size();
        case _ => -1;
    };
}

static_assert(dep(0) == 0);
static_assert(dep("hello"s) == 5);
static_assert(dep(0.0) == -1);
```

Barry: do-expression lifetime https://godbolt.org/z/WxGY7ETGr

```
#include <expected>
#include <type_traits>
#include <utility>

#define FWD(e) static_cast<decltype(e)&&>(e)

template<class T>
struct try_traits;

template<class T, class E>
struct try_traits<std::expected<T, E>> {
    static constexpr bool
    should_continue(std::expected<T, E> const& e) {
        return e.has_value();
    }

    static constexpr auto
    extract_continue([[clang::lifetimebound]] auto&& e) -> auto&& {
        return *FWD(e);
    }

    static constexpr auto
    extract_break([[clang::lifetimebound]] auto&& e) -> auto&& {
        return FWD(e).error();
    }

    static constexpr auto from_break(auto&& error) {
        return std::unexpected<E>(FWD(error));
    }
};

#ifdef NEVER_XVALUE
template<class T>
constexpr decltype(auto) decay_xvalue(T&& value) {
    if constexpr (std::is_lvalue_reference_v<T&&>) {
        return (value);
    } else {
        using U = std::remove_reference_t<T&&>;
        return static_cast<U>(FWD(value));
    }


#define MAYBE_DECAY_XVALUE(expr) decay_xvalue(expr)
#else
#define MAYBE_DECAY_XVALUE(expr) expr
#endif

#define TRY(e) e match -> decltype(auto) {                       \
  case auto&& __r => do -> decltype(auto) {                      \
    using CT = try_traits<std::remove_cvref_t<decltype(__r)>>;   \
    if (!CT::should_continue(__r)) [[unlikely]] {                \
        return CT::from_break(CT::extract_break(FWD(__r)));      \
    }                                                            \
    MAYBE_DECAY_XVALUE(CT::extract_continue(FWD(__r)))           \
  }; \
}

#define TRY_STMT(tgt, e)                                          \
    auto&& __r = e;                                               \
    using CT = try_traits<std::remove_cvref_t<decltype(__r)>>;    \
    if (!CT::should_continue(__r)) {                              \
        return CT::from_break(CT::extract_break(FWD(__r)));       \
    }                                                             \
    tgt = CT::extract_continue(FWD(__r))

enum class E {};

template<class T>
auto get_data() -> std::expected<T, E>;

auto f1() -> std::expected<int, E> {
    auto&& data = TRY(get_data<int>());
    return data;
}

auto consume(int x) -> int { return x; }

auto f2() -> std::expected<int, E> {
    auto&& data = consume(TRY(get_data<int>()));
    return data;
}
```
