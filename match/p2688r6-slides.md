---
title: "P2688R6: Pattern Matching for Real C++"
subtitle: "A use-case-driven revision of P2688R5"
author: "Michael Park"
date: "August 2026"
revealjs-url: "https://cdn.jsdelivr.net/npm/reveal.js@5"
theme: white
transition: none
slideNumber: "&#39;c/t&#39;"
center: false
header-includes: |
  <style>
    .reveal .slides { text-align: left; }
    .columns { display: flex; gap: 1em; align-items: flex-start; }
    .column { flex: 1 1 0; min-width: 0; }
    .before { border-top: 4px solid #a43d2a; }
    .after { border-top: 4px solid #00796f; }
    .before > p:first-child, .after > p:first-child {
      font-weight: bold;
      text-transform: uppercase;
    }
    .callout { border-left: 5px solid #8a6500; padding-left: .6em; }
    .source { color: #666; font-size: .5em; }
    .small { font-size: .85em; }
  </style>
---

<!--
Build with:
  pandoc p2688r6-slides.md --standalone --to=revealjs \
    --output=generated/p2688r6-slides.html
-->

# Two years after R5

P2688R5 established a composable pattern language:

```cpp
subject match {
  pattern if (guard) => handler;
  pattern           => handler;
};
```

But the first questions were consistently about the surface model:

- Why does C++ need `let`?
- Does `auto&& x` bind the whole `variant` or its active alternative?
- Is `Circle& c` a static type test or a runtime downcast?
- How do `optional`, `expected`, `any`, and user-defined choices fit?
- Is non-exhaustiveness merely a warning?

::: {.callout}
R6 starts from real C++ code, then assigns distinct syntax to **binding**,
**runtime refinement**, and **choice projection**.
:::

# What the code survey found

A broad, non-exhaustive survey of large production C++ codebases found a few
recurring shapes:

| Recurring code | What programmers are doing |
|---|---|
| `std::visit(overloaded{...})` | Dispatch by active alternative and bind it |
| `get_if` / `holds_alternative` chains | First-match runtime type dispatch |
| `switch (v.index())` + `get_if<I>` | Dispatch by variant state, then project |
| `has_value()` / `hasError()` | Split value, empty, and error states |
| `dynamic_cast` chains | Refine a polymorphic object |
| `visit([](auto x) { return x == 0; })` | Apply one value pattern across alternatives |

The overwhelming variant use case binds a typed payload. Generic payload
handling and nested value/decomposition matching are less common, but uniquely
valuable when they occur.

# Use case: remove the visitor ceremony

:::: {.columns}
::: {.column .before}
Today

```cpp
return std::visit(
  overloaded{
    [](shared_ptr<const IdentifierRecord> record) {
      return ResultValue(record->value);
    },
    [](shared_ptr<const Parameter> p) {
      return ResultValue(clone(p->value));
    },
    [](uint64_t n) {
      return ResultValue(static_cast<int64_t>(n));
    },
    [](auto&& x) {
      return ResultValue(FWD(x));
    }},
  std::move(input));
```
:::

::: {.column .after}
Pattern matching

```cpp
return std::move(input) match -> ResultValue {
  case { shared_ptr<const IdentifierRecord> record }
    => ResultValue(record->value);

  case { shared_ptr<const Parameter> p }
    => ResultValue(clone(p->value));

  case { uint64_t n }
    => ResultValue(static_cast<int64_t>(n));

  case { auto&& x }
    => ResultValue(FWD(x));
};
```
:::
::::

# What that example asks from the language

```cpp
case { shared_ptr<const Parameter> p } => ...;
case { auto&& x }                      => ...;
```

1. A familiar declaration should bind the payload.
2. `auto&&` should preserve the payload's value category.
3. The syntax must say that matching enters the `variant`.
4. The final generic arm must be checked for every projected type.
5. First match wins; arms do not form an overload set.

::: {.callout}
This leads to the central R6 rule: **a declaration matches the current
subject; braces explicitly enter a runtime projection or refinement layer.**
:::

# Use case: type and structure compose

:::: {.columns}
::: {.column .before}
Today

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
:::

::: {.column .after}
Pattern matching

```cpp
return input match -> RecordView {
  case { auto&& [first, second] }
    => records().lookup(first, second);

  case { reference_wrapper<const Record> ref }
    => ref.get().view();

  case { _ }
    => throw invalid_argument(
         "unsupported record reference");
};
```
:::
::::

The decomposition arm is viable only for structurally compatible projections.

# Use case: replace a `get_if` chain

:::: {.columns}
::: {.column .before}
Today

```cpp
if (auto* set = std::get_if<CollectionFilter>(&filter)) {
  values = std::move(*set->values());
} else if (auto* range =
               std::get_if<LimitFilter>(&filter)) {
  values = {*range->value()};
} else {
  std::unreachable();
}
```
:::

::: {.column .after}
Pattern matching

```cpp
filter match {
  case { CollectionFilter& set }
    => values = std::move(*set.values());

  case { LimitFilter& range }
    => values = {*range.value()};
};
```
:::
::::

The closed choice is exhaustive, so the impossible defensive branch disappears.

# Use case: replace index plus projection

:::: {.columns}
::: {.column .before .small}
Today

```cpp
switch (result.index()) {
case 0: {
  auto& promise = *std::get_if<0>(&result);
  out.emplace_back(promise->result.value());
  break;
}
case 1: {
  auto& future = *std::get_if<1>(&result);
  out.emplace_back(co_await std::move(future));
  break;
}
case 2: {
  auto& value = *std::get_if<2>(&result);
  out.emplace_back(std::move(value).value());
  break;
}
default:
  folly::assume_unreachable();
}
```
:::

::: {.column .after .small}
Pattern matching

```cpp
result match {
  case { DeferredPtr& pending }
    => out.emplace_back(pending->result.value());

  case { folly::SemiFuture<TResult>& future }
    => out.emplace_back(co_await std::move(future));

  case { folly::Try<TResult>& value }
    => out.emplace_back(std::move(value).value());
};
```
:::
::::

# Use case: one value pattern, many types

:::: {.columns}
::: {.column .before}
Today

```cpp
using MetricValue =
  variant<int16_t, int32_t, int64_t,
          float, double>;

return ranges::all_of(metrics, [](const auto& item) {
  return std::visit(
      [](auto value) { return value == 0; },
      item.second);
});
```
:::

::: {.column .after}
Pattern matching

```cpp
return ranges::all_of(metrics, [](const auto& item) {
  return item.second match {
    case { 0 } => true;
    case _     => false;
  };
});
```
:::
::::

`{ 0 }` is the important non-binding case: it applies the value pattern to
every viable numeric projection.

# Use case: stop asking twice

:::: {.columns}
::: {.column .before .small}
Today

```cpp
if (holds_alternative<ref<InlineMap>>(data)) {
  auto& map = get<ref<InlineMap>>(data).get();
  insertInline(map, key, value);
} else if (holds_alternative<ref<RunningState>>(data)) {
  insertAggregate<RunningState>(data, values);
} else if (holds_alternative<ref<BatchState>>(data)) {
  insertAggregate<BatchState>(data, values);
} else if (holds_alternative<ref<ExpandedMap>>(data)) {
  get<ref<ExpandedMap>>(data).get()[key].emplace(id, value);
}
```
:::

::: {.column .after .small}
Pattern matching

```cpp
data match {
  case { ref<InlineMap> map }
    => insertInline(map.get(), key, value);

  case { ref<RunningState> state }
    => insertAggregate(state.get(), values);

  case { ref<BatchState> state }
    => insertAggregate(state.get(), values);

  case { ref<ExpandedMap> map }
    => map.get()[key].emplace(id, value);
};
```
:::
::::

# Use case: optional value or empty

:::: {.columns}
::: {.column .before}
Today

```cpp
auto value = parseIntegerText(input);
if (!value.has_value()) {
  throw ParseError(fieldName, "expected an integer");
}
return std::move(*value);
```
:::

::: {.column .after}
Pattern matching

```cpp
return parseIntegerText(input)
  match -> std::string {
    case { std::string value }
      => std::move(value);

    case {}
      => throw ParseError(
           fieldName, "expected an integer");
  };
```
:::
::::

`{}` is an explicit non-projectable state, not a magic spelling for
`std::nullopt` alone.

# Use case: expected value or error

:::: {.columns}
::: {.column .before .small}
Today

```cpp
auto result = loadResources();
if (result.hasError()) {
  return unexpected(format(
      "resource initialization failed: {}",
      result.error()));
}
context.resources = std::move(result.value());
```
:::

::: {.column .after .small}
Pattern matching

```cpp
loadResources() match {
  case { .value: auto&& resources }
    => context.resources = std::move(resources);

  case { .error: const std::string& error }
    => return unexpected(format(
         "resource initialization failed: {}", error));
};
```
:::
::::

Named states preserve the distinction even when value and error have the same
projected type.

# Use case: polymorphic refinement

:::: {.columns}
::: {.column .before}
Today

```cpp
bool IntegerNode::equalTo(const Node& other) const {
  if (auto* i = dynamic_cast<const IntegerNode*>(&other)) {
    return value_ == i->value_;
  }
  if (auto* d = dynamic_cast<const FloatingNode*>(&other)) {
    return value_ == d->value_;
  }
  return false;
}
```
:::

::: {.column .after}
Pattern matching

```cpp
bool IntegerNode::equalTo(const Node& other) const {
  return other match {
    case { const IntegerNode& i }
      => value_ == i.value_;

    case { const FloatingNode& d }
      => value_ == d.value_;

    case _ => false;
  };
}
```
:::
::::

Braces mark the runtime boundary. Here they request polymorphic refinement with
`dynamic_cast` semantics rather than closed-choice projection.

# What the survey changed

| Evidence | Design consequence |
|---|---|
| Most variant arms name and bind a type | Give the common path declaration syntax |
| Generic visitors are real and useful | Keep `{ auto&& x }` as a per-alternative arm |
| Value tests across alternatives occur | Keep composable `{ 0 }`, not only type dispatch |
| Tuple-like alternatives occur among other types | Permit `{ [P...] }` across viable projections |
| Expected-like code names value and error | Support named alternatives |
| Bare declarations should not silently become runtime operations | Use `{ Circle& c }` for polymorphic refinement |
| Static multi-dispatch examples were difficult to find | Do not make runtime syntax serve speculative static dispatch |

::: {.callout}
The result favors familiar syntax for prevalent code without giving up the
composability that motivated P2688.
:::

# The R6 mental model

| Pattern | Meaning |
|---|---|
| `P` | Match `P` against the current subject |
| `T x` | Declare `x` from the current subject |
| `T` | Test the current subject as if `T x` had omitted `x` |
| `[P1, P2]` | Decompose the current subject |
| `{ P }` | Enter a runtime projection or refinement layer, then match `P` |
| `{ .name: P }` | Select a named state, project it, then match `P` |
| `{}` | Match an advertised non-projectable state |
| `_` | Match the current subject without projection |

::: {.callout}
**Bare declarations are static. Braces mark runtime projection or refinement.**
:::

# Arms now say `case`

:::: {.columns}
::: {.column .before}
R5

```cpp
value match {
  0 => zero();
  _ => other();
};

if (value match 0) {
  // ...
}
```
:::

::: {.column .after}
R6

```cpp
value match {
  case 0 => zero();
  case _ => other();
};

if (value match case 0) {
  // ...
}
```
:::
::::

- Makes the arm boundary explicit to readers and parsers.
- Leaves room for attributes and future arm-level syntax.

# `let` becomes a declaration

:::: {.columns}
::: {.column .before}
R5

```cpp
value match {
  let x => consume(x);
};

pair match {
  let [x, y] => use(x, y);
};
```
:::

::: {.column .after}
R6

```cpp
value match {
  case auto&& x => consume(x);
};

pair match {
  case auto&& [x, y] => use(x, y);
};
```
:::
::::

The declaration grammar follows a for-range-declaration:

```cpp
case Widget w
case const Widget& w
case auto&& w
case std::integral auto i
```

# Declaration semantics are C++ semantics

```cpp
make_widget() match {
  case Widget w       => consume(std::move(w));
  case const Widget& w => inspect(w);
};
```

- By-value declarations perform ordinary initialization.
- Reference declarations follow ordinary reference binding.
- `auto&&` preserves the subject's value category.
- Constrained placeholders remain available.
- A failed guarded arm may already have initialized its declaration.

The viability category is overload-resolution **exact match**:

| Accepted | Rejected |
|---|---|
| Identity | Promotion |
| Qualification adjustment | Conversion |
| Lvalue/array/function transformations | User-defined conversion |

First matching arm wins. Arms do not overload against one another.

# Why projection must be visible

```cpp
std::variant<int, std::string> v;

v match {
  case auto&& x => use(x);
};
```

Without a marker, does `x` mean:

1. the `variant` object itself,
2. its active alternative, or
3. a template-like binding checked once per alternative?

R6 makes the distinction explicit:

```cpp
case auto&& whole => use(whole);  // current subject
case { auto&& alt } => use(alt);  // projected alternative
```

# Generic projection is the payoff

```cpp
using V = std::variant<
    int,
    std::tuple<int, int>,
    std::pair<int, int>,
    std::array<int, 2>>;

V value;

value match {
  case { int i }         => scalar(i);
  case { auto&& [x, y] } => coordinates(x, y);
};
```

The second arm handles three structurally compatible alternatives without
naming them. That capability is specific to C++'s closed generic sum types
and should remain explicit.

# Type patterns

A type pattern is a declaration pattern with no identifier:

```cpp
value match {
  case int         => integer_without_binding();
  case double d    => floating_with_binding(d);
  case auto&& rest => fallback(rest);
};
```

It composes normally:

```cpp
pair match {
  case [int, const std::string& text] => use(text);
  case [_, _]                         => fallback();
};
```

`void` is supported as a type pattern, including for a `void` projection such
as the value state of `expected<void, E>`.

# Named and empty alternatives

:::: {.columns}
::: {.column}
Named states

```cpp
std::expected<int, Error> result;

result match {
  case { .value: int value }
    => use(value);

  case { .error: const Error& error }
    => report(error);
};
```
:::

::: {.column}
Non-projectable state

```cpp
std::optional<int> value;

value match {
  case { int i } => use(i);
  case {}        => empty();
};

int* pointer;
pointer match {
  case { int& i } => use(i);
  case {}         => null();
};
```
:::
::::

Names disambiguate semantically distinct states. `{}` says a state exists but
has no value to project.

# `std::any`: an open choice

`any` has no finite list of alternatives. It still has a projection boundary:

```cpp
std::any value;

value match {
  case { int i }                => use(i);
  case { const std::string& s } => use(s);
  case { _ }                    => unknown_nonempty_value();
  case {}                       => empty();
};
```

- Typed braces compare `value.type()` with `typeid(T)` and then use
  `any_cast<T>`.
- `{ _ }` covers any non-empty stored type without exposing that erased type.
- `{}` covers the empty state.
- A naked `case int i` does **not** silently inspect an `any`.

This keeps ordinary declaration patterns from acquiring hidden type-erasure
semantics.

# Two forms of `alternative_traits`

:::: {.columns}
::: {.column .small}
Closed, indexed choice

```cpp
template<>
struct alternative_traits<MyChoice> {
  static constexpr size_t size = 2;
  static constexpr bool is_exhaustive = true;

  template<size_t I>
  using type = /* declared alternative type */;

  static size_t index(const MyChoice&);

  template<size_t I, class Self>
  static decltype(auto) get(Self&&);

  struct names {
    static constexpr alternative_name<alternative_traits> value = 0;
    static constexpr alternative_name<alternative_traits> error = 1;
  };
};
```
:::

::: {.column .small}
Open, type-indexed choice

```cpp
template<>
struct alternative_traits<std::any> {
  template<class T, class Self>
  static T* try_cast(Self&& self) noexcept;

  // Optional; enables {}.
  static bool has_value(const std::any&) noexcept;
};
```
:::
::::

Without `has_value`, an open choice has no separately matchable empty state.

# Current protocol models

| Subject | Choice model | Required states |
|---|---|---|
| `T*` | Compiler-provided pointer projection | null and non-null |
| `optional<T>` | Closed: empty, value | both |
| `expected<T, E>` | Closed: named value, error | both |
| `variant<Ts...>` | Closed: each declared index | every index |
| `any` | Open: runtime type plus empty | open residual and empty |

`variant::valueless_by_exception()` is deliberately residual rather than a
normal advertised alternative. It is useful to handle, but is not required
for ordinary exhaustiveness.

# Exhaustiveness is a language rule

```cpp
bool b;

b match {
  case true => yes();
};
// error: example of a missing case: false
```

```cpp
b match {
  case true  => yes();
  case false => no();
  case _     => impossible();
};
// error: redundant case
```

- Non-exhaustiveness is a hard error.
- Redundant cases are hard errors.
- Guarded arms do not establish coverage.
- Diagnostics produce source-like witnesses such as `{ std::string }`,
  `{ false }`, `{ _ }`, or `{}`.

# Required versus residual states

```cpp
enum E { A = 0, B = 2 };

e match {
  case A => a();
  case B => b();
};
// exhaustive: every declared enumerator value is covered
```

```cpp
e match {
  case A => a();
  case B => b();
  case _ => unnamed_enum_value();
};
// `_` is useful for residual values in the enum's range
```

The same distinction lets every `variant` index be required while keeping
`valueless_by_exception()` residual.

# Templates: useful, maybe useful, not useful

```cpp
template<class V>
int classify(V value) {
  return value match {
    case { int }         => 0;
    case { std::string } => 1;
    case { char }        => 2;
  };
}
```

For one specialization, `{ char }` may match no projection. It remains
**maybe useful** because another specialization may make it viable.

The checker distinguishes:

- **useful**: covers a state not covered above;
- **maybe useful**: viability can change under substitution;
- **not useful**: structurally redundant regardless of substitution.

Dependent redundancy remains an important specification and implementation
audit area.

# Evaluation model

The current semantic direction and prototype behavior are:

- Evaluate the match subject exactly once.
- Reuse compatible alternative and decomposition projections.
- Run a guard only after its pattern has matched.
- Initialize declaration bindings eagerly, using ordinary C++ semantics.
- Do not count guarded arms toward exhaustiveness.

```cpp
subject match {
  case Widget w if (acceptable(w)) => consume(w);
  case Widget w                    => fallback(w);
};
```

If the first guard fails, `w` may be initialized twice. The proposal still
needs to specify which protocol and decomposition operations may be reused.

# R5 to R6 at a glance

| P2688R5 | Current R6 direction | Why |
|---|---|---|
| `P =>` | `case P =>` | Explicit arm boundary |
| `let x` | `auto&& x`, `T x`, ... | Familiar C++ declaration vocabulary |
| `T: let x` | `{ T x }` | Make choice projection visible |
| `T: P` | `{ T: P }` | Retain recursive selection inside the projection boundary |
| `C: P` | `{ C: P }` | Constrain the declared alternative `type<I>` |
| `? let x` | `{ auto&& x }` | One projection model |
| empty optional via `_` | `{}` | Name the non-projectable state |
| direct `any` cast pattern | `{ T x }` | Type erasure is an explicit open choice |
| direct polymorphic declaration | `{ T& x }` | Runtime refinement is explicit |
| `(P)` pattern | removed | Parentheses retain expression meaning |

The recursive selector remains available, but only inside braces. Positional
`{ I: P }` handles duplicate or otherwise indistinguishable alternative types.

# What is implemented

The Clang/libc++ prototype now includes:

- Required `case` syntax and single-pattern `E match case P`
- Declaration and type patterns
- Braced polymorphic runtime refinement
- Braced, named, and empty projection patterns
- Typed, constrained, and positional projection selectors
- Closed and open `alternative_traits`
- Pointer, `optional`, `expected`, `variant`, and `any` models
- Subject-once evaluation and compatible projection reuse
- Separate semantic instantiations for generic projected arms
- CFG, constant evaluation, and code generation
- Hard exhaustiveness and redundancy checking

The implementation is intentionally experimental: modules/PCH serialization,
libclang/tooling integration, type subjects, and named aggregate decomposition
remain outside the current scope.

# The risks to resolve before wording

1. **Implicit template regions**
   `{ auto&& x }` may instantiate a handler once per projected type.

2. **Guard and move semantics**
   Failed guarded arms can copy, move, mutate, or invalidate projections.

3. **Projection observability**
   The number of `index`, `get`, tuple `get`, and RTTI operations needs a rule.

4. **Dependent usefulness**
   Substitution-dependent viability must not hide universal redundancy.

5. **Protocol contract**
   Lookup, malformed traits, exceptions, residual states, and naming need
   precise specification.

6. **Grammar overlap**
   Declarations, type patterns, expressions, attributes, and decomposition
   share prefixes and need principled disambiguation.

# Takeaways

1. **Optimize the syntax for code C++ programmers already write:** typed
   variant dispatch, optional/expected state handling, and polymorphic casts.

2. **Use real declarations for binding:** value category, cv/ref, constraints,
   and initialization should mean what they mean elsewhere in C++.

3. **Make projection visible:** braces resolve whole-object versus active-value
   ambiguity and enable generic composition.

4. **Use one state model for matching and coverage:** `alternative_traits`
   drives projection, names, empty states, and exhaustiveness.

5. **Make exhaustiveness contractual:** required and residual states provide
   precision without pretending rare runtime states cannot exist.

::: {.callout}
R6 is more familiar on the common path and more explicit where C++'s generic
sum types are uniquely powerful.
:::
