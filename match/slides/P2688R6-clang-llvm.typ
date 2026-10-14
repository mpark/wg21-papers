#import "@preview/touying:0.6.1": *
#import themes.simple: *

#let ink = rgb("243447")
#let accent = rgb("00796b")
#let warm = rgb("b45309")
#let before-fill = rgb("fff5f2")
#let after-fill = rgb("f0fdfa")
#let quiet-fill = rgb("f5f7fa")
#let show-speaker-notes = sys.inputs.at("speaker-notes", default: "false") == "true"

#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-common(
    show-notes-on-second-screen: if show-speaker-notes { right } else { none },
  ),
  config-info(
    title: [Pattern Matching in Clang and LLVM],
    subtitle: [P2688R6 and implementation experience],
    author: [Michael Park],
    date: [October 14, 2026],
  ),
)

#set text(fill: ink)
#show raw.where(block: true): set text(size: 13pt)
#show strong: set text(fill: accent)

#let panel(title, body, fill: quiet-fill, stripe: accent) = block(
  width: 100%,
  fill: fill,
  stroke: (top: 3pt + stripe),
  radius: 4pt,
  inset: 10pt,
  [
    #text(weight: "bold", fill: stripe, size: 14pt, title)
    #v(5pt)
    #body
  ],
)

#let compare(before, after) = grid(
  columns: (1fr, 1fr),
  gutter: 14pt,
  panel([Today], before, fill: before-fill, stripe: warm),
  panel([P2688R6], after, fill: after-fill, stripe: accent),
)

#let callout(body) = block(
  width: 100%,
  fill: after-fill,
  stroke: (left: 4pt + accent),
  inset: 10pt,
  body,
)

#let small(body) = text(size: 17pt, body)

#title-slide[]

== The claim

#set align(center)
#v(1.1em)
#text(size: 34pt, weight: "bold", fill: accent)[
  Clang and LLVM already contain pattern matching.
]

#v(0.7em)

#text(size: 27pt)[
  We spell it as combinations of `switch`, `dyn_cast`, `get_if`,
  `holds_alternative`, structured bindings, and nested `if` statements.
]

#v(0.8em)

#callout([
  P2688 gives those operations one composable language,
  with exhaustiveness checking and ordinary C++ declarations.
])

#speaker-note[
- Open with the claim that LLVM already performs pattern matching manually.
- This talk is about consolidating existing operations, not importing an alien
  functional-programming model.
- The safety claim is as important as concision: tests and projections become
  one checked construct.
]

== What we tested

#grid(
  columns: (1fr, 1fr),
  gutter: 18pt,
  [
    *Implementation*

    - Parsing, AST, Sema, constant evaluation, and CodeGen
    - Exhaustiveness and usefulness checking
    - Decision-tree lowering
    - Closed and open customization protocols
  ],
  [
    *Self-hosting experiment*

    - Generated alternatives for `Decl`, `DeclContext`, and `Stmt`
    - `variant`, `optional`, `PointerUnion`, and `ErrorOr`
    - `StringSwitch` and `TypeSwitch` migrations
    - Clang and libc++ test suites pass
  ],
)

#v(0.6em)

#callout([The interesting result is not that every rewrite is shorter. It is
that the shape being analyzed becomes explicit and checkable.])

#speaker-note[
- Present R6 as the proposal and later work as implementation evidence.
- Mention that both the P2688 compiler and the self-hosted Clang build their
  test suites.
- Do not imply that the self-host branch is a proposed wholesale migration.
]

== Existing demand in LLVM

#table(
  columns: (2.1fr, 0.7fr, 2.8fr),
  align: (left, right, left),
  inset: 7pt,
  table.header([*Signal*], [*Count*], [*What it represents*]),
  [`std::visit`], [41], [Closed alternative dispatch],
  [`std::get_if`], [132], [Manual test plus projection],
  [`std::holds_alternative`], [101], [Manual type predicates],
  [`std::optional` / `nullopt`], [13,503 / 6,469], [Nullable values],
  [`Expected` / `ErrorOr`], [7,830 / 657], [Value-or-error results],
  [`PointerUnion`], [239], [LLVM-specific closed choices],
  [`dyn_cast`], [26,502], [Open and closed class dispatch],
  [`StringSwitch`], [865], [Ordered value dispatch],
  [`TypeSwitch`], [22], [Ordered runtime type dispatch],
)

#v(0.35em)
#small([Survey: 12,366 non-test Clang, LLVM, LLD, and LLDB source files,
approximately 6.5 million lines.])

#speaker-note[
- Do not read the table row by row.
- Emphasize three populations: nullable/result types, closed alternatives, and
  LLVM's very large `dyn_cast` ecosystem.
- `StringSwitch` and `TypeSwitch` show that LLVM already values declarative
  ordered dispatch.
]

= The proposal

== A selection can be a statement or an expression

#compare(
  [
```cpp
switch (coin) {
case Coin::Penny:  return 1;
case Coin::Nickel: return 5;
case Coin::Dime:   return 10;
case Coin::Quarter:return 25;
}
```
  ],
  [
```cpp
return match (coin) {
  case Coin::Penny   => 1;
  case Coin::Nickel  => 5;
  case Coin::Dime    => 10;
  case Coin::Quarter => 25;
};
```
  ],
)

#v(0.4em)
#callout([Cases are checked in source order. A selection must be exhaustive,
and all reachable expression handlers have a common result type.])

#speaker-note[
- `match` deliberately follows the visual shape of `switch`.
- The same syntax serves statements and expressions.
- Exhaustiveness is required, not merely a warning mode.
]

== Patterns use existing C++ vocabulary

#table(
  columns: (1.4fr, 2.6fr, 2.2fr),
  inset: 7pt,
  table.header([*Pattern*], [*Meaning*], [*Example*]),
  [Value], [Compare the current subject], [`case 0`],
  [Wildcard], [Match without introducing a name], [`case _`],
  [Declaration], [Initialize an ordinary declaration], [`case const T& x`],
  [Decomposition], [Recursively match tuple-like elements], [`case [0, int y]`],
  [Alternative], [Project an active runtime state], [`case { const T& x }`],
  [Or-pattern], [Try alternatives against one subject], [`case A or B`],
  [Guard], [Test after the pattern succeeds], [`case P if (condition)`],
)

#speaker-note[
- The vocabulary is intentionally small and mostly existing C++ syntax.
- Ordinary declarations carry cvref, ownership, constraints, and forwarding.
- Braces are the one crucial new boundary: they enter an alternative state.
]

== Decomposition composes with values and declarations

```cpp
match (roll_two_dice()) {
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

#callout([A pattern describes the shape and introduces exactly the names needed
by its handler. Tests, projection, and binding remain adjacent.])

#speaker-note[
- Use this slide to establish recursive composition.
- The guard runs after the pattern succeeds and can use both declarations.
- Multiple separately produced match subjects use the same decomposition
  shape, but that detail can wait for questions.
]

== Braces enter an alternative

#grid(
  columns: (1fr, 1fr),
  gutter: 16pt,
  [
    *Nullable state*
```cpp
match (try_dice_roll()) {
  case { int roll } => move(roll);
  case {} => roll_again();
}
```
  ],
  [
    *Closed choice*
```cpp
match (result) {
  case { const File& f } => open(f);
  case { const Directory& d } => open(d);
}
```
  ],
)

#v(0.5em)

```cpp
case auto&& whole      // binds the variant/optional object
case { auto&& payload } // binds once for each viable projected type
```

#speaker-note[
- This distinction answers a recurring R5 question: does `auto&&` bind the
  wrapper or its payload?
- `{}` is an advertised empty state; it is not special-cased to optional.
- The right-hand example is exhaustive because `SearchResult` is closed.
]

== Named states distinguish identical payload types

```cpp
std::expected<std::string, std::string> result = read_file(path);

match (result) {
  case { .value: const auto& contents } => process(contents);
  case { .error: const auto& message }  => report(message);
}
```

#v(0.5em)

#callout([The state is part of the pattern. It is not reconstructed from the
payload type, and `value` and `error` remain distinct even when their types are
the same.])

#speaker-note[
- This motivates named discriminator states in `alternative_traits`.
- Skip this slide if discussion has already consumed several minutes.
]

== Runtime class refinement uses declaration syntax

#compare(
  [
```cpp
if (auto* circle =
      dynamic_cast<const Circle*>(&shape))
  return area(*circle);

if (auto* rectangle =
      dynamic_cast<const Rectangle*>(&shape))
  return area(*rectangle);

throw invalid_argument("unknown shape");
```
  ],
  [
```cpp
return match (shape) {
  case const Circle& circle =>
    area(circle);
  case const Rectangle& rectangle =>
    area(rectangle);
  case _ =>
    throw invalid_argument("unknown shape");
};
```
  ],
)

#speaker-note[
- For a polymorphic subject, a declaration can perform runtime refinement.
- This is an open domain, so the wildcard is required.
- LLVM can provide analogous behavior through its own cast protocol rather
  than C++ RTTI.
]

== Patterns also work as tests and conditions

```cpp
bool is_file = match(result, case { const File& });

if (case { const Directory& directory } = result) {
  open_directory(directory);
}
```

#v(0.7em)

#grid(
  columns: (1fr, 1fr),
  gutter: 18pt,
  panel([Test expression], [Produces `bool`; introduced names do not escape.]),
  panel([Pattern condition], [Names are available in later conditions and the
  successful statement.]),
)

#speaker-note[
- A test answers only yes or no.
- A pattern condition additionally exports declarations into the successful
  continuation, like an `if` condition declaration.
- Keep this brief; the LLVM examples are the main event.
]

= LLVM experience

== Everyday code: test an optional value

#compare(
  [
```cpp
std::optional<bool> Res =
    isImpliedCondition(TrueVal, B, DL);

if (Res && *Res == false)
  return replaceOperand(SI, 0, A);
```
  ],
  [
```cpp
std::optional<bool> Res =
    isImpliedCondition(TrueVal, B, DL);

if (match(Res, case { false }))
  return replaceOperand(SI, 0, A);
```
  ],
)

#v(0.4em)
#small([`llvm/lib/Transforms/InstCombine/InstCombineSelect.cpp`])

#speaker-note[
- Start the migration section with a deliberately ordinary example.
- `{ false }` means engaged optional whose projected bool equals false.
- This is not the strongest rewrite; it demonstrates everyday composability.
]

== Replace a `get_if` chain

#compare(
  [
```cpp
if (const auto *R =
      std::get_if<const Record *>(&Action))
  OS << (*R)->getName();
else if (const auto *S =
           std::get_if<std::string>(&Action))
  OS << '"' << *S << '"';
else
  OS << std::get<unsigned>(Action);
```
  ],
  [
```cpp
match (Action) {
  case { const Record *R } =>
    OS << R->getName();
  case { const std::string &S } =>
    OS << '"' << S << '"';
  case { unsigned Value } =>
    OS << Value;
}
```
  ],
)

#v(0.25em)
#small([The subject appears once, and every successful test carries the correct
projection into its handler.])

#speaker-note[
- This is the cleanest introductory LLVM migration.
- Today the programmer must keep the `get_if` type and subsequent access in
  agreement.
- The variant's closed domain makes the match exhaustive without an `else`.
]

== Destructive extraction is visible

#compare(
  [
```cpp
IsBoolean = holds_alternative<bool>(Value);
IsComparison =
  holds_alternative<ComparisonResult>(Value);

if (IsBoolean)
  Bits.Value = get<bool>(Value);
else if (auto *R = get_if<ComparisonResult>(&Value))
  constructAPValue(encode(*R));
else
  constructAPValue(get<APValue>(move(Value)));
```
  ],
  [
```cpp
match (std::move(Value)) {
  case { bool Result } =>
    setBoolean(Result);
  case { APValue &&Result } =>
    constructAPValue(std::move(Result));
  case { ComparisonResult Result } =>
    constructAPValue(encode(Result));
}
```
  ],
)

#v(0.25em)
#small([Declaration patterns make copying, borrowing, and moving explicit.])

#speaker-note[
- This is stronger than replacing syntax around `visit`.
- `std::move(Value)` plus `APValue&&` makes destructive extraction explicit.
- Each handler receives the right projected type and value category.
]

== Collapse nested nullable control flow

#compare(
  [
```cpp
if (auto Parsed = parseAtomicScopeIRString(
        AMDGPU, AMDGCNScope)) {
  auto [Scope, IsSingleAS] = *Parsed;
  if (auto Str = getAtomicScopeIRString(
          TargetTriple, Scope, IsSingleAS))
    return *Str;
}
return AMDGCNScope;
```
  ],
  [
```cpp
if (case { auto [Scope, IsSingleAS] } =
        parseAtomicScopeIRString(
            AMDGPU, AMDGCNScope) &&
    case { StringRef Str } =
        getAtomicScopeIRString(
            TargetTriple, Scope, IsSingleAS))
  return Str;
return AMDGCNScope;
```
  ],
)

#speaker-note[
- Names from the first successful pattern are available to the next condition.
- This removes indentation while preserving left-to-right dependency.
- Skip when short on time; it is not central to the alternative protocol.
]

== The larger opportunity: Clang's AST

```cpp
switch (D->getKind()) {
case Decl::ParmVar:
  mangleFunctionParam(cast<ParmVarDecl>(D));
  break;

case Decl::EnumConstant: {
  const auto *ED = cast<EnumConstantDecl>(D);
  mangleIntegerLiteral(ED->getType(), ED->getInitVal());
  break;
}

case Decl::NonTypeTemplateParm:
  mangleTemplateParameter(
      cast<NonTypeTemplateParmDecl>(D)->getDepth(), ...);
  break;

default:
  mangle(D);
}
```

#callout([The discriminator and the cast encode one fact twice.])

#speaker-note[
- Slow down here; this begins the strongest part of the talk.
- Clang already has a generated closed discriminator and a known mapping from
  each kind to a concrete class.
- A mismatch between the switch label and cast is possible in today's form.
]

== Generated alternatives for `Decl`

```cpp
match (*D) {
case { const ParmVarDecl &PD } =>
  mangleFunctionParam(&PD);

case { const EnumConstantDecl &ED } =>
  mangleIntegerLiteral(ED.getType(), ED.getInitVal());

case { const NonTypeTemplateParmDecl &PD } =>
  mangleTemplateParameter(PD.getDepth(), PD.getIndex());

case _ =>
  mangle(D);
}
```

#v(0.4em)

#callout([The generated protocol reads Clang's existing `Decl::Kind` once and
projects with the corresponding concrete type. It is not a chain of RTTI
tests.])

#speaker-note[
- The `alternative_traits<Decl>` specialization is generated from the same
  TableGen hierarchy as the AST nodes.
- Base declaration patterns can cover several concrete leaves.
- Be explicit that this dispatch still uses `Decl::Kind`, not `dynamic_cast`.
]

== Matching the domain, not the representation

#small([
`DeclContext::getPrimaryContext()` accepted only declarations that are
`DeclContext`s, but switched over the much broader `Decl::Kind` enumeration.
])

#v(0.5em)

#compare(
  [
```cpp
switch (getDeclKind()) {
case Decl::TranslationUnit: ...
case Decl::Namespace: ...
case Decl::CXXRecord: ...
case Decl::Record:
case Decl::Enum: ...
default:
  assert(getDeclKind() >=
         Decl::firstFunction &&
         getDeclKind() <= Decl::lastFunction);
  return this;
}
```
  ],
  [
```cpp
return match (*this) -> DeclContext * {
case { FunctionDecl & } or
     { ObjCMethodDecl & } => this;
case { TranslationUnitDecl &D } =>
  D.getFirstDecl();
case { NamespaceDecl &D } =>
  D.getFirstDecl();
case { CXXRecordDecl &D } =>
  D.getDefinitionOrSelf();
case { TagDecl &D } =>
  D.getDefinitionOrSelf();
// ... exhaustive over DeclContext
};
```
  ],
)

#speaker-note[
- The key is the subject domain: this function cannot receive every `Decl`.
- `-Wswitch` sees `Decl::Kind`, while the match sees generated
  `alternative_traits<DeclContext>`.
- The wildcard-like default and numeric function range disappear.
]

== This would have prevented a real Clang crash

#set text(size: 21pt)

- Historical `PrintDeclContext` accepted a `DeclContext *`.
- It switched over broad `Decl::Kind` values.
- It omitted `ClassTemplateSpecializationDecl` and
  `ClassTemplatePartialSpecializationDecl`.
- A `default` hid the missing valid states from `-Wswitch`.
- The omission reached `llvm_unreachable` at runtime.
- Later, the printer was removed after its incomplete AST-node list caused
  further crashes.

#v(0.5em)

#callout([`alternative_traits<DeclContext>` advertises the actual finite domain.
An exhaustive match diagnoses the omission where it is written.])

#speaker-note[
- Cite LLVM commits `eebc494a577a` and `65ebd13f4185` if asked.
- The claim is narrow: this particular class of omitted valid `DeclContext`
  would become a compile-time exhaustiveness error.
- This is the slide to preserve if earlier questions force cuts.
]

== Not every migration is a win

#grid(
  columns: (1fr, 1fr),
  gutter: 18pt,
  panel([Strong fits], [
    - Discriminator plus cast
    - `get_if` / `holds_alternative` chains
    - Nested structural tests
    - Exhaustive closed domains
    - Value-producing dispatch
  ]),
  panel([Usually keep the existing code], [
    - One isolated `holds_alternative`
    - A generic `visit` already expressing one operation
    - Specialized APIs with domain-specific optimizations
    - Rewrites that obscure familiar local control flow
  ], fill: before-fill, stripe: warm),
)

#v(0.6em)
#small([The self-hosting branch deliberately contains both compelling and weak
transformations. It is design evidence, not a proposed mechanical migration.])

#speaker-note[
- Acknowledge weak migrations directly.
- The selection criterion is clearer data shape and stronger checking, not
  source-line reduction.
- Skip if the audience already raised this point.
]

= Protocol and implementation

== Closed alternatives opt in structurally

```cpp
template<class T, class E>
struct std::alternative_traits<my::Result<T, E>> {
  static constexpr alternative_info alternatives[] = {^^T, ^^E};
  static constexpr bool has_residual_states = false;

  enum class state : bool { value, error };

  static constexpr state index(const my::Result<T, E>& r) noexcept {
    return r.has_value() ? state::value : state::error;
  }

  template<state S, class Self>
  static constexpr decltype(auto) get(Self&& self) {
    if constexpr (S == state::value)
      return std::forward<Self>(self).value();
    else
      return std::forward<Self>(self).error();
  }
};
```

#speaker-note[
- This is an illustrative complete closed customization.
- `alternatives` gives the compiler the domain; `index` reads one runtime
  discriminator; `get` preserves cvref while projecting.
- Do not get stuck on reflection spelling or final library naming.
]

== What the protocol buys us

#table(
  columns: (1.5fr, 3.9fr),
  inset: 8pt,
  table.header([*Operation*], [*Information exposed to the language*]),
  [`alternatives`], [The finite required state domain and projected types],
  [`index(subject)`], [One discriminator read suitable for multiway dispatch],
  [`get<State>(subject)`], [The correct projection with preserved cvref],
  [`has_residual_states`], [Whether unadvertised runtime states may exist],
)

#v(0.6em)

#callout([`operator==` can test a value, but it cannot describe the state
domain, projection, exhaustiveness, or a reusable discriminator.])

#speaker-note[
- This is the answer to “why not just use equality plus syntactic sugar?”
- The compiler needs structural information before optimization and before
  handler instantiation.
]

== Code generation: the same source intent

#compare(
  [
```cpp
int with_equals(std::optional<int>& x) {
  if (x == 0) return 42;
  if (x == 1) return 7;
  if (x == 2) return 99;
  if (x == 3) return -3;
  if (x == 4) return 55;
  if (x == 5) return 18;
  if (x == 6) return 77;
  if (x == 7) return 4;
  if (x == std::nullopt) return -1;
  return 0;
}
```
  ],
  [
```cpp
int with_match(std::optional<int>& x) {
  return match (x) {
    case { 0 } => 42;
    case { 1 } => 7;
    case { 2 } => 99;
    case { 3 } => -3;
    case { 4 } => 55;
    case { 5 } => 18;
    case { 6 } => 77;
    case { 7 } => 4;
    case {} => -1;
    case _ => 0;
  };
}
```
  ],
)

#speaker-note[
- Both functions express the same source-level mapping.
- The standard-library equality operators are visible and inline here, so this
  is not merely an ABI-boundary example.
- The next slide shows the output from the current rebased prototype.
]

== Code generation: what Clang sees at `-O3`

#grid(
  columns: (1fr, 1fr),
  gutter: 14pt,
  panel([Eight opaque equality tests], [
```asm
cmp  value, 0
jne  next_1
mov  eax, 42
ret
next_1:
cmp  value, 1
jne  next_2
mov  eax, 7
ret
; ... six more compare/branches ...
```
  ], fill: before-fill, stripe: warm),
  panel([One structural dispatch], [
```asm
mov  eax, -1
cmp  byte ptr [x + 4], 1 ; engaged?
jne  done
mov  ecx, dword ptr [x]
xor  eax, eax             ; default: 0
cmp  rcx, 7
ja   done
lea  rax, [result_table]
mov  eax, dword ptr [rax + 4*rcx]
done:
ret
```
  ], fill: after-fill, stripe: accent),
)

#v(0.35em)
#small([Clang 24 P2688 prototype, libc++, C++26, x86-64, `-O3`. The match
decision tree exposes one engagement test and one multiway value test before
LLVM optimization begins.])

#speaker-note[
- The left side contains eight repeated equality and engagement tests.
- The right side performs one engagement test, one unsigned range check, and
  one indexed load from an eight-entry result table.
- Qualify the claim: an optimizer could theoretically recover this structure,
  but current Clang does not at `-O3`; match exposes it directly.
]

== Closed and open matching are different

#grid(
  columns: (1fr, 1fr),
  gutter: 18pt,
  panel([Closed], [
    `variant`, `optional`, `expected`, `PointerUnion`, `Decl`

    - Enumerated states
    - Exhaustiveness and usefulness
    - One discriminator can drive a switch
  ]),
  panel([Open], [
    Open class hierarchies, `any`, extensible registries

    - Type-directed `try_cast<T>`
    - No claim that known types are complete
    - Wildcard normally required
  ], fill: rgb("f5f3ff"), stripe: rgb("6d28d9")),
)

#speaker-note[
- Closed domains support exhaustiveness and discriminator-based lowering.
- Open domains support useful runtime refinement but cannot claim that the
  listed types are complete.
- `Decl` is closed; extensible registries and general polymorphic roots are
  open.
]

== Case-local instantiation

```cpp
template<class T>
void use(std::variant<bool, T> value) {
  match (value) {
    case { true }  => on_true();
    case { false } => on_false();
    case { auto&& payload } => payload.do_something();
  }
}
```

#v(0.5em)

- The first two cases cover the complete `bool` domain.
- The generic handler is useful only for `T`.
- Its body is not instantiated for `bool`.
- First-match source semantics do not become overload resolution.

#callout([Usefulness analysis participates in deciding which case
specializations exist, not only in producing diagnostics afterward.])

#speaker-note[
- This is the template-instantiation model in one example.
- The two bool rows cover bool completely, so the generic handler is never
  instantiated with bool.
- First-match semantics remain source ordered; cases do not become overloads.
]

== Compiler architecture

#set text(size: 19pt)

#align(center)[
```text
Parser
  |
  v
Pattern AST + source cases
  |
  v
Candidate planning
  |  alternative states, cast applicability, dependent specialization
  v
Usefulness / exhaustiveness matrix
  |
  v
Decision-tree planning
  |  discriminator tests, values, decomposition, guards, fallbacks
  v
Clang CodeGen + constant evaluator
```
]

#v(0.25em)
#small([The implementation has dedicated pattern semantics. It is not a source
rewrite into nested `if` statements.])

#speaker-note[
- Candidate planning determines viable projected cases.
- The usefulness matrix serves both diagnostics and safe handler
  instantiation.
- The decision tree is a CodeGen representation, not the exhaustiveness data
  structure itself.
]

== Decision-tree lowering preserves source semantics

```cpp
match (value) {
  case { 1 } => one();
  case { 2 } if (expensive()) => guarded_two();
  case { 3 } => three();
  case _ => other();
}
```

#v(0.4em)

- The discriminator can select `1`, `2`, or `3` together.
- `expensive()` is evaluated only when the `2` row reaches its action.
- A failed guard continues with the remaining source rows.
- Pattern declarations are initialized immediately before their handler.
- Integral value tests can become a switch or lookup table.

#speaker-note[
- A discriminator test may select several source rows at once.
- Guards remain action-local and retain a continuation for later rows.
- Declarations move into the selected action so failed tests do not perform
  copies or moves.
]

== Current status

#grid(
  columns: (1fr, 1fr),
  gutter: 18pt,
  panel([Implemented], [
    - Full parser and AST
    - Template dependence
    - Constant evaluation
    - Exhaustiveness/usefulness
    - Code generation
    - Standard-library protocols
    - Self-hosting Clang/LLVM branch
  ]),
  panel([Still being refined], [
    - Exact library protocol surface
    - Wording
    - Diagnostics and recovery
    - Compile-time performance
    - Additional decision-tree optimizations
  ], fill: rgb("fffbeb"), stripe: warm),
)

#v(0.55em)
#callout([R6 is the design being presented. Post-R6 implementation work is
being used to validate and sharpen that design, not to expand tomorrow's
surface-area discussion.])

#speaker-note[
- Be candid that wording and protocol spelling remain unfinished.
- PCH/PCM completeness is not the focus of the prototype.
- The implementation is mature enough to measure behavior on real code.
]

== Takeaways

#set text(size: 24pt)

1. *The use cases already exist* throughout Clang and LLVM.

2. *Ordinary declarations* express ownership, references, constraints, and
   forwarding without a second binding language.

3. *`alternative_traits` exposes structure* that equality and cast chains hide.

4. *Exhaustiveness over the right domain matters*, especially for generated
   AST hierarchies such as `DeclContext`.

5. *The prototype is substantial enough to evaluate* semantics, diagnostics,
   compile times, and generated code using real code.

#speaker-note[
- Recap structure, safety, and implementation evidence.
- Stop here rather than filling the hour; this audience will have detailed
  questions.
]

== Questions

#set align(center)
#v(1.2em)
#text(size: 40pt, weight: "bold", fill: accent)[Questions]
#v(0.8em)
#text(size: 22pt)[P2688R6 · implementation branch · LLVM self-hosting branch]

= Backup

== Generic projection is structural

```cpp
using Value = std::variant<
    int,
    std::tuple<int, int>,
    std::pair<int, int>,
    std::array<int, 2>>;

match (value) {
  case { int scalar } => use_scalar(scalar);
  case { auto&& [x, y] } => use_coordinates(x, y);
}
```

#v(0.5em)

#callout([The second case is specialized only for structurally compatible
projections. It handles three alternatives without naming their types.])

#speaker-note[
- This is the main payoff of generic projection beyond typed variant dispatch.
- The braces enter each viable alternative; decomposition then checks the
  projected type's structure.
- The handler is instantiated separately for the useful projected types.
]

== Why not extend `switch`?

- `switch` performs integral promotions and ignores user-defined equality.
- Its condition and labels are not general composable patterns.
- Existing grammar and control-flow rules assume labels inside one statement.
- Pattern handlers need expression results and declaration scopes.
- Alternative projection, decomposition, and runtime class refinement are not
  naturally case-label operations.

#v(0.5em)

#callout([The proposal keeps familiar `match (subject) { case ... }` syntax
without retrofitting every historical `switch` rule onto a different model.])

== Why not depend entirely on `operator==`?

```cpp
if (x == 0) return 42;
else if (x == 1) return 7;
else if (x == 2) return 99;
// ... eight optional comparisons ...
```

- Equality is opaque across an ABI or uninlined call.
- It does not advertise an alternative domain.
- It does not identify a projection.
- It cannot establish exhaustiveness or redundancy.
- A chain may remain linear even at `-O3`.

```cpp
match (x) {
  case { 0 } => 42;
  case { 1 } => 7;
  case { 2 } => 99;
  // ...
  case {} => -1;
  case _ => 0;
}
```

The prototype emits one engagement test and multiway value dispatch.

== Why `case`?

```cpp
match (x) {
  [[likely]] case [[maybe_unused]] int value => use(value);
  case _ => fallback();
}
```

- Clearly marks the start of each arm in large selections.
- Provides an attachment point for case attributes.
- Unifies `match`, `match(E, case P)`, and `if (case P = E)`.
- Makes contextual recognition of `match (x) { case ... }` practical.

Without `case`, existing code such as this remains syntactically relevant:

```cpp
struct match { int x; };
match (x) { 0 }; // declaration today
```

== Subject lifetime and value category

```cpp
match (make_variant()) {
  case { Widget&& widget } => consume(std::move(widget));
  case { const Error& error } => report(error);
}
```

- The subject is evaluated exactly once.
- Its lifetime extends through the selection.
- Projection preserves the customization's cvref behavior.
- A declaration pattern then performs its stated initialization.
- Non-trivial moves are restricted where a later guard or test could fail.

== Exhaustiveness vocabulary

#table(
  columns: (1.4fr, 4fr),
  inset: 8pt,
  table.header([*Term*], [*Meaning*]),
  [Required states], [Advertised states that exhaustive matching must cover],
  [Residual states], [Possible runtime states outside the required domain],
  [Useful case], [A case that matches at least one value not covered earlier],
  [Opaque test], [A test whose truth does not structurally cover a state],
)

#v(0.5em)

```cpp
match (value) {
  case { int x } => use(x);
  case { int y } => use_again(y); // diagnosed as redundant
}
```

== Self-hosting scope

#set text(size: 18pt)

The experiment includes transformations involving:

- `std::variant`, `std::optional`, and `std::expected`-like types
- `llvm::ErrorOr` and `llvm::PointerUnion`
- `llvm::object::Binary` open and closed dispatch
- `Decl`, `DeclContext`, and `Stmt` generated alternatives
- `StringSwitch`, prefix predicates, and selected `TypeSwitch` sites
- AST printing, mangling, CodeGen, indexing, module maps, HLSL, WebAssembly,
  object tools, debug information, XRay, and TableGen

#v(0.5em)

#callout([The branch changes roughly 100 files. The purpose is broad design
validation; it is not a request to migrate LLVM wholesale.])
