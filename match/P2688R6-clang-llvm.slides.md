---
title: Pattern Matching in Clang/LLVM
subtitle: P2688R6 Design Review
author: Michael Park
date: October 14, 2026
highlighting:
  keywords:
    cpp: match
header-includes: |
  <style>
  .reveal {
    font-size: 38px;
  }
  .reveal .slides > section:not(.stack),
  .reveal .slides > section.stack > section {
    padding: 2.5% 4%;
  }
  .reveal .slides > section.stack { padding: 0; }
  .reveal h1 { font-size: 2.25em; }
  .reveal h2 { font-size: 1.75em; margin-bottom: 0.7em; }
  .reveal pre code { font-size: 0.96em; }
  .reveal .columns pre code { font-size: 0.78em; }
  #match-the-data-shape .columns pre code { font-size: 0.68em; }
  #string-predicate-dispatch pre code { font-size: 0.78em; }
  .reveal .slide-number {
    bottom: 1.5%;
    left: 50%;
    right: auto;
    transform: translateX(-50%);
  }
  #title-slide {
    display: flex !important;
    flex-direction: column;
    justify-content: center;
    padding: 5% 4% 10%;
  }
  #title-slide h1 {
    font-size: 2.65em;
    margin: 0 0 0.2em;
    max-width: 94%;
  }
  #title-slide .subtitle {
    font-size: 1.35em;
    font-weight: 600;
    margin: 0;
  }
  #title-slide .author,
  #title-slide .date {
    left: 4%;
    margin: 0;
    position: absolute;
  }
  #title-slide .author { bottom: 11%; }
  #title-slide .date { bottom: 4%; }
  .reveal .slides section.section-divider {
    align-items: center;
    display: flex !important;
    justify-content: center;
  }
  .reveal .slides section.section-divider h1 {
    margin: 0;
    text-align: center;
  }
  .reveal .source-pointer {
    font-size: 0.55em;
    margin-top: 1em;
    text-align: right;
  }
  .reveal .protocol-code .sourceCode,
  .reveal .protocol-code pre {
    margin-bottom: 0;
    margin-top: 0;
  }
  .reveal .protocol-code pre {
    border-radius: 0;
  }
  </style>
---

# A Tour of P2688R6

```cpp
match (subject) {
  case pattern if (guard) => handler;
  case pattern            => handler;
}
```

- A statement or an expression
- Cases are considered in source order
- Patterns compose tests, projections, and declarations
- Every match must be exhaustive

::: notes
Walk through the paper and Compiler Explorer for the full introductory tour.
The slides retain only the examples needed to establish the model.
:::

## Value Pattern

```cpp
enum class Coin { Penny, Nickel, Dime, Quarter };

int value_in_cents(Coin coin) {
  return match (coin) {
    case Coin::Penny   => 1;
    //   ^^^^^^^^^^^  value pattern
    case Coin::Nickel  => 5;
    case Coin::Dime    => 10;
    case Coin::Quarter => 25;
  };
}
```

A value pattern compares the subject. Every enumerator must be covered.

## Predicate Pattern

```cpp
void zero();
void large_value();
void smaller_value();

constexpr bool is_at_least_five(int value) {
  return value >= 5;
}

void classify(int value) {
  match (value) {
    case 0 => zero();
    case is_at_least_five => large_value();
    //   ^^^^^^^^^^^^^^^^  predicate pattern
    case _ => smaller_value();
  }
}
```

Equality is tried first. If it is unavailable, a callable constant is invoked
as a predicate.

## Declaration Pattern

```cpp
int dice_roll();
void add_fancy_hat();
void remove_fancy_hat();
void move_player(int spaces);

void take_turn() {
  match (dice_roll()) {
    case 3 => add_fancy_hat();
    case 7 => remove_fancy_hat();
    case int roll => move_player(roll);
    //   ^^^^^^^^  declaration pattern
  }
}
```

A declaration pattern binds using ordinary C++ declaration syntax.

## Wildcard Pattern

```cpp
void reroll();

void reroll_unless_special() {
  match (dice_roll()) {
    case 3 => add_fancy_hat();
    case 7 => remove_fancy_hat();
    case _ => reroll();
    //   ^  wildcard pattern
  }
}
```

`_` matches without introducing a name.

## Or-Pattern

```cpp
void lose_turn();

void take_turn_with_or_pattern() {
  match (dice_roll()) {
    case 1 or 2 => lose_turn();
    //   ^^^^^^  or-pattern
    case 3 => add_fancy_hat();
    case 7 => remove_fancy_hat();
    case int roll => move_player(roll);
  }
}
```

An or-pattern tries its alternatives against the same subject.

## Decomposition

```cpp
std::pair<int, int> roll_two_dice();
void snake_eyes();
void boxcars();
void play_doubles(int roll);

void take_turn_with_pair() {
  match (roll_two_dice()) {
    case [1, 1] => snake_eyes();
    //   ^^^^^^  decomposition pattern
    case [6, 6] => boxcars();
    case [int r1, int r2] if (r1 == r2) => play_doubles(r1);
    case [int r1, int r2] => move_player(r1 + r2);
  }
}
```

- Decomposition recursively matches tuple-like elements
- A guard runs after its pattern succeeds

## Multiple Subjects

```cpp
void take_turn_with_two_subjects() {
  match (dice_roll(), dice_roll()) {
    case [1, 1] => snake_eyes();
    case [6, 6] => boxcars();
    case [int r1, int r2] if (r1 == r2) => play_doubles(r1);
    case [int r1, int r2] => move_player(r1 + r2);
  }
}
```

Separately produced subjects form one unnamed product.

## `std::optional`

```cpp
std::optional<int> try_dice_roll();
void roll_again();

void take_optional_turn() {
  match (try_dice_roll()) {
    case { int roll } => move_player(roll);
    //   ^^^^^^^^^^^^  alternative pattern
    case {} => roll_again();
  }
}
```

`{ P }` projects the value state and recursively applies `P`. `{}` matches the
empty state.

## `std::variant`

```cpp
struct File { std::string name; };
struct Directory { std::string name; };
using SearchResult = std::variant<File, Directory>;

void open_file(const File&);
void open_directory(const Directory&);

void open(const SearchResult& result) {
  match (result) {
    case { const File& file } => open_file(file);
    case { const Directory& directory } => open_directory(directory);
  }
}
```

Each declaration pattern selects and binds the corresponding alternative.

## `std::expected`

```cpp
std::expected<int, std::string> parse_port(std::string_view text);
void connect(int port);
void report(const std::string& message);

void connect_from(std::string_view text) {
  match (parse_port(text)) {
    case { int port } => connect(port);
    case { const std::string& error } => report(error);
  }
}
```

Value and error alternatives use the same projection model.

## Named Selectors

```cpp
std::expected<std::string, std::string>
read_file(std::string_view path);
void process(const std::string& contents);

void read_config(std::string_view path) {
  auto result = read_file(path);

  match (result) {
    case { .value: const auto& contents } => process(contents);
    case { .error: const auto& message }  => report(message);
  }
}
```

Named selectors distinguish states whose projections have the same type.

## Open Class Hierarchies

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

Declaration patterns also support runtime refinement of polymorphic classes.

## Pattern Test

```cpp
SearchResult search(std::string_view path);

bool is_file(std::string_view path) {
  SearchResult result = search(path);
  return match(result, case { const File& });
}
```

The test is an ordinary `bool` expression and does not export declarations.

## Pattern Condition

```cpp
void open_if_directory(const SearchResult& result) {
  if (case { const Directory& directory } = result) {
    open_directory(directory);
  }
}
```

A pattern condition exports its declarations into the successful continuation.

## Chained Conditions

```cpp
bool should_open(const Directory&);

void open_path(std::string_view path) {
  if (case { const Directory& directory } = search(path) &&
      should_open(directory)) {
    open_directory(directory);
  }
}
```

Pattern conditions participate in left-to-right `&&` chains. Introduced names
are available to later conditions and the successful statement.

## Pattern Vocabulary

| Pattern | Example | Role |
|---|---|---|
| Value | `case 0` | Compare |
| Predicate | `case is_at_least_five` | Invoke a callable constant |
| Wildcard | `case _` | Match without binding |
| Declaration | `case const T& x` | Initialize a declaration |
| Decomposition | `case [0, int y]` | Match tuple-like elements |
| Alternative | `case { const T& x }` | Project a runtime state |
| Or-pattern | `case A or B` | Try either pattern |
| Guard | `case P if (condition)` | Test after matching |

## Custom Alternative Types

::: {.protocol-code}
```cpp
template<class T, class E>
struct std::alternative_traits<my::Result<T, E>> {
```
::: {.fragment data-fragment-index="0"}
```cpp
  static constexpr std::alternative_info alternatives[] = {^^T, ^^E};
```
:::
::: {.fragment data-fragment-index="1"}
```cpp
  static constexpr bool has_residual_states = false;
```
:::
::: {.fragment data-fragment-index="2"}
```cpp
  static constexpr std::size_t index(const my::Result<T, E>& result) noexcept {
    return result.has_value() ? 0 : 1;
  }
```
:::

::: {.fragment data-fragment-index="3"}
```cpp
  template<std::size_t I, class Self>
  static constexpr decltype(auto) get(Self&& self) noexcept {
    if constexpr (I == 0) return std::forward<Self>(self).value();
    else if constexpr (I == 1) return std::forward<Self>(self).error();
    else static_assert(false);
  }
```
:::
```cpp
};
```
:::

::: {.fragment data-fragment-index="0"}
`alternatives` advertises the complete set of states.
:::

::: {.fragment data-fragment-index="2"}
`index()` selects the active state.
:::

::: {.fragment data-fragment-index="3"}
`get<I>()` projects its value.
:::

## Alternative Protocol

:::: {.columns}
::: {.column width="47%"}
```cpp
my::Result<int, std::string> read_number();
void use(int);

my::Result<int, std::string> number = read_number();

match (number) {
  case { int v } => use(v);
  case { const std::string& e } => report(e);
}
```
:::
::: {.column .fragment width="53%"}
```cpp
using Traits = std::alternative_traits<decltype(number)>;

switch (Traits::index(number)) {
  case 0: {
    int v = Traits::get<0>(number);
    use(v);
    break;
  }
  case 1: {
    const std::string& e = Traits::get<1>(number);
    report(e);
    break;
  }
}
```
:::
::::

The state descriptions enable exhaustiveness checking; this lowering is only
illustrative.

## Named Selector Protocol

```cpp
enum class state { value, error };

static constexpr state index(const my::Result<T, E>& result) {
  return result.has_value() ? state::value : state::error;
}

template<state State, class Self>
static constexpr decltype(auto) get(Self&& self) {
  if constexpr (State == state::value)
    return std::forward<Self>(self).value();
  else
    return std::forward<Self>(self).error();
}
```

The selector name is looked up in the return type of `index()`. In
`{ .value: P }`, `P` is applied to `get<state::value>(subject)`.

# Real Clang/LLVM Examples {.section-divider}

## Exhaustive Variant Dispatch

:::: {.columns}
::: {.column width="55%"}
```cpp
return std::visit(
    [&](const auto &S) -> llvm::Error {
      using T = std::decay_t<decltype(S)>;
      if constexpr (std::is_same_v<T, TUSummary>) {
        return writeTUSummary(S, Path);
      } else if constexpr (std::is_same_v<T, LUSummary>) {
        return writeLUSummary(S, Path);
      } else {
        static_assert(std::is_same_v<T, WPASuite>,
                      "Artifact visitor must cover all variant alternatives");
        return writeWPASuite(S, Path);
      }
    },
    A);
```
:::
::: {.column .fragment width="45%"}
```cpp
return match (A) {
  case { const TUSummary &S } => writeTUSummary(S, Path);
  case { const LUSummary &S } => writeLUSummary(S, Path);
  case { const WPASuite &S } => writeWPASuite(S, Path);
};
```
:::
::::

The language checks exhaustiveness without a generic lambda, type recovery,
or a manually maintained `static_assert`.

::: {.source-pointer}
Source: [`JSONFormat::writeArtifact`](https://github.com/llvm/llvm-project/blob/ba617c51a2a50fbab0eaae92b4f1522cbec2425a/clang/lib/ScalableStaticAnalysis/Core/Serialization/JSONFormat/Artifact.cpp#L83)
:::

::: notes
From `JSONFormat::writeArtifact`, commit d090cc6448ea.
:::

## String Value Dispatch

:::: {.columns}
::: {.column width="50%"}
```cpp
return StringSwitch<clang::Language>(*Language)
    .Case("c", clang::Language::C)
    .Case("c++", clang::Language::CXX)
    .Case("objective-c", clang::Language::ObjC)
    .Case("objective-c++", clang::Language::ObjCXX)
    .Default(clang::Language::Unknown);
```
:::
::: {.column .fragment width="50%"}
```cpp
return match (*Language) {
  case "c" => clang::Language::C;
  case "c++" => clang::Language::CXX;
  case "objective-c" => clang::Language::ObjC;
  case "objective-c++" => clang::Language::ObjCXX;
  case _ => clang::Language::Unknown;
};
```
:::
::::

String literals are ordinary value patterns.

::: {.source-pointer}
Source: [`Implementation::parseLanguage`](https://github.com/llvm/llvm-project/blob/72a3a84ac622cf2ca17e3735fb8ef3ec8fc93581/clang/lib/InstallAPI/FileList.cpp#L84)
:::

::: notes
From `Implementation::parseLanguage`, commit 49ceb8bdda3b.
:::

## String Predicate Dispatch

:::: {.columns}
::: {.column width="50%"}
```cpp
return StringSwitch<ISAKind>(Arch)
    .StartsWith("aarch64", ISAKind::AARCH64)
    .StartsWith("arm64", ISAKind::AARCH64)
    .StartsWith("thumb", ISAKind::THUMB)
    .StartsWith("arm", ISAKind::ARM)
    .Default(ISAKind::INVALID);
```
:::
::: {.column .fragment width="50%"}
```cpp
return match (Arch) {
  case starts_with("aarch64") => ISAKind::AARCH64;
  case starts_with("arm64") => ISAKind::AARCH64;
  case starts_with("thumb") => ISAKind::THUMB;
  case starts_with("arm") => ISAKind::ARM;
  case _ => ISAKind::INVALID;
};
```
:::
::::

```cpp
constexpr auto starts_with(StringLiteral prefix) {
  return [prefix = StringRef(prefix)](auto&& s) {
    return s.starts_with(prefix);
  };
}
```

`starts_with("arm")` is a callable constant, so it is a predicate pattern.

::: {.source-pointer}
Source: [`ARM::parseArchISA`](https://github.com/llvm/llvm-project/blob/49ceb8bdda3bb7dbaae6f4c00a80b5be3de6c907/llvm/lib/TargetParser/ARMTargetParserCommon.cpp#L103)
:::

::: notes
From `ARM::parseArchISA`, commit 7c98455c7ec0.
:::

## AST Dispatch Today

:::: {.columns}
::: {.column width="50%"}
### `switch`

```cpp
switch (D->getKind()) {
case Decl::Function:
  use(cast<FunctionDecl>(D));
  break;
case Decl::Var:
  use(cast<VarDecl>(D));
  break;
}
```

- Can diagnose missing enumerators
- Repeats the `Kind` to class mapping
- The discriminator and cast can disagree
:::
::: {.column .fragment width="50%"}
### `dyn_cast`

```cpp
if (auto *FD = dyn_cast<FunctionDecl>(D))
  use(FD);
else if (auto *VD = dyn_cast<VarDecl>(D))
  use(VD);
```

- Names each concrete class once
- Naturally handles an open hierarchy
- Repeatedly tests the runtime discriminator
- Cannot diagnose a missing class
:::
::::

## Generated `alternative_traits`

`DeclNodes.td` already generates the hierarchy and `Decl::Kind` mapping. The
self-host uses that information to generate:

```cpp
alternative_traits<Decl> // every concrete Decl
```

- The generated protocol owns the discriminator-to-class mapping
- Patterns bind the concrete class directly
- The advertised alternatives support exhaustiveness checking

## AST Dispatch with `match`

```cpp
match (*D) {
  case { FunctionDecl &FD } => use(&FD);
  case { VarDecl &VD } => use(&VD);
  case _ => ;
}
```

- Each concrete class is named once
- The generated protocol owns the `Kind`-to-class mapping
- The runtime discriminator is dispatched once
- `_` covers the rest of the `Decl` domain

## Generated Subdomains

The same TableGen pass generates a more precise domain for each intermediate
AST class:

```cpp
alternative_traits<NamedDecl>         // concrete NamedDecl subclasses
alternative_traits<CXXRecordDecl>     // three possible concrete classes
alternative_traits<ObjCContainerDecl> // five possible concrete classes
```

`getKind()` still returns the full `Decl::Kind` enumeration. A `switch` cannot
infer these subsets, but exhaustiveness for `match` uses the subject's static
domain.

## Discriminator and Cast

Dispatch excerpt from `VisitObjCContainerDecl`:

:::: {.columns}
::: {.column width="50%"}
```cpp
switch (D->getKind()) {
case Decl::ObjCInterface:
case Decl::ObjCImplementation:
  GenObjCClass(...);
  break;
case Decl::ObjCCategory: {
  const auto *CD = cast<ObjCCategoryDecl>(D);
  GenObjCCategory(...);
  break;
}
case Decl::ObjCCategoryImpl: {
  const auto *CD = cast<ObjCCategoryImplDecl>(D);
  GenObjCCategory(...);
  break;
}
case Decl::ObjCProtocol: {
  const auto *PD = cast<ObjCProtocolDecl>(D);
  GenObjCProtocol(...);
  break;
}
default:
  llvm_unreachable("Invalid ObjC container");
}
```
:::
::: {.column .fragment width="50%"}
```cpp
match (*D) {
  case { const ObjCInterfaceDecl & } or
       { const ObjCImplementationDecl & } => GenObjCClass(...);
  case { const ObjCCategoryDecl &CD } => GenObjCCategory(...);
  case { const ObjCCategoryImplDecl &CD } => GenObjCCategory(...);
  case { const ObjCProtocolDecl &PD } => GenObjCProtocol(...);
}
```
:::
::::

The discriminator selects and projects the concrete declaration exactly once.

::: {.source-pointer}
Source: [`USRGenerator::VisitObjCContainerDecl`](https://github.com/llvm/llvm-project/blob/e384de31a471b9a496d2a63be9ac51752c18449d/clang/lib/UnifiedSymbolResolution/USRGeneration.cpp#L466)
:::

::: notes
From `USRGenerator::VisitObjCContainerDecl`, commit d4b01025e181. The omitted
handler details are unchanged; this slide isolates the dispatch structure.
:::

## A Closed Subdomain

:::: {.columns}
::: {.column width="40%"}
```cpp
switch (getDeclKind()) {
case Decl::ClassTemplatePartialSpecialization:
  return true;
case Decl::ClassTemplateSpecialization:
  return false;
case Decl::CXXRecord:
  return getDescribedClassTemplate() != nullptr;
default:
  llvm_unreachable("unexpected decl kind");
}
```
:::
::: {.column .fragment width="60%"}
```cpp
return match (*this) {
  case { const ClassTemplatePartialSpecializationDecl & } => true;
  case { const ClassTemplateSpecializationDecl & } => false;
  case { const CXXRecordDecl &D } => D.getDescribedClassTemplate() != nullptr;
};
```
:::
::::

The static type `CXXRecordDecl` narrows the advertised alternatives, making the
match exhaustive without a default.

::: {.source-pointer}
Source: [`CXXRecordDecl::hasInjectedClassType`](https://github.com/llvm/llvm-project/blob/e384de31a471b9a496d2a63be9ac51752c18449d/clang/lib/AST/DeclCXX.cpp#L2165)
:::

::: notes
From `CXXRecordDecl::hasInjectedClassType`, commit d4b01025e181.
:::

## Structure Enables Better Codegen

For eight value cases inside `optional<int>`:

```cpp
if (x == 0) return 42;
else if (x == 1) return 7;
// ...
else if (x == 7) return 4;
```

remains a linear comparison chain with Clang at `-O3`.

::: {.fragment}
```cpp
return match (x) {
  case { 0 } => 42;
  // ...
  case { 7 } => 4;
  case {}    => -1;
  case _     => 0;
};
```

becomes one engagement test and one table lookup at `-O1`.
:::

::: {.source-pointer}
[Compiler Explorer](https://godbolt.org/z/no8aPGvj1)
:::

# Interesting Design Points {.section-divider}

## Applicability in Templates

```cpp
template<class V>
int classify(V value) {
  return match (value) {
    case { int }         => 0;
    case { std::string } => 1;
    case { char }        => 2;
  };
}

classify(std::variant<int, std::string>{42});
//       The char case is omitted.
```

::: {.fragment}
```cpp
classify(std::variant<char, std::string>{'x'});
//       The int case is omitted.
```
:::

- Each projected alternative instantiates only applicable cases
- A case useless in one specialization can be useful in another
- The same useless case is diagnosed for a non-dependent subject

> Think of the braces as a `visit` whose visitor contains a dependent match.

## Declaration or Expression?

```cpp
constexpr int x = 42;
match (value) {
  case int(x) => matched();
  //   ^^^^^^ expression pattern: functional cast
}
```

::: {.fragment}
```cpp
match (function) {
  case int (*f)(double) => use(f);
  //   ^^^^^^^^^^^^^^^^ declaration pattern
}
```
:::

::: {.fragment}
```cpp
match (array) {
  case int (&a)[2] => use(a);
  //   ^^^^^^^^^^^ declaration pattern
}
```
:::

- `int x`, `int& x`, and `int *x` are declaration patterns
- A terminal `int(x)` retains its existing expression meaning
- A following function or array suffix makes the parenthesized declarator a
  declaration

::: notes
This keeps `case bool(expected)` available as a value pattern while supporting
the full declarator forms needed for function pointers and array references.
The distinction follows declarator structure rather than a special case for
pointers or references.
:::

## Coverage Directs Instantiation

```cpp
std::variant<bool, DoSomething> value;

match (value) {
  case { true }  => handle_true();
  case { false } => handle_false();
  case { auto&& object } => object.do_something();
}
```

Usefulness proves that the first two rows cover the complete `bool` domain.
Each handler is instantiated only for projections where its case remains
useful, so the generic handler instantiates only for `DoSomething`.

This ordering matters: instantiating first would reject valid code.

## Usefulness and Exhaustiveness

```cpp
std::variant<bool, std::pair<int, int>> value;

match (value) {
  case { true } => ;
  case { false } => ;
  case { auto [x, y] } => use(x, y);
}
```

One analysis supports:

- redundant-case diagnostics
- missing-case diagnostics
- pruning covered candidate domains
- selecting which handlers are semantically instantiated

## Moves and Guards

```cpp
match (std::move(value)) {
  case Widget owned if (owned.satisfies()) => use(std::move(owned)); // ill-formed
  case _ => fallback();
}
```

A failed guard continues matching, but cannot restore a subject consumed by a
non-trivial move.

::: {.fragment}
```cpp
case Widget&& candidate if (candidate.satisfies()) => use(Widget(std::move(candidate)));
```

References defer the move until the handler is selected.
:::

## Discussion

1. Is the declaration and value-category model recognizably C++?
2. Is non-applicability in dependent matches the right substitution model?
3. Should usefulness control handler instantiation?
4. Are the move-before-guard restrictions at the right boundary?
5. Does the protocol expose enough structure without overfitting library types?

# Backup {.section-divider}

## Closed Alternative Protocol

```cpp
template<class... Ts>
struct alternative_traits<std::variant<Ts...>> {
  static constexpr alternative_info alternatives[] = /* ... */;

  static constexpr auto index(const std::variant<Ts...>& value);

  template<size_t I, class Self>
  static constexpr decltype(auto) get(Self&& value);
};
```

`alternatives` exposes the finite domain. `index` selects a state. `get<I>`
projects it while preserving value category.

## Compiler Pipeline

```text
Parser
  -> pattern AST
  -> candidate planning
  -> applicability and specialization
  -> incremental usefulness analysis
  -> case-local semantic instantiation
  -> normalized pattern matrix
  -> decision tree
  -> LLVM IR
```

The same semantic facts drive diagnostics, template instantiation, and code
generation.

## Decision-Tree Lowering

```text
rows + columns
      |
      v
choose a test from the first useful row
      |
      v
specialize rows for success and failure
      |
      v
DecisionTest / DecisionSuccess / DecisionFailure
```

- Closed discriminators become multiway branches
- Integral value tests can fold into switches
- Guards enter the success continuation
- Shared handlers are emitted once

## Current Status

:::: {.columns}
::: {.column width="50%"}
**Implemented**

- Parser and AST
- Template dependence
- Constant evaluation
- Exhaustiveness and usefulness
- Code generation
- Library protocols
- Self-hosting branch
:::
::: {.column width="50%"}
**Still being refined**

- Protocol surface
- Wording
- Diagnostics and recovery
- Compile-time performance
- Decision-tree optimizations
:::
::::
