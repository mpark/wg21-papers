---
title: "Pattern Matching Usage in Chromium"
document: D0000R0
date: 2026-09-01
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

This report tests the proposed design against a large public C++ codebase by
surveying
[Chromium revision 45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5](https://github.com/chromium/chromium/tree/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5).
All source links are pinned to that revision.

The main findings are:

- nullable and result-like types are much more common than `std::variant`;
- explicit overload-set visitors are common and translate directly to match
  arms;
- manual `get_if` dispatch matters most when it is mixed with enclosing
  `break`, `continue`, and `return` control flow;
- grouped `switch` labels provide strong evidence for or-patterns;
- Blink's custom `DynamicTo` protocol is far more prevalent than C++ RTTI,
  motivating an open cast customization rather than special treatment only
  for `dynamic_cast`; and
- generic one-operation visitors and correlated multi-variant visitors expose
  places where `match` is not automatically clearer.

# Survey methodology

The survey used a shallow, partial Chromium checkout at the revision above.
The corpus contains non-test `.h`, `.hh`, `.hpp`, `.cc`, `.cpp`, `.cxx`, and
`.mm` files under:

```
base, cc, chrome, components, content, device, gpu, media, net,
services, third_party/blink, ui
```

Directories named `test`, `tests`, `testing`, `unittests`, `examples`,
`test_support`, and `test_utils` were excluded. Files whose stems end in
`_test`, `_unittest`, `_browsertest`, `_perftest`, `_fuzzer`, `_test_util`,
`_test_utils`, or `_test_base` were also excluded.

The resulting corpus has 72,503 files and approximately 13.29 million lines.
A lexical scanner masked comments and string and character literals before
counting syntax and library names.

The tables distinguish three kinds of evidence:

- **Lexical counts** count occurrences after masking comments and literals.
- **Reviewed sites** start from a lexical heuristic and were then inspected
  manually.
- **Candidate clusters** are conservative lower bounds over recognizable
  source shapes. They are not claims that every site should be rewritten.

Aliases, wrappers, macros, and project-specific types make these counts
underestimates of semantic usage. Conversely, a template-id may occur in a
declaration or implementation utility that would not benefit from matching.
The proposed rewrites are illustrative and have not been submitted to
Chromium.

# Corpus census

| Signal | Count | Interpretation |
|---|---:|---|
| `std::variant<...>` | 773 mentions in 569 files | Closed choices are established but not dominant |
| `std::visit(...)` | 422 calls | Direct visitor-replacement candidates |
| Explicit `absl::Overload`-style visitors | 284 calls | Strong candidates for declaration arms |
| Simple generic visitors | 99 calls | Usually modest syntactic benefit |
| `std::get_if<...>` | 404 occurrences | Manual alternative tests and bindings |
| `std::holds_alternative<...>` | 962 occurrences | Type predicates and grouped alternatives |
| `std::optional<...>` / `std::nullopt` | 60,798 / 19,107 occurrences | Nullable projection is pervasive |
| `base::expected<...>` | 3,474 occurrences | Value/error projection is a first-class use case |
| `std::any` | 0 occurrences | Standard open type erasure is not motivated by this corpus |
| Blink `DynamicTo<...>` / `IsA<...>` | 4,313 / 1,493 occurrences | Project-specific open type refinement is heavily used |
| C++ `dynamic_cast` | 0 executable occurrences | Built-in RTTI alone would reach little Chromium code |
| Structured bindings | 1,340 declarations | Structural decomposition is familiar vocabulary |
| `std::pair<...>` / `std::tuple<...>` / `std::tie(...)` | 4,050 / 591 / 752 occurrences | Product values are common, but not every use is a match |
| `switch` | 19,888 occurrences | Integral and enum dispatch remains important |
| Consecutive grouped `case` runs | 10,016 runs containing 47,270 labels | Strong lower bound for useful or-patterns |
| `holds_alternative` disjunctions | 6 reviewed lexical candidates | Type or-patterns occur, but are not dominant |
| Multi-variant `std::visit` | 2 calls | Correlated product dispatch is rare in this corpus |

The visitor categories are syntactic. A call classified as an explicit
overload set contains an `Overload`/`Overloaded` helper at the call site. A
simple generic visitor contains a generic lambda, no overload helper, and no
`if constexpr`. The remaining calls include named visitors and generic
visitors with type-dependent control flow.

# Design priorities from the corpus

| Priority | Evidence | Consequence for the design |
|---|---|---|
| Closed alternative dispatch | 284 explicit overload-set visitors, 404 `get_if` uses | `{ declaration }` arms should be direct and exhaustive |
| Nullable and result projection | 60,798 `optional` and 3,474 `base::expected` mentions | `alternative_traits` cannot be designed only around `variant` |
| Enclosing control flow | Reviewed `get_if` and `expected` loops use `continue`, `break`, and `return` | Handlers must not be trapped inside visitor lambdas |
| Or-patterns | 10,016 grouped `case` runs | Shared-handler alternatives deserve first-class syntax |
| Custom open refinement | 4,313 Blink `DynamicTo` uses | A cast protocol is needed in addition to C++ RTTI |
| Pattern composition | HLS parsing combines result, variant, optional, enum, and guards | Nested patterns are more important than isolated shorthand |
| Preserve concise generic operations | 99 simple generic visitors | `match` need not replace every visitor |

# Closed choices

## Explicit overload sets

Chromium commonly uses `absl::Overload` to construct a visitor with one lambda
per alternative. A compact example is `EnterpriseCompanionStatus::code()`
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/chrome/enterprise_companion/enterprise_companion_status.h#L80-L85)):

::: cmptable

### Before: compact overload set
```cpp
return std::visit(
    absl::Overload{[](std::monostate) { return 0; },
                   [](const PersistedError& error) { return error.code; },
                   [](auto&& x) { return static_cast<int>(x); }},
    status_variant_);
```

### After: direct alternatives
```cpp
return status_variant_ match {
  case { std::monostate } => 0;
  case { const PersistedError& error } => error.code;
  case { auto&& value } => static_cast<int>(value);
};
```
:::

The result is only modestly shorter, but the alternative selection and
bindings are visible without constructing an overload object. A larger WebNN
model-editor example has six such arms
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/services/webnn/ort/model_editor.cc#L223-L270)):

::: cmptable

### Before: overload-set visitor
```cpp
std::visit(absl::Overload{
  [&](int64_t value) {
    CHECK_STATUS(ort_api->CreateOpAttr(
        name.c_str(), &value, 1, ORT_OP_ATTR_INT,
        ScopedOrtOpAttr::Receiver(attribute).get()));
  },
  [&](float value) {
    CHECK_STATUS(ort_api->CreateOpAttr(
        name.c_str(), &value, 1, ORT_OP_ATTR_FLOAT,
        ScopedOrtOpAttr::Receiver(attribute).get()));
  },
  [&](base::cstring_view value) {
    CHECK_STATUS(ort_api->CreateOpAttr(
        name.c_str(), value.data(), value.size(), ORT_OP_ATTR_STRING,
        ScopedOrtOpAttr::Receiver(attribute).get()));
  },
  [&](base::span<const int64_t> value) { /* ... */ },
  [&](base::span<const float> value) { /* ... */ },
  [&](base::span<const char*> value) { /* ... */ },
}, data);
```

### After: declaration arms
```cpp
data match {
  case { int64_t value } => do {
    CHECK_STATUS(ort_api->CreateOpAttr(
        name.c_str(), &value, 1, ORT_OP_ATTR_INT,
        ScopedOrtOpAttr::Receiver(attribute).get()));
  };
  case { float value } => do {
    CHECK_STATUS(ort_api->CreateOpAttr(
        name.c_str(), &value, 1, ORT_OP_ATTR_FLOAT,
        ScopedOrtOpAttr::Receiver(attribute).get()));
  };
  case { base::cstring_view value } => do {
    CHECK_STATUS(ort_api->CreateOpAttr(
        name.c_str(), value.data(), value.size(), ORT_OP_ATTR_STRING,
        ScopedOrtOpAttr::Receiver(attribute).get()));
  };
  case { base::span<const int64_t> value } => /* ... */;
  case { base::span<const float> value } => /* ... */;
  case { base::span<const char*> value } => /* ... */;
};
```
:::

The handler bodies do not become shorter. The gain is structural: the subject,
selection, binding, source order, and exhaustiveness are all represented by
the language rather than by a constructed overload set.

## Recovering the active type with `if constexpr`

Some generic visitors recover the active type and rebuild a dispatch chain.
`OverlayLayerId::ToString` does this before applying a nested value switch
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/ui/gfx/overlay_layer_id.cc#L71-L103)):

::: cmptable

### Before: generic visitor plus type recovery
```cpp
std::visit(
    [&](auto&& arg) {
      using T = std::decay_t<decltype(arg)>;
      if constexpr (std::is_same_v<T, VizInternalId>) {
        switch (arg) {
          case VizInternalId::kOsCompositorRoot:
            out << "OsCompositorRoot";
            break;
          // ...
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

### After: type and value patterns compose
```cpp
impl_ match {
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

The important feature is not merely declaration syntax. A value pattern can
be nested under alternative projection, avoiding a visitor arm whose first
operation is another dispatch.

This match is exhaustive under the proposal's required-domain rule. The three
value arms cover every declared `VizInternalId` enumerator, and the remaining
two arms cover the other `variant` alternatives. It is not total over residual
runtime states: because `VizInternalId` has a fixed `uint32_t` underlying type,
unnamed enum values remain possible, and `variant` can be valueless by
exception. A trailing `case _` would therefore still be useful, but neither
residual state is required for exhaustiveness. In this void match, an
unmatched residual state performs no handler.

# Enclosing control flow

Visitor lambdas make control flow target the lambda. Chromium therefore often
uses `get_if` when dispatch is embedded in a loop. The tab-strip bridge probes
two alternatives, validates the projected handle, and may continue the
enclosing loop
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/chrome/browser/ui/tabs/tab_strip_api/tab_strip_model_impl/tab_strip_model_event_bridge.cc#L46-L65)):

::: cmptable

### Before: `get_if` chain in a loop
```cpp
for (const auto& handle : handles) {
  if (const auto* tab = std::get_if<tabs::TabHandle>(&handle)) {
    if (!tab->Get())
      continue;
    Notify(events::ToEvent(*tab, position, *tab_strip_model_adapter_));
  } else if (const auto* collection =
                 std::get_if<tabs::TabCollectionHandle>(&handle)) {
    if (!collection->Get())
      continue;
    Notify(events::ToEvent(*collection, position, *tab_strip_model_adapter_,
                           insert_from_detached));
  }
}
```

### After: match arms retain loop control
```cpp
for (const auto& handle : handles) {
  handle match {
    case { const tabs::TabHandle& tab } if (!tab.Get()) => continue;
    case { const tabs::TabHandle& tab } =>
        Notify(events::ToEvent(tab, position, *tab_strip_model_adapter_));
    case { const tabs::TabCollectionHandle& collection }
        if (!collection.Get()) => continue;
    case { const tabs::TabCollectionHandle& collection } =>
        Notify(events::ToEvent(collection, position,
                               *tab_strip_model_adapter_,
                               insert_from_detached));
  };
}
```
:::

This is a concrete reason for handlers to support jump statements that target
the enclosing function or loop. Replacing this code with `std::visit` would
require translating `continue` into an indirect convention.

# Results and composition

## Value/error handling inside a loop

Chromium uses `base::expected` extensively. Session construction parses each
credential and either appends the value or returns the error from the enclosing
function
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/net/device_bound_sessions/session.cc#L204-L212)):

::: cmptable

### Before: inspect, then project
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

### After: named projected states
```cpp
for (const auto& cred : params.credentials) {
  CookieCraving::Create(params.fetcher_url, cred.name, cred.attributes,
                        base::Time::Now()) match {
    case { .value: CookieCraving craving } =>
        session->cookie_cravings_.push_back(std::move(craving));
    case { .error: SessionError error } =>
        return base::unexpected(std::move(error));
  };
}
```
:::

This supports named states without requiring `expected` to masquerade as a
variant whose two alternatives happen to have distinct types. It also remains
unambiguous when `T` and `E` are the same type.

## Result, variant, value, and loop control together

The HLS parser demonstrates why composability matters more than replacing an
isolated `if`. Each iteration first handles a parse result, then distinguishes
line-item alternatives, then applies value tests and may `break`, `continue`,
or return from the enclosing parser
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/media/formats/hls/media_playlist.cc#L120-L151)):

::: cmptable

### Before: result handling followed by `get_if`
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

### After: nested protocols remain one selection
```cpp
while (true) {
  GetNextLineItem(&src_iter) match {
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

The rewrite is intentionally not claimed to shorten the full parser. It shows
that named result states, closed alternatives, guards, and enclosing control
flow must compose without introducing nested visitors or ad hoc status
variables.

# Value and product patterns

## Or-patterns replace grouped labels

The scanner found 10,016 runs of consecutive `case` labels sharing one body.
This is a direct lower bound for useful or-patterns. A small representative
example groups the four credential modes into two outcomes
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/services/network/url_loader_util.cc#L78-L93)):

::: cmptable

### Before: grouped `switch` labels
```cpp
switch (credentials_mode) {
  case mojom::CredentialsMode::kInclude:
  case mojom::CredentialsMode::kSameOrigin:
    return true;

  case mojom::CredentialsMode::kOmit:
  case mojom::CredentialsMode::kOmitBug_775438_Workaround:
    return false;
}
```

### After: or-patterns
```cpp
return credentials_mode match {
  case mojom::CredentialsMode::kInclude ||
       mojom::CredentialsMode::kSameOrigin => true;
  case mojom::CredentialsMode::kOmit ||
       mojom::CredentialsMode::kOmitBug_775438_Workaround => false;
};
```
:::

This is not merely syntax for variants. Or-patterns are justified by ordinary
enum dispatch at much greater scale.

## Product matching combines related tests

An offline-pages callback treats one pair of values as a distinguished case
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/components/offline_pages/core/model/clear_storage_task.cc#L179-L193)):

::: cmptable

### Before: coordinate-wise tests
```cpp
void ClearStorageTask::OnClearPagesDone(
    std::pair<size_t, DeletePageResult> result) {
  if (result.first == 0 && result.second == DeletePageResult::SUCCESS) {
    InformClearStorageDone(result.first, ClearStorageResult::UNNECESSARY);
    return;
  }

  ClearStorageResult clear_result = ClearStorageResult::SUCCESS;
  if (result.second != DeletePageResult::SUCCESS)
    clear_result = ClearStorageResult::DELETE_FAILURE;
  InformClearStorageDone(result.first, clear_result);
}
```

### After: one product condition
```cpp
void ClearStorageTask::OnClearPagesDone(
    std::pair<size_t, DeletePageResult> result) {
  if (case [0, DeletePageResult::SUCCESS] = result) {
    InformClearStorageDone(result.first, ClearStorageResult::UNNECESSARY);
    return;
  }

  ClearStorageResult clear_result = ClearStorageResult::SUCCESS;
  if (result.second != DeletePageResult::SUCCESS)
    clear_result = ClearStorageResult::DELETE_FAILURE;
  InformClearStorageDone(result.first, clear_result);
}
```
:::

The corpus contains many conjunctions, but most combine unrelated predicates
or range checks and should remain ordinary boolean code. Product patterns are
valuable when the source already treats several components as one state; raw
counts of `&&` conditions substantially overestimate that population.

# Open runtime type refinement

Chromium's C++ RTTI use is not representative of its dynamic type dispatch.
Blink defines `IsA<T>`, `To<T>`, and `DynamicTo<T>` on top of
`DowncastTraits<T>`
([protocol](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/third_party/blink/renderer/platform/wtf/casting.h#L68-L193)).
The survey found 4,313 `DynamicTo` calls and 1,493 `IsA` calls, compared with
no executable C++ `dynamic_cast` expression.

For example, CSS pseudo-class handling performs a five-way ordered refinement
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/third_party/blink/renderer/core/css/selector_checker.cc#L2999-L3021)):

::: cmptable

### Before: project-specific cast chain
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

### After: open refinement through `{ declaration }`
```cpp
return element match {
  case { HTMLDialogElement& dialog } =>
      dialog.FastHasAttribute(html_names::kOpenAttr);
  case { HTMLDetailsElement& details } =>
      details.FastHasAttribute(html_names::kOpenAttr);
  case { HTMLSelectElement& select } => select.PopupIsVisible();
  case { HTMLInputElement& input } => input.IsPickerVisible();
  case { HTMLMenuItemElement& menuitem } => menuitem.IsSubmenuOpen();
  case _ => false;
};
```
:::

The after form requires an open projection customization whose `try_cast<T>`
uses Blink's `DynamicTo<T>`. Treating only C++ polymorphic classes specially
would leave the dominant Chromium hierarchy unsupported. Conversely, core
language matching should not attempt to infer Blink's class discriminator;
the project-specific cast operation is the semantic authority.

This evidence favors one `{ declaration }` runtime-refinement syntax with
multiple providers:

- closed indexed `alternative_traits` for `variant`, `optional`, and
  `expected`;
- built-in `dynamic_cast` semantics for ordinary polymorphic classes; and
- an open `try_cast<T>` customization for `any`-like and project-defined
  hierarchies.

# Where `match` is not automatically better

## One generic operation

Ninety-nine visitors apply one generic operation to every alternative. The
paint iterator contains several clear examples
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/cc/paint/paint_op_buffer_iterator.h#L174-L204)):

::: cmptable

### Existing code
```cpp
const PaintOp* get() const {
  return std::visit([](const auto& iter) { return iter.get(); }, iter_);
}

CompositeIterator& operator++() {
  std::visit([](auto& iter) { ++iter; }, iter_);
  return *this;
}
```

### Possible match spelling
```cpp
const PaintOp* get() const {
  return iter_ match { case { const auto& iter } => iter.get(); };
}

CompositeIterator& operator++() {
  iter_ match { case { auto& iter } => ++iter; };
  return *this;
}
```
:::

The match spelling is comparable, not clearly superior. The visitor already
states the useful fact: perform one generic operation on the active value.
The language design should not be judged by replacing these calls.

## Correlated multi-variant dispatch

Only two `std::visit` calls in the corpus pass multiple variants. One checks
whether two log events have the same active type before calling a type-specific
operation
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/components/autofill/core/browser/autofill_field.cc#L344-L358)):

```cpp
return std::visit(
    [](const auto& e1, const auto& e2) {
      if constexpr (std::is_same_v<decltype(e1), decltype(e2)>)
        return AreCollapsible(e1, e2);
      return false;
    },
    event1, event2);
```

The current pattern vocabulary does not have a concise relational pattern
meaning "the second projected alternative has the same type as the first".
Enumerating every same-type pair would be worse. This visitor should remain a
visitor unless a future proposal adds relationships between bindings. The low
frequency in this corpus argues against complicating P2688R6 for this case.

## Simple nullable tests

The volume of `optional` use does not imply that every `if (value)` should be
rewritten. A direct boolean test followed by `*value` is already established
and concise. Match becomes compelling when the nullable state composes with a
payload pattern, a guard, another choice, or a selection expression. This is
why the protocol is high priority even though many individual migrations have
little syntactic payoff.

`StringViewOrString::get()` is a representative small `optional` branch
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/base/base64url.cc#L27-L41)):

::: cmptable

### Before: direct optional test
```cpp
std::string_view get() const {
  if (str_) {
    return *str_;
  }
  return piece_;
}
```

### After: optional projection
```cpp
std::string_view get() const {
  return str_ match {
    case { const std::string& str } => str;
    case {} => piece_;
  };
}
```
:::

The same shape occurs with raw pointers. `GetWindowPropertyAsWindow()` tests a
lookup result and either dereferences it or returns a sentinel
([source](https://github.com/chromium/chromium/blob/45613f3c80b1f207dc2c79eb6b82e1d63e76ffa5/ui/gfx/x/connection.cc#L94-L99)):

::: cmptable

### Before: direct pointer test
```cpp
if (const Window* wm_window = PropertyCache::GetAs<Window>(value)) {
  return *wm_window;
}
return Window::None;
```

### After: pointer projection
```cpp
return PropertyCache::GetAs<Window>(value) match {
  case { const Window& wm_window } => wm_window;
  case {} => Window::None;
};
```
:::

These examples validate the `{ P }` and `{}` vocabulary, but they are not
strong syntactic wins. More persuasive uses combine the projection with value
patterns or additional structure, as in the earlier result and HLS examples.

# Conclusions

The Chromium evidence supports the following priorities for P2688R6:

1. Keep declaration patterns concise for closed alternatives. Explicit
   overload visitors are common enough that `case { T value }` is a central
   use case, not an escape hatch.
2. Specify nullable and result protocols alongside `variant`. In this corpus,
   `optional` and `base::expected` are substantially more prevalent.
3. Preserve enclosing `return`, `break`, and `continue`. This is a material
   advantage over visitor lambdas and explains many manual `get_if` chains.
4. Retain full pattern composition. Real parsers combine result state,
   alternative type, value tests, guards, and control flow in one operation.
5. Include or-patterns. Consecutive grouped switch labels are widespread and
   provide direct, language-independent evidence.
6. Provide an open cast customization. Built-in `dynamic_cast` semantics are
   useful, but they do not cover Blink's dominant dispatch model.
7. Do not optimize the design for one-operation generic visitors or rare
   correlated multi-variant visitors. Existing C++ is already competitive for
   those shapes.

The broad conclusion is not that every branch should become a pattern. The
largest gains occur where C++ currently separates testing, projection,
binding, and control flow across several constructs. Pattern matching is most
valuable when it reunifies those operations while retaining ordinary C++
value categories and enclosing control flow.
