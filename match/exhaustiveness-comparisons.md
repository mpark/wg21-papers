# Exhaustiveness Checking Across Languages

## Common Model

Most approaches answer the same set question:

```text
useful(previous, P)  iff  values(P) \ values(previous) is nonempty
exhaustive(patterns) iff  required-domain \ values(patterns) is empty
```

They differ in how those sets are represented and manipulated.

| Language | Core approach | Main strength | Main limitation |
|---|---|---|---|
| Rust | Maranget-style usefulness matrix | Precise recursive patterns, ranges, slices, and or-patterns | Worst-case exponential/NP-complete |
| OCaml | Pattern matrix plus witness re-typechecking | Mature ML algorithm; handles GADTs | GADT/type inhabitation requires conservative heuristics |
| Haskell/GHC | Guard trees plus symbolic refinement states | Models guards, GADTs, laziness, and bottom | Much more machinery; explicit precision limit |
| C#/Roslyn | Decision DAG plus abstract value sets | Checker closely follows runtime dispatch semantics | Open class hierarchy; arbitrary guards remain opaque |
| Java/javac | Fixed-point type/record coverage reduction | Simple, predictable, and directly specifiable | Only supports Java's restricted pattern universe |
| Scala 3 | Symbolic space algebra | Natural union/intersection/subtraction model | Space normalization can grow rapidly |
| Dart | Symbolic space algebra | Designed directly around sealed types, records, and objects | User-defined/open behavior needs approximation |
| Swift | Recursive case-space decomposition | Strong enum/tuple checking and library evolution | Arbitrary `~=` patterns cannot prove coverage |
| Kotlin | Enumeration of enum/sealed alternatives | Very predictable | Not a general compositional pattern checker |
| Python | No language exhaustiveness checking | No compile-time complexity | Type checkers must provide optional approximations |

## Rust

Rust uses a modern extension of Luc Maranget's usefulness algorithm.

A match is represented as a matrix of pattern vectors. For each constructor,
the checker specializes the matrix by removing that constructor and exposing
its fields. It recursively checks the resulting matrix and later
"unspecializes" missing witnesses.

Important extensions include:

- Integer ranges are partitioned at pattern boundaries.
- Slice lengths are grouped into finitely many equivalence classes.
- Or-patterns are expanded while usefulness is tracked per alternative.
- A contextual `Missing` constructor represents all constructors absent from a
  column.
- `#[non_exhaustive]` introduces a hidden constructor.
- Opaque constants do not contribute to proving exhaustiveness.
- Guarded arms generally do not contribute coverage.
- "Relevancy" pruning avoids exploring Cartesian combinations that cannot
  change the answer.

Rust explicitly notes that exhaustiveness is NP-complete. Its relevancy
optimization preserves the yes/no answer but may change which witnesses are
reported.

Sources: [rustc usefulness implementation][rust-usefulness],
[rustc development guide][rust-guide].

## OCaml

OCaml's `Parmatch` is the direct production descendant of Maranget's
algorithm:

- `satisfiable(matrix, row)` implements usefulness.
- `exhaust(matrix)` generates uncovered vectors.
- A single-row shortcut avoids exponential expansion of patterns such as
  `(A | B, A | B, ...)`.
- Guarded clauses are removed from the matrix used to prove exhaustiveness.
- Polymorphic and extensible variants are treated as potentially open.

For GADTs, the structural checker may generate witnesses that are impossible
under type constraints. OCaml converts those witnesses back into source
patterns and asks the type checker whether they are inhabitable. Impossible
witnesses are discarded.

The source explicitly accepts conservative redundancy results: an ill-typed
but superficially coherent branch may cause dead code not to be diagnosed.

Sources: [OCaml `parmatch.ml`][ocaml-parmatch],
[Warnings for Pattern Matching][maranget], and
[GADTs and Exhaustiveness][ocaml-gadt].

## Haskell/GHC

GHC moved beyond a conventional matrix because Haskell has guards, view
patterns, GADTs, pattern synonyms, laziness, and bottom.

"Lower Your Guards" lowers matching into a small guard-tree language
containing:

- Constructor tests
- Let bindings
- Strictness tests
- Sequential guards
- Alternative clauses

The checker symbolically interprets this tree over sets of normalized
refinement types called `Nablas`. It separately tracks:

- Covered values
- Uncovered values
- Diverging values

The solver combines term constraints with GHC's type constraints and
understands `COMPLETE` pattern-synonym sets.

GHC has an explicit `-fmax-pmcheck-models` limit. When refinement would exceed
it, GHC forgets information and returns to a larger incoming state. This is
deliberately conservative:

- It may miss redundant clauses.
- It may report a match as possibly incomplete when it is actually complete.
- It should not incorrectly declare an incomplete match exhaustive or a useful
  clause redundant.

Sources: [Lower Your Guards][lower-guards] and [GHC checker][ghc-checker].

## C#

Roslyn builds a decision DAG containing evaluations, tests, bindings, guard
nodes, and arm leaves.

Exhaustiveness is operationally simple: Roslyn adds or retains a
failure/default leaf and determines whether that leaf remains reachable.
`PatternExplainer` follows a path to it to construct a missing example.

Its abstract tests include:

- Null and type tests
- Constant and relational tests
- Numeric value sets and intervals
- Property/deconstruction evaluations
- List length and element tests

A nonconstant `when` guard leaves both success and failure possible. C# also
models the full underlying domain of enums, so covering every named enumerator
can still produce CS8524 for an unnamed enum value.

Subsumed arms are errors. Non-exhaustive switch expressions generally produce
a warning and retain a runtime throwing path.

Sources: [Roslyn pattern design][roslyn-patterns] and
[C# pattern specification][csharp-spec].

## Java

OpenJDK 25 uses a narrower, concrete reduction algorithm rather than a general
matrix.

`javac` collects descriptions of unguarded binding and record patterns, then
repeatedly:

1. Replaces all covered permitted subclasses with their sealed supertype.
2. Groups record patterns that differ in one component.
3. Recursively reduces that component.
4. Replaces a record whose components are covered with a binding pattern.
5. Checks whether the selector type is covered.

Boolean literals and enum constants receive dedicated handling. Generic sealed
hierarchies filter permitted subclasses based on whether they are compatible
with the instantiated selector type.

Java distinguishes exhaustiveness from unconditionality and runtime remainder:

- `case Object o` can be exhaustive even though it does not match `null`; null
  triggers the switch's implicit null check.
- An exhaustive enum or sealed switch gets a synthetic throwing default to
  protect against separate-compilation evolution.
- Guarded cases do not contribute unless effectively unguarded.

Sources: [OpenJDK exhaustiveness note][java-exhaustiveness], [JEP 441][jep441],
and [javac `Flow.java`][javac-flow].

## Space Algorithms

Scala 3 and Dart represent patterns as symbolic sets called spaces. Typical
forms are:

```text
Empty
Type(T)
Constructor(C, fields...)
Union(space...)
```

They implement `union`, `intersection`, `isSubspace`, and `subtract`.
Exhaustiveness is computed directly as:

```text
selector-space - union(case-spaces)
```

This is mathematically clean and naturally handles union types, sealed
subclasses, products, and nested patterns. It is essentially the set-theoretic
dual of Maranget specialization. Its practical challenge is keeping
subtraction and normalization from producing exponentially many spaces.

Sources: [generic space algorithm][space-paper] and
[Dart exhaustiveness design][dart-exhaustiveness].

## Implications for P2688

The strongest fit is a Rust/OCaml-style usefulness checker, expressed
semantically as space subtraction:

- `alternative_traits` alternatives are constructors.
- Integers and enum values use interval/singleton constructor partitions.
- Structural patterns specialize into component columns.
- Or-patterns expand into alternative rows.
- Guards do not contribute coverage unless manifestly `true`.
- Dependent patterns use the existing useful/maybe-useful/not-useful
  classification.
- Opaque user-defined comparisons should not prove exhaustiveness.

The required-versus-residual distinction is defensible and has nearby
precedent:

- Rust has `Missing` and hidden non-exhaustive constructors.
- Java distinguishes exhaustive source coverage from runtime remainder.
- Swift distinguishes frozen and nonfrozen enum evolution.
- C# explicitly keeps unnamed enum values in the domain.

The principal implementation risk is exponential state growth. GHC provides
the clearest conservative fallback model: overapproximate remaining values,
which may lose redundancy diagnostics or request a wildcard, but never accepts
a genuinely incomplete match.

Finally, coverage analysis and dispatch lowering should remain separate. C#
shares a decision DAG because its runtime tests and coverage abstraction align
closely; C++ projections, templates, arbitrary equality, and user protocols
make that coupling substantially riskier.

[rust-usefulness]: https://doc.rust-lang.org/nightly/nightly-rustc/src/rustc_pattern_analysis/usefulness.rs.html
[rust-guide]: https://rustc-dev-guide.rust-lang.org/pat-exhaustive-checking.html
[ocaml-parmatch]: https://github.com/ocaml/ocaml/blob/trunk/typing/parmatch.ml
[maranget]: http://moscova.inria.fr/~maranget/papers/warn/warn.pdf
[ocaml-gadt]: https://arxiv.org/abs/1702.02281
[lower-guards]: https://dl.acm.org/doi/10.1145/3408989
[ghc-checker]: https://gitlab.haskell.org/ghc/ghc/-/blob/master/compiler/GHC/HsToCore/Pmc/Check.hs
[roslyn-patterns]: https://github.com/dotnet/roslyn/blob/main/docs/features/patterns.md
[csharp-spec]: https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/patterns
[java-exhaustiveness]: https://openjdk.org/projects/amber/design-notes/patterns/exhaustiveness
[jep441]: https://openjdk.org/jeps/441
[javac-flow]: https://github.com/openjdk/jdk/blob/master/src/jdk.compiler/share/classes/com/sun/tools/javac/comp/Flow.java
[space-paper]: https://doi.org/10.1145/2998392.2998401
[dart-exhaustiveness]: https://github.com/dart-lang/language/blob/main/accepted/3.0/patterns/exhaustiveness.md
