---
title: "Structured Bindings as Function Parameters"
document: DXXXXR0
date: today
audience: Evolution
author:
  - name: Michael Park
    email: <mcypark@gmail.com>
toc: true
toc-depth: 4
---

# Introduction

Structured bindings let a declaration name the components of a product instead
of naming the product itself. Function and lambda parameters are a conspicuous
gap: code must introduce a parameter name and then immediately decompose it.

```cpp
auto predicate = [](const auto& item) {
  const auto& [key, value] = item;
  return use(key, value);
};
```

This paper proposes permitting a structured-binding-list in a parameter:

```cpp
auto predicate = [](const auto& [key, value]) {
  return use(key, value);
};
```

This paper is concerned with parameter-position decomposition. A separate note,
[`sb-typed.md`](sb-typed.md), considers typed structured bindings. That facility
is needed to preserve concrete parameter types in ordinary functions and
non-generic lambdas; merely permitting today's `auto` structured bindings as
parameters does not cover those cases.

# Motivation

The parameter name in these examples is representational: `item`, `pair`, or
`entry`. The body immediately replaces it with domain names. Moving the
structured binding into the parameter:

- removes a name that has no semantic role;
- makes the callable's expected product shape visible at its boundary;
- avoids ordinal `std::get<I>` access; and
- makes short range predicates and projections read as expressions rather than
  miniature blocks.

# Surveys

## Chromium

The Chromium checkout at
[commit `45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5`][chromium-commit] was
searched while excluding tests, `third_party`, and build output. The initial
mechanical search found 79 immediate structured-binding declarations across 63
files, 44 lambdas with an explicitly written `std::pair` parameter, 228 generic
lambdas using common pair-like parameter names, and 236 uses of `std::get<I>`.

These are raw counts, not a claim that every occurrence should be rewritten.
Loop-local decompositions, wrapped values, comparators where the whole-object
names remain useful, and one-component projections were excluded from the
examples below.

## LLVM

The LLVM checkout at
[commit `3f226265c84026cbe6965b317757c96989cb6ff8`][llvm-commit] was searched
with the same exclusions. The mechanical search found 162 immediate
structured-binding declarations across 86 production files. Of those, 66
matches in 21 files are generic lambdas whose parameter is immediately
decomposed; 41 occur in LLDB's RISC-V instruction emulator. The broader search
also found 92 explicitly typed `pair` lambdas and 1,377 uses of `get<I>`.

Only four of the 66 generic-lambda matches use the same cv/ref form for the
parameter and the following structured binding. Those four are exact
source-level candidates for the minimal facility described here. Many of the
remaining 62 are still plausible cleanups, but currently take by value or by
forwarding reference and then make a separate by-value decomposition. Folding
those two declarations together would change copy or reference behavior and
therefore depends on additional design decisions.

# Examples

## Map predicate

From [Chromium's `dialog_image_info.cc`][dialog-image-info]:

```cpp
bool BitmapMapsEqual(const UnorderedSizeToBitmap& left,
                     const UnorderedSizeToBitmap& right) {
  return left.size() == right.size() &&
         std::ranges::all_of(left, [&right](const auto& item) {
           const auto& [size, bitmap] = item;
           auto it = right.find(size);
           return it != right.end() && gfx::BitmapsAreEqual(bitmap, it->second);
         });
}
```

With a structured-binding parameter:

```cpp
bool BitmapMapsEqual(const UnorderedSizeToBitmap& left,
                     const UnorderedSizeToBitmap& right) {
  return left.size() == right.size() &&
         std::ranges::all_of(left, [&right](const auto& [size, bitmap]) {
           auto it = right.find(size);
           return it != right.end() && gfx::BitmapsAreEqual(bitmap, it->second);
         });
}
```

## Zipped range

From [Chromium's `permission_service_impl.cc`][permission-service]:

```cpp
bool all_unchanged = std::ranges::all_of(
    std::views::zip(initial_statuses, results), [](const auto& item) {
      const auto& [initial_status, result] = item;
      return initial_status == result.status;
    });
```

With a structured-binding parameter:

```cpp
bool all_unchanged = std::ranges::all_of(
    std::views::zip(initial_statuses, results),
    [](const auto& [initial_status, result]) {
      return initial_status == result.status;
    });
```

This is especially relevant to range adaptors. `zip`, `enumerate`, Cartesian
products, and associative ranges naturally produce tuple-like elements.

## Nontrivial range predicate

From [Chromium's `payments_util.cc`][payments-util]:

```cpp
bool IsCreditCardNumberSupported(
    const std::u16string& card_number,
    const std::vector<std::pair<int, int>>& supported_card_bin_ranges) {
  std::u16string stripped_number = StripCardNumberSeparators(card_number);
  return std::ranges::any_of(supported_card_bin_ranges, [&](const auto& p) {
    auto& [bin_low, bin_high] = p;
    unsigned long range_num_of_digits = base::NumberToString(bin_low).size();
    DCHECK_EQ(range_num_of_digits, base::NumberToString(bin_high).size());
    // The first n digits of credit card number, where n is the number of
    // digits in range's starting/ending number.
    int first_digits_start, first_digits_end;
    base::StringToInt(stripped_number.substr(0, range_num_of_digits),
                      &first_digits_start);
    base::StringToInt(stripped_number.substr(0, range_num_of_digits),
                      &first_digits_end);
    return first_digits_start >= bin_low && first_digits_end <= bin_high;
  });
}
```

With a structured-binding parameter:

```cpp
bool IsCreditCardNumberSupported(
    const std::u16string& card_number,
    const std::vector<std::pair<int, int>>& supported_card_bin_ranges) {
  std::u16string stripped_number = StripCardNumberSeparators(card_number);
  return std::ranges::any_of(
      supported_card_bin_ranges, [&](const auto& [bin_low, bin_high]) {
        unsigned long range_num_of_digits =
            base::NumberToString(bin_low).size();
        DCHECK_EQ(range_num_of_digits, base::NumberToString(bin_high).size());
        // The first n digits of credit card number, where n is the number of
        // digits in range's starting/ending number.
        int first_digits_start, first_digits_end;
        base::StringToInt(stripped_number.substr(0, range_num_of_digits),
                          &first_digits_start);
        base::StringToInt(stripped_number.substr(0, range_num_of_digits),
                          &first_digits_end);
        return first_digits_start >= bin_low && first_digits_end <= bin_high;
      });
}
```

## Validation of a map of aliases

From [Chromium's `local_set_declaration.cc`][local-set-declaration]:

```cpp
if (!std::ranges::all_of(aliases, [&](const auto& p) {
      const auto& [alias_site, canonical_site] = p;
      // The canonical entry must exist.
      if (!entries.contains(canonical_site)) {
        emit(
            "Invalid local Related Website Set: alias names a site that has "
            "no entry in the set.");
        return false;
      }
      // The alias entry must not exist explicitly.
      if (entries.contains(alias_site)) {
        emit(
            "Invalid local Related Website Set: alias site should not be "
            "listed in `entries`.");
        return false;
      }
      return true;
    })) {
  return false;
}
```

With a structured-binding parameter:

```cpp
if (!std::ranges::all_of(
        aliases, [&](const auto& [alias_site, canonical_site]) {
          // The canonical entry must exist.
          if (!entries.contains(canonical_site)) {
            emit(
                "Invalid local Related Website Set: alias names a site that "
                "has no entry in the set.");
            return false;
          }
          // The alias entry must not exist explicitly.
          if (entries.contains(alias_site)) {
            emit(
                "Invalid local Related Website Set: alias site should not be "
                "listed in `entries`.");
            return false;
          }
          return true;
        })) {
  return false;
}
```

## `std::get<I>` on a zip element

From [Chromium's `platform_sensor_fusion.cc`][platform-sensor-fusion]:

```cpp
bool PlatformSensorFusion::IsSignificantlyDifferent(
    const SensorReading& reading1,
    const SensorReading& reading2,
    mojom::SensorType) {
  return std::ranges::any_of(
      std::views::zip(reading1.raw.values, reading2.raw.values),
      [threshold = fusion_algorithm_->threshold()](const auto& pair) {
        return std::fabs(std::get<0>(pair) - std::get<1>(pair)) >= threshold;
      });
}
```

With a structured-binding parameter:

```cpp
bool PlatformSensorFusion::IsSignificantlyDifferent(
    const SensorReading& reading1,
    const SensorReading& reading2,
    mojom::SensorType) {
  return std::ranges::any_of(
      std::views::zip(reading1.raw.values, reading2.raw.values),
      [threshold = fusion_algorithm_->threshold()](
          const auto& [first, second]) {
        return std::fabs(first - second) >= threshold;
      });
}
```

# LLVM Examples

## VPlan enumeration

From [LLVM's `VPlanTransforms.cpp`][vplan-transforms]:

```cpp
if (any_of(enumerate(OpsI),
           [WideMember0, Idx, IsScalable](const auto &P) {
             const auto &[OpIdx, OpV] = P;
             return !canNarrowLoad(
                 WideMember0, Idx, OpV, OpIdx, IsScalable);
           }))
  return false;
```

With a structured-binding parameter:

```cpp
if (any_of(enumerate(OpsI),
           [WideMember0, Idx, IsScalable](const auto &[OpIdx, OpV]) {
             return !canNarrowLoad(
                 WideMember0, Idx, OpV, OpIdx, IsScalable);
           }))
  return false;
```

## Lifetime metadata traversal

From [LLVM's `MemoryTaggingSupport.cpp`][memory-tagging-support]:

```cpp
bool isSupportedLifetime(const AllocaInfo &AInfo, const DominatorTree *DT,
                         const LoopInfo *LI) {
  if (AInfo.LifetimeStart.empty())
    return false;
  SmallVector<BasicBlock *, 2> LastEndBlocks;
  SmallPtrSet<const BasicBlock *, 2> FirstEndBlocks;
  SmallPtrSet<BasicBlock *, 2> StartBlocks;
  for_each(AInfo.BBInfos, [&](const auto &It) {
    const auto &[BB, BBI] = It;
    if (BBI.Last == Intrinsic::lifetime_end)
      LastEndBlocks.append(succ_begin(BB), succ_end(BB));
    else
      StartBlocks.insert(BB);
    if (BBI.First == Intrinsic::lifetime_end)
      FirstEndBlocks.insert(BB);
  });
  if (LastEndBlocks.empty() || FirstEndBlocks.empty())
    return true;
  return !isManyPotentiallyReachableFromMany(LastEndBlocks, FirstEndBlocks,
                                             &StartBlocks, DT, LI);
}
```

With a structured-binding parameter:

```cpp
bool isSupportedLifetime(const AllocaInfo &AInfo, const DominatorTree *DT,
                         const LoopInfo *LI) {
  if (AInfo.LifetimeStart.empty())
    return false;
  SmallVector<BasicBlock *, 2> LastEndBlocks;
  SmallPtrSet<const BasicBlock *, 2> FirstEndBlocks;
  SmallPtrSet<BasicBlock *, 2> StartBlocks;
  for_each(AInfo.BBInfos, [&](const auto &[BB, BBI]) {
    if (BBI.Last == Intrinsic::lifetime_end)
      LastEndBlocks.append(succ_begin(BB), succ_end(BB));
    else
      StartBlocks.insert(BB);
    if (BBI.First == Intrinsic::lifetime_end)
      FirstEndBlocks.insert(BB);
  });
  if (LastEndBlocks.empty() || FirstEndBlocks.empty())
    return true;
  return !isManyPotentiallyReachableFromMany(LastEndBlocks, FirstEndBlocks,
                                             &StartBlocks, DT, LI);
}
```

## Register-definition predicate

From [LLVM's `SIFoldOperands.cpp`][si-fold-operands]:

```cpp
if (!llvm::all_of(llvm::drop_begin(Defs), [&](const auto &Def) {
      const auto &[Op, _] = Def;
      return Op->isReg() && Op->getReg() == FirstReg &&
             Op->getSubReg() == FirstSubReg;
    }))
  return false;
```

With a structured-binding parameter:

```cpp
if (!llvm::all_of(llvm::drop_begin(Defs), [&](const auto &[Op, _]) {
      return Op->isReg() && Op->getReg() == FirstReg &&
             Op->getSubReg() == FirstSubReg;
    }))
  return false;
```

## A large near-match cluster

[LLDB's RISC-V emulator][lldb-riscv-emulator] contains 41 callbacks of this
form:

```cpp
return transformOptional(
           zipOpt(emulator.ReadMem<T>(*addr), inst.rs2.Read(emulator)),
           [&](auto &&tup) {
             auto [tmp, rs2] = tup;
             return emulator.WriteMem<T>(*addr, T(rs2)) &&
                    inst.rd.Write(emulator, extend(tmp));
           })
    .value_or(false);
```

The tempting spelling is:

```cpp
return transformOptional(
           zipOpt(emulator.ReadMem<T>(*addr), inst.rs2.Read(emulator)),
           [&](auto &&[tmp, rs2]) {
             return emulator.WriteMem<T>(*addr, T(rs2)) &&
                    inst.rd.Write(emulator, extend(tmp));
           })
    .value_or(false);
```

However, the original has a forwarding-reference parameter followed by a
by-value decomposition. The shorter form appears to bind the components by
forwarding reference instead. This cluster is strong evidence that the design
must address parameter-object and component-binding semantics separately, but
it is not an exact rewrite under the simplest interpretation.

# Applicability Audit

The Chromium examples and the first three LLVM examples satisfy all of the
following:

- the aggregate parameter is not used after decomposition;
- the decomposition uses the same cv/ref form as the parameter;
- every binding used by the body remains in scope with the same effective
  access; and
- the tuple-like expressions are already proven decomposable by the existing
  declaration.

The LLDB cluster is intentionally identified as a near match rather than an
equivalent rewrite because it currently separates forwarding-reference
parameter passing from by-value component extraction.

# Scope

This facility should preserve the behavior of an ordinary structured-binding
declaration moved to the function boundary. In particular:

- `auto [a, b]` is by value;
- `auto& [a, b]` and `const auto& [a, b]` bind by reference;
- `auto&& [a, b]` retains its forwarding behavior; and
- the tuple-like, array, and direct-member decomposition protocols remain the
  existing structured-binding protocols.

The binding names have function-body scope and do not contribute to the
function type. The implementation may still require an unnamed underlying
parameter object, analogous to the hidden variable of an ordinary structured
binding.

# Relationship to Typed Structured Bindings

The examples above already use generic lambdas, so an `auto`-based parameter
facility is sufficient for them. It is not sufficient for this common shape:

```cpp
void consume(Result result) {
  auto [value, status] = result;
}
```

Writing `void consume(auto [value, status])` would produce an abbreviated
function template, not a function taking `Result`. The same issue arises for
explicitly typed lambdas used for overload sets or callback adaptation.

Those examples motivate the orthogonal typed facility described in
[`sb-typed.md`](sb-typed.md). If both features are adopted, typed structured
bindings should naturally be permitted in parameter position.

# Conclusion

Generic callbacks over product-like range elements repeatedly introduce a
meaningless parameter name only to decompose it on the first line. Structured
bindings in parameter position remove that ceremony and expose the expected
shape at the callable boundary. This is useful independently of typed
structured bindings, while composing naturally with them.

[chromium-commit]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5
[dialog-image-info]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/chrome/browser/web_applications/model/dialog_image_info.cc#14
[permission-service]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/content/browser/permissions/permission_service_impl.cc#97
[payments-util]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/components/autofill/core/browser/payments/payments_util.cc#52
[local-set-declaration]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/net/first_party_sets/local_set_declaration.cc#29
[platform-sensor-fusion]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/services/device/generic_sensor/platform_sensor_fusion.cc#234
[llvm-commit]: https://github.com/llvm/llvm-project/tree/3f226265c84026cbe6965b317757c96989cb6ff8
[vplan-transforms]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/llvm/lib/Transforms/Vectorize/VPlanTransforms.cpp#L3955-L3960
[memory-tagging-support]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/llvm/lib/Transforms/Utils/MemoryTaggingSupport.cpp#L68-L85
[si-fold-operands]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/llvm/lib/Target/AMDGPU/SIFoldOperands.cpp#L2568-L2574
[lldb-riscv-emulator]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/lldb/source/Plugins/Instruction/RISCV/EmulateInstructionRISCV.cpp#L333-L345
