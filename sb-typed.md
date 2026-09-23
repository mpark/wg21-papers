---
title: "Typed Structured Bindings"
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

Structured bindings currently require a placeholder type:

```cpp
auto [value, status] = expression;
const auto& [key, mapped] = entry;
```

This couples two independent choices: decomposing an object and deducing the
type of that object. There is no way to request decomposition while explicitly
stating the type of the underlying object.

This note explores typed structured bindings, using `T [a, b]` as illustrative
syntax:

```cpp
Result [value, status] = expression;
const Entry& [key, mapped] = expression;
```

Function parameters provide particularly strong motivation. A parameter must
contribute a type to the function type, overload set, and ABI. Merely allowing
an `auto` structured binding in a parameter would turn an ordinary function
into a function template and a typed lambda into a generic lambda.

This note is complementary to [`sb-param.md`](sb-param.md), which covers the
orthogonal act of permitting structured bindings in parameter position.

# Why `auto` Parameters Are Not Enough

Consider:

```cpp
void consume(Result result) {
  auto [value, status] = result;
}
```

The desired refactoring is:

```cpp
void consume(Result [value, status]) {
}
```

It is not:

```cpp
void consume(auto [value, status]) {
}
```

The latter is an abbreviated function template. It accepts every decomposable
two-element type for which the body is valid, changes overload resolution and
symbol generation, and cannot directly replace an override or a callback with
a fixed signature.

Similarly:

```cpp
[](const std::pair<A, B>& pair) {
  return use(pair.first, pair.second);
}
```

cannot in general become a `const auto&` structured-binding lambda. A generic
lambda may interact differently with overload sets and callable constraints.
The explicit pair type is part of the program.

# Survey Evidence

The Chromium examples below come from
[commit `45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5`][chromium-commit]. The LLVM
examples come from
[commit `3f226265c84026cbe6965b317757c96989cb6ff8`][llvm-commit]. Tests,
third-party code, and build output were excluded from both surveys.

The LLVM search found 162 immediate structured-binding declarations across 86
production files, 92 explicitly typed `pair` lambdas, and 1,377 uses of
`get<I>`. Manual review found at least twelve clear named-function definitions
where a concrete parameter is immediately decomposed or accessed exclusively
through its components. These are a conservative lower bound, not a count of
every candidate in the broader syntactic pools.

# Chromium Examples

## An ordinary member function

From [Chromium's `textfield.cc`][textfield]:

```cpp
void Textfield::OnTextCommandExecuted(gfx::SelectionModel selection_model,
                                      Textfield::EditCommandResult result) {
  auto [text_changed, cursor_changed] = result;
  cursor_changed |= (GetSelectionModel() != selection_model);
  if (cursor_changed && HasSelection()) {
    UpdateSelectionClipboard();
  }
  UpdateAfterChange(
      text_changed ? TextChangeType::kUserTriggered : TextChangeType::kNone,
      cursor_changed);
  OnAfterUserAction();
}
```

With a typed structured-binding parameter:

```cpp
void Textfield::OnTextCommandExecuted(
    gfx::SelectionModel selection_model,
    Textfield::EditCommandResult [text_changed, cursor_changed]) {
  cursor_changed |= (GetSelectionModel() != selection_model);
  if (cursor_changed && HasSelection()) {
    UpdateSelectionClipboard();
  }
  UpdateAfterChange(
      text_changed ? TextChangeType::kUserTriggered : TextChangeType::kNone,
      cursor_changed);
  OnAfterUserAction();
}
```

The declaration in the class can remain `void OnTextCommandExecuted(
gfx::SelectionModel, EditCommandResult);`: the underlying parameter type is
unchanged, and the binding names belong only to the definition.

## A function template with one non-deduced product parameter

From [Chromium's `normalization.h`][gamepad-normalization]:

```cpp
template <class T>
double NormalizeGamepadAxis(T value, const GamepadLogicalBounds& bounds) {
  const auto& [minimum, maximum] = bounds;
  if (minimum == maximum) {
    return 0.0;
  }
  return (2.0 * (value - minimum) / (maximum - minimum)) - 1.0;
}

template <class T>
double NormalizeGamepadButton(T value, const GamepadLogicalBounds& bounds) {
  const auto& [minimum, maximum] = bounds;
  if (minimum == maximum) {
    return 0.0;
  }
  return (value - minimum) / (maximum - minimum);
}
```

With typed structured-binding parameters:

```cpp
template <class T>
double NormalizeGamepadAxis(
    T value, const GamepadLogicalBounds& [minimum, maximum]) {
  if (minimum == maximum) {
    return 0.0;
  }
  return (2.0 * (value - minimum) / (maximum - minimum)) - 1.0;
}

template <class T>
double NormalizeGamepadButton(
    T value, const GamepadLogicalBounds& [minimum, maximum]) {
  if (minimum == maximum) {
    return 0.0;
  }
  return (value - minimum) / (maximum - minimum);
}
```

Only `T` is intended to be deduced. The second parameter deliberately remains
`GamepadLogicalBounds`.

## Preserving a named product type

From [Chromium's `d3d12_video_processor_wrapper.cc`][d3d12-processor]:

```cpp
bool D3D12VideoProcessorWrapper::Wait(D3D12FenceAndValue fence_and_value) {
  auto [fence, value] = fence_and_value;
  CHECK(fence);
  HRESULT hr = command_queue_->Wait(fence.Get(), value);
  if (FAILED(hr)) {
    DLOG(ERROR) << "D3D12 video process command queue wait failed: "
                << logging::SystemErrorCodeToString(hr);
    return false;
  }
  return true;
}
```

With a typed structured-binding parameter:

```cpp
bool D3D12VideoProcessorWrapper::Wait(
    D3D12FenceAndValue [fence, value]) {
  CHECK(fence);
  HRESULT hr = command_queue_->Wait(fence.Get(), value);
  if (FAILED(hr)) {
    DLOG(ERROR) << "D3D12 video process command queue wait failed: "
                << logging::SystemErrorCodeToString(hr);
    return false;
  }
  return true;
}
```

## Ownership-bearing parameters

From [Chromium's `votes_uploader.cc`][votes-uploader]:

```cpp
void VotesUploader::OnFieldTypesDetermined(
    base::TimeTicks initial_interaction_timestamp,
    base::TimeTicks submission_timestamp,
    bool observed_submission,
    ukm::SourceId ukm_source_id,
    std::pair<std::unique_ptr<FormStructure>,
              std::vector<AutofillUploadContents>> form_and_upload_contents) {
  auto& [form, upload_contents] = form_and_upload_contents;
  LocalFrameToken frame = form->global_id().frame_token;
  WipePendingVotesForForm(form->form_signature());
  if (observed_submission) {
    UploadVote(std::move(form), std::move(upload_contents),
               initial_interaction_timestamp, submission_timestamp,
               observed_submission, ukm_source_id);
    FlushPendingVotesForFrame(frame);
  } else {
    FlushOldestPendingVotesIfNecessary();
    pending_votes_.push_front(
        {.frame_of_form = frame,
         .form_signature = form->form_signature(),
         .upload_vote = base::BindOnce(
             &VotesUploader::UploadVote, weak_ptr_factory_.GetWeakPtr(),
             std::move(form), std::move(upload_contents),
             initial_interaction_timestamp, submission_timestamp,
             observed_submission, ukm_source_id)});
  }
}
```

With a typed structured-binding parameter:

```cpp
void VotesUploader::OnFieldTypesDetermined(
    base::TimeTicks initial_interaction_timestamp,
    base::TimeTicks submission_timestamp,
    bool observed_submission,
    ukm::SourceId ukm_source_id,
    std::pair<std::unique_ptr<FormStructure>,
              std::vector<AutofillUploadContents>> [form, upload_contents]) {
  LocalFrameToken frame = form->global_id().frame_token;
  WipePendingVotesForForm(form->form_signature());
  if (observed_submission) {
    UploadVote(std::move(form), std::move(upload_contents),
               initial_interaction_timestamp, submission_timestamp,
               observed_submission, ukm_source_id);
    FlushPendingVotesForFrame(frame);
  } else {
    FlushOldestPendingVotesIfNecessary();
    pending_votes_.push_front(
        {.frame_of_form = frame,
         .form_signature = form->form_signature(),
         .upload_vote = base::BindOnce(
             &VotesUploader::UploadVote, weak_ptr_factory_.GetWeakPtr(),
             std::move(form), std::move(upload_contents),
             initial_interaction_timestamp, submission_timestamp,
             observed_submission, ukm_source_id)});
  }
}
```

The parameter remains by value, and the individual bindings remain movable.

## Explicitly typed lambdas

From [Chromium's `permission_overrides.cc`][permission-overrides]:

```cpp
return std::visit(
    absl::Overload(
        [](const GlobalKey& global_key) {
          return std::make_pair(ContentSettingsPattern::Wildcard(),
                                ContentSettingsPattern::Wildcard());
        },
        [](const url::Origin& origin) {
          return std::make_pair(
              ContentSettingsPattern::Wildcard(),
              ContentSettingsPattern::FromURLNoWildcard(origin.GetURL()));
        },
        [](const std::pair<net::SchemefulSite, net::SchemefulSite>& key) {
          return std::make_pair(
              ContentSettingsPattern::FromURLToSchemefulSitePattern(
                  key.first.GetURL()),
              ContentSettingsPattern::FromURLToSchemefulSitePattern(
                  key.second.GetURL()));
        },
        [](const std::pair<url::Origin, net::SchemefulSite>& key) {
          return std::make_pair(
              ContentSettingsPattern::FromURLNoWildcard(key.first.GetURL()),
              ContentSettingsPattern::FromURLToSchemefulSitePattern(
                  key.second.GetURL()));
        }),
    scope_);
```

With typed structured-binding parameters:

```cpp
return std::visit(
    absl::Overload(
        [](const GlobalKey& global_key) {
          return std::make_pair(ContentSettingsPattern::Wildcard(),
                                ContentSettingsPattern::Wildcard());
        },
        [](const url::Origin& origin) {
          return std::make_pair(
              ContentSettingsPattern::Wildcard(),
              ContentSettingsPattern::FromURLNoWildcard(origin.GetURL()));
        },
        [](const std::pair<net::SchemefulSite, net::SchemefulSite>&
               [first_site, second_site]) {
          return std::make_pair(
              ContentSettingsPattern::FromURLToSchemefulSitePattern(
                  first_site.GetURL()),
              ContentSettingsPattern::FromURLToSchemefulSitePattern(
                  second_site.GetURL()));
        },
        [](const std::pair<url::Origin, net::SchemefulSite>& [origin, site]) {
          return std::make_pair(
              ContentSettingsPattern::FromURLNoWildcard(origin.GetURL()),
              ContentSettingsPattern::FromURLToSchemefulSitePattern(
                  site.GetURL()));
        }),
    scope_);
```

Changing these alternatives to `const auto&` would make both lambdas generic,
destroying the type-based overload set.

From [Chromium's `form_filler.cc`][form-filler], another `std::visit` overload
selects a concrete pair alternative and then accesses both of its members:

```cpp
[&](const AugmentedFillingPayload::EntityPayload&
        entity_and_fields_and_types) {
  const EntityInstance& entity =
      CHECK_DEREF(entity_and_fields_and_types.first);
  const std::vector<AutofillFieldWithAttributeType>& fields =
      entity_and_fields_and_types.second;
  return GetFillingValueAndTypeForEntity(
      entity, fields, field, action_persistence,
      manager_->client().GetAppLocale(),
      manager_->client().GetAddressNormalizer());
}
```

`EntityPayload` is an alias for
`std::pair<const EntityInstance*,
std::vector<AutofillFieldWithAttributeType>>`. With a typed
structured-binding parameter, the overload still selects exactly that variant
alternative while naming its components directly:

```cpp
[&](const AugmentedFillingPayload::EntityPayload& [entity_ptr, fields]) {
  const EntityInstance& entity = CHECK_DEREF(entity_ptr);
  return GetFillingValueAndTypeForEntity(
      entity, fields, field, action_persistence,
      manager_->client().GetAppLocale(),
      manager_->client().GetAddressNormalizer());
}
```

From [Chromium's `btm_bounce_detector.cc`][btm-bounce-detector], two visitor
overloads take the same concrete pair by value and immediately bind references
to its elements. The first is:

```cpp
[&](std::pair<GURL, ukm::SourceId>
        previous_nav_last_committed_url_and_source_id) {
  auto& [url, source_id] =
      previous_nav_last_committed_url_and_source_id;
  BtmRedirectContext temp_context(
      handler_, issue_handler_, are_3pcs_generally_enabled_callback_,
      url, source_id,
      /*redirect_prefix_count=*/0);
  temp_context.AppendServerRedirects(std::move(server_redirects));
  temp_context.ReportIssue(
      /*final_url=*/url);
  temp_context.EndChain(
      /*final_url=*/url,
      /*final_source_id=*/source_id,
      /*current_page_has_interaction=*/false);
}
```

The second is:

```cpp
[this, current_page_has_interaction](
    std::pair<GURL, ukm::SourceId>
        previous_nav_last_committed_url_and_source_id) {
  auto& [url, source_id] =
      previous_nav_last_committed_url_and_source_id;
  EndChain(url, source_id, current_page_has_interaction);
}
```

Both become direct by-value typed structured-binding parameters:

```cpp
[&](std::pair<GURL, ukm::SourceId> [url, source_id]) {
  BtmRedirectContext temp_context(
      handler_, issue_handler_, are_3pcs_generally_enabled_callback_,
      url, source_id,
      /*redirect_prefix_count=*/0);
  temp_context.AppendServerRedirects(std::move(server_redirects));
  temp_context.ReportIssue(
      /*final_url=*/url);
  temp_context.EndChain(
      /*final_url=*/url,
      /*final_source_id=*/source_id,
      /*current_page_has_interaction=*/false);
}

[this, current_page_has_interaction](
    std::pair<GURL, ukm::SourceId> [url, source_id]) {
  EndChain(url, source_id, current_page_has_interaction);
}
```

Here the written pair type is important: each lambda is one arm of an overload
set and must continue to accept only that variant alternative.

## Explicitly typed range projections

From [Chromium's `address_form_data_importer.cc`][address-form-data-importer]:

```cpp
return base::MakeFlatMap<FieldType, std::u16string>(
    preceding_values, {},
    [](const std::pair<FieldType, ValueForImport>& p) {
      return std::make_pair(p.first, p.second.value_for_import);
    });
```

With a typed structured-binding parameter:

```cpp
return base::MakeFlatMap<FieldType, std::u16string>(
    preceding_values, {},
    [](const std::pair<FieldType, ValueForImport>& [type, value]) {
      return std::make_pair(type, value.value_for_import);
    });
```

# LLVM Examples

## A named MLIR helper

From [LLVM's `ExtractSliceFromReshapeUtils.cpp`][extract-slice]:

```cpp
static ValueRange invertCollapseShapeIndexing(
    OpBuilder &b, Location loc, ArrayRef<ReassociationIndices> reassociation,
    ArrayRef<OpFoldResult> reshapeSourceShape, const DimAndIndex &dimAndIndex) {
  const auto &[dim, indexValue] = dimAndIndex;
  SmallVector<OpFoldResult> basis;
  for (int64_t i : reassociation[dim])
    basis.push_back(reshapeSourceShape[i]);
  auto delinearized =
      AffineDelinearizeIndexOp::create(b, loc, indexValue, basis);
  return delinearized->getResults();
}
```

With a typed structured-binding parameter:

```cpp
static ValueRange invertCollapseShapeIndexing(
    OpBuilder &b, Location loc, ArrayRef<ReassociationIndices> reassociation,
    ArrayRef<OpFoldResult> reshapeSourceShape,
    const DimAndIndex &[dim, indexValue]) {
  SmallVector<OpFoldResult> basis;
  for (int64_t i : reassociation[dim])
    basis.push_back(reshapeSourceShape[i]);
  auto delinearized =
      AffineDelinearizeIndexOp::create(b, loc, indexValue, basis);
  return delinearized->getResults();
}
```

## A typed data-structure member

From [LLVM's `OutlinedHashTree.cpp`][outlined-hash-tree]:

```cpp
void OutlinedHashTree::insert(const HashSequencePair &SequencePair) {
  auto &[Sequence, Count] = SequencePair;
  HashNode *Current = getRoot();

  for (stable_hash StableHash : Sequence) {
    auto I = Current->Successors.find(StableHash);
    if (I == Current->Successors.end()) {
      std::unique_ptr<HashNode> Next = std::make_unique<HashNode>();
      HashNode *NextPtr = Next.get();
      NextPtr->Hash = StableHash;
      Current->Successors.try_emplace(StableHash, std::move(Next));
      Current = NextPtr;
    } else
      Current = I->second.get();
  }
  if (Count)
    Current->Terminals = Current->Terminals.value_or(0) + Count;
}
```

With a typed structured-binding parameter:

```cpp
void OutlinedHashTree::insert(const HashSequencePair &[Sequence, Count]) {
  HashNode *Current = getRoot();

  for (stable_hash StableHash : Sequence) {
    auto I = Current->Successors.find(StableHash);
    if (I == Current->Successors.end()) {
      std::unique_ptr<HashNode> Next = std::make_unique<HashNode>();
      HashNode *NextPtr = Next.get();
      NextPtr->Hash = StableHash;
      Current->Successors.try_emplace(StableHash, std::move(Next));
      Current = NextPtr;
    } else
      Current = I->second.get();
  }
  if (Count)
    Current->Terminals = Current->Terminals.value_or(0) + Count;
}
```

## Repeated six-element parameters

From [LLVM's `CombinerHelper.cpp`][combiner-helper]:

```cpp
bool CombinerHelper::matchCombineMemCpyFamily(
    MachineInstr &MI, MemCpyFamilyLoweringInfo &MatchInfo,
    unsigned MaxLen) const {
  auto &[Dst, Src, KnownLen, Alignment, DstAlignCanChange, MemOps] = MatchInfo;
  return canLowerMemCpyFamily(MI, MRI, MaxLen, Dst, Src, KnownLen, Alignment,
                              DstAlignCanChange, MemOps);
}

void CombinerHelper::applyCombineMemCpyFamily(
    MachineInstr &MI, MemCpyFamilyLoweringInfo &MatchInfo) const {
  auto &[Dst, Src, KnownLen, Alignment, DstAlignCanChange, MemOps] = MatchInfo;
  MachineIRBuilder HelperBuilder(MI);
  GISelObserverWrapper DummyObserver;
  LegalizerHelper Helper(HelperBuilder.getMF(), DummyObserver, HelperBuilder);
  bool Changed = Helper.lowerMemCpyFamily(MI, Dst, Src, KnownLen, Alignment,
                                          DstAlignCanChange, MemOps) ==
                 LegalizerHelper::LegalizeResult::Legalized;
  assert(Changed && "expected memcpy-family instruction to lower");
  (void)Changed;
}
```

With typed structured-binding parameters:

```cpp
bool CombinerHelper::matchCombineMemCpyFamily(
    MachineInstr &MI,
    MemCpyFamilyLoweringInfo
        &[Dst, Src, KnownLen, Alignment, DstAlignCanChange, MemOps],
    unsigned MaxLen) const {
  return canLowerMemCpyFamily(MI, MRI, MaxLen, Dst, Src, KnownLen, Alignment,
                              DstAlignCanChange, MemOps);
}

void CombinerHelper::applyCombineMemCpyFamily(
    MachineInstr &MI,
    MemCpyFamilyLoweringInfo
        &[Dst, Src, KnownLen, Alignment, DstAlignCanChange, MemOps]) const {
  MachineIRBuilder HelperBuilder(MI);
  GISelObserverWrapper DummyObserver;
  LegalizerHelper Helper(HelperBuilder.getMF(), DummyObserver, HelperBuilder);
  bool Changed = Helper.lowerMemCpyFamily(MI, Dst, Src, KnownLen, Alignment,
                                          DstAlignCanChange, MemOps) ==
                 LegalizerHelper::LegalizeResult::Legalized;
  assert(Changed && "expected memcpy-family instruction to lower");
  (void)Changed;
}
```

## Replacing ordinal tuple access

From [LLVM's `TypeDetail.h`][type-detail]:

```cpp
using KeyTy = std::tuple<TypeRange, TypeRange>;

bool operator==(const KeyTy &key) const {
  if (std::get<0>(key) == getInputs())
    return std::get<1>(key) == getResults();
  return false;
}
```

With a typed structured-binding parameter:

```cpp
using KeyTy = std::tuple<TypeRange, TypeRange>;

bool operator==(const KeyTy &[inputs, results]) const {
  if (inputs == getInputs())
    return results == getResults();
  return false;
}
```

## An explicitly typed lambda

From [LLVM's `FuncOps.cpp`][func-ops]:

```cpp
auto newAttrs = llvm::map_to_vector(
    newAttrMap, [](std::pair<StringAttr, Attribute> attrPair) {
      return NamedAttribute(attrPair.first, attrPair.second);
    });
```

With a typed structured-binding parameter:

```cpp
auto newAttrs = llvm::map_to_vector(
    newAttrMap,
    [](std::pair<StringAttr, Attribute> [name, value]) {
      return NamedAttribute(name, value);
    });
```

The explicit type may participate in overload resolution and library callable
constraints. Replacing it with `auto` is not generally equivalent.

# Applicability Audit

The following examples preserve the original parameter type, cv/ref category,
and component access directly:

- Chromium's gamepad normalization helpers and `VotesUploader` callback;
- Chromium's explicitly typed visitors and map projection; and
- all five LLVM examples above.

The Chromium `Textfield`, D3D12, and preload-histogram examples currently take
their aggregate by value and then perform another by-value structured binding.
A by-value typed structured-binding parameter would remove that second copy.
That is likely the desired cleanup for these concrete product types, but it is
an observable semantic difference for types with nontrivial copy constructors.
They should be presented as optimization opportunities rather than perfectly
mechanical rewrites.

No included example uses the aggregate parameter after decomposition. None
requires recursive decomposition, and every decomposed type is already proven
to support the existing structured-binding protocol at that source location.

# A General Declaration Facility

Although parameters provide the motivating examples, the type and the
decomposition are orthogonal properties of a declaration. The general facility
should support the same forms wherever structured bindings are otherwise
allowed:

```cpp
Result [value, status] = expression;
const Result& [value, status] = expression;
Result&& [value, status] = expression;

void consume(Result [value, status]);
void inspect(const Result& [value, status]);

auto callback = [](Result&& [value, status]) {
  use(std::move(value), status);
};
```

This keeps two questions separate:

1. What is the type and cv/ref category of the underlying object?
2. What names are introduced for its components?

The existing `auto` forms remain useful when deduction is intended. Typed forms
add the ability to constrain, convert, or document the underlying object type.

# Design Requirements

A design for typed structured bindings should specify:

- that the written type is the type of the hidden object;
- how initialization and conversion to that type occur;
- how cv/ref qualifiers determine the binding types and value categories;
- that a structured-binding parameter contributes its underlying object type,
  not its individual bindings, to the function type and ABI;
- how a declaration without binding names corresponds to a definition that
  introduces them;
- how attributes and default arguments attach;
- how the syntax is distinguished from array declarators; and
- whether an ignored-binding facility is available when only some components
  are used.

# Conclusion

Parameter decomposition is not adequately served by an `auto`-only extension.
Production code frequently has an intentionally concrete parameter type and
then immediately names its components. Typed structured bindings provide the
missing orthogonality: state the type of the object and its decomposition in a
single declaration. Function parameters are a particularly strong application
of that general facility.

[textfield]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/ui/views/controls/textfield/textfield.cc#2273
[gamepad-normalization]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/device/gamepad/normalization.h#18
[d3d12-processor]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/media/gpu/windows/d3d12_video_processor_wrapper.cc#86
[votes-uploader]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/components/autofill/core/browser/crowdsourcing/votes_uploader.cc#437
[permission-overrides]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/content/browser/permissions/permission_overrides.cc#225
[form-filler]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/components/autofill/core/browser/filling/form_filler.cc#1227
[btm-bounce-detector]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/content/browser/btm/btm_bounce_detector.cc#344
[address-form-data-importer]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/components/autofill/core/browser/form_import/addresses/address_form_data_importer.cc#438
[chromium-commit]: https://chromium.googlesource.com/chromium/src/+/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5
[llvm-commit]: https://github.com/llvm/llvm-project/tree/3f226265c84026cbe6965b317757c96989cb6ff8
[extract-slice]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/mlir/lib/Dialect/Tensor/Transforms/ExtractSliceFromReshapeUtils.cpp#L47-L59
[outlined-hash-tree]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/llvm/lib/CGData/OutlinedHashTree.cpp#L70-L88
[combiner-helper]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/llvm/lib/CodeGen/GlobalISel/CombinerHelper.cpp#L1733-L1751
[type-detail]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/mlir/lib/IR/TypeDetail.h#L67-L72
[func-ops]: https://github.com/llvm/llvm-project/blob/3f226265c84026cbe6965b317757c96989cb6ff8/mlir/lib/Dialect/Func/IR/FuncOps.cpp#L204-L209
