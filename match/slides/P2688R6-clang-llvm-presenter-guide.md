# P2688R6 Clang/LLVM Presentation Notes

## Timing

Target 35–38 minutes of prepared material, leaving at least 20 minutes for
questions.

| Time | Slides | Goal |
|---:|---|---|
| 0:00–0:05 | Claim, experiment, census | Establish that this is implementation evidence, not a syntax pitch |
| 0:05–0:15 | Proposal overview | Teach enough R6 syntax to read the migrations |
| 0:15–0:29 | LLVM experience | Move from an optional test to generated AST alternatives |
| 0:29–0:38 | Protocol, code generation, and implementation | Explain why this is more than `operator==` and nested `if` |
| 0:38–0:40 | Status and takeaways | Stop and invite technical questions |

If discussion starts early, skip these main slides first:

1. *Named states distinguish identical payload types*
2. *Collapse nested nullable control flow*
3. *Not every migration is a win*
4. *Decision-tree lowering preserves source semantics*

Do not rush the `DeclContext` example. It is the strongest part of the talk.

## Framing

- Present R6 as the proposal under discussion.
- Describe subsequent work as implementation and self-hosting experience.
- Do not teach `and` patterns, block-scope pattern declarations, or other
  tentative post-R6 additions unless somebody asks.
- This is not a proposal to mechanically rewrite LLVM. Some experimental
  transformations are intentionally marginal so that the design is tested at
  its boundaries.

## Example Sources

### Optional value test

- Self-hosting commit: `30ec3fcc7060`
- File: `llvm/lib/Transforms/InstCombine/InstCombineSelect.cpp`
- Point: `{ false }` simultaneously checks engagement and the projected value.

### Variant `get_if` chain

- Self-hosting commit: `822032dc4484`
- File: `llvm/utils/TableGen/DFAEmitter.cpp`
- Point: the test and projection cannot become inconsistent, and the closed
  variant provides exhaustiveness.

### Destructive variant extraction

- Self-hosting commit: `350f81b7f5c5`
- File: `clang/lib/AST/ExprCXX.cpp`
- Point: declaration syntax exposes whether the payload is copied, borrowed,
  or moved.

### Chained nullable projection

- Self-hosting commit: `30ec3fcc7060`
- File: `clang/lib/CodeGen/TargetBuiltins/AMDGPU.cpp`
- Point: names introduced by the first pattern condition are usable by the
  second condition and successful statement.

### Generated `Decl` alternatives

- Generator commit: `84811d795752`
- Usage commit: `15bd2d7a2d88`
- Representative files:
  - `clang/lib/AST/ItaniumMangle.cpp`
  - `clang/lib/AST/ASTContext.cpp`
  - `clang/lib/CodeGen/CodeGenPGO.cpp`
- Point: Clang already owns a closed discriminator. Pattern matching joins it
  to the corresponding typed projection.

### `DeclContext` domain

- Generator commit: `879b6836e1e3`
- Usage commit: `030ac68c4f68`
- File: `clang/lib/AST/DeclBase.cpp`
- Historical bug: LLVM commit `eebc494a577a`
- Later removal: LLVM commit `65ebd13f4185`
- Point: matching the actual narrowed domain gives stronger exhaustiveness
  checking than switching over broad `Decl::Kind` and adding a `default`.

### Optional code-generation comparison

Generated with the current P2688 prototype (`6a8cbe851111`) and libc++:

```sh
build-release/bin/clang++-p2688 \
  -std=c++26 -fpattern-matching -stdlib=libc++ \
  -O3 -S -masm=intel optional-codegen.cpp
```

`with_equals` remains eight linear compare-and-branch blocks. `with_match`
contains:

1. one engagement test;
2. one unsigned `value <= 7` range check; and
3. one indexed load from an eight-entry result table.

The claim is not that an optimizer could never recover structure from inline
`operator==` implementations. The evidence is that the current optimizer does
not do so here even at `-O3`, while the match lowering exposes that structure
directly before LLVM optimization.

## Questions To Expect

### Why not extend `switch`?

Lead with semantics rather than syntax: `switch` has integral promotions,
labels embedded in one statement, historical control-flow rules, and no model
for projection or declaration-bearing expression handlers. A separate
construct can still lower to a switch.

### Why is `alternative_traits` necessary?

Equality and casts answer individual runtime questions. They do not advertise
a finite domain, connect a discriminator to projections, or support structural
exhaustiveness. The protocol exposes those facts once.

### Does this use `dynamic_cast` for `Decl`?

No. The generated specialization uses `Decl::Kind` as its discriminator and
projects the corresponding concrete type. Open polymorphic matching is a
separate protocol.

### Is case selection overload resolution?

No. Cases remain ordered. Declaration applicability determines whether a case
can match a candidate subject; it does not rank cases against one another.

### What happens in templates?

Projection can create case-local dependent contexts similar to a visitor's
generic lambda. Usefulness analysis prevents already-covered alternative
domains from instantiating later generic handlers.

### Are guards allowed to mutate the subject?

Cases are considered in source order, but the ordering of independent pattern
tests is intentionally not an observable sequencing mechanism. A guard runs
only after its pattern succeeds; its side effects remain if the guard fails.

### What about code generation?

The implementation builds a decision tree. Closed discriminators and integral
value tests can become multiway branches. Declarations are delayed until the
selected action. Guards retain explicit fallback continuations.

### What is implemented today?

Parser, AST, semantic analysis, templates, exhaustiveness/usefulness,
constant evaluation, and CodeGen are implemented. PCH/PCM completeness is not
the focus of the prototype. Both `check-clang` and `check-cxx` pass on the
current pattern-matching branch.

## Build

```sh
cd ~/local/wg21-papers/match
make slides
```

This requires Typst and access to the Touying `0.6.1` preview package. The
current development host does not have Typst installed, and its network filter
blocks both GitHub release assets and `packages.typst.org`, so the first PDF
render still needs to be run in an environment with that toolchain.
