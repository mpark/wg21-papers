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

This paper is the next revision of [@P2688R5]. [@P2688R5] was considered for
C++26 at the February 2025 Hagenberg meeting, but did not reach consensus for
forwarding to CWG. This revision targets C++29.

R6 is not just R5 retargeted to a later standard. We have continued the
implementation, looked through production C++ for examples, and reconsidered
the parts of R5 that did not look or feel like C++. The biggest change is that
patterns now use ordinary declarations to introduce names:

```cpp
match (value) {
  case 0                 => zero();
  case int i             => integer(i);
  case const Widget& w   => widget(w);
  case auto&& [x, y]     => pair(x, y);
}
```

This replaces the `let` syntax from R5. A declaration says whether the match
copies, moves, or binds a reference, and gives `decltype` the answer a C++
programmer would expect.

The other large change is that braces explicitly mean "look inside a choice":

```cpp
std::variant<int, std::string> value;

match (value) {
  case { int i }                   => print(i);
  case { const std::string& text } => print(text);
}
```

The same notation works for pointers, `optional`, `expected`, `variant`,
`any`, and user-defined choice types. Closed and open choice types customize
the operation through `std::alternative_traits`. A declaration without braces
still applies to the object itself.

R6 also makes the selection a prefix construct. In an expression-only context
it is an expression:

```cpp
auto result = match (@*match-subject-list*@) {
    @*match-preamble-declaration-seq~opt~*@
    case @*pattern~1~*@ => @*handler~1~*@;
    case @*pattern~2~*@ => @*handler~2~*@;
    ...
};
```

At the start of a statement, it is a statement. Each handler is an ordinary
statement and there is no semicolon after the closing brace:

```cpp
match (@*match-subject-list*@) {
    @*match-preamble-declaration-seq~opt~*@
    case @*pattern~1~*@ => @*statement~1~*@
    case @*pattern~2~*@ => @*statement~2~*@
}
```

One expression gives `match` one subject. Several expressions form an unnamed
product and are matched with a decomposition pattern:

```cpp
match (x, y) {
  case [0, 0] => origin();
  case [int x, int y] => point(x, y);
}
```

An extra pair of parentheses retains the ordinary comma expression meaning:
`match ((x, y))` has one subject.

A single-pattern test uses a function-like spelling:

```cpp
match( @*match-subject-list*@ , case @*pattern*@ )
```

It produces a `bool` and does not make declarations in the pattern available
afterward. When those declarations are needed, a pattern condition is used:

```cpp
if (case @*pattern*@ = @*expression*@) {
  // names introduced in the pattern are available here
}
```

This paper proposes the following six patterns:

| Pattern | Examples | Meaning |
|---|---|---|
| Wildcard | `_` | Matches and ignores its subject. |
| Value | `42`, `"hello"`, `some_constant` | Compares an expression with its subject. |
| Declaration or type | `int value`, `const Widget&`, `auto x` | Initializes an object or reference using exact-match conversions; the identifier may be omitted. |
| Decomposition | `[0, auto y]` | Decomposes its subject and applies nested patterns to its components. |
| Alternative | `{ int value }`, `{ .error: Error& error }`, `{}` | Selects an advertised alternative and, when present, applies a nested pattern to its projection. |
| Or | `0 || 1`, `[0, int x] || [int x, 0]` | Matches the first successful alternative against the same subject. |

Decomposition and alternative patterns provide new subjects to their nested
patterns. The other patterns do not need to know where their subject came
from. This is the basic composition model.

The list is intentionally small. It is based on implementation experience,
committee feedback, production C++, and related papers such as
[@P2392R3]{.title}, [@P3332R0]{.title}, and [@P3619R1]{.title}.

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

# Examples from Real-World C++

We looked through pinned revisions of
[Chromium](https://github.com/chromium/chromium/tree/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5)
and [LLVM](https://github.com/llvm/llvm-project/tree/52a463254a82be0bcd75f0b7cbfe4728e31c1b26)
to see what pattern matching code looks like in practice. This covered about
13.29 million lines in 72,503 non-test Chromium files and 6.50 million lines in
12,366 non-test LLVM files.

The examples below were picked to show different parts of the design. They are
not meant to suggest that every `visit`, `if`, or `switch` should be rewritten,
and the rewrites have not been submitted to those projects.

## Basic Examples

Let's start with a few small examples.

### Nullable alternatives

Chromium's `StringViewOrString::get()` selects between an optional owned string
and a fallback view
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/base/base64url.cc#L27-L41)):

::: cmptable

### Existing C++
```cpp
std::string_view get() const {
  if (str_) {
    return *str_;
  }
  return piece_;
}
```

### With pattern matching
```cpp
std::string_view get() const {
  return match (str_) {
    case { auto& str } => str;
    case {} => piece_;
  };
}
```

:::

The same pattern applies to pointers. `GetWindowPropertyAsWindow()` selects
between a projected window and a sentinel
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/ui/gfx/x/connection.cc#L94-L99)):

::: cmptable

### Existing C++
```cpp
if (const Window* wm_window = PropertyCache::GetAs<Window>(value)) {
  return *wm_window;
}
return Window::None;
```

### With pattern matching
```cpp
return match (PropertyCache::GetAs<Window>(value)) {
  case { const Window& wm_window } => wm_window;
  case {} => Window::None;
};
```

:::

The existing code is already concise. These examples mainly show that `{ P }`
and `{}` work the same way for `optional` and pointer-like types.

## Closed Alternative Dispatch

Chromium commonly uses `absl::Overload` to construct a visitor with one lambda
for each alternative. The survey found 284 such calls. A compact example is
`EnterpriseCompanionStatus::code()`
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/chrome/enterprise_companion/enterprise_companion_status.h#L80-L85)):

::: cmptable

### Existing C++
```cpp
return std::visit(
    absl::Overload{[](std::monostate) { return 0; },
                   [](const PersistedError& error) { return error.code; },
                   [](auto&& value) { return static_cast<int>(value); }},
    status_variant_);
```

### With pattern matching
```cpp
return match (status_variant_) {
  case { std::monostate } => 0;
  case { const PersistedError& error } => error.code;
  case { auto&& value } => static_cast<int>(value);
};
```

:::

This is only modestly shorter, but the alternatives and their declarations are
visible without constructing an overload object. A larger
[WebNN model-editor example](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/services/webnn/ort/model_editor.cc#L223-L270)
contains six explicit overloads with the same structure.

A second common visitor form recovers the active type inside a generic lambda.
LLVM serializes a closed artifact variant this way, dispatching through an
`if constexpr` chain and using a final `static_assert` to enforce coverage
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/clang/lib/ScalableStaticAnalysis/Core/Serialization/JSONFormat/Artifact.cpp#L188-L208)):

::: cmptable

### Existing C++
```cpp
return std::visit(
    [&](const auto& encoding) -> llvm::Error {
      using T = std::decay_t<decltype(encoding)>;
      if constexpr (std::is_same_v<T, TUSummaryEncoding>) {
        return writeTUSummaryEncoding(encoding, path);
      } else if constexpr (std::is_same_v<T, LUSummaryEncoding>) {
        return writeLUSummaryEncoding(encoding, path);
      } else if constexpr (std::is_same_v<T, StaticLibrary>) {
        return writeStaticLibrary(encoding, path);
      } else if constexpr (std::is_same_v<T, MultiArchStaticLibrary>) {
        return writeMultiArchStaticLibrary(encoding, path);
      } else {
        static_assert(std::is_same_v<T, MultiArchSharedLibrary>);
        return writeMultiArchSharedLibrary(encoding, path);
      }
    },
    artifact);
```

### With pattern matching
```cpp
return match (artifact) -> llvm::Error {
  case { const TUSummaryEncoding& encoding }
    => writeTUSummaryEncoding(encoding, path);
  case { const LUSummaryEncoding& encoding }
    => writeLUSummaryEncoding(encoding, path);
  case { const StaticLibrary& encoding }
    => writeStaticLibrary(encoding, path);
  case { const MultiArchStaticLibrary& encoding }
    => writeMultiArchStaticLibrary(encoding, path);
  case { const MultiArchSharedLibrary& encoding }
    => writeMultiArchSharedLibrary(encoding, path);
};
```

:::

The alternative patterns perform the selection and the declarations perform
the initialization. Exhaustiveness checking replaces the manually maintained
assertion in the final branch.

## Compile-Time Selection

The examples above use `if constexpr` to recover the active type of a runtime
choice. There is another important use of `if constexpr`: selecting behavior
from an explicit compile-time value while the selected branch operates on
unrelated runtime state. This is the use case for `match constexpr`.

A lexical scan found the following source lines. Chromium excludes
`third_party` and build output; the LLVM count covers Clang, LLVM, LLD, LLDB,
MLIR, libc++, and libc. Tests are included in both counts.

| Corpus | Files containing `if constexpr` | `if constexpr` lines | `else if constexpr` lines |
|---|---:|---:|---:|
| Chromium | 262 | 756 | 144 |
| LLVM family | 829 | 2,826 | 492 |

These are lexical counts, not counts of distinct chains. They establish that
the idiom is common but substantially overstate the opportunity for
`match constexpr`.

Chromium's `FindOrNull` selects one of three accessors using an enum non-type
template parameter. Each branch returns a different pointer type
([source](https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/content/browser/web_package/signed_exchange_signature_header_field.cc#24)):

::: cmptable

### Existing C++
```cpp
template <Item::ItemType kType>
auto* FindOrNull(
    net::structured_headers::ParameterisedIdentifier::Parameters& params,
    std::string_view key) {
  auto* value = base::FindOrNull(params, key);

  if constexpr (kType == Item::kStringType) {
    return value ? value->GetIfString() : nullptr;
  } else if constexpr (kType == Item::kIntegerType) {
    return value ? value->GetIfInteger() : nullptr;
  } else if constexpr (kType == Item::kByteSequenceType) {
    return value ? value->GetIfByteSequence() : nullptr;
  } else {
    static_assert(false, "add branch for kType");
  }
}
```

### With pattern matching
```cpp
template <Item::ItemType kType>
auto* FindOrNull(
    net::structured_headers::ParameterisedIdentifier::Parameters& params,
    std::string_view key) {
  auto* value = base::FindOrNull(params, key);

  return match constexpr (kType) {
    case Item::kStringType =>
      value ? value->GetIfString() : nullptr;
    case Item::kIntegerType =>
      value ? value->GetIfInteger() : nullptr;
    case Item::kByteSequenceType =>
      value ? value->GetIfByteSequence() : nullptr;
    case _ => static_assert(false, "add branch for kType");
  };
}
```

:::

Only the selected handler participates in return-type deduction. The runtime
lookup of `value` still happens normally; `constexpr` applies to selection,
not to every expression in the selected handler.

LLVM libc has a larger version of the same pattern. Its VDSO dispatcher maps
an enum non-type template parameter to one of ten distinct function-pointer
types
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/libc/src/__support/OSUtil/linux/vdso_sym.h#L42-L68)):

::: cmptable

### Existing C++
```cpp
template <VDSOSym sym>
constexpr auto dispatcher() {
  if constexpr (sym == VDSOSym::ClockGetTime)
    return static_cast<int (*)(clockid_t, timespec*)>(nullptr);
  else if constexpr (sym == VDSOSym::ClockGetTime64)
    return static_cast<int (*)(clockid_t, __kernel_timespec*)>(nullptr);
  else if constexpr (sym == VDSOSym::GetTimeOfDay)
    return static_cast<int (*)(timeval*, timezone*)>(nullptr);
  // ... seven more VDSO symbols ...
  else
    return static_cast<void*>(nullptr);
}
```

### With pattern matching
```cpp
template <VDSOSym sym>
constexpr auto dispatcher() {
  return match constexpr (sym) {
    case VDSOSym::ClockGetTime =>
      static_cast<int (*)(clockid_t, timespec*)>(nullptr);
    case VDSOSym::ClockGetTime64 =>
      static_cast<int (*)(clockid_t, __kernel_timespec*)>(nullptr);
    case VDSOSym::GetTimeOfDay =>
      static_cast<int (*)(timeval*, timezone*)>(nullptr);
    // ... seven more VDSO symbols ...
    case _ => static_cast<void*>(nullptr);
  };
}
```

:::

Two other LLVM examples illustrate the same model:

- [`llvm::byteswap`](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/include/llvm/ADT/bit.h#L100-L145)
  selects implementations for `sizeof(T)` equal to 1, 2, 4, or 8 while
  operating on the runtime value `V`.
- Clang's
  [`getFunctionDeclAbbrev`](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/clang/lib/Serialization/ASTWriterDecl.cpp#L2436-L2481)
  selects among six `FunctionDecl::TemplatedKind` values while appending to a
  runtime `BitCodeAbbrev` object.

These examples also show the limit of the feature. Many `if constexpr` chains
are ordered `requires` probes, overlapping or negated concepts, threshold
tests, or pure dispatch on a type with no value subject. Those do not naturally
become the value-oriented `match constexpr` proposed here. A chain over the
static type of a runtime value can sometimes become an ordinary dependent
match, while pure type dispatch is better addressed by the future type-subject
form discussed in [Static Type Subjects].

## Value Patterns Within an Alternative

Chromium's `OverlayLayerId::ToString` uses a generic visitor, recovers the
active type with `decltype`, and then performs a nested value switch
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/ui/gfx/overlay_layer_id.cc#L71-L103)):

::: cmptable

### Existing C++
```cpp
std::visit(
    [&](auto&& arg) {
      using T = std::decay_t<decltype(arg)>;

      if constexpr (std::is_same_v<T, VizInternalId>) {
        switch (arg) {
          case VizInternalId::kOsCompositorRoot:
            out << "OsCompositorRoot";
            break;
          case VizInternalId::kDelegatedInkTrail:
            out << "DelegatedInkTrail";
            break;
          case VizInternalId::kBackgroundColorLayer:
            out << "kBackgroundColorLayer";
            break;
        }
      }

      if constexpr (std::is_same_v<
                        T, std::array<uint8_t, sizeof(RenderPassId)>>) {
        out << "RenderPass(" << base::U64FromNativeEndian(arg) << ")";
      }

      if constexpr (std::is_same_v<T, RendererLayer>) {
        out << arg.layer_namespace_id.first << ":"
            << arg.layer_namespace_id.second << ":" << arg.layer_id << "."
            << arg.sqs_z_order;
      }
    },
    impl_);
```

### With pattern matching
```cpp
match (impl_) {
  case { VizInternalId::kOsCompositorRoot } => out << "OsCompositorRoot";
  case { VizInternalId::kDelegatedInkTrail } => out << "DelegatedInkTrail";
  case { VizInternalId::kBackgroundColorLayer } =>
    out << "kBackgroundColorLayer";
  case { const std::array<uint8_t, sizeof(RenderPassId)>& bytes } =>
    out << "RenderPass(" << base::U64FromNativeEndian(bytes) << ")";
  case { const RendererLayer& layer } =>
    out << layer.layer_namespace_id.first << ":"
        << layer.layer_namespace_id.second << ":" << layer.layer_id << "."
        << layer.sqs_z_order;
};
```

:::

Here the value patterns match values within one alternative, and the
declaration patterns bind the other alternatives. We no longer need a visitor
whose first operation is another dispatch.

## One Value Pattern Across Alternatives

The following example is representative of numeric telemetry stored in a
closed alternative type:

```cpp
using MetricValue =
    variant<int16_t, int32_t, int64_t, float, double>;

return ranges::all_of(metrics, [](const auto& item) {
  return std::visit(
      [](auto value) { return value == 0; },
      item.second);
});
```

One value pattern can be applied to every projected alternative for which the
comparison is viable:

```cpp
return ranges::all_of(metrics, [](const auto& item) {
  return match (item.second) {
    case { 0 } => true;
    case _ => false;
  };
});
```

The braces project the alternative, and `0` independently describes what must
match. This is one of the important reasons these need to be separate patterns.

## Named Result Alternatives

Chromium uses `base::expected` extensively. Session construction tests each
result, projects either its value or error, and may return from the enclosing
function
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/net/device_bound_sessions/session.cc#L204-L212)):

::: cmptable

### Existing C++
```cpp
for (const auto& cred : params.credentials) {
  base::expected<CookieCraving, SessionError> craving = CookieCraving::Create(
      params.fetcher_url, cred.name, cred.attributes, base::Time::Now());
  if (craving.has_value()) {
    session->cookie_cravings_.push_back(craving.value());
  } else {
    return base::unexpected(SessionError{std::move(craving.error())});
  }
}
```

### With pattern matching
```cpp
for (const auto& cred : params.credentials) {
  base::expected<CookieCraving, SessionError> craving = CookieCraving::Create(
      params.fetcher_url, cred.name, cred.attributes, base::Time::Now());
  match (craving) {
    case { .value: const CookieCraving& value } =>
      session->cookie_cravings_.push_back(value);
    case { .error: SessionError& error } =>
      return base::unexpected(SessionError{std::move(error)});
  };
}
```

:::

Named alternatives preserve the distinction between value and error even when
the two types are the same. The handler can also return directly from the
enclosing function rather than from a visitor lambda.

## Pattern conditions

LLVM's object-size analysis first obtains an optional `APInt` and then asks
whether that value can be represented as a `uint64_t`
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/Analysis/MemoryBuiltins.cpp#L627-L632)):

::: cmptable

### Existing C++
```cpp
if (optional<APInt> size = getAllocSize(call, TLI)) {
  if (optional<uint64_t> extended = size->tryZExtValue())
    return TypeSize::getFixed(*extended);
}
```

### With pattern matching
```cpp
if (case { const APInt& size } = getAllocSize(call, TLI) &&
    case { uint64_t extended } = size.tryZExtValue())
  return TypeSize::getFixed(extended);
```

:::

The second computation needs the name introduced by the first. Conjoined
pattern conditions express this without adding another level of control flow.

## Product and Value Matching

LLVM's X86 intrinsic upgrader contains a decision table over vector width,
element width, and whether the element type is floating point
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/IR/AutoUpgrade.cpp#L2434-L2478)):

::: cmptable

### Existing C++
```cpp
if (vectorWidth == 128 && elementWidth == 32 && isFloat)
  intrinsic = Intrinsic::x86_avx512_vpermi2var_ps_128;
else if (vectorWidth == 128 && elementWidth == 32 && !isFloat)
  intrinsic = Intrinsic::x86_avx512_vpermi2var_d_128;
else if (vectorWidth == 128 && elementWidth == 64 && isFloat)
  intrinsic = Intrinsic::x86_avx512_vpermi2var_pd_128;
else if (vectorWidth == 128 && elementWidth == 64 && !isFloat)
  intrinsic = Intrinsic::x86_avx512_vpermi2var_q_128;
// ... the remaining supported combinations ...
else
  llvm_unreachable("Unexpected intrinsic");
```

### With pattern matching
```cpp
match (vectorWidth, elementWidth, isFloat) {
  case [128, 32, true]
    => intrinsic = Intrinsic::x86_avx512_vpermi2var_ps_128;
  case [128, 32, false]
    => intrinsic = Intrinsic::x86_avx512_vpermi2var_d_128;
  case [128, 64, true]
    => intrinsic = Intrinsic::x86_avx512_vpermi2var_pd_128;
  case [128, 64, false]
    => intrinsic = Intrinsic::x86_avx512_vpermi2var_q_128;
  // ... the remaining supported combinations ...
  case _ => llvm_unreachable("Unexpected intrinsic");
};
```

:::

The product pattern turns the `if` chain into a table where all three inputs
are visible in every case. The selection forms the product directly without
constructing or naming a library tuple.

## Recursive Composition and Enclosing Control Flow

Chromium's HLS parser handles a parse result, distinguishes a line-item
alternative, applies further value tests, and may `break`, `continue`, or
return from the enclosing parser
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/media/formats/hls/media_playlist.cc#L120-L151)):

::: cmptable

### Existing C++
```cpp
while (true) {
  auto item_result = GetNextLineItem(&src_iter);
  if (!item_result.has_value()) {
    auto error = std::move(item_result).error();
    if (error.code() == ParseStatusCode::kReachedEOF)
      break;
    return std::move(error);
  }

  auto item = std::move(item_result).value();
  if (auto* tag = std::get_if<TagItem>(&item)) {
    if (!tag->GetName().has_value()) {
      HandleUnknownTag(*tag);
      continue;
    }
    // Dispatch on the tag kind and tag name.
  }
}
```

### With pattern matching
```cpp
while (true) {
  match (GetNextLineItem(&src_iter)) {
    case { .error: const auto& error }
        if (error.code() == ParseStatusCode::kReachedEOF) => break;
    case { .error: auto error } => return error;
    case { .value: { TagItem: auto&& tag } }
        if (!tag.GetName().has_value()) => do {
      HandleUnknownTag(tag);
      continue;
    };
    case { .value: { TagItem: auto&& tag } } => do {
      // Dispatch on the tag kind and tag name.
    };
    case _ => ;
  };
}
```

:::

This example puts named result states, a nested `variant`, guards, and
enclosing control flow in one place. It is more than a shorter spelling for one
of the individual tests.

## Open Runtime Refinement

Chromium's Blink renderer uses its own `DynamicTo<T>` protocol instead of C++
RTTI. CSS pseudo-class handling contains a five-way ordered refinement
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/third_party/blink/renderer/core/css/selector_checker.cc#L2999-L3021)):

::: cmptable

### Existing C++
```cpp
if (auto* dialog = DynamicTo<HTMLDialogElement>(element)) {
  return dialog->FastHasAttribute(html_names::kOpenAttr);
} else if (auto* details = DynamicTo<HTMLDetailsElement>(element)) {
  return details->FastHasAttribute(html_names::kOpenAttr);
} else if (auto* select = DynamicTo<HTMLSelectElement>(element)) {
  return select->PopupIsVisible();
} else if (auto* input = DynamicTo<HTMLInputElement>(element)) {
  return input->IsPickerVisible();
} else if (auto* menuitem = DynamicTo<HTMLMenuItemElement>(element)) {
  return menuitem->IsSubmenuOpen();
}
return false;
```

### With pattern matching
```cpp
return match (element) {
  case { HTMLDialogElement: auto& dialog } =>
    dialog.FastHasAttribute(html_names::kOpenAttr);
  case { HTMLDetailsElement: auto& details } =>
    details.FastHasAttribute(html_names::kOpenAttr);
  case { HTMLSelectElement: auto& select } => select.PopupIsVisible();
  case { HTMLInputElement: auto& input } => input.IsPickerVisible();
  case { HTMLMenuItemElement: auto& menuitem } => menuitem.IsSubmenuOpen();
  case _ => false;
};
```

:::

The survey found 4,313 `DynamicTo` calls and 1,493 `IsA` calls, but no
executable C++ `dynamic_cast` expressions. Supporting open refinement therefore
requires an explicit customization path rather than special treatment only for
C++ RTTI.

## Where `match` Is Not Automatically Clearer

Not every existing dispatch benefits materially. Chromium contains 99 visitors
that apply one generic operation to every alternative. For example, its paint
iterator already expresses one such operation concisely
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/cc/paint/paint_op_buffer_iterator.h#L174-L204)):

```cpp
const PaintOp* get() const {
  return std::visit([](const auto& iter) { return iter.get(); }, iter_);
}
```

The corresponding `match` is comparable rather than clearly better:

```cpp
const PaintOp* get() const {
  return match (iter_) { case { const auto& iter } => iter.get(); };
}
```

The biggest improvements are in code where testing, accessing the value,
binding names, and control flow are currently spread across several constructs.
A visitor that already applies one uniform operation is often fine as-is.

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
match (s) {
  case "foo" => std::print("got foo");
  case "bar" => std::print("got bar");
  case _ => std::print("don't care");
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
match (p) {
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
match (v) {
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
match (v) {
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
};
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

The examples above come from a larger, non-exhaustive survey of production C++.
The same forms showed up repeatedly:

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
};
```

Unlike `switch`, the patterns can be nested inside decomposition and choice
patterns. Unlike a visitor, the cases remain ordered and can be checked for
exhaustiveness.

## Replacing Visitor Ceremony

The following is typical code that turns several variant alternatives into one
result type:

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

An optional value currently requires a test followed by a projection:

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
};
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
  };
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
};
```

The faithful rewrite explicitly covers the rest of the `int` alternative:

```cpp
match (value) {
  case { 0 }   => zero();
  case { int } => ;
  case { _ }   => other();
};
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

The following is an informal grammar. See [](#expr-match) for wording.

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

The R5 patterns that are removed by this paper are retained below and marked as
such until the wording is updated.

## Pattern Specifications

### Wildcard Pattern

> | `_`

A wildcard pattern always matches any *subject*.

```cpp
int v = 42;
match (v) {
    case _ => std::print("ignored");
//  ^  wildcard pattern
};
```

This paper again proposes `_` as the wildcard pattern.
See [Wildcard Pattern Syntax] for further discussion.

- Matching Condition: None

### Declaration and Type Patterns (R6)

> | `@*declaration-pattern*@:`
> | `    @*attribute-specifier-seq~opt~ pattern-type-id pattern-declarator-id~opt~*@`
> | `    @*attribute-specifier-seq~opt~ type-specifier-seq ref-qualifier~opt~*@ [ @*sb-identifier-list*@ ]`
> | `@*pattern-type-id*@:`
> | `    @*type-specifier-seq conversion-declarator~opt~*@`
> | `@*pattern-declarator-id*@:`
> | `    @*identifier attribute-specifier-seq~opt~*@`
> | `    ... @*identifier attribute-specifier-seq~opt~*@`

A declaration pattern is a declaration initialized from the current subject.
We deliberately restrict its declarator. The type portion follows a
*conversion-type-id*, which gives us pointers, references, member pointers,
cv-qualification, attributes, and constrained placeholders without also
admitting parenthesized, function, or array declarators. Structured bindings
have a separate form. Storage-class specifiers such as `static` and
`thread_local` are not allowed.

```cpp
match (value) {
  case Widget object => consume(object);
  case const Widget& reference => inspect(reference);
  case auto&& forwarded => pass(std::forward<decltype(forwarded)>(forwarded));
  case std::integral auto integer => use(integer);
};
```

Only exact-match standard conversion sequences make the pattern applicable.
Once it is applicable, ordinary initialization determines copying, moving,
reference binding, constraints, accessibility, and destruction.

The identifier can be omitted. We call this a type pattern. As with an unnamed
function parameter, omitting the identifier does not suppress initialization:

```cpp
case int
case const Widget&
case auto&&
case std::integral auto
```

`case Widget` therefore initializes and destroys an unnamed `Widget`, just as
`case Widget value` does. A reference type is the non-owning spelling. An
invalid initialization, such as one requiring a deleted copy constructor, is
diagnosed in the same way as the corresponding named declaration pattern.

More complicated function and array types can be named with an alias:

```cpp
using Function = int(double);
using Array = int[4];

case Function* function
case Array& array
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

### Value Pattern

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

### Or-pattern

> | `@*pattern*@ || @*pattern*@`

An or-pattern applies every alternative to the same subject, from left to
right, and succeeds on the first match.

```cpp
match (direction) {
  case Direction::north || Direction::south => vertical();
  case Direction::east || Direction::west => horizontal();
};
```

Because it is a pattern rather than a shorthand for several cases, it composes
recursively. For example, several values can share one choice projection:

```cpp
static bool found_load_reserve(const RISCVInst& inst) {
  return match(inst, case { LR_W || LR_D });
}

match (response) {
  case { .error: timeout || cancelled } => retry();
  case _ => fail();
};
```

The following table compares general pattern composition in ten languages.
"Limited" means that alternatives can share an arm, but do not form a pattern
that can be nested arbitrarily. The table describes P2688R6 for C++; the
current C++ standard does not yet have these pattern operators.

| Language | OR | AND | NOT | Grouping `(P)` |
|---|---|---|---|---|
| Swift | Limited: comma-separated case alternatives | No | No | Yes |
| Rust | Yes, `P1 | P2` | No | No | Yes |
| Scala | Yes, `P1 | P2` | No | No | Yes |
| Haskell | GHC extension: `OrPatterns` | No | No | Yes |
| F# | Yes, `P1 | P2` | Yes, `P1 & P2` | No | Yes |
| OCaml | Yes, `P1 | P2` | No | No | Yes |
| Python | Yes, `P1 | P2` | No | No | Yes |
| Java | Limited: grouped case labels | No | No | No |
| C# | Yes, `P1 or P2` | Yes, `P1 and P2` | Yes, `not P` | Yes |
| C++ (P2688R6) | Yes, `P1 || P2` | No | No | Yes |

Binding rules differ even among the languages with general or-patterns. For
example, some require every alternative to introduce the same names and
types, while others prohibit particular bindings beneath an alternative or a
negation. Standard Haskell has no or-pattern; the entry above refers to GHC's
`OrPatterns` extension. Java's finalized pattern grammar has no general
parenthesized pattern, although earlier switch-pattern previews included one.
Swift obtains the same grouping effect through its recursive tuple-pattern
grammar rather than a separately named parenthesized-pattern production.

In practice, grouping in these languages is mostly needed for two reasons.
Rust, Scala, Haskell, OCaml, and Python use it to control the interaction
between an or-pattern and a whole-value binding, for example Rust's
`value @ (A | B)`, OCaml's `(A | B) as value`, and Python's
`(A as value) | (B as value)`. F# and C# also need it to compose operators of
different precedence, such as `(A | B) & C` and `not (A or B)`. Swift's
parentheses are primarily a consequence of its recursive tuple-pattern
grammar; ordinary grouping is less important in its current pattern language.
This is evidence for retaining grouping before adding C++'s eventual
as-pattern or additional pattern operators, rather than retrofitting it later.

**Why `||`, rather than `|`.** Most of the languages in the table use `|` for
alternation, but `|` already has an important meaning in C++ value patterns. A
conservative lexical survey of production LLVM, Clang, LLD, and LLDB code
found at least 89 single-line `case A | B` labels in 11 files. The same search
found at least 17 labels in six Chromium files. The search excluded tests and
misses qualified and multiline expressions, so these are lower bounds rather
than exact AST counts.

For example, Clang distinguishes two individual header roles from their exact
bitwise combination
([source](https://github.com/llvm/llvm-project/blob/da9625ca5a1517ec21224e3467be3ff250887061/clang/lib/Lex/ModuleMap.cpp#L72-L83)):

```cpp
case PrivateHeader:
  return Module::HK_Private;
case TextualHeader:
  return Module::HK_Textual;
case PrivateHeader | TextualHeader:
  return Module::HK_PrivateTextual;
```

LLDB similarly switches over every useful combination of readable, writable,
and executable permission bits
([source](https://github.com/llvm/llvm-project/blob/da9625ca5a1517ec21224e3467be3ff250887061/lldb/source/Utility/State.cpp#L44-L64)).
Chromium distinguishes two extension states from their combination
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/chrome/browser/extensions/extension_util.cc#L405-L421)):

```cpp
case kDse:
  return DseNtpOverrideType::kDse;
case kNtp:
  return DseNtpOverrideType::kNtp;
case kDse | kNtp:
  return DseNtpOverrideType::kBoth;
```

Bitwise intersections occur as exact case values too, although much less
often. The production scan found two clear LLVM cases and no Chromium cases;
both LLVM cases classify floating-point masks
([source](https://github.com/llvm/llvm-project/blob/da9625ca5a1517ec21224e3467be3ff250887061/llvm/lib/Transforms/InstCombine/InstCombineCalls.cpp#L1054-L1064)):

```cpp
case ~fcZero & ~fcNan:
case ~(fcZero | fcSubnormal) & ~fcNan:
```

Equality tests against values such as `(MemProt::Read | MemProt::Exec)` and
`(kBlock | kStart)` provide additional examples that would naturally become
value patterns. By contrast, the survey found no production `case A && B` or
`case A || B` label in either corpus. The only direct examples were Clang tests
of constant-expression diagnostics.

Using `|` for pattern alternation would therefore make a common C++ spelling
mean the opposite of what it means in an existing `switch`, unless every
combined value were parenthesized. `||` preserves the useful distinction:

```cpp
case Read | Write  => combined_value();
case Read || Write => either_value();
```

The grammar consumes `||` as pattern alternation. Its existing alternative
token `or` has exactly the same grammatical meaning. Parentheses group the
pattern, so matching the result of an ordinary logical-or expression requires
an unambiguous expression spelling:

```cpp
match (value) {
  case first || second => either_pattern();
  case (first || second) => either_pattern_grouped();
  case static_cast<bool>(first || second) => boolean_expression();
};
```

Bitwise `|` remains part of an expression pattern, preserving bitmask
constants. A top-level `&&` is not part of a pattern in this revision and no
and-pattern is proposed. Matching the result of an ordinary logical expression
uses an explicit expression spelling:

```cpp
case bool(first || second) => logical_or_value();
case bool(first && second) => logical_and_value();
```

Every alternative must introduce the same ordered names and pack structure.
The declarations corresponding to one name need not have the same type or
value category. The selected alternative determines those properties, and the
guard and handler are instantiated for each viable alternative:

```cpp
match (pair) {
  case [0, int value] || [int value, 0] => use(value);
};

match (variant) {
  case { int value } || { std::string const& value } => use(value);
};

match (tuple) {
  case [0, auto&& ...values] || [auto&& ...values, 0] =>
    use(values...);
};
```

The second example has separate semantic instantiations in which `value` is
`int` and `std::string const&`, respectively. Exactly one alternative's
declarations are initialized. If its guard fails, matching continues with the
next source arm rather than another alternative of the same or-pattern. A
corresponding pack can contain a different number of declarations after each
alternative is specialized; the pack name and pack position in the binding
interface are what must agree.

### Parenthesized Pattern

> | `( @*pattern*@ )`

A parenthesized pattern groups any pattern. It has the same matching semantics
and introduces the same bindings as its nested pattern.

- Matching Condition: `@*subject*@ match @*pattern*@`

```cpp
match (direction) {
  case (north || south) => vertical();
  case _ => horizontal();
};

match (pair) {
  case ([0, int value]) => use(value);
  case (_) => fallback();
};
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
};
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

### Alternative Pattern (R6)

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
};
```

```cpp
expected<int, Error> result;

match (result) {
  case { .value: int value } => use(value);
  case { .error: Error& error } => report(error);
};
```

```cpp
variant<int, tuple<int, int>, pair<int, int>> value;

match (value) {
  case { int: 0 } => zero();
  case { int: auto integer } => use(integer);
  case { tuple<int, int>: [auto x, auto y] } => use_tuple(x, y);
  case { pair<int, int>: [auto x, auto y] } => use_pair(x, y);
};
```

```cpp
variant<int, long, double> number;

match (number) {
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
  match (x) {
    case 0 => // ...
    case _ => // ...
  }
}
```

In this example, whether `x == 0` is a valid expression is checked at
compile-time. If `x` is a `std::string` for example, the program is ill-formed.

```cpp
void f2(std::string x) {
  match (x) {
    case 0 => // ill-formed
    case _ => // ...
  }
}
```

This behavior is likely to be pretty obvious to folks. But what if `x` were
a templated parameter instead?

```cpp
void f3(auto x) {
  match (x) {
    case 0 => // fine here
    case _ => // ...
  }
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
  match (x) {
    case 0 => // ...
    case 1 => // ...
    case _ => // ...
  }
}
```

## `match constexpr`

```cpp
template <std::size_t I>
const auto& get(const S& s) {
  return match constexpr (I) -> const auto& {
    case 0 => s.foo();
    case 1 => s.bar();
    case _ => static_assert(false);
  };
}
```

:::

# R6 Syntax Details

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

Prefix syntax gives the subject an ordinary expression boundary:

```cpp
match (*pointer) { /* ... */ }
match (object.*member) { /* ... */ }
match (a + b) { /* ... */ }
```

The difficulty is that `match` remains an identifier. It can already name a
type, function, or object. We preserve those programs by recognizing a
selection tentatively. If the tokens do not identify one, the parser returns
to the original `match` token and performs ordinary C++ parsing. Classification
does not build the subject, perform overload resolution, or emit diagnostics.

The normative recognition flow is:

```text
start at `match`
|
+- next token is `constexpr` -> selection
+- next token is not `(`     -> ordinary C++
+- next token is `)` -> ordinary C++
`- scan through the balanced `( ... )`
   |
   +- no matching `)` -> ordinary C++
   `- inspect the token after `)`
      |
      +- `{`
      |  |
      |  +- expression-only context -> selection expression
      |  `- direct statement/declaration context
      |     |
      |     +- body starts with an arm or preamble introducer
      |     |  `- selection statement
      |     +- lookup does not find `match` as a type-name
      |     |  `- selection statement
      |     `- tentatively parse `( ... )` as a declarator
      |        +- declarator     -> ordinary C++
      |        `- not declarator -> selection statement
      |
      +- `->`
      |  |
      |  +- direct statement/declaration context -> ordinary C++
      |  `- expression-only context
      |     |
      |     +- complete valid type-id followed by `{`
      |     |  `- selection expression
      |     `- otherwise -> ordinary C++
      |
      `- anything else -> ordinary C++
```

This is the rule for valid programs. An implementation can recognize more
ill-formed sequences for better diagnostics, but that does not change the
classification of a well-formed program.

A selection requires a subject expression. Empty parentheses therefore select
ordinary C++ immediately, regardless of what follows:

```cpp
match ();
match ()();
match ()->member;
```

An implementation can still recognize a later match-shaped body when
diagnosing an ill-formed construct such as `match () { case _ => 0; }`.

Here "ordinary C++" includes both expressions and declarations:

```cpp
match (value);             // call or declaration
match (value) = 42;        // assignment or declaration
match (value)();           // chained call or declaration
match (value) + 1;         // ordinary expression
match (value)->member;     // ordinary member access
match (value)->function(); // ordinary member call
```

An arrow alone cannot identify a selection because it can begin member access.
In an expression-only context, a prospective result type identifies a
selection only when it is a complete valid *type-id* and the following `{`
completes the selection form:

```cpp
return match (value) -> Result {
  case P => result;
};
```

When the first token after `->` can also begin member access, recognition is
lookup-sensitive. The prospective result type must parse as a complete type-id
using the normal rules for recognizing a type, and the next token must be `{`.
This is important because an identifier following `->` can instead name a
member:

```cpp
match (value)->result; // ordinary member access
```

An unresolved or otherwise invalid type-id does not participate in this core
grammatical decision when its first token could also begin member access. The
ordinary expression parser retains control in that case.

At the start of a statement, a selection has an implicit result type of
`void`, so its grammar does not admit a trailing return type. A `->` following
`match (subject)` therefore selects ordinary C++ under the normative
classification. The token sequence will often still be ill-formed, in which
case an implementation can diagnose it as an attempted selection statement.

Thus these declarations retain their existing meaning:

```cpp
struct match { match (int); };

match object(0);
match (object) { 0 };
```

while these are selections:

```cpp
match (value) { case _ => consume(value); }
match (value + 1) { case _ => consume(value); }
match (value) { [[likely]] case _ => consume(value); }
```

A single `[` after the opening brace does not identify a selection because it
can begin a lambda in a braced initializer:

```cpp
match (callback) { [] { return 1; }() }; // declaration
```

Two consecutive `[` tokens do identify a selection arm attribute. The parser
does not need to parse or validate the attribute before making this decision.
Consequently, a malformed arm attribute is diagnosed as an attribute in a
match body rather than causing fallback to declaration parsing.

The deciding token can be arbitrarily far away. This is not new for C++:
declaration-versus-expression disambiguation already has the same property.
For example, these cannot be distinguished until the parser has traversed the
parenthesized declarator or expression and inspected the following token:

```cpp
T (*****x) = y;   // declaration: x has five pointer levels
T (*****x) == y;  // expression: five dereferences, then comparison
```

The mechanisms are not identical. Ordinary C++ performs a grammar-directed
tentative declarator parse. The prototype first scans over the balanced subject
and inspects what follows, then restores the parser to `match` and parses the
chosen grammar. Deeply nested selections can therefore cause repeated scanning
in the prototype. This is an implementation issue, not an inherent requirement;
a production parser can cache matching delimiters.

### Existing uses of `match`

We surveyed production C++ sources in Chromium and the LLVM monorepo to
estimate how often the difficult parsing paths arise. Tests and vendored code
were excluded when counting declarations. Symbols were classified with
Universal Ctags, and the relevant token sequences were checked separately with
a balanced-parenthesis search.

The exact lowercase identifier `match` is common, but its uses are distributed
very unevenly:

| | Chromium | LLVM |
|---|---:|---:|
| Types named `match` | 0 | 0 |
| Macros named `match` | 0 | 0 |
| Namespace-level `match` overloads | 0 | approximately 11 |
| Distinct member-function signatures named `match` | a handful | approximately 374 |
| Local variables named `match` | at least 267 | 67 |
| Parameters named `match` | at least 422 | 23 |
| Ordinary `match (...) ->` token sequences | 0 | 0 |
| Code-token `match (...) {` candidates before contextual classification | 1 | 172 |
| Ordinary `match (...) { ... }` statements or expressions | 0 | 0 |

LLVM's function count is not hundreds of unrelated public APIs. Most are the
uniform `match` operations of matcher implementations: the Itanium demangler,
IR pattern matching, SelectionDAG and GlobalISel pattern matching, VPlan, and
MLIR matcher classes. There are also namespace-level APIs such as
`llvm::PatternMatch::match`, `clang::ast_matchers::match`, and
`Fortran::evaluate::match::match`. The LLVM sources contain more than 200
`using namespace PatternMatch` directives, so unqualified ordinary calls to
`match` are widespread. Member functions also matter because they can be
called unqualified from within their class.

Chromium instead uses `match` predominantly as a domain variable or parameter,
particularly for `AutocompleteMatch`. It has only a handful of member
accessors named `match`, including shared-dictionary accessors and an Omnibox
view accessor.

The token-sequence results are more important for the grammar than the raw
identifier counts. A balanced-parenthesis scan found 172 non-test LLVM
code-token sequences in which `match (...)` is immediately followed by `{`.
Every one is a function definition, where the parser is already in a
declaration. Chromium had one code-token occurrence, a constructor member
initializer of the form `..., match (value) {}`. It is likewise outside a
statement or expression context. Comment-only matches were discarded.

We therefore found no existing production statement or expression with the
selection-shaped `match (subject) { ... }` syntax. We also found no production
occurrence of `match (...) ->` at all, with or without whitespace before the
arrow. LLVM contains four immediate `match (...).member` uses, all querying an
AST matcher result with `size()` or `empty()`; these do not interact with the
trailing-result-type syntax.

The survey suggests that normal code will almost always be classified by the
token following the balanced subject and by ordinary lookup of `match`. In
particular, the statement-level tentative declarator path is entered only when
`match` names a type, a case absent from both production codebases. The lookup
and candidate-preservation rules remain necessary for correctness and useful
diagnostics, especially in LLVM scopes containing `match` functions, but the
most difficult ambiguities appear to be rare in practice.

### Diagnostic recovery

The prototype uses one tentative classifier. Its core branches implement the
rule above. Additional branches classify some ill-formed sequences as
selections solely to obtain better diagnostics. Either way, the classifier
restores the parser to the original `match` token before the real parse begins.

The relevant diagnostic branches within that classifier are:

```text
tentatively classify the construct beginning at `match`
|
+- a valid selection is recognized
|  `- return Match
|
+- `match` is followed by neither `constexpr` nor `(`
|  |
|  +- `match:` is a label                              -> return Ordinary
|  +- `<` can begin an explicit-template-argument call -> return Ordinary
|  +- ordinary lookup finds an entity named `match`    -> return Ordinary
|  +- lookup is dependent                              -> return Ordinary
|  `- ordinary lookup finds nothing
|     `- return Match with a missing-parentheses diagnostic marker
|
+- declaration-shaped `match ( ... ) { ... }` wins
|  |
|  +- no top-level `=>` -> return Ordinary
|  `- top-level `=>` suggests an omitted `case`
|     `- return Ordinary with a missing-`case` diagnostic marker
|
`- possible `match ( ... ) -> ...`
   |
   +- a complete valid type-id is followed by `{`
   |  `- return Match
   |
   +- the token after `->` can begin a type-id but not member access
   |  `- return Match for diagnostics
   |
   +- tentatively run the real trailing-return-type parser with normal
   |  recovery and typo correction
   |  +- parser stops immediately before a top-level `{`
   |  |  `- return Match for diagnostics
   |  `- otherwise -> rewind that probe
   |
   `- tentatively parse the call arguments and probe lookup
      |
      +- the arguments are invalid                          -> return Ordinary
      +- ordinary lookup finds any entity named `match`    -> return Ordinary
      +- the call is dependent                              -> return Ordinary
      +- ADL finds any candidate                            -> return Ordinary
      `- non-dependent lookup and ADL find no candidate
         `- return Match for diagnostics
```

After rollback, Match causes the real selection parser to run from the original
token and emit diagnostics normally. Ordinary causes the normal C++ parser to
run from the original token. The missing-`case` marker does not change that
classification or reinterpret the construct as a selection. It is additional
lookahead for a richer diagnostic. The statement parser emits that diagnostic
and then skips the malformed declaration-shaped construct for ordinary error
synchronization rather than producing a cascade of declaration diagnostics.

The missing-parentheses branch likewise changes only the handling of an
otherwise ill-formed program. Without an ordinary declaration named `match`, a
bare unqualified `match` cannot be a valid id-expression. The real selection
parser diagnoses `expected '(' after 'match'`, parses the following expression
as the subject, and consumes a following match body for synchronization. It
does not tentatively parse that expression during classification. Explicit
template arguments are kept ordinary because `match<T>(value)` can find
`match` through dependent ADL even when ordinary lookup initially finds
nothing.

This requires a dedicated missing-parentheses recovery mode in the selection
parser. Merely invoking the ordinary selection parser would diagnose the
missing `(` and return immediately, leaving the intended subject and arm body
to be parsed as unrelated statements. For example:

```cpp
match value {
  case _ => consume(value);
}
```

The dedicated mode still diagnoses the program as ill-formed, but then treats
`value` as the intended subject and consumes the braced selection body. This
avoids secondary diagnostics such as a missing semicolon after `value` or an
undeclared `_`. It is error recovery, not an alternative grammar that permits
unparenthesized subjects.

Syntax that can begin a type-id but cannot begin a member name does not need a
recovery probe. The implementation can run the selection parser directly and
obtain its normal type or missing-body diagnostic. This covers `auto`,
`decltype`, `typename`, cv-qualifiers, and built-in type specifiers.

For the remaining identifier-like syntax, the next recovery step uses the real
trailing-return-type parser rather than another approximation of the type-id
grammar. Its diagnostics are suppressed and its parser and typo-correction
state are restored afterward. If normal type recovery leaves the current token
at `{`, the implementation runs the selection parser from the original `match`
token. The selection parser then emits the ordinary type diagnostic, including
typo correction and missing `typename` suggestions, and continues parsing the
body. The `{` is sufficient; its contents do not need to begin with `case` or
an attribute.

This is not a scan for a later brace. The type parser itself must consume the
would-be result type and leave the immediately following top-level token at
`{`. For example, this step handles both syntax that unambiguously begins a
type-id and an unresolved identifier that can be recovered as a type:

```cpp
return match (value) -> typename T::result_type {
  case _ => 0;
};

return match (value) -> UnknownResult {
  case _ => 0;
};
```

The direct type-only check preserves a focused missing-body diagnostic for
cases such as:

```cpp
return match (value) -> int;
// error: expected '{' after match result type
```

The remaining cases begin with identifier-like syntax that can denote either a
type or a member. The implementation then asks only whether the ordinary
`match (subject)` prefix has an ordinary meaning. It does not require the call or
construction to be valid. "Any entity" found by ordinary lookup includes a
type, class template, function, function template, callable object, and a
non-callable value. Similarly, any ADL candidate preserves the ordinary
interpretation even when it is non-viable, ambiguous, deleted, inaccessible, or
has unsatisfied constraints. This keeps the normal C++ diagnostics for:

```cpp
match (value)->misspelled_member;
match (value)->private_member;
match (value)->function(bad_argument);
```

At the start of a statement, the same reasoning permits an implementation to
diagnose an apparent trailing return type as part of an attempted selection
statement. A selection statement has an implicit `-> void`, so the diagnostic
does not need to depend on whether the recovered type-id ultimately resolves:

```cpp
match (value) -> const UnknownResult& {
  case _ =>;
} // error: match statement cannot have an explicit result type
```

An unresolved identifier followed by `{` also receives focused diagnostic
recovery. Although the identifier can name a member, an ordinary member-access
expression cannot be followed directly by a brace:

```cpp
return match (value) -> UnknownResult {
  case _ => 0;
}; // error: unknown type name 'UnknownResult'
```

If ordinary lookup finds nothing, a dependent call is initially retained as
ordinary C++ because ADL remains deferred. The dependent AST retains that the
call appeared directly before the prospective result type. At instantiation,
candidate collection makes the same decision without reparsing: any ordinary or
ADL candidate preserves the normal call diagnostic, while an empty candidate
set produces the missing-selection-body diagnostic. For a non-dependent call,
candidate collection is sufficient immediately; overload resolution does not
need to select a viable candidate.

If the subject itself is invalid, ordinary parsing is retained. Both
interpretations would diagnose the subject, and its invalidity prevents the
implementation from reliably determining what ADL would have found.

The resulting diagnostic choices include:

| Source | Interpretation and diagnostic |
|---|---|
| `return match (x) -> UnknownResult { case _ => 0; };` | The recovering type parser reaches `{`; diagnose the unknown result type as part of a selection. |
| `return match (x) -> voctor<int> { case _ => 0; };` | The recovering type parser reaches `{`; perform normal type-name typo correction, such as suggesting `vector`. |
| `return match (x) -> vector<T::value_type> { case _ => 0; };` | The recovering type parser reaches `{`; issue the normal missing-`typename` diagnostic. |
| `return match (x) -> int;` | `int` cannot begin member access; diagnose the missing selection body. |
| `return match (x) -> Result;` with no ordinary meaning for `match` | Candidate collection finds nothing; parse as a selection and diagnose the missing body. |
| `Node* match (int); return match (x)->missing;` | Ordinary lookup finds `match`; issue the normal missing-member diagnostic. |
| `Node* match (int); return match ("wrong")->value;` | Ordinary lookup finds `match`; issue the normal no-matching-function diagnostic. |
| `Node* match (Key) = delete; return match (key)->value;` | ADL or ordinary lookup finds the deleted candidate; issue the normal deleted-call diagnostic. |
| `template<class T> auto f(T x) { return match (x)->value; }` | The call is dependent and ADL is deferred; retain ordinary C++ parsing until instantiation. If candidate collection is then empty, diagnose the missing selection body. |
| `return match (unknown)->Result;` | The subject is invalid; retain the useful undeclared-identifier diagnostic for `unknown`. |

The presence of an ordinary candidate, rather than call viability, is the
important distinction. For example, a non-viable `match (int)` still proves
that `match ("wrong")` was plausibly intended as an ordinary call. Conversely,
when no declaration and no ADL candidate exists, interpreting the identifier
after `->` as an attempted selection result type generally gives the more
useful diagnostic.

For example:

```cpp
return match (value) -> vocter<Foo> {
  case _ => 0;
};
// error: 'vocter<Foo>' does not name a type
// note: a selection result following '->' must be a type-id
```

If `match (value)` has no ordinary lookup or ADL candidate, the ordinary
interpretation has been ruled out without asking whether any overload is
viable. The implementation can therefore diagnose the prospective result type
directly. This reasoning does not apply to a dependent call for which ADL is
deferred until instantiation, or when ordinary parsing failed for an unrelated
reason such as an invalid argument expression.

This strategy does not scan farther forward merely looking for a brace. The
prefix can still be a valid member-access expression, and a later brace can
belong to another operand:

```cpp
return match (value)->member + [] {
  [[maybe_unused]] int local = 1;
  return 1;
}();
```

Merely finding such a later `{`, even one beginning with `[[`, is insufficient.

Omitting `case` presents one diagnostic problem when `match` names a type:

```cpp
struct match { match (int); };

match (value) {
  _ => 0; // intended selection statement, but declaration parsing wins
}
```

The `=>` token does not participate in grammatical disambiguation and the
construct is not reparsed as a selection. An implementation can nevertheless
use a top-level `=>` encountered while diagnosing the invalid declaration as
evidence for a focused missing-`case` diagnostic and fix-it. The prototype
limits this diagnostic probe to the first top-level `,`, `;`, or `}` and skips
nested delimiters.

Without that diagnostic, ordinary declaration parsing reports a vexing parse,
a redefinition of `value`, an undeclared `_`, and a missing semicolon. The
focused diagnostic is instead:

```text
error: expected 'case' before pattern
  _ => 0;
  ^
  case
note: 'match' names a type, so this construct is otherwise parsed as a declaration
```

This is diagnostic lookahead only. It does not change which grammar was
selected or construct a selection AST. Skipping the malformed construct after
the diagnostic is ordinary parser error synchronization.

Some omissions are inherently indistinguishable from ordinary C++:

```cpp
match (value);          // call, or a selection with its body omitted?
match (value)->result;  // member access, or a misspelled result type?
```

In particular, lookup cannot identify the second line as an attempted result
type. The identifier after `->` is looked up as a member of the call's result,
not by unqualified lookup in the surrounding scope, and that member lookup can
be dependent. Even an identifier known to denote a type in the surrounding
scope can also be a member name here. Syntax that cannot begin member access,
such as a built-in type keyword, can be diagnosed as an attempted match result
missing `{`; an identifier cannot. Match-specific diagnostics are otherwise
available only after a match-specific token sequence has been seen.

In an expression-only context, `match (subject) {` is always a selection
expression, regardless of whether `match` also names a type or function. At
the start of a statement, it is a selection statement with an implicit
`-> void`. Parentheses can force the expression interpretation when needed:

```cpp
(void)match (value) -> int {
  case 0 => 1;
  case _ => 2;
};
```

The single-pattern test uses the same prefix form. A top-level comma followed
by `case` separates the complete subject list from the pattern, and the closing
parenthesis separates the pattern from the surrounding expression:

```cpp
match(value, case a * b)   // expression pattern `a * b`
match(value, case T * x)   // declaration pattern `T* x`, if `T` names a type
match(value, case a) * b   // multiplication outside the match
```

This removes the operator-precedence rule required by the postfix spelling.
It also extends naturally to multiple subjects:

```cpp
match(first, second, case [P, Q])
```

The `case` keyword cannot occur as an ordinary function argument, so the comma
followed by `case` is also a reliable parser discriminator. Commas nested
within a subject expression, such as one in a call or lambda body, do not
participate.

Declaration, type, and expression patterns intentionally occupy one syntactic
position. The design uses these disambiguation rules:

- Pattern-specific introducers commit to pattern grammar. In particular, `_`
  starts a wildcard pattern, `(` starts a parenthesized pattern, `[` starts a
  decomposition pattern, and `{` starts an alternative pattern. `_ + 1`,
  `(x) + 1`, and `[]{}()` are therefore ill-formed as patterns; functional
  casts such as `auto(_ + 1)`, `auto((x) + 1)`, and `auto([]{}())` provide an
  explicit expression spelling.
- A declaration pattern uses a *type-specifier-seq* followed by an optional
  *conversion-declarator* and optional identifier. Consequently `T value`,
  `T* pointer`, and `T&& reference` are declarations, while `T(value)`, `T()`,
  and `auto(value)` are expressions. Lookup determines whether the first name
  is a type; there is no additional declaration-over-expression priority rule.
- A structured-binding declaration is also a declaration pattern. Its opening
  `[` is recognized only after a complete structured-binding decl-specifier
  sequence.
- `[[` is the sole overlapping pattern introducer. It is parsed as an
  attribute when it forms a complete attribute-specifier and the following
  token can continue the surrounding declaration; otherwise it starts nested
  decomposition. Ordinary and pattern structured bindings use the same rule.
- In `case P = E`, the first top-level `=` terminates the pattern.
- In a pattern condition, each ordinary Boolean element and each case subject
  is an *inclusive-or-expression*. A top-level `&&` separates condition
  elements; assignment, conditional expressions, and `||` require
  parentheses.
- Parsing proceeds left-to-right. A later `&& case` does not retroactively
  change an overloaded `operator&&` contained wholly within an earlier ordinary
  expression.

Malformed patterns recover at the case boundary and suppress follow-on
exhaustiveness diagnostics.

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


# Pattern Model

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

## Wildcard and Value Patterns

`_` matches every value in its current domain and introduces no binding.

This is different from a C++26 placeholder variable in a declaration pattern:

```cpp
case _      // ignores the subject; performs no declaration initialization
case auto _ // initializes an unnamed by-value declaration
```

The latter can copy, move, throw, and run a destructor. The wildcard cannot.

A value pattern ordinarily compares its expression with the current subject.
In a selection case the expression must be constant. A single-pattern test or
pattern condition can instead compare with a runtime expression. The
comparison has to be well-formed. When a closed choice advertises that constant
as a state label, the pattern tests the state instead of comparing with the
whole subject:

```cpp
match (value) {
  case 0          => zero();
  case [0, _]     => on_y_axis();
  case { [_, 0] } => on_x_axis_payload();
};
```

Parentheses group patterns. An expression whose leading parentheses would
otherwise select pattern grammar can use an unambiguous expression spelling,
such as a named expression or `static_cast`.

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
};
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
};
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
};
```

Qualification adjustment can intentionally make one earlier case cover several
alternatives:

```cpp
variant<int*, const int*> pointer;

match (pointer) {
  case { const int* value } => inspect(value); // can cover both alternatives
  case { int* value }       => mutate(value);  // error if fully dominated
};
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
  };
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

## Decomposition Patterns

`[P1, P2, ...]` decomposes the current subject using the structured-binding
rules, then matches each component recursively:

```cpp
match (point) {
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
  };
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
  };
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

## Why Polymorphic Refinement Is Not Braced

We considered requiring braces for runtime class refinement:

```cpp
match (shape) {
  case { Circle& circle } => draw(circle);
  case _                  => draw_unknown(shape);
};
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

## Why Pointer Declarations Do Not Refine

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
  };
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
};
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

## Why Choice Projection Is Explicit

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
};
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
};
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
};
```

`{}` matches a state that has no value to project:

```cpp
optional<int> value;

match (value) {
  case { int integer } => use(integer);
  case {}              => empty();
};
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
};
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
};
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
};
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
};
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
};
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
};
```

The spelling that tests before consuming is explicit:

```cpp
match (std::move(value)) {
  case Widget&& candidate if (candidate.satisfies()) =>
      use(Widget(std::move(candidate)));
};
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


# R6 Design Decisions

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

A non-returning expression arm needs to be excluded from result-type deduction:

```cpp
return match (status) -> int {
  case fatal => not return std::terminate();
  case _    => 42;
};
```

We treat this as a handler action, parallel to `return expression`:

```cpp
case done  => return result;
case fatal => not return std::terminate();
```

The `! return expression` syntax follows the `if ! consteval` precedent
established by P1938 [@P1938R3].

The expression is evaluated as a discarded-value expression. If it completes
normally, the behavior is undefined. The handler does not contribute to result
type deduction. We put the action after `=>` because it applies only after the
pattern and guard succeed. Before `case`, it would appear to describe the whole
case even though the pattern or guard can fail.

Spelling the action `[[noreturn]] expression` was considered. The property is
essential to type and control-flow semantics and cannot be safely ignored as an
unknown attribute. That spelling would also open the position to an arbitrary
attribute sequence.

The contextual forms `noreturn expression` and `noreturn(expression)` were
also considered. The latter resembles an ordinary function call; the former
can capture an intended expression such as `noreturn + 1`. Neither issue is a
source-compatibility problem because the enclosing match syntax is new, and a
source survey found no production variable, function, or member named
`noreturn` in Chromium or LLVM. Nevertheless, `not return` is both visibly a
handler action and unambiguous: `return` cannot be the operand of the unary
`!` operator.

Exception-enabled C++ already permits a generic, if contrived, workaround:

```cpp
return match (status) -> int {
  case fatal => throw (std::terminate(), 0);
  case _    => 42;
};
```

The comma expression calls `std::terminate()` and manufactures an exception
operand in the impossible event that it returns. The outer `throw` expression
does not contribute a result type, so the dummy operand is independent of the
selection's result type. The parentheses are essential:
`throw std::terminate(), 0` attempts to throw the `void` result of
`std::terminate()` and is ill-formed. A function-like macro can hide the
construction:

```cpp
#define noreturn(...) throw (static_cast<void>((__VA_ARGS__)), 0)
```

Both throw-based forms are rejected under `-fno-exceptions`, which is a common
configuration for LLVM and Chromium. Without the `throw`,
`(std::terminate(), 0)` contributes `int` to result-type deduction. An
immediately invoked lambda has the same problem: it must manufacture the result
type that the non-returning arm was meant not to provide.

Allowing `throw std::terminate()` would be more compact and would reuse the
existing non-producing role of a throw expression. Today it is ill-formed
because a thrown expression cannot have type `void`. Extending `throw` would
also need to define what happens if the `void` expression completes normally,
and would solve the problem only through a special case for `throw`.

The general diverging-expression model in [@P3549R0] is better: it permits the
direct call without a match-specific action. `not return` is intentionally
provisional so that P2688 remains self-contained while both papers target
C++29. We should remove it if P3549 is adopted in time.

## Why Selection Cases Require `case`

R5 allowed a pattern to begin a case directly. We now require `case`. It gives
the parser a reliable recovery point, distinguishes case attributes from
declaration-pattern attributes, and makes empty and statement handlers easier
to parse. It also leaves more room to extend the pattern grammar later.

It also aligns the selection form with `switch` while retaining source-ordered
pattern semantics.

## Why `_` Is the Wildcard

This paper retains `_` as the wildcard spelling. This follows [@P2392R2] and the broad
language precedent in Python, Rust, Scala, Swift, C#, Erlang, Prolog, Haskell,
OCaml, and others. [@P1371R3] used `__`, following [@P1110R0], while
[@P1469R0] proposed restricting `_` as an identifier in structured bindings.

The wildcard remains distinct from a C++26 placeholder variable:

```cpp
match (value) {
  case _      => ignore_without_initialization();
  case auto _ => initialize_an_unnamed_object();
};
```

The special interpretation means that a bare `_` cannot refer to an outer
variable in pattern position:

```cpp
int _ = 42;

match (value) {
  case _ => always_matches();
};
```

An ordinary expression can still perform that comparison through a guard:

```cpp
match (value) {
  case auto&& current if (current == _) => equal_to_outer_underscore();
  case _ => different();
};
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
};
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
};
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
};
```

If arbitrary conversions were admitted, the `int` declaration could consume a
`double` and make the second case dead. This paper instead uses the exact-match
rank and lets usefulness analysis diagnose domination among the conversions
that remain.

Third, a by-value declaration really copies or moves. `auto value` copies an
lvalue and moves from an rvalue. `auto&& value` is the forwarding spelling. A
guarded declaration cannot invoke a non-trivial move constructor before testing
the guard; bind a reference and move in the handler instead.

## Removed R5 Pattern Forms

R5's `? P` combined nullable testing and dereference. R6 models nullable types
as choices instead, so `{ P }` and `{}` use the same protocol as `variant` and
`expected`.

R5's unbraced `T: P` made variant selection concise, but did not answer whether
`auto` binds the whole object or its payload. R6 spells the recursive operation
`{ T: P }`: braces perform the projection, `T` selects the projected type, and
`P` matches the resulting subject.
Variant supplies `{ .index<I>: P }` as the corresponding escape hatch for
duplicate or otherwise indistinguishable alternative types. This is an
opt-in name, not a facility automatically exposed by every choice protocol.

R6 retains and generalizes the R5 parenthesized pattern. Parentheses group any
pattern rather than serving as an expression-pattern escape.

## Why Projection Is Explicit

It is tempting to let `int value` automatically inspect a
`variant<int, double>`. But then should `[int x, int y]` automatically inspect a
`variant<pair<int, int>, tuple<int, int>>`? More importantly, does
`auto&& value` bind the `variant` or the active alternative?

There is no good answer based only on the declaration. Braces mean "look inside
this choice," after which the nested pattern has its normal meaning. This is
the main syntax cost of the new design.

## Transparent Value Patterns

There is one case where the braces can appear unnecessary:

```cpp
optional<bool> value;

match (value) {
  case true         => yes();
  case false        => no();
  case std::nullopt => empty();
};
```

These three comparisons cover every runtime value of `optional<bool>`.
However, the exhaustiveness checker cannot generally infer that equality on a
wrapper is equivalent to equality on one of its projections. It therefore
does not consider the example exhaustive. The explicit form is:

```cpp
match (value) {
  case { true }     => yes();
  case { false }    => no();
  case std::nullopt => empty();
};
```

We considered letting `alternative_traits` mark an alternative as transparent
to value patterns. For a pattern `P` and state `I`, that opt-in would promise
that `subject == P` is equivalent to:

```cpp
index(subject) == I && get<I>(subject) == P
```

This works for `optional` and for the value state of `expected`. It does not
work for pointers or smart pointers, whose equality compares addresses rather
than pointees. It also does not handle the error state of `expected` without a
more complicated transformation between `unexpected<E>` and `E`.

These examples do not justify another protocol rule. We require the braces and
keep value patterns on their current subject.

## Why First Match Rather Than Overload Resolution

We also considered treating cases as an overload set. That would make order
mostly irrelevant and allow surprising conversions for closed sum types:

```cpp
variant<int, double> value;

match (value) {
  case { int integer } => use(integer);
  case { double real }  => use(real);
};
```

With general conversions, the `int` case could handle both alternatives and
the `double` case would never be selected. Reversing them would not fix the
problem. We use first-match semantics and exact-match conversions.
Exhaustiveness checking diagnoses an unreachable case.

## Why Not One Implicit `as` Operation

[@P2392R3] puts type testing, conversion, and binding behind an `as` spelling.
This looks good in simple examples, but gives one syntax several different
jobs. In particular, conversion-based matching over `variant<int, double>` can
make an `int` case accept a `double` alternative and make the later `double`
case useless.

C# declaration patterns are good precedent for runtime refinement of an
object. C++ also has closed generic sum types whose active value can be handled
without naming its type. A bare declaration cannot mean both "bind this object"
and "bind this object's active alternative."

We separate the operations instead:

```cpp
case int value       // bind the current subject
case { int value }   // project a choice, then bind the result
```

The exact-match restriction prevents ordinary numeric conversions from
silently changing closed-choice dispatch. A class declaration can also refine
a polymorphic class object, as described in
[Why Polymorphic Refinement Is Not Braced]; it still does not enter a choice.

## Why `any` Also Requires Braces

If a bare `int value` could inspect an `any`, an ordinary-looking declaration
would silently perform a type-erased runtime operation. `any`, `variant`, and
user-defined choices all use braces. Polymorphic classes are different because
the derived object is still the same object denoted by the base reference; it
is not a stored payload.

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
  };
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
};
```

It also admits the full condition grammar, including init-statements and
condition declarations, without inventing another unparenthesized expression
boundary. The pattern condition uses a different solution:
top-level `&&` separates later conditions, so it does not accept a case-style
trailing guard.

## Multiple Subjects

Earlier revisions required callers to construct a library product explicitly:

```cpp
match (std::forward_as_tuple(lhs, rhs)) {
  case [P1, P2] => first();
  case [P3, P4] => second();
}
```

The prefix syntax provides a natural boundary for a subject list, so this
revision accepts the direct form:

```cpp
match (lhs, rhs) {
  case [P1, P2] => first();
  case [P3, P4] => second();
}
```

Conceptually, multiple expressions initialize an unnamed in-place product.
Each element refers to its corresponding expression: an lvalue remains an
lvalue, and an xvalue or materialized prvalue is projected as an xvalue. The
product is itself a materialized prvalue and is presented to a whole-subject
pattern as an xvalue. The expressions are each evaluated once, and their
temporaries live through the selection. No tuple protocol or library type is
involved.

This also gives a stable interpretation to pack expansion:

```cpp
template<class... Ts>
constexpr size_t arity(Ts&&... values) {
  return match (std::forward<Ts>(values)...) {
    case [auto&&... elements] => sizeof...(elements);
  };
}
```

The subject remains a product when the pack expands to zero or one element, so
the pattern does not change meaning between instantiations. A source-level
selection still requires at least one expression. An ordinary comma expression
can be selected as one value by retaining its own parentheses:

```cpp
match ((first(), second())) { // one subject: the result of second()
  case P => action();
}
```

A subject is an expression, not a braced-init-list. A typed expression remains
available when list-initialization is useful:

```cpp
match (std::initializer_list{1, 2, 3}) {
  case P => action();
}
```

A `void` expression cannot be a product element because there is no object or
reference for that element to denote. Sequencing a `void` expression before a
subject remains possible with an ordinary parenthesized comma expression.

There is a tooling wrinkle when a pack expands to zero elements. The semantic
specialization contains an empty product even though source-level `match ()` is
not accepted. An AST printer therefore needs to retain enough source-form
information to print the original pack expansion rather than synthesizing an
invalid empty subject list.

Multiple subject expressions are indeterminately sequenced, but their relative
order is unspecified, following function-argument evaluation. Each expression
is still evaluated exactly once before pattern matching begins. The prototype
currently happens to evaluate them from left to right because it forms the
exposition-only product with aggregate list-initialization; programs cannot
depend on that order.

The unnamed product is an exposition-only semantic device. To keep that type
from becoming observable, each top-level case must be a decomposition pattern,
a structured-binding declaration pattern, or a wildcard (possibly
parenthesized or combined with other such patterns using `||`):

```cpp
match (first, second) {
  case [0, int value] => use(value);
  case auto&& [x, y] => use(x, y);
  case _ => use_fallback();
}
```

A declaration such as `auto whole` remains ill-formed at that position. Once
the product has been decomposed, every component accepts the full pattern
grammar. A bit-field presents one representational exception: it cannot
initialize a reference member, so the prototype stores that element by value.

## Expression Boundaries

Both selection and testing use prefix syntax, so neither requires a new
operator-precedence level. In a single-pattern test, `case` marks the transition
from the comma-separated subject list to the pattern, and the closing
parenthesis terminates the pattern. Parentheses give each subject an ordinary
expression boundary; an extra pair retains a comma expression as one subject:

```cpp
match(first, second, case [P, Q]) // two subjects
match((first, second), case P)    // one comma-expression subject
```

The `case` keyword separates the complete subject list from the pattern. The
closing parenthesis then separates the complete pattern from any surrounding
Boolean expression:

```cpp
match(x, case A || B) && ready
```

Here `A || B` is an or-pattern and `&& ready` is outside the test. A logical
expression used as a value pattern remains explicit:

```cpp
match(x, case bool(A || B))
match(x, case bool(A && B))
```

This two-sided delimitation matters because C++ uses `||` for both logical
disjunction and pattern alternation. C# avoids the same ambiguity by using a
pattern-only keyword:

```csharp
value is A or B || ready
```

Here `or` can only combine patterns, while `||` combines Boolean expressions.
C++ cannot make that lexical distinction while spelling an or-pattern `||`.
The corresponding C++ test instead makes the boundary structural:

```cpp
match(value, case A || B) || ready
```

The `||` inside the parentheses belongs to the pattern; the `||` after the
closing parenthesis belongs to the surrounding expression.

Selection needs no additional parentheses around a binary subject:

```cpp
match (a + b) {
  case 0 => zero();
  case _ => nonzero();
}

match (a <=> b) {
  case strong_ordering::less    => less();
  case strong_ordering::equal   => equal();
  case strong_ordering::greater => greater();
}
```

This is one reason to use prefix syntax for multi-arm selection: it avoids
making the common selection form depend on a novel precedence rule, while the
short single-pattern test retains a well-defined place in the expression
grammar.

## Alternatives for a Single-Pattern Test

R5 used a postfix test:

```cpp
value match case P
```

This reads reasonably in isolation and keeps the subject first. It also makes
`match` a binary operator. The language then needs to assign it a precedence,
and the pattern grammar has to decide how greedily to consume operators that
are meaningful both inside and outside a pattern. For example:

```cpp
value match case A || B
value match case A && ready
```

The first line could mean an or-pattern or a logical disjunction whose left
operand is a pattern test. If the pattern consumes greedily, the second line
looks like an and-pattern even though this paper does not propose one. If it
does not, the pattern syntax accepted after `case` differs between a selection
and a test. Parenthesizing either the whole test or the pattern can resolve
individual cases, but does not remove the precedence rule or extend naturally
to several subjects.

C# does not encounter this exact conflict in `value is A or B || ready`:
`or` is part of the pattern grammar and `||` is part of the enclosing
expression grammar. Because this proposal deliberately uses `||` for an
or-pattern, a postfix C++ form cannot make the same distinction from the token
alone.

Dropping `case`, as in `value match P`, makes the boundary less visible and
removes a useful parser recovery point. A parenthesized variation such as
`value match (case P)` makes the right boundary explicit, but retains the
binary-operator and multiple-subject problems. These postfix forms were
therefore not retained in R6.

Once selection itself became prefix, a prefix test was the natural direction.
We considered using the selection body:

```cpp
match (value) { case P }
```

Interpreting this otherwise handler-less arm as a Boolean test makes it look
like an incomplete selection. It also overloads braces with two different
exhaustiveness and result rules. In particular, `match (value) {}` would need
a special meaning or a special prohibition, and adding a handler would
silently change the kind of construct.

The remaining prefix alternatives differ in how they delimit the subject list
and pattern:

```cpp
match(subjects...; case P)
match(subjects..., P)
match(subjects..., case P)
```

The semicolon form gives the construct two explicit regions and is a token that
cannot occur at the top level of an ordinary call or declarator. It is therefore
a particularly cheap parser discriminator. However, it is unfamiliar in a
function-like expression, especially in the common one-subject form:

```cpp
match(value; case P)
```

The comma form reads like an ordinary function call. `case` still provides an
unambiguous grammar boundary: preceding comma-separated operands are subjects,
and the final operand is a pattern. This remains clear with several subjects:

```cpp
match(first, second, case [P, Q])
```

Omitting `case` would make the construct indistinguishable from an ordinary
call and would lose the common introducer shared with selection arms. R6
therefore retains `case` but uses the familiar comma separator.

R6 therefore uses:

```cpp
match(value, case P)
match(first, second, case [P, Q])
```

This is deliberately printed with function-call spacing. It is an ordinary
Boolean expression and does not export bindings. The multi-arm construct keeps
keyword spacing:

```cpp
match (value) {
  case P => result;
}
```

We also considered making the declaration-like pattern condition itself an
expression, for example `bool(case P = value)` or `match(case P = value)`.
That conflates two different facilities. A pattern condition exports names to
the successful controlled statement and participates directly in control-flow
scope. A single-pattern test composes as a Boolean expression, exports no
names, and can appear in a requires-expression. R6 retains both spellings for
those separate uses:

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
};
```

The first line parses as a pattern `condition` followed by an implication
expression handler. This follows the general rule that a rare expression which
conflicts with the pattern boundary can be parenthesized. `->`, `:`, and a new
token such as `~>` were considered, but do not offer a compelling improvement:
`->` has the same issue, `:` is already heavily used by choice names and
labels, and a new token would be unfamiliar.

## Deferred Pattern Facilities

The following remain strong candidates for later work:

- static type subjects, including reflection values;
- named aggregate decomposition such as `[.x: P, .y: Q]`;
- range patterns;
- whole-value binding combined with a nested pattern;
- dynamic slice and sequence patterns;
- block-scope pattern declarations.

Nested structured bindings are being developed separately. They are useful
independently of pattern matching and provide the declaration analogue of
recursive structural patterns.

## Block-Scope Pattern Declarations

R6 does not allow a pattern declaration as an ordinary block-scope statement.
Several possible spellings remain available for later work. One makes the
hidden subject declaration explicit:

```cpp
auto&& case P = E;
auto&& case P = E else { return; }
```

The *cvref-auto* would control an underlying declaration such as
`auto&& subject = E`. Another option keeps that declaration implicit and uses
the absence of parentheses to indicate that successful bindings are introduced
into the enclosing scope:

```cpp
if case P = E else { return; }
```

The `else` statement would be required not to complete normally. This form
could use ordinary `auto&&` declaration lifetime rules, unlike the
range-for-style extension used by the R6 parenthesized condition. A bare
`case P = E;` was also considered, but it is too easily confused with a
`switch` label.

None of these forms should implicitly make the remainder of an ordinary block
a template region. Type-varying bindings or local binding packs would require
an explicitly enclosing template region. The useful irrefutable cases also
overlap substantially with nested structured bindings, so block-scope pattern
declarations are left out of R6.

## Other Extensions Considered

### Evidence for Or-patterns

Or-patterns are included because grouped dispatch is common in existing C++.
The LLVM, Clang, LLD, and LLDB survey found 17,230 runs of consecutive `case`
labels sharing a handler, containing 96,902 labels. The Chromium survey found
another 10,016 runs containing 47,270 labels. These are lower bounds: both
codebases also provide library encodings of the same operation through
`StringSwitch::Cases` and `TypeSwitch::Case<Ts...>`.

For example, LLVM's verifier groups three instruction kinds:

```cpp
switch (instruction.getOpcode()) {
case Instruction::And:
case Instruction::Or:
case Instruction::Xor:
  verifyBitwiseBinaryOperator(instruction);
  break;
default:
  break;
};
```

The direct pattern form preserves that grouping:

```cpp
match (instruction.getOpcode()) {
  case Instruction::And || Instruction::Or || Instruction::Xor =>
    verifyBitwiseBinaryOperator(instruction);
  case _ => ;
};
```

The same need appears in variant predicates. LLDB currently tests two
load-reserve alternatives with two `holds_alternative` calls joined by `||`.
The compositional spelling projects the variant once:

```cpp
return match(inst, case { LR_W || LR_D });
```

The survey counts do not imply that every grouped switch should be rewritten.
They show that a facility intended to replace `switch`, variant visitation,
and runtime type switches needs a non-duplicating form for shared behavior.

### Named Aggregate Decomposition

Positional decomposition is awkward when only a few members matter or when
layout order is not the semantic interface. A future extension could use
designators:

```cpp
match (point) {
  case [.x: 0, .y: 0] => origin();
  case [.x: int x, .y: int y] => use(x, y);
};
```

The leading dot is intentionally parallel to designated initialization. It is
also why named choice alternatives use `{ .name: P }`: the braces distinguish
choice-state lookup from future member lookup in square brackets.

### Typed Recursive Choice Selection

R5's `T: P` could both select a nominal alternative and recursively match its
payload. This paper retains that operation inside braces:

```cpp
match (command) {
  case { ChangeColor: [{ Rgb: [auto r, auto g, auto b] }] } =>
    use_rgb(r, g, b);
  case { ChangeColor: [{ Hsv: [auto h, auto s, auto v] }] } =>
    use_hsv(h, s, v);
};
```

For closed choices, a type selector considers each projectable state whose
projection admits `T`; duplicate matching states produce separate semantic
case instantiations. For an open choice, `T` supplies the requested cast type.
Polymorphic class subjects do not use this selector; a bare declaration or type
pattern performs their `dynamic_cast`-equivalent refinement.

Variant provides a parameterized `index` name for the rare cases where source
code needs to select by position rather than by type or value:

```cpp
variant<int, int> value;

match (value) {
  case { .index<0>: auto first } => use_first(first);
  case { .index<1>: auto second } => use_second(second);
};
```

The argument shall identify an advertised variant index. The selected state
must be projectable when `: P` is present; the state-only form does not require
a projection. `optional` and `expected` do not expose `.index<I>` because their
semantic names are better interfaces. A user-defined choice similarly exposes
positional selection only when its discriminator provides that parameterized
name.

`{ T: P }` selects an alternative whose advertised type is exactly `T`, then
applies `P` to its projection. A state that advertises a type must therefore
provide a compatible projection and cannot also be empty. `{ T }` has a
different composition: braces project a viable alternative and the nested
type pattern initializes an unnamed `T`. It is not a state-only abbreviation
for `{ T: _ }`.

### Static Type Subjects

Static dispatch does not need to overload value declaration patterns. A type
subject could instead use ordinary type patterns:

```cpp
match (T) {
  case int => integral_case();
  case double => floating_case();
  case _ => fallback();
};
```

C++26 reflection suggests an additional spelling over reflections:

```cpp
match (^^T) {
  case ^^int => integral_case();
  case ^^double => floating_case();
  case _ => fallback();
};
```

The lookup, constraint, and reflection models should be designed together.
This paper does not need static type subjects to provide dependent value
matching.

### Reflection-Based Customization

Earlier revisions considered replacing tuple-like and variant-like library
protocols entirely with reflection-based maps. For example, an encapsulated
record could advertise reflected accessors rather than `tuple_size`,
`tuple_element`, and `get<I>` specializations.

This paper takes a narrower step for choices.
`alternative_traits::alternatives` is a reflected descriptor table, but
runtime discrimination still uses `index(subject)`, and projection uses a
small ordered set of `get<selector>(subject)` forms. Products continue to use
existing structured-binding machinery. A fully reflection-driven projection
protocol remains future work.


# Design Decisions and Discussions

::: note
This section preserves the detailed design record from R5. Where R6 changes a
conclusion, the current direction is described in [R6 Design Decisions] and
the R5 discussion below remains as history and motivation.
The examples in this section are being updated incrementally.
:::

## R5 Unified `match` Expression

The R5 `match` expression unified the syntax for a single pattern match and a
selection of pattern matches. Namely,
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

There is a general desire to unify the handling of sum types like `variant`
and polymorphic types. For example, [@P2411R0] points out:

> The ‘is’-and-‘as’ notation [P2392] is cleaner and more general than the
[P1371] and successors notation. For example, it eliminates the need to use
the different notation styles for variant, optional, and any access. Uniform
notation is the backbone of generic programming.

[@P1371R3] already had uniform notation for `variant`, `any`, and polymorphic
types. R6 nevertheless adopts the declaration-shaped syntax for polymorphic
objects and retains braces for choices. The operations are not interchangeable:
`variant` has a generic active payload, whereas an open hierarchy has no
statically typed generic most-derived value. [Why Polymorphic Refinement Is Not
Braced] records the tradeoff and the pointer cases that ultimately motivated
the distinction.

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

## R5 Operator Precedence of Postfix Selection

::: note
This subsection records the R5 postfix syntax. R6 uses prefix syntax for both
multi-arm selection and single-pattern tests, so this discussion is retained
only as design history.
:::

### Proposed Solution: Between Pointer-to-member and Multiplicative Operator

The solution proposed in R5 was for `match` to have a precedence between
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

The parser recognizes a prefix selection immediately in an expression-only
context. At the start of a statement, it first scans the parenthesized
subject list to establish that a `{` or trailing return type follows. Only when
`match` names a type and the parenthesized tokens can be a declarator does it
inspect the first token of the body: `case`, the `[[` attribute introducer,
`using`, `namespace`, or `static_assert` selects the match grammar; otherwise
ordinary declaration parsing wins. A single `[` is not sufficient
because a declaration's braced initializer can begin with a lambda. This keeps
the tentative declarator parse confined to the genuinely ambiguous case, and
it does not require parsing an arm attribute during disambiguation.

When `match` is followed by neither `constexpr` nor `(`, the prototype performs
ordinary lookup without parsing the would-be subject. A declaration or a
dependent lookup keeps the ordinary interpretation; otherwise the selection
parser issues the focused missing-parentheses diagnostic. Labels and
explicit-template-argument calls remain ordinary special cases.

After the subject, `->` is also ambiguous with ordinary member access. The
normative classifier recognizes an expression selection only when a complete
valid *type-id* is followed by `{`. The prototype extends Clang's existing
lookup-sensitive tentative type-id parser with an
`InMatchTrailingReturnType` context. Unlike contexts that can return as soon as
the first token establishes a type, this context consumes the complete
*type-id* and leaves the parser at the following token. The operation remains
tentative and emits no diagnostics.

The implementation has additional diagnostic paths for ill-formed programs. It
commits immediately when the next token can begin a type-id but not member
access. For identifier-like syntax, it tentatively runs the real trailing
return type parser with normal type recovery and typo correction; reaching an
immediately following `{` selects the match parser for diagnostics. It does not
scan for a later brace: that brace may belong to a braced operand or lambda
appearing later in an otherwise valid member-access expression.

If type recovery does not reach a match body, the prototype parses the
arguments and asks whether ordinary lookup or ADL finds any entity named
`match`. Candidate existence, rather than overload viability, preserves
ordinary diagnostics for non-viable, deleted, ambiguous, or otherwise invalid
calls. A non-dependent call with no candidate is instead diagnosed as an
attempted selection. A dependent call retains the ordinary AST shape; during
instantiation the same candidate test selects either the ordinary overload
diagnostic or the missing-selection-body diagnostic. Ordinary
`match (x)->member` expressions remain unaffected.

When declaration parsing wins but a top-level `=>` appears before the first
top-level `,`, `;`, or `}`, the prototype diagnoses a likely omitted `case`.
This probe is diagnostic only: it neither changes the grammatical decision nor
constructs a match AST. Nested delimiters are skipped, so commas in
decomposition patterns and semicolons in guard conditions do not terminate the
probe.

For a single-pattern test, the prototype scans the balanced parentheses for a
top-level comma immediately followed by `case`. Earlier top-level commas
separate subjects. Nested delimiters are skipped, so commas in calls, lambdas,
and parenthesized comma expressions do not create a false match-test boundary.
No binary operator precedence or infix parser hook is required.

Requiring `case` gives every case a reliable recovery point. Within a pattern,
pattern-specific introducers commit immediately: `_`, `(`, `[`, and `{` begin
wildcard, parenthesized, decomposition, and alternative patterns,
respectively. They are not tentatively reparsed as expressions after a later
token. Expressions such as `_ + 1`, `(x) + 1`, lambda calls, and GNU
statement-expressions use an explicit functional-cast spelling when they occur
as patterns.

Declarations and expressions continue to share one position. The parser
recognizes a restricted declaration prefix consisting of a
*type-specifier-seq* and *conversion-declarator*. A following `(` or `{` cannot
continue that declarator and therefore begins a functional-cast expression;
otherwise the parser commits to the declaration pattern. This requires normal
C++ type lookup but no complete-pattern classification.

Attributes need additional care because `[[` can begin either an attribute or
a nested decomposition pattern. The parser accepts an attribute interpretation
when it forms a complete attribute-specifier and the following token can
continue the surrounding declaration; otherwise `[` begins structural pattern
parsing. The same probe is used by ordinary nested structured bindings and
declaration patterns. For example,
`[[likely]] case [[maybe_unused]] auto [x, y]` has a case attribute followed by
a declaration attribute, while `case [[_, _], _]` begins a decomposition
pattern. This is the only pattern introducer requiring structurally unbounded
lookahead, and it only scans one balanced attribute candidate.

`case P = E` introduces another parsing boundary. The first top-level `=`
terminates the pattern, and direct-condition operands stop at top-level `&&`.
This is why assignment and logical-or subjects require parentheses in that
form.

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

## R5 Parsing of the `match` Operator

::: note
This subsection records the R5 parser architecture. R6 no longer adds a
`match` precedence level or an infix parser hook. Both selection and testing
use prefix syntax and are parsed as described in [Parsing].
:::

Broadly speaking, in Clang, expressions are first parsed as a *cast-expression* with `ParseCastExpression`,
then `ParseRHSOfBinaryExpression` looks ahead to see if there is an infix operator. If it finds an operator,
it folds a sequence of RHS into LHS based on the associativity and precedence of the discovered operators.

The R5 prototype added `prec::Match` to the operator precedence table and
changed `ParseRHSOfBinaryExpression` to detect an upcoming `match` token. A
following `constexpr`, `->`, or `{` began a selection; otherwise it began a
single-pattern test.

For a single-pattern test, placing `prec::Match` correctly in the operator
precedence table caused an expression pattern to be parsed as the intended
*pm-expression*. R6 replaces this machinery with the prefix and delimiter
rules described in [Parsing].

## Parsing the Parenthesized Pattern

Pattern-specific introducers commit immediately. For example, `_` is a
wildcard pattern even if a variable named `_` is in scope, while `*_` is an
expression pattern and `_ + 1` is ill-formed.

```cpp
match (expr) {
  case _ => // wildcard pattern
  case *_ => // dereference
  case auto(_ + 1) => // addition using an outer variable named `_`
  case auto([]{}()) => // lambda-call expression
  case [] => // empty decomposition pattern
}
```

Parentheses always group a pattern. Expressions beginning with pattern syntax
use a functional-cast spelling:

```cpp
auto(_ + 1)
auto([]{}())
auto(({ int x = 1; x; }))
auto((T)value)
auto(value)
```

The parser does not scan a complete parenthesized or decomposition candidate
and then retry it as an expression. Complete constructs such as `(A || B)`,
`(int value)`, `([P...])`, and `(_)` retain their pattern meaning, while the
functional-cast operand is parsed by the ordinary expression grammar.

The remaining `[[` ambiguity is shared with nested structured-binding
declarations. A localized probe scans one complete attribute candidate and
checks whether the next token can continue the surrounding declaration. It
does not classify or rebuild an arbitrary complete pattern.

# Questions Before Wording

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

::: note
This section incrementally revises the R5 proposed wording. The prefix
selection and test syntax, multiple subjects, and declaration preamble grammar
have been updated. The pattern productions below still use the R5 `let`,
optional, alternative, and parenthesized patterns and are not yet the complete
R6 wording.
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
  - [1.4+1]{.pnum} *match-select-expression*, *match-test-condition*, or
    *match-case*
:::

introduces a *block scope* that includes that statement [or]{.rm}[,]{.add}
*handler*[, *match-select-expression*, *match-test-condition*, or
*match-case*]{.add}.

Add a new section to [expr.prim]{.sref}:

::: add

### 7.6.4+1 [expr.match] Pattern matching expression {#expr-match - .unlisted}

#### 7.6.4+1.1 [expr.match.general] General {- .unlisted}

```
  @*match-test-expression*@:
      match( @*match-subject-list*@ , case @*match-test-condition*@ )

  @*match-subject*@:
      @*assignment-expression*@ ...@*~opt~*@

  @*match-subject-list*@:
      @*match-subject*@
      @*match-subject-list*@ , @*match-subject*@

  @*match-test-condition*@:
      @*match-test-pattern*@ @*match-guard~opt~*@

  @*match-test-pattern*@:
      @*let-pattern*@
      @*match-test-matching-pattern*@ @*let-pattern~opt~*@

  @*match-test-matching-pattern*@:
      _
      @*pattern-expression*@
      ( @*match-case-pattern*@ )
      ? @*match-test-pattern*@
      @*discriminator*@ : @*match-test-pattern*@
      [ @*match-case-pattern-list*@ ]

  @*match-select-expression*@:
      match constexpr@*~opt~*@ ( @*match-subject-list*@ ) @*trailing-return-type~opt~*@ { @*match-preamble-declaration-seq~opt~*@ @*match-case-seq*@ }

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

  @*match-case-seq*@:
      @*match-case*@ @*match-case-seq~opt~*@

  @*match-case*@:
      @*match-case-condition*@ => @*expr-or-braced-init-list~opt~*@ ;
      @*match-case-condition*@ => @*escape-statement*@ ;
      @*match-case-condition*@ => @*non-returning-handler*@

  @*non-returning-handler*@:
      ! return @*expression*@ ;

  @*match-case-condition*@:
      @*match-case-pattern*@ @*match-guard~opt~*@

  @*match-case-pattern*@:
      @*let-pattern*@
      @*match-case-matching-pattern*@ @*let-pattern~opt~*@

  @*match-case-matching-pattern*@:
      _
      @*pattern-expression*@
      ( @*match-case-pattern*@ )
      ? @*match-case-pattern*@
      @*discriminator*@ : @*match-case-pattern*@
      [ @*match-case-pattern-list*@ ]

  @*pattern-expression*@:
      @*inclusive-or-expression*@

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

[#]{.pnum} Each *assignment-expression* in the *match-subject-list* of a
*match-test-expression* or *match-select-expression* is called a *subject
expression*. If the list contains one expression and does not contain a pack
expansion, that expression provides the *subject*. Otherwise, the subject is
the unnamed product formed from the subject expressions as described below.

[#]{.pnum} A declaration in a *match-preamble-declaration-seq* inhabits the
block scope introduced by the *match-select-expression*. Its normal point of
declaration applies. Consequently, a name declared in the preamble can be used
by each following preamble declaration and *match-case*, but not by a preceding
declaration or by a subject expression.

[#]{.pnum} The *expr-or-braced-init-list*, *escape-statement*, or
*non-returning-handler* to the right of `=>` in a *match-case* is called its
*handler*. An *expr-or-braced-init-list* handler is also called its *operand*.
The *expression* in a *non-returning-handler* is called its *non-returning
operand*.

[#]{.pnum} A *pattern* is a construct in *match-test-pattern* or *match-case-pattern* with
a set of *matching conditions*, described in [expr.pattern].

[#]{.pnum} A pattern *matches* a value if the matching conditions of the pattern are
satisfied by the value.

[#]{.pnum} A *match-test-condition* or *match-case-condition* matches the subject
if the corresponding pattern matches the value of the subject and either there is
no *match-guard* or the *match-guard* evaluates to `true`.

[#]{.pnum} A *match-test-expression* is a prvalue of type `bool`. The result is `true`
if *match-test-condition* matches the subject and `false` otherwise.

[#]{.pnum} The type of a *match-select-expression* is the *trailing-return-type*.
If the *trailing-return-type* is not present, it is considered to be `-> auto`.
If the *trailing-return-type* contains a placeholder type, the type is deduced from
the operands of *match-case*s as described in [dcl.spec.auto]{.sref}.

[#]{.pnum} A *match-select-expression* is an lvalue if the result type is an lvalue
reference type or an rvalue reference to function type, an xvalue if the result type is
an rvalue reference to object type, and a prvalue otherwise.

[#]{.pnum} A *non-returning-handler* shall appear only in a selection
expression, not in a selection statement. Its *non-returning operand* is a
discarded-value expression. If evaluation of that expression completes
normally, the behavior is undefined.

[#]{.pnum} For the first *match-case* whose *match-case-condition* matches the
subject, if its handler is an operand, the result of the
*match-select-expression* is the result of the possibly-converted operand. If
the handler is an *escape-statement*, control is transferred accordingly. If
the handler is a *non-returning-handler*, its non-returning operand is evaluated
as described above and the selection does not complete normally.
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

#### 7.6.4+1.5 [expr.pattern.const] Value Pattern {- .unlisted}

[#]{.pnum} A *pattern-expression* shall be a constant expression or an
*id-expression* that names an immediate function. Let *p* denote its constant
value in the former case and the named function in the latter case.

[#]{.pnum} If the canonical constant value of the *pattern-expression* is
advertised for one or more states of the closed alternative model of `E`, the
value pattern matches if the saved discriminator identifies one of those
states. Otherwise, if `bool(@*e*@ == @*p*@)` is well-formed, the value pattern
matches if that expression yields `true`. Otherwise, the value pattern matches
if `bool(@*p*@(@*e*@))` is well-formed and yields `true`. Otherwise, the program
is ill-formed.

[#]{.pnum} If the value pattern is an *id-expression* that refers to
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
