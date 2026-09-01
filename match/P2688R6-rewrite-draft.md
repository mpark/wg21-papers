# P2688R6 Material Not Yet Incorporated

This file contains only material from the former standalone R6 rewrite that
has not yet been incorporated into `P2688R6.md`. Once an item is incorporated,
remove it from this file.

# Introduction Material

C++ already contains the ingredients from which programmers approximate
pattern matching:

- `switch` for finite integral states;
- structured bindings for product decomposition;
- `std::visit`, `get_if`, and `holds_alternative` for closed sums;
- `has_value`, `value`, and `error` for nullable and expected-like values;
- `dynamic_cast` for polymorphic refinement;
- `if constexpr` and constraints for dependent selection.

The problem is not that these operations are impossible. The problem is that
they do not compose. A programmer who needs to select a variant alternative,
decompose it, test one component, bind another, and preserve its value category
must manually combine several unrelated facilities and repeat the control-flow
structure.

The design is guided by four requirements:

1. Common C++ operations should use familiar C++ declarations.
2. Runtime projection must be visible rather than inferred from the subject's
   type.
3. Patterns must compose recursively.
4. Templates, evaluation, exhaustiveness, and diagnostics must have a
   specification model independent of one compiler implementation.

# Design in One Page

The basic selection form is:

```cpp
subject match {
  case pattern if (guard) => handler;
  case pattern            => handler;
  default                 => handler;
};
```

Patterns apply to a current subject:

```cpp
_                         // wildcard
constant-expression       // value pattern
declaration               // declaration pattern
type-pattern              // declaration with its identifier omitted
[P1, P2, ...]             // decomposition pattern
{ P }                     // runtime projection or refinement
{ .name: P }              // named choice projection
{}                        // advertised state with no projection
```

A declaration always binds the current subject:

```cpp
case Widget value
case const Widget& value
case auto&& value
case std::integral auto value
```

A declaration does not implicitly enter a `variant`, `optional`, or `any`, and
does not implicitly refine a polymorphic class. Braces request those runtime
operations:

```cpp
variant<int, string> value;

value match {
  case auto&& whole           => inspect_variant(whole);
  case { int integer }        => use(integer);
  case { const string& text } => print(text);
};
```

The example above makes the first arm dominate the others; it is shown only to
contrast the meanings. In a useful match, the whole-object arm would normally
have a guard or appear after projected arms.

Patterns compose without changing meaning:

```cpp
variant<tuple<int, int>, pair<int, int>, array<int, 2>> value;

value match {
  case { [0, auto&& y] }        => on_axis(y);
  case { [auto&& x, auto&& y] } => point(x, y);
};
```

The single-pattern expression does not export bindings:

```cpp
bool is_origin = value match case { [0, 0] };
```

The pattern-first condition does:

```cpp
if (case { [int x, int y] } = value && x < y) {
  use(x, y);
}
```

# Wording Revision Checklist

The retained R5 wording needs coordinated core-language and library updates.

Core wording needs to cover:

- grammar and precedence for `match`, `case`, guards, handlers, and direct
  conditions;
- the current-subject model and recursive pattern evaluation;
- declaration/type-pattern applicability and initialization;
- choice projection and polymorphic refinement;
- scope, point of declaration, lifetime, and evaluation order;
- dependence, implicit template regions, and discarded handlers;
- result typing, constant evaluation, and unmatched execution;
- mandatory usefulness and exhaustiveness diagnostics.

Library wording needs to define:

- `alternative_traits` and `alternative_name`;
- standard-library models for `variant`, `optional`, `expected`, selected smart
  pointers, and `any`;
- unchecked-projection preconditions and `noexcept` discriminator requirements;
- feature-test macros and required header availability.

The wording should specify observable behavior rather than mandate the
prototype's pattern-matrix or branch-based lowering.

# Implementation Preface

The prototype demonstrates that the design is implementable, but it should not
be mistaken for the final architecture.

The implementation is maintained in the
[`p2688-pattern-matching`](https://github.com/mpark/llvm-project/tree/p2688-pattern-matching)
branch of Clang and is enabled with `-fpattern-matching`. Earlier revisions
were also made available through Compiler Explorer as `x86-64 clang (pattern
matching - P2688)`; that deployment should be refreshed for the R6 syntax
before publication.

# R6 Acknowledgement Addendum

R6 also benefited from extensive implementation-driven discussion around
declaration patterns, exhaustiveness, dependent case instantiation, choice
customization, evaluation, code generation, and nested structured bindings.
The commit history of the prototype preserves individual code contributions
and authorship as that work continues.

# Editorial Items

- Consider grouping the R5-to-R6 revision list under surface-language,
  semantic, and implementation subheadings.
- Rename the comparison-table column from "This Paper" to "P2688R6".
- Modernize minor formatting in the earlier revision history without removing
  any polls or revision-specific details.
- Incorporate the wording checklist next to the retained R5 wording once the
  first R6 wording edits begin.
