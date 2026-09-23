---
title: "Pattern Matching Usage in LLVM and Clang"
document: D0000R0
date: 2026-08-31
audience: Evolution
author:
  - name: Michael Park
    email: <mcypark@gmail.com>
toc: true
toc-depth: 3
highlighting:
  keywords:
    cpp: ["match"]
---

# Abstract

This is a supporting empirical report for P2688R6, *Pattern Matching: `match`
Expression*.

This report tests the P2688R6 design against a large public C++ codebase by
surveying
[llvm-project revision 52a463254a82be0bcd75f0b7cbfe4728e31c1b26](https://github.com/llvm/llvm-project/tree/52a463254a82be0bcd75f0b7cbfe4728e31c1b26).
The links in this report are commit-pinned source references rather than links
to a moving branch.

# Survey methodology

The corpus contains the non-test `.h`, `.hh`, `.hpp`, `.cc`, `.cpp`, and `.cxx`
files under `clang`, `llvm`, `lld`, and `lldb`. Directories named `test`,
`tests`, `unittests`, and `examples` were excluded. The resulting corpus has
12,366 files and approximately 6.50 million lines. A lexical scanner masked
comments and string and character literals before counting syntax and library
names.

The tables distinguish three kinds of evidence:

- **Lexical counts** count occurrences after masking comments and literals.
- **Reviewed sites** start from a lexical heuristic and were then inspected
  manually.
- **Candidate clusters** are deliberately conservative lower bounds over a
  recognizable source shape. They are not claims that every site should be
  rewritten.

Aliases, helper functions, macros, and project-specific sum types make all of
these counts underestimates of semantic usage. Conversely, a template-id may be
mentioned in declarations or implementation machinery rather than in code
that would benefit from pattern matching.

# Corpus census

| Signal | Count | Interpretation |
|---|---:|---|
| `std::variant<...>` | 115 mentions in 74 files | Closed choice types are present but not dominant |
| `std::visit(...)` | 41 call sites | Direct visitor-replacement candidates |
| `std::get_if<...>` | 132 occurrences | Manual alternative tests and bindings |
| `std::holds_alternative<...>` | 101 occurrences | Type predicates, assertions, and grouped alternatives |
| `std::optional<...>` / `std::nullopt` | 13,503 / 6,469 occurrences | Nullable projection is substantially more common than `variant` dispatch |
| `llvm::Expected<...>` / `llvm::ErrorOr<...>` | 7,830 / 657 occurrences | A customization protocol matters for LLVM-style result types |
| `llvm::PointerUnion<...>` / `PointerSumType<...>` | 239 / 4 occurrences | Other closed choices also need an opt-in path |
| `std::any` | 0 occurrences | Open type erasure is not motivated by this corpus |
| LLVM `dyn_cast` / `dyn_cast_or_null` | 26,502 occurrences | LLVM's class-dispatch protocol dominates C++ RTTI locally |
| C++ `dynamic_cast` | 1 executable occurrence | Built-in polymorphic matching alone reaches little LLVM code |
| Structured bindings | 1,847 declarations | Structural decomposition is already established vocabulary |
| `std::pair<...>` / `std::tuple<...>` / `std::tie(...)` | 6,222 / 515 / 1,794 occurrences | Product values are common subjects for compositional patterns |
| `llvm::StringSwitch<...>` | 865 occurrences | Value dispatch also includes non-integral domains with performance-sensitive implementations |
| `llvm::TypeSwitch<...>` | 22 executable uses | LLVM already provides first-match dynamic type dispatch as a library abstraction |

The 41 `std::visit` calls split into two nearly equal populations:

| Visitor shape | Sites | Expected benefit from `match` |
|---|---:|---|
| One generic operation for every alternative | 21 | Usually modest; the visitor is already concise |
| Explicit overload set | 10 | Strong; declaration arms state the alternatives directly |
| Generic visitor with an `if constexpr` type chain | 5 | Strong; removes recovered-type boilerplate and manual coverage assertions |
| Named or otherwise non-local visitor | 5 | Mixed, but often brings dispatch and behavior back together |

For `std::get_if`, a proximity scan found 29 clusters containing at least two
calls within twelve lines. Manual inspection rejected four accidental
clusters. The remaining 25 clusters contain 90 of the 132 occurrences and
represent 28 actual dispatch sites; several source clusters contain more than
one function. This is a stronger signal than the raw occurrence count: over
two thirds of the `get_if` calls occur in repeated manual dispatch rather than
isolated probing.

# Existing LLVM dispatch abstractions

LLVM does not express all selection directly with `if`, `switch`, or
`std::visit`. It has several declarative library facilities that overlap with
parts of pattern matching. These are important evidence because they show both
which semantics users already rely on and which specialized behavior should
remain outside the core language facility.

## `StringSwitch`

`llvm::StringSwitch` accounts for 865 occurrences in the surveyed corpus. It
performs ordered first-match selection over a `StringRef` and supports:

- exact `Case` matching;
- grouped `Cases` matching;
- case-insensitive matching;
- prefix and suffix matching;
- arbitrary `Predicate` cases; and
- `Default` or `DefaultUnreachable` termination.

For example, Clang groups several option kinds that have the same result
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/clang/utils/TableGen/ClangOptionDocEmitter.cpp#L172-L192)):

::: cmptable

### Before: `StringSwitch`
```cpp
return StringSwitch<unsigned>(optionKind->getName())
    .Cases({"KIND_JOINED", "KIND_JOINED_OR_SEPARATE", "KIND_SEPARATE"}, 1)
    .Cases({"KIND_REMAINING_ARGS", "KIND_REMAINING_ARGS_JOINED",
            "KIND_COMMAJOINED"}, 1)
    .Default(0);
```

### After: `match`
```cpp
return optionKind->getName() match {
  case "KIND_JOINED" || "KIND_JOINED_OR_SEPARATE" || "KIND_SEPARATE"
    => 1;
  case "KIND_REMAINING_ARGS" || "KIND_REMAINING_ARGS_JOINED" ||
       "KIND_COMMAJOINED"
    => 1;
  case _ => 0;
};
```
:::

The direct pattern-matching analogue is a value-producing, ordered selection.
The existing plural `Cases` member is particularly direct evidence for an
or-pattern: without one, every listed string requires a duplicate arm. This
report uses `||` as the hypothetical spelling throughout.

Prefix matching is naturally expressed by binding the string and applying a
guard. For example, lld assigns section-order categories using `StartsWith`
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/lld/wasm/Writer.cpp#L1096-L1112)):

::: cmptable

### Before: `StringSwitch`
```cpp
auto order = [](StringRef name) {
  return StringSwitch<int>(name)
      .StartsWith(".rodata", 0)
      .StartsWith(".data", 1)
      .StartsWith(".tdata", 3)
      .StartsWith(".bss", 4)
      .Default(2);
};
```

### After: `match` with guards
```cpp
auto order = [](StringRef name) {
  return name match {
    case auto&& s if s.starts_with(".rodata") => 0;
    case auto&& s if s.starts_with(".data")   => 1;
    case auto&& s if s.starts_with(".tdata")  => 3;
    case auto&& s if s.starts_with(".bss")    => 4;
    case _ => 2;
  };
};
```
:::

The other `StringSwitch` operations follow the same model:

| `StringSwitch` operation | Pattern-matching form |
|---|---|
| `.EndsWith("coff", value)` | `case auto&& s if s.ends_with("coff") => value` |
| `.CaseLower("json", value)` | `case auto&& s if s.equals_insensitive("json") => value` |
| `.CasesLower({"ld", "ld.lld"}, value)` | One guarded arm whose condition tests either insensitive spelling; an or-pattern over predicate patterns would be a possible future extension |
| `.Predicate(pred, value)` | `case auto&& s if pred(s) => value` |

Suffix matching demonstrates why first-match order remains observable. LLVM
checks `"xcoff"` before `"coff"` because both suffix predicates match the
first spelling
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/TargetParser/Triple.cpp#L720-L730)).

This existing API supports several R6 choices:

- matching is ordered and stops after the first successful case;
- a wildcard arm is required to cover an open string domain;
- grouped cases are sufficiently important to have dedicated library support;
  and
- prefix, suffix, and arbitrary predicate cases can be expressed by a binding
  pattern plus a guard without requiring each predicate form in the pattern
  grammar.

`StringSwitch` also exposes a limitation of a library encoding: every chained
member-call argument is evaluated even after an earlier case has matched,
whereas language handlers naturally provide lazy evaluation and ordinary
control flow.

## `TypeSwitch`

`llvm::TypeSwitch` is an even closer precedent. It performs ordered dispatch by
calling LLVM's `dyn_cast`, passes the refined value to a handler, and supports
both one type and several types in one `Case<T...>`. The surveyed four-project
corpus contains 22 executable uses. A broader textual scan of the same pinned
revision found 329 non-test source lines containing `TypeSwitch<`, including
238 in MLIR, 57 in Flang, 18 in Clang, 13 in LLVM, and 3 in
`clang-tools-extra`.

[`TypeSwitch` is implemented in terms of `dyn_cast`](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/include/llvm/ADT/TypeSwitch.h#L66-L70),
not `dynamic_cast`. The subjects accepted by that one API nevertheless have
materially different shapes:

| Subject family | Runtime model | Pattern-matching consequence |
|---|---|---|
| `llvm::object::Binary` | A root-owned `TypeID` whose values identify concrete binary formats | A closed indexed `alternative_traits` specialization can expose the concrete formats, with an optional residual state for extensions |
| `VPRecipeBase` | A root-owned `VPRecipeTy` identifying concrete recipes, plus overlapping inheritance and mixin views | The concrete tags form a closed primary partition, while types such as `VPHeaderPHIRecipe` and `VPWidenMemoryRecipe` cover several leaves |
| `mlir::Operation` | An extensible registry whose concrete operation types are nullable value-like wrappers around `Operation*` | This is genuinely open and requires type-directed casting rather than finite alternative enumeration |

This distinction matters for both exhaustiveness and implementation. A finite
root discriminator should be read once and can support a switch. A target-side
`classof` predicate alone does not establish a disjoint or complete state set.

The loop vectorizer uses `TypeSwitch` to map recipes to instruction opcodes
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/Transforms/Vectorize/LoopVectorize.cpp#L3191-L3207)):

::: cmptable

### Before: `TypeSwitch`
```cpp
unsigned Opcode = TypeSwitch<const VPRecipeBase*, unsigned>(R)
    .Case([](const VPHeaderPHIRecipe*) { return Instruction::PHI; })
    .Case([](const VPWidenStoreRecipe*) { return Instruction::Store; })
    .Case([](const VPWidenLoadRecipe*) { return Instruction::Load; })
    .Case<VPWidenCallRecipe, VPWidenIntrinsicRecipe>(
        [](const auto*) { return Instruction::Call; });
// Additional cases omitted.
```

### After: `match`
```cpp
unsigned Opcode = *R match {
  case { const VPHeaderPHIRecipe& } => Instruction::PHI;
  case { const VPWidenStoreRecipe& } => Instruction::Store;
  case { const VPWidenLoadRecipe& } => Instruction::Load;
  case { const VPWidenCallRecipe& ||
         const VPWidenIntrinsicRecipe& } => Instruction::Call;
  // ... remaining cases ...
};
```
:::

This is direct evidence for declaration patterns over runtime-refined types,
first-match semantics, and value-producing handlers. It also exposes the
overlapping-view question: `VPHeaderPHIRecipe` is not one concrete recipe tag,
but a base covering a range of concrete tags. A root-level
`alternative_traits<VPRecipeBase>` can advertise the concrete partition, while
the pattern semantics must decide how broader inheritance and mixin views map
onto those alternatives.

The grouped call-recipe arm is independent evidence for or-patterns over
runtime-refined types. Grouped cases whose handler binds and uses values of
different refined types raise an additional design question: an or-pattern
must either provide a coherent dependent binding across its alternatives or
require separate arms.

A `Binary` specialization can instead expose its root discriminator directly:

```cpp
template<>
struct std::alternative_traits<llvm::object::Binary> {
  static constexpr size_t size = /* concrete advertised TypeIDs */;
  static constexpr bool has_residual_states = true;

  static size_t index(const llvm::object::Binary& binary) noexcept {
    return /* normalize binary.getType() */;
  }

  template<size_t I, class Self>
  static decltype(auto) get(Self&& binary) noexcept;
};
```

Here `has_residual_states == true` conservatively preserves an unknown residual
state for future or externally supplied binary kinds. The concrete advertised
states still participate in usefulness analysis and direct indexed dispatch.

That root-level opt-in turns a four-way `dyn_cast` chain in LLVM's
interface-stub reader into a direct selection
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/InterfaceStub/ELFObjHandler.cpp#L689-L706)):

::: cmptable

### Before: `dyn_cast` chain
```cpp
Binary *Bin = BinOrErr->get();
if (auto Obj = dyn_cast<ELFObjectFile<ELF32LE>>(Bin)) {
  return buildStub(*Obj);
} else if (auto Obj = dyn_cast<ELFObjectFile<ELF64LE>>(Bin)) {
  return buildStub(*Obj);
} else if (auto Obj = dyn_cast<ELFObjectFile<ELF32BE>>(Bin)) {
  return buildStub(*Obj);
} else if (auto Obj = dyn_cast<ELFObjectFile<ELF64BE>>(Bin)) {
  return buildStub(*Obj);
}
return createStringError(errc::not_supported, "unsupported binary format");
```

### After: open-sum `match`
```cpp
return *Bin match {
  case { ELFObjectFile<ELF32LE>& Obj ||
         ELFObjectFile<ELF64LE>& Obj ||
         ELFObjectFile<ELF32BE>& Obj ||
         ELFObjectFile<ELF64BE>& Obj } => buildStub(Obj);
  case { _ } =>
    createStringError(errc::not_supported, "unsupported binary format");
};
```
:::

The rewrite makes the first-match dispatch and its result explicit and removes
the repeated cast, test, dereference, and return scaffolding. It is also a
concrete use for an or-pattern that introduces one name with a different type
in each alternative; its handler would be an implicit template region over
the selected `Obj`.

MLIR operations do not fit the current pointer-only open protocol directly.
`dyn_cast<SomeOp>(Operation*)` returns a nullable `SomeOp` wrapper value, not a
`SomeOp*`. The more general rule originally proposed by P3521 works: require a
`try_cast<T>` result to be contextually convertible to `bool` and
dereferenceable. An `alternative_traits<Operation>` adapter can then return
`optional<T>`:

```cpp
template<>
struct std::alternative_traits<mlir::Operation> {
  template<class T, class Self>
  static auto try_cast(Self&& self) noexcept {
    T result = llvm::dyn_cast<T>(std::addressof(self));
    return result ? std::optional<T>(result) : std::nullopt;
  }
};
```

The compiler retains that result through the guard and handler and matches the
declaration against `*result`. Pointers remain the zero-overhead result type
for `any`, `exception_ptr`, and ordinary object casts; value-like wrapper
systems can use `optional<T>` or another nullable dereferenceable result.

`TypeSwitch` does not provide static exhaustiveness. Its
`DefaultUnreachable()` is a runtime assertion, just as
`StringSwitch::DefaultUnreachable()` is. A language match over a closed domain
can provide stronger compile-time checking when its cast protocol exposes the
set of alternatives; an open cast protocol still requires a wildcard arm.

## Related specialized mechanisms

Three other facilities clarify where a general `match` should not absorb
domain-specific behavior:

- [`llvm::StringMatcher`](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/include/llvm/TableGen/StringMatcher.h#L22-L50)
  is a TableGen utility that emits a character-based switch tree for a fixed
  string table. It reinforces the need to preserve semantic dispatch long
  enough to choose an efficient decision tree rather than specifying a linear
  chain as the physical lowering.
- [`mlir::AsmParser::KeywordSwitch`](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/mlir/include/mlir/IR/OpImplementation.h#L859-L906)
  combines token consumption, source locations, diagnostics, and keyword
  dispatch. Its selection surface resembles `StringSwitch`, but its parser
  effects are intentionally more specialized than ordinary value matching.
- [`handleErrors` and `handleAllErrors`](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/include/llvm/Support/Error.h#L987-L1014)
  dispatch typed handlers over consumable error payloads. Unhandled payloads
  may be propagated and an `Error` may contain a list of payloads, so this is
  not first-match selection over one ordinary object. Declaration-pattern
  syntax may look similar, but the ownership and aggregation semantics should
  remain library-specific.

The following rewrites are illustrative applications of the P2688R6 syntax,
not proposed patches to LLVM.

# Replacing a visitor and `if constexpr` chain

The serialization code for a closed artifact variant uses a generic visitor,
recovers the active type with `decltype`, dispatches with `if constexpr`, and
ends with a `static_assert` to enforce coverage ([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/clang/lib/ScalableStaticAnalysis/Core/Serialization/JSONFormat/Artifact.cpp#L188-L208)):

The declaration patterns perform the dispatch and binding directly, while
mandatory exhaustiveness replaces the manual assertion:

::: cmptable

### Before: `std::visit`
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

### After: `match`
```cpp
return artifact match -> llvm::Error {
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

This is a significant improvement over visitor ceremony. By contrast, the
generic operation in LLDB's mutex wrapper
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/lldb/source/API/SBMutex.cpp#L30-L37))
is already compact:

::: cmptable

### Before: Generic visitor
```cpp
std::visit([](auto& mutex) { mutex.lock(); }, variant);
```

### After: Generic projection
```cpp
variant match { case { auto& mutex } => mutex.lock(); };
```
:::

The `match` spelling is more uniform with larger dispatches, but not
substantially shorter.

# Quantifying the need for or-patterns

LLVM has already added library-level or-patterns twice:
`StringSwitch::Cases({s1, s2, ...}, value)` groups string values, while
`TypeSwitch::Case<T1, T2, ...>(handler)` groups runtime-refined types. The
following source-level counts show that the same need extends well beyond
those helper APIs.

The corpus contains 16,270 `switch` statements. Within them, the scanner found
17,230 runs in which two or more consecutive `case` labels share one handler,
covering 96,902 labels in total:

| Labels sharing a handler | Runs |
|---:|---:|
| 2 | 7,213 |
| 3 | 2,916 |
| 4 | 1,990 |
| 5 | 1,034 |
| 6 or more | 4,077 |

There can be several such runs in one switch. The runs are distributed across
all four surveyed projects: 10,577 in `llvm`, 5,039 in `clang`, 1,119 in
`lldb`, and 495 in `lld`. A deterministic sample of 30 runs was manually
reviewed; all 30 were genuine grouped labels rather than lexical false
positives. Representative cases include grouping `And`, `Or`, and `Xor` in the
IR verifier
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/IR/Verifier.cpp#L4361-L4368))
and grouping several DWARF modifier tags in local transformation utilities
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/Transforms/Utils/Local.cpp#L1784-L1794)).

This is not evidence that 17,230 switches should be rewritten. It is evidence
that a pattern selection intended to subsume `switch` needs a non-duplicating
way to preserve its most common fallthrough idiom. Separate arms with repeated
handlers are a material regression in source quality.

The need also appears directly in variant predicates. Manual review found six
positive two-alternative `holds_alternative<A>(x) ||
holds_alternative<B>(x)` tests and two equivalent negated tests. For example,
LLDB classifies two load-reserve alternatives identically
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/lldb/source/Plugins/Instruction/RISCV/EmulateInstructionRISCV.h#L35-L43)):

::: cmptable

### Before: Boolean type predicates
```cpp
static bool FoundLoadReserve(const RISCVInst& inst) {
  return std::holds_alternative<LR_W>(inst) ||
         std::holds_alternative<LR_D>(inst);
}
```

### After: Or-pattern
```cpp
static bool FoundLoadReserve(const RISCVInst& inst) {
  return inst match case { LR_W || LR_D };
}
```
:::

An or-pattern preserves the grouped decision and remains composable inside a
larger pattern.

The count therefore supports or-patterns as a high-priority extension. The
remaining design questions are not trivial. `||` is also an operator inside a
constant-expression pattern, so the grammar must distinguish one logical-or
expression from two patterns. Alternatives that introduce names must also
agree on which names exist and on their types, value categories, and
initialization semantics. The evidence establishes the need, not the final
grammar or binding model.

# Composing optional, variant, and value matching

An LLDB response message is an `optional<variant<ResponseMessage, String>>`.
The implementation tests the optional, selects the active variant alternative,
and then switches on the enum value ([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/lldb/tools/lldb-dap/Protocol/ProtocolBase.cpp#L123-L146)).
The full decision can be written as one compositional pattern selection:

::: cmptable

### Before: Nested optional, variant, and switch
```cpp
if (response.message) {
  if (const auto* message =
          std::get_if<ResponseMessage>(&*response.message)) {
    switch (*message) {
      case eResponseMessageCancelled:
        result.insert({"message", "cancelled"});
        break;
      case eResponseMessageNotStopped:
        result.insert({"message", "notStopped"});
        break;
    }
  } else if (const auto* message =
                 std::get_if<String>(&*response.message)) {
    result.insert({"message", *message});
  }
}
```

### After: Composed patterns
```cpp
response.message match {
  case { { eResponseMessageCancelled } }
    => result.insert({"message", "cancelled"});
  case { { eResponseMessageNotStopped } }
    => result.insert({"message", "notStopped"});
  case { { const String& message } }
    => result.insert({"message", message});
  case {} => ;
};
```
:::

The outer braces project the optional value. The inner braces project the
variant alternative. The enum constants and declaration then operate on that
projected subject. This example demonstrates the composability objective, but
also exposes a syntax concern discussed below: repeated braces are precise but
visually dense.

# Replacing a multi-dimensional condition table

A deliberately narrow search found 337 single-line `else if` rows that test at
least two dimensions with equality and `&&`. Grouping nearby rows produced 44
candidate decision tables in 30 files. This excludes multiline rows and tables
using inequalities, helper predicates, or nested control flow, so it is a lower
bound; unlike the grouped-switch count, it remains a heuristic. Individual
two-comparison conditions were not counted as benefits because replacing one
ordinary `if` with a tuple match is often worse.

LLVM's X86 intrinsic upgrader contains a long `if`/`else if` table over vector
width, element width, and whether the element type is floating point
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/IR/AutoUpgrade.cpp#L2434-L2478)).
Matching a tuple makes the state space explicit:

::: cmptable

### Before: Multi-dimensional condition chain
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

### After: Product and value patterns
```cpp
tuple{vectorWidth, elementWidth, isFloat} match {
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

This use does not involve a sum type. Structural and value patterns flatten a
nested Boolean decision tree into a table whose dimensions are visible in each
arm.

# Matching two choice values

WebAssembly assembly type checking compares two variants. The implementation
tests for wildcard alternatives, swaps the operands to normalize one case, and
then extracts another alternative ([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/Target/WebAssembly/AsmParser/WebAssemblyAsmTypeCheck.cpp#L71-L87)).
A tuple of references exposes the Cartesian cases directly:

::: cmptable

### Before: Manual normalization and extraction
```cpp
if (typeA == typeB)
  return false;
if (std::get_if<Any>(&typeA) || std::get_if<Any>(&typeB))
  return false;

if (std::get_if<Ref>(&typeB))
  std::swap(typeA, typeB);
assert(std::get_if<wasm::ValType>(&typeB));
if (std::get_if<Ref>(&typeA) &&
    WebAssembly::isRefType(std::get<wasm::ValType>(typeB)))
  return false;
return true;
```

### After: Product of choice patterns
```cpp
if (typeA == typeB)
  return false;

return tie(typeA, typeB) match {
  case [{ Any }, _] => false;
  case [_, { Any }] => false;
  case [{ Ref }, { wasm::ValType type }]
    if (WebAssembly::isRefType(type)) => false;
  case [{ wasm::ValType type }, { Ref }]
    if (WebAssembly::isRefType(type)) => false;
  case _ => true;
};
```
:::

No dedicated multi-subject grammar is required, and the normalization swap is
eliminated.

# Mixing dispatch with enclosing control flow

Clang's dependency-scanning cache returns a variant containing either a
resolved entry or ownership of an in-progress producer. The resolved case
returns from the enclosing function; the producer case initializes a local
value ([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/clang/lib/DependencyScanning/DependencyScanningFilesystem.cpp#L235-L246)):

Handlers that participate in ordinary C++ control flow allow the dispatch and
initialization to remain one expression:

::: cmptable

### Before: Probe, return, then extract
```cpp
if (auto* resolved = std::get_if<SlotResolved>(&slot)) {
  assert(*resolved && **resolved);
  return **resolved;
}
auto producer = std::move(std::get<SlotProducer>(slot));
```

### After: Match with enclosing return
```cpp
auto producer = std::move(slot) match {
  case { SlotResolved resolved } => do {
    assert(resolved && *resolved);
    return *resolved;
  };
  case { SlotProducer producer } => std::move(producer);
};
```
:::

This is difficult to express with `std::visit` because one alternative exits
the surrounding function while the other contributes the initializer.

A supplemental example from MLIR, outside the four-project census above,
shows the same issue for loop control. Its template renderer manually probes
each bytecode alternative and uses `continue` to finish the current iteration
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/mlir/lib/Target/IRDLToCpp/TemplatingUtils.h#L53-L74)):

::: cmptable

### Before: Probe alternatives and continue
```cpp
for (auto instruction : bytecode) {
  if (auto* inst = std::get_if<LiteralToken>(&instruction)) {
    out << inst->text;
    continue;
  }

  if (auto* inst = std::get_if<ReplacementToken>(&instruction)) {
    auto replacement = replacements.find(inst->keyName);
#ifndef NDEBUG
    if (replacement == replacements.end()) {
      llvm::errs() << "Missing template key: " << inst->keyName << "\n";
      llvm_unreachable("Missing template key");
    }
#endif
    out << replacement->second;
    continue;
  }

  llvm_unreachable("non-exhaustive bytecode visit");
}
```

### After: Exhaustive match in the loop
```cpp
for (auto instruction : bytecode) {
  instruction match {
    case { LiteralToken& inst } => out << inst.text;
    case { ReplacementToken& inst } => do {
      auto replacement = replacements.find(inst.keyName);
#ifndef NDEBUG
      if (replacement == replacements.end()) {
        llvm::errs() << "Missing template key: " << inst.keyName << "\n";
        llvm_unreachable("Missing template key");
      }
#endif
      out << replacement->second;
    };
  };
}
```
:::

Here ordinary completion of either arm advances the loop, so both explicit
`continue` statements disappear. Exhaustiveness also replaces the manually
maintained `llvm_unreachable`. If an arm instead needed to skip code following
the match or terminate the loop, it could directly use `continue` or `break`;
there is no visitor-lambda boundary to cross.

# Composing binding conditions

LLVM also contains nested optional projections where the second computation
depends on the first. For example, object-size analysis first obtains an
`APInt` and then asks whether it can be represented as `uint64_t`
([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/Analysis/MemoryBuiltins.cpp#L627-L632)):

Conjoined `case` conditions preserve the dependency without nesting:

::: cmptable

### Before: Nested optional conditions
```cpp
if (optional<APInt> size = getAllocSize(call, TLI)) {
  if (optional<uint64_t> extended = size->tryZExtValue())
    return TypeSize::getFixed(*extended);
}
```

### After: Conjoined binding conditions
```cpp
if (case { const APInt& size } = getAllocSize(call, TLI) &&
    case { uint64_t extended } = size.tryZExtValue())
  return TypeSize::getFixed(extended);
```
:::

# Further direct applications

The survey found several other direct applications with the same character:

| Source | Existing structure | Benefit from `match` |
|---|---|---|
| [Clang HLSL root-signature validation](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/clang/lib/Sema/SemaHLSL.cpp#L1557-L1603) | Long `get_if` chain over six root-element alternatives | Exhaustive arms bind each payload without repeating the variant subject |
| [LLDB breakpoint-result response](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/lldb/source/Plugins/Process/gdb-remote/GDBRemoteCommunicationServerLLGS.cpp#L3156-L3173) | Generic visitor, recovered type, `static_assert`, and `if constexpr` chain | Three declaration arms directly return the corresponding protocol response |
| [LLVM TableGen DFA action printing](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/utils/TableGen/DFAEmitter.cpp#L340-L353) | `get_if` chain followed by unchecked `get` in the final branch | Exhaustive alternatives remove the implicit assumption in the final `else` |
| [LLDB MCP identifier encoding](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/lldb/source/Protocol/MCP/Protocol.cpp#L33-L39) | Two `get_if` tests followed by `llvm_unreachable` | An exhaustive value-producing selection has no manual unreachable state |

# Priorities implied by the survey

The evidence suggests the following order of importance for the language
design. The ranking considers both frequency and whether pattern matching
provides a material improvement over existing C++.

| Priority | Design capability | Evidence |
|---:|---|---|
| 1 | Closed-choice declaration patterns with mandatory coverage | 20 alternative-specific visitors and 28 reviewed manual `get_if` dispatch sites |
| 2 | Or-patterns | 17,230 grouped switch-label runs, eight direct variant disjunction predicates, and grouped cases in `StringSwitch` and `TypeSwitch` |
| 3 | Composable structural and value patterns | At least 44 multi-dimensional decision-table clusters, plus pervasive pair, tuple, and structured-binding use |
| 4 | Nullable and user-defined choice customization | 13,503 `optional`, 7,830 `Expected`, 657 `ErrorOr`, and 239 `PointerUnion` mentions |
| 5 | An explicit opt-in cast protocol beyond C++ RTTI | 26,502 LLVM `dyn_cast` calls, at least 2,569 single-line `else if` continuation arms, and existing `TypeSwitch` use |
| 6 | Open type-erased choice matching | No `std::any` occurrence in this corpus; useful in general, but not supported by LLVM-specific evidence |

The first, third, and fourth items reinforce the current R6 direction. The
second motivates or-patterns as a high-priority addition. The fifth should not
change the semantics of built-in braced polymorphic patterns: those should
continue to mean `dynamic_cast`. It instead motivates a distinct customization point
for ecosystems with their own RTTI. The sixth is a warning against letting the
open-choice design dominate the syntax or implementation complexity.

# Design pressure exposed by LLVM

The survey also identifies places where the current proposal is incomplete or
provides only a modest improvement.

1. **LLVM-style RTTI is outside the current model.** The masked scan found
   26,502 `dyn_cast` or `dyn_cast_or_null` calls, but only one executable
   `dynamic_cast` occurrence. A conservative single-line search also found
   2,569 `else if` continuation arms containing `dyn_cast`, and LLVM already
   packages the same operation as `TypeSwitch`. Chains such as lld's
   dispatch over `DefinedFunction`, `DefinedGlobal`, `DefinedTag`, and
   `DefinedData` ([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/lld/wasm/Writer.cpp#L833-L860))
   resemble class patterns, but LLVM's `classof` protocol is not C++ RTTI.
   Braced dynamic class semantics should continue to follow `dynamic_cast`; making
   this code matchable would require a separate explicit opt-in cast protocol.

2. **Repeated projection braces can become noisy.** The LLDB response example
   requires `{ { P } }` for `optional<variant<...>>`. Named views can improve
   some cases, but the customization and provider-mixing rules must remain
   understandable.

3. **The absence of or-patterns causes duplication.** The 17,230 grouped-label
   runs quantify an idiom that `switch` already handles well but separate
   `match` arms do not. LLVM also frequently groups several alternatives with
   identical behavior. For example,
   three versions of DirectX runtime information return the same member
   ([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/Object/DXContainer.cpp#L919-L946)).
   Without a binding-preserving or-pattern, each type needs a separate arm.

4. **Correlated choice alternatives are difficult to state.** LLVM's
   `DenseMapInfo<variant<...>>::isEqual` first proves that two variants have the
   same index, then erases one payload to `void*` so the other dispatch can
   recover the common type ([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/include/llvm/ADT/DenseMapInfoVariant.h#L40-L56)).
   A pattern cannot currently bind the first payload and use its type to declare
   a sibling pattern in the same pattern. Nested matches can express the
   operation, but the direct relational form remains unavailable.

5. **Many LLVM sum-like abstractions are not `std::variant`.** The corpus has
   7,830 `Expected`, 657 `ErrorOr`, and 239 `PointerUnion` mentions. APIs based
   on `getAs<T>()` are also common. Their usefulness as pattern subjects
   depends on `alternative_traits` being a sufficiently small and practical
   opt-in protocol.

6. **Simple generic visits are not a major syntax win.** One-arm visitors such
   as the mutex example above, or the forwarding visitors in LLVM's special
   case list ([source](https://github.com/llvm/llvm-project/blob/52a463254a82be0bcd75f0b7cbfe4728e31c1b26/llvm/lib/Support/SpecialCaseList.cpp#L264-L269)),
   are already concise. The value of `match` in those cases is consistency with
   larger selections and language-level coverage, not line-count reduction.

7. **Physical dispatch remains an implementation question.** These examples
   justify preserving alternative dispatch semantically, but do not imply that
   every match should lower to a linear chain. A production implementation
   should retain enough semantic structure for a decision-DAG lowering to
   choose between direct branches, switches, jump tables, and outlined
   dispatch after inlining and profile information are available.
