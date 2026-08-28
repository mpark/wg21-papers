---
title: "Nested Structured Bindings"
document: DXXXXR0
date: today
audience: Evolution
author:
  - name: Michael Park
    email: <mcypark@gmail.com>
toc: true
toc-depth: 4
---

# Abstract

Structured bindings provide concise names for the immediate components of an
array or class object, but they cannot directly describe a recursively nested
product. This is increasingly limiting as generic library facilities compose
product types. Associative containers add a `pair` around their key and mapped
value, range adaptors such as `zip` and `enumerate` compose tuple layers, and
concurrency facilities commonly return tuples whose elements are themselves
tuple-like.

This paper proposes allowing a structured-binding-list wherever an identifier
can currently appear in a structured binding:

```cpp
auto [[x, y], z] = expression;

for (const auto& [[attribute, source], values] : attributes) {
  // ...
}

auto [[first_value, first_status],
      [second_value, second_status]] = collect_results();
```

Only the outer declaration has a *decl-specifier-seq* and optional
*ref-qualifier*. A nested structured-binding-list is an implicit forwarding
decomposition of the corresponding projection. It does not independently
copy, move, or const-qualify that projection.

# Introduction

Structured bindings were introduced by [@P0144R2] and have become the normal
way to consume small product types in C++. Their syntax, however, is limited to
one level:

```cpp
auto [outer, value] = expression;
auto [x, y] = outer;
```

The language can describe the shape of the first product but not the shape of
the complete value. An intermediate name must be introduced even when the
program has no use for that intermediate object as a whole.

This paper proposes the direct spelling:

```cpp
auto [[x, y], value] = expression;
```

The proposal is deliberately recursive. Any component that can be decomposed
by an ordinary structured binding can itself contain a nested
structured-binding-list:

```cpp
auto [a, [b, [c, d]], e] = expression;
```

The proposal does not flatten products. Bracket nesting continues to express
the actual structure of the object.

# Motivation

The examples in this section are simplified from recurring constructions found
in a survey of a large production C++ codebase. In particular, the survey found
direct two-stage structured bindings in container traversal, coroutine result
handling, range-adaptor pipelines, and service code, as well as substantially
more code accessing nested products through chains of `.first` and `.second`.

## Product Types Compose

The strongest motivation is not saving a line of code. It is restoring
compositionality.

Many library operations naturally add one product layer around another:

```cpp
// map<pair<Key, Source>, vector<Value>>::value_type
pair<const pair<Key, Source>, vector<Value>>

// enumerate(zip(indices, strides))
pair<size_t, tuple<Index&, Stride&>>

// collect_all(task<pair<A, B>>, task<pair<C, D>>)
tuple<pair<A, B>, pair<C, D>>
```

The types compose recursively, but the corresponding declaration syntax does
not. Users must turn a structural operation into a sequence of statements.

## Associative Containers

Consider a map whose key is itself a product:

```cpp
using AttributeMap =
    std::map<std::pair<AttributeKey, std::string>,
             std::vector<std::string>>;

for (const auto& [map_key, values] : attributes) {
  const auto& [attribute, source] = map_key;
  // ...
}
```

The proposed syntax names the domain values directly:

```cpp
for (const auto& [[attribute, source], values] : attributes) {
  // ...
}
```

The same situation occurs when the mapped value is tuple-like:

```cpp
for (const auto& [id, value] : adjustments) {
  const auto& [kind, weight, owner] = value;
  // ...
}
```

becomes:

```cpp
for (const auto& [id, [kind, weight, owner]] : adjustments) {
  // ...
}
```

Names such as `map_key`, `value`, `pair`, and `tuple` describe representation,
not the domain. Nested structured bindings allow names to be attached only to
the components the program actually uses.

## Range Adaptor Composition

Range adaptors frequently produce nested tuple-like values. For example, code
consuming an enumeration of a zip currently needs two declarations:

```cpp
auto [position, zipped] = element;
auto [index, stride] = zipped;
```

With nested structured bindings:

```cpp
auto [position, [index, stride]] = element;
```

Flattening the adaptor result is not a general substitute. Nesting preserves
which operation produced each group, and arbitrary compositions cannot
reasonably provide a bespoke flattened result type.

## Concurrent Results

Concurrency APIs commonly preserve the result type of each operation:

```cpp
auto [first_result, second_result] = co_await collect_all(first(), second());
auto& [first_value, first_status] = first_result;
auto& [second_value, second_status] = second_result;
```

The proposed syntax directly describes the result shape:

```cpp
auto [[first_value, first_status],
      [second_value, second_status]] =
    co_await collect_all(first(), second());
```

The outer object is still materialized only once. The nested lists refer to
its projected components.

## Nested Pairs in Existing Interfaces

Some existing interfaces expose nested `pair`s that cannot immediately be
replaced by named classes. Such code often contains sequences like:

```cpp
for (const auto& range : feature_ranges) {
  const auto& feature_name = range.first.first;
  const auto& indices = range.first.second;
  const auto& operation = range.second.first;
  const auto& value = range.second.second;
  // ...
}
```

Nested structured bindings provide a local structural description:

```cpp
for (const auto& [[feature_name, indices], [operation, value]] :
     feature_ranges) {
  // ...
}
```

A named class is often preferable for a durable domain model. It is not,
however, an answer for externally defined interfaces, generic adaptor results,
or temporary products assembled by library composition.

# Proposal

Permit a structured-binding-list in place of an identifier within another
structured-binding-list:

```cpp
auto [x, [y, z]] = expression;
```

The declaration has exactly one written *decl-specifier-seq* and optional
*ref-qualifier*:

```cpp
auto [x, [y, z]] = expression;
auto& [x, [y, z]] = expression;
const auto& [x, [y, z]] = expression;
auto&& [x, [y, z]] = expression;
```

The outer declaration controls the ownership and lifetime of the initialized
object. A nested list does not introduce another independently configurable
`auto`, `auto&`, or `auto&&` declaration.

## Recursive Structure

Nesting is structural rather than flattening:

```cpp
std::tuple<std::pair<int, int>, int> value;

auto [[x, y], z] = value; // OK
auto [x, y, z] = value;   // still ill-formed: value has two components
```

Arity is checked independently at every level. If any nested component is not
decomposable with the indicated number of bindings, the declaration is
ill-formed.

## Names and Scope

Only identifiers at the leaves introduce names:

```cpp
auto [[x, y], z] = expression;
```

introduces `x`, `y`, and `z`. No entity corresponding to the first nested
group is nameable.

The leaf identifiers inhabit the same scope and have the same locus as the
identifiers in an ordinary structured-binding declaration. Their referenced
types, `decltype` behavior, capture behavior, and placeholder-name behavior
are otherwise unchanged.

If the program needs both an intermediate object and its components, it should
continue to use two declarations:

```cpp
auto& [key, value] = entry;
auto& [first, second] = key;
use(key, first, second);
```

This proposal does not introduce an `as`-binding for simultaneously naming an
interior node and its descendants.

# Forwarding Semantics

## Overview

A nested structured-binding-list behaves as an implicit forwarding
decomposition of its corresponding component. Introducing an intermediate
source-level name must not turn an xvalue projection into an lvalue.

Define the forwarding expression for an entity `e` as:

```cpp
F(e) = static_cast<decltype(e)&&>(e)
```

For each nested binding position, the initializer of the recursive
decomposition is determined according to the same decomposition protocol that
selected the component.

| Decomposition protocol | Recursive initializer |
|---|---|
| Array | `F(e)[i]` |
| Tuple-like | `static_cast<U_i&&>(r_i)` |
| Member | `F(e).m_i` |

The nested list is then interpreted as an implicit structured-binding
declaration whose *decl-specifier-seq* is `auto` and whose *ref-qualifier* is
`&&`:

```cpp
auto&& [nested-bindings...] = recursive-initializer;
```

This process is recursive.

## Array Decomposition

For an array decomposition, the recursive initializer for element `i` is:

```cpp
F(e)[i]
```

For example:

```cpp
int matrix[2][2] = {{1, 2}, {3, 4}};
auto& [[a, b], [c, d]] = matrix;
```

Both row projections are lvalues because `e` is an lvalue reference. If the
outer entity is an xvalue, the array element projection is correspondingly an
xvalue.

The complete outer array is initialized according to the written
`cvref-auto`. Nested decomposition does not independently copy either row.

## Tuple-Like Decomposition

For tuple-like decomposition, use the entities already specified by
[dcl.struct.bind]. Let:

```cpp
T_i = std::tuple_element_t<i, E>
```

and let `I_i` be the initializer formed by the appropriate member or
argument-dependent `get<i>` call. The existing structured-binding rules define
`U_i` as follows:

```cpp
U_i = T_i;    // I_i is a prvalue
U_i = T_i&;   // I_i is an lvalue
U_i = T_i&&;  // I_i is an xvalue
```

The implementation introduces an entity `r_i` of type `U_i`, initialized from
`I_i`. The recursive initializer is:

```cpp
static_cast<U_i&&>(r_i)
```

Reference collapsing preserves the category recorded by `U_i`:

```cpp
U_i = T_i&   // recursive initializer is T_i&
U_i = T_i&&  // recursive initializer is T_i&&
U_i = T_i    // recursive initializer is T_i&&
```

This cannot in general be reproduced from the source-level binding name.
For a binding `x`:

```cpp
decltype(x)   // the referenced type T_i
decltype((x)) // an lvalue reference because x is a named expression
```

Neither form recovers `U_i`.

`std::forward_like` is not a substitute. For example:

```cpp
int value = 42;
std::tuple<int&> tuple(value);
auto&& [x] = std::move(tuple);

static_assert(std::same_as<
    decltype(std::get<0>(std::move(tuple))), int&>);
static_assert(std::same_as<
    decltype(std::forward_like<decltype(std::move(tuple))>(x)), int&&>);
```

The tuple projection remains an lvalue reference, while `forward_like`
incorrectly imposes the outer tuple's rvalue category on the referred-to
`int`. The compiler can forward correctly because it retains `U_i`.

## Member Decomposition

For member decomposition, the recursive initializer for member `m_i` is:

```cpp
F(e).m_i
```

For example:

```cpp
struct Outer {
  Inner inner;
};

auto&& [[x, y]] = Outer{};
```

is conceptually:

```cpp
auto&& e = Outer{};
auto&& nested = static_cast<decltype(e)&&>(e).inner;
auto&& [x, y] = static_cast<decltype(nested)&&>(nested);
```

Using the actual forwarded member-access expression handles language rules
that `forward_like` applied to a binding name cannot reconstruct:

```cpp
struct Outer {
  Inner& reference;
  mutable Inner mutable_value;
};
```

Accessing `reference` remains an lvalue regardless of the containing object's
value category. Accessing `mutable_value` does not incorrectly acquire
`const`. The member-access expression itself supplies the correct type and
value category.

## Why the Naive Expansion Is Not Equivalent

The following source transformation is not equivalent to the proposal:

```cpp
auto&& [[x, y]] = Outer{};
```

into:

```cpp
auto&& [temporary] = Outer{};
auto&& [x, y] = temporary;
```

`temporary` is a named expression and therefore an lvalue. This inserts an
accidental lvalue barrier.

The difference is observable for a tuple-like nested component with
ref-qualified `get` overloads:

```cpp
int&  get<0>(Inner&);
int&& get<0>(Inner&&);
```

The proposed nested declaration invokes the `Inner&&` overload when the
projection is an xvalue. The naive expansion invokes the `Inner&` overload.
The overloads may have different effects, return different value categories,
or only one overload may be available.

This does not change the behavior of an existing named member binding:

```cpp
auto&& [inner] = Outer{};
```

The expression `inner` remains an lvalue, as every expression consisting of a
name is. The nested form differs because no source-level name is introduced at
that position. The recursive decomposition consumes the projection before its
category would be erased by naming it.

When every recursive level uses only ordinary array or member decomposition,
the distinction will commonly be unobservable: the final binding names still
refer to the same subobjects. It becomes observable when a recursively
projected object uses a category-sensitive protocol, most notably
ref-qualified tuple-like `get` overloads.

This forwarding behavior follows the existing tuple-like structured-binding
precedent. An owning declaration such as:

```cpp
auto [x] = tuple;
```

already invokes `get<0>` with the hidden copied tuple as an xvalue. The
compiler-generated name does not create an lvalue barrier. Recursive
decomposition should preserve the same property.

Users who intentionally want an lvalue barrier can write the two declarations
explicitly.

# Initialization and Lifetime

The outer decomposition entity is initialized exactly once according to the
written declaration. Each component projection used by a nested binding is
evaluated exactly once.

Initialization proceeds depth-first and left-to-right. A nested decomposition
at position `i` is completed before initialization proceeds to position
`i + 1` of its enclosing list. Destruction is in the corresponding reverse
order.

A prvalue produced by a tuple-like projection is materialized in the existing
`r_i` entity and lives for the lifetime already prescribed for that entity.
The recursive decomposition refers to that materialized object. No additional
copy or move is introduced merely because the binding is nested.

As with ordinary structured bindings, user-defined `get` functions can have
side effects. Nesting does not permit an implementation to evaluate a
projection more than once.

# Packs

Structured-binding packs from [@P1061R10] can appear within any nested list:

```cpp
auto [[first, ...middle, last], metadata] = expression;
```

The pack belongs to the list in which it appears, and its size is determined
from the arity of that list's subject.

This paper does not propose making a nested list itself a pack expansion:

```cpp
auto [...[x, y]] = expression; // not proposed
```

Such syntax would need to specify whether `x` and `y` are correlated packs,
how their expansions are represented, and how they interact with pack
indexing. That is separable future work.

# Attributes and the `[[` Ambiguity

The most visible grammatical issue is that a nested list in the first position
begins with two consecutive `[` tokens:

```cpp
auto [[x, y], z] = expression;
```

Those tokens can initially resemble the start of an
*attribute-specifier-seq*.

Existing declaration attributes and attributes on binding identifiers must
remain valid:

```cpp
[[maybe_unused]] auto [x, y] = expression;
auto [x [[maybe_unused]], y] = expression;
```

The proposed disambiguation is:

1. When `[[` appears where either declaration attributes or a structured
   binding declarator can begin, recognize an *attribute-specifier-seq* only
   when the complete attribute sequence is followed by a token sequence that
   can begin a declarator permitted in that context, including a
   structured-binding declarator.
2. Otherwise, the first `[` begins the outer structured-binding-list and the
   second `[` begins its first nested element.

Therefore:

```cpp
auto [[x, y], z] = expression;
//   ^ outer list
//    ^ nested first element

[[maybe_unused]] auto [[x, y], z] = expression;
// declaration attribute  ^ nested structured-binding declarator
```

After the *decl-specifier-seq* or ref-qualifier, a `[[` token sequence can
still be parsed as an attribute-specifier by the existing grammar, including
in ill-formed programs and for implementation-defined type attributes. This
requires bounded tentative parsing of one potential attribute sequence and
the beginning of the following declarator. It does not require arbitrary token
scanning.

This paper does not add attributes that apply to a nested list as a group.
Existing declaration attributes and attributes on individual structured
binding identifiers remain available.

## The Existing `[[` Restriction

[dcl.attr.grammar] currently requires two consecutive left square bracket
tokens to appear only when introducing an attribute-specifier or within the
balanced-token-seq of an attribute argument. The accompanying note makes this
restriction apply even when another grammar production would otherwise give
the tokens an unambiguous meaning.

Consequently, whitespace does not avoid the problem:

```cpp
auto [ [x, y], z] = expression; // still two consecutive `[` tokens
```

This proposal necessarily adds a narrow exception for the case where the first
token opens a structured-binding-list and the second opens a nested
structured-binding-list. The exception is needed only when a nested group is
the first element of its enclosing list:

```cpp
auto [[x, y], z] = expression; // requires the exception
auto [z, [x, y]] = expression; // does not
```

## A Broader Relaxation

The existing restriction also prohibits an opening subscript, array bound, or
pack index from being immediately followed by a lambda introducer:

```cpp
table[[]{ return 1; }()];
int data[[]{ return 4; }()];
new int[[]{ return size; }()];
pack...[[]{ return 0; }()];
```

Those expressions can be written by parenthesizing the lambda expression:

```cpp
table[([]{ return 1; }())];
```

It would be possible to replace the global restriction with a contextual rule:
two consecutive `[` tokens would introduce an attribute only where an
attribute-specifier is permitted, and would otherwise participate normally in
the surrounding grammar. This would make the examples above well-formed and
would avoid reserving this token sequence against future bracket-composing
features.

The practical motivation outside nested structured bindings appears limited,
however, and all existing expression cases have a straightforward
parenthesized spelling. A broad relaxation would also change parsing and
diagnostics beyond this proposal. The conservative direction is therefore to
retain the existing rule generally and add only the structured-binding
exception required by this feature. A broader cleanup remains separable.

## Parenthesized Initialization

An outer list containing exactly one nested list has the same complete bracket
shape as an attribute-specifier:

```cpp
auto [[x]](expression);
```

There are two possible interpretations:

```cpp
auto [[x]] (expression); // attribute followed by a parenthesized declarator
auto [[x]](expression);  // nested binding with a parenthesized initializer
```

When `expression` is an identifier, the first interpretation is syntactically
a variable declaration, but placeholder type deduction subsequently makes it
ill-formed because the variable has no initializer. Selecting the nested
interpretation on that basis would make disambiguation depend on more than the
local grammar.

Some forms have two interpretations that can each produce a well-formed
declaration:

```cpp
auto [[vendor_attribute]](f());
```

The attribute interpretation declares a function named `f` with a deduced
return type. The nested-binding interpretation decomposes the result of calling
`f` and introduces a binding named `vendor_attribute`.

Unlike the familiar function-declaration-versus-object-initialization case,
adding another pair of parentheses does not force the initializer
interpretation here:

```cpp
auto [[vendor_attribute]]((f()));
```

Under the attribute interpretation, the declarator-id has not been consumed
before the parentheses are encountered, so the declarator itself can be
parenthesized repeatedly. This still declares a function named `f`.

Making the latter interpretation available requires an explicit priority rule:
when an attribute-shaped token sequence following `auto` can also form a
nested structured-binding declarator followed by a parenthesized initializer,
the nested structured-binding interpretation would have to win. This would
reinterpret currently valid attributed function declarations such as the one
above. An attributed parenthesized variable declarator followed by an explicit
initializer remains distinguishable because the trailing initializer cannot
belong to the nested interpretation:

```cpp
auto [[vendor_attribute]] (name) = initializer; // attribute interpretation
```

Such declarations are unusual, and many declaration attributes can instead be
placed before `auto`, but changing their interpretation is nevertheless a
source compatibility break. Preserving the existing attribute/declarator
priority instead means that this one nested form must use `=` or braces:

```cpp
auto [[x]] = expression;
auto [[x]]{expression};
```

Those initializer forms are not always semantically interchangeable with
parenthesized direct-initialization. For example:

```cpp
struct Inner {
  int value;
};

struct Outer {
  Inner inner;

  explicit Outer(Outer const&) = default;
  Outer(std::initializer_list<Outer>) = delete;
};

Outer outer;

auto [a](outer);  // OK: direct-initialization considers the explicit constructor
auto [b] = outer; // error: copy-initialization does not
auto [c]{outer};  // error: direct-list-initialization prefers initializer_list
```

For a non-array initializer, C++23's deduced functional-cast syntax provides a
generic rewrite that preserves direct-initialization of the copy while the
outer initialization benefits from guaranteed copy elision:

```cpp
auto [[x]] = auto(expression);
```

This avoids naming the subject type. It is not completely general, however:
`auto(array)` performs array-to-pointer conversion, whereas a by-value
structured binding initialized directly from an array preserves the array type
and initializes its elements individually. Thus `=` and braces are not by
themselves equivalent replacements for parentheses, but `auto(expression)`
substantially reduces the practical cost for class subjects. This cost must be
weighed against changing the attribute/declarator priority.

The prototype currently preserves attribute/declarator priority. Whether the
parenthesized nested form is important enough to justify reversing that
priority is an explicit design question rather than an implementation detail.

# Grammar

The grammar should distinguish a leaf identifier from a recursively nested
binding. Using descriptive names rather than attempting to exactly reproduce
the current working draft's pack grammar, the intended structure is:

```bnf
structured-binding-list:
    structured-binding
    structured-binding-list , structured-binding

structured-binding:
    structured-binding-identifier
    [ structured-binding-list ]
```

The existing syntax for a structured-binding pack remains part of
*structured-binding-identifier*. A nested *structured-binding-list* is not
itself permitted to carry an ellipsis by this proposal.

The empty-list question is orthogonal. If an empty structured binding is
otherwise permitted by the language version, it is also permitted recursively;
otherwise a nested empty list remains ill-formed.

# Examples

## Nested Member and Tuple-Like Decomposition

```cpp
struct Record {
  std::tuple<int, std::string> key;
  double score;
};

Record record;
auto& [[id, name], score] = record;

id = 42;
score += 1.0;
```

The outer member projection of `key` is an lvalue because `record` is bound by
`auto&`. The inner tuple-like decomposition therefore invokes `get` with an
lvalue tuple.

## Forwarding an Rvalue

```cpp
struct Record {
  std::tuple<std::unique_ptr<int>> payload;
};

auto&& [[pointer]] = Record{/* ... */};
```

The `payload` member is projected from the forwarded outer entity and is an
xvalue. Its tuple-like decomposition therefore uses its rvalue `get` overload.
The name `pointer` remains an lvalue expression, as all named variables do;
the forwarding applies while recursively selecting and initializing the
binding entity.

## Reference Members

```cpp
struct Record {
  std::tuple<int, int>& payload;
};

Record record{some_tuple};
auto&& [[x, y]] = std::move(record);
```

Even though the `Record` is an xvalue, member access to `payload` is an lvalue
because `payload` is a reference member. The nested tuple is consequently
decomposed as an lvalue.

## Range-For

```cpp
for (auto&& [position, [left, right]] :
     views::enumerate(views::zip(lhs, rhs))) {
  compare(position, left, right);
}
```

The proposal composes naturally with the existing structured-binding use in a
*for-range-declaration*.

# Alternatives Considered

## Repeat `cvref-auto` at Every Level

An alternative syntax is:

```cpp
auto [x, auto&& [y, z]] = expression;
```

This raises an immediate semantic question: does the inner `auto`, `auto&`, or
`auto&&` introduce another independently initialized object?

If it does, then:

```cpp
auto [x, auto [y, z]] = expression;
```

can copy or move the nested projection a second time. Users would need to
write `auto&&` at every level merely to request ordinary recursive
decomposition. It would also introduce mixed-ownership declarations such as:

```cpp
auto& [x, auto [y, z]] = expression;
auto& [x, const auto& [y, z]] = expression;
```

Those operations are possible with two explicit declarations and should
remain explicit unless compelling uses are demonstrated.

If the inner specifier does not independently affect initialization, it is
redundant and misleading.

The repeated form avoids the leading `[[` attribute ambiguity, but parser
convenience is not sufficient justification for a noisier and more complex
semantic model. The syntax remains available for a future proposal for
explicit inner materialization.

## Specify the Naive Two-Declaration Expansion

Another possibility is to specify:

```cpp
auto&& [[x, y]] = expression;
```

as though it were:

```cpp
auto&& [temporary] = expression;
auto&& [x, y] = temporary;
```

This loses the projection's value category because `temporary` is an lvalue.
It changes ref-qualified `get` selection and can make an otherwise viable
rvalue-only decomposition ill-formed. This paper instead preserves the
compiler-known binding category.

## Flatten Nested Products

The language could flatten nested tuple-like objects automatically:

```cpp
auto [x, y, z] = std::tuple{std::pair{1, 2}, 3};
```

This loses structural information, makes arity dependent on recursive library
customizations, and makes it impossible to distinguish intentionally grouped
products. Explicit bracket nesting is predictable and compositional.

## Use `std::apply`

`std::apply` can destructure one tuple-like layer into lambda parameters, but
nested products require nested lambdas and do not cover arrays or member
decomposition uniformly:

```cpp
std::apply([&](auto&& inner, auto&& z) {
  std::apply([&](auto&& x, auto&& y) {
    // ...
  }, std::forward<decltype(inner)>(inner));
}, expression);
```

This is not a practical declaration syntax.

## Require Named Classes

Named classes are preferable when a nested product represents a durable domain
concept. They do not address generic products created by standard containers,
range adaptors, coroutine combinators, or third-party interfaces. Nested
structured bindings improve consumption without requiring ownership of the
producing API.

# Compatibility

The proposed syntax is currently ill-formed. Existing valid attributed
structured bindings retain their meaning under the disambiguation rule above.
No object layout or calling-convention change is required. ABI specifications
that encode structured-binding names need to define how the recursively nested
source leaves participate in that encoding; the implementation experience
below describes the leaf-sequence model used by the prototype.

Because this changes the grammar and observable structured-binding behavior,
the value of the `__cpp_structured_bindings` feature-test macro should be
increased to a new value chosen for this feature.

# Implementation Considerations

An implementation should represent the binding structure recursively rather
than flattening it during parsing. Each nested list needs its own source range,
arity, and pack information, while all leaf declarations belong to the scope
of the enclosing structured-binding declaration.

Semantic analysis can reuse the existing three decomposition implementations:

1. Build the outer decomposition entity normally.
2. For each element, build or identify its projection exactly once.
3. If the element is an identifier, complete the existing binding behavior.
4. If the element is a nested list, retain the projection's compiler-known
   category and recursively apply decomposition through an implicit `auto&&`
   entity.

For tuple-like decomposition, implementations already retain the hidden
`U_i` entity. This is important because neither `decltype(binding)` nor
`decltype((binding))` recovers its type. For array and member decomposition,
the implementation should form the projection from the forwarded parent
entity rather than attempting to reconstruct the category from a visible
binding name.

AST printing, constant evaluation, code generation, debug information,
template instantiation, and structured-binding packs must traverse the same
recursive binding tree. Implementations should test ref-qualified and
side-effecting `get` overloads to ensure that projections are neither
converted into lvalues nor evaluated more than once.

The Clang pattern-matching prototype associated with [@P2688R6] implements
recursively nested structural decompositions. The prototype has now also been
extended to ordinary structured-binding declarations, conditions, range-for
declarations, templates, binding packs, constant evaluation, code generation,
PCH serialization, AST printing, and pattern declaration bindings.

## Implementation Experience

The prototype exposed several distinctions that should be reflected in the
wording and in implementation APIs.

### Source Bindings and Semantic Bindings

A compiler needs both the recursively written binding tree and the expanded
semantic binding sequence. They are not interchangeable when packs are
present:

```cpp
auto [[first, ...middle, last], tail] = expression;
```

The source tree contains one declaration for `middle`; after instantiation,
the semantic projection sequence contains one binding for every element of
that pack. Diagnostics, indexing, printing, and mangling generally need the
source leaves. Code generation, constant evaluation, lifetime analysis, and
exception analysis generally need the expanded semantic bindings in
initialization order.

The prototype initially used one flattened traversal for both purposes. That
left the source pack declaration in its "being initialized" state and caused
valid uses of the pack after the declaration to be rejected. Keeping the two
views explicit fixed the problem and appears to be the appropriate AST model.
Name-oriented traversals must also omit an unnamed source pack rather than
attempting to mangle or index a null identifier.

### Representation of a Nested Group

A nested group occupies a projection position but introduces no source-level
name. The prototype represents that position with an unnamed implicit binding
that owns a nested decomposition declaration. This preserves the recursive
source structure and lets existing decomposition machinery be reused.

Tuple-like decomposition may nevertheless require a materialized hidden
`r_i` object for such a group. At namespace scope, that object must not acquire
a fixed externally visible name: two nested groups would otherwise collide.
The prototype gives such implementation-only holders internal linkage while
retaining the ordinary linkage of the visible leaf bindings.

Local static and thread-local declarations inside inline functions require a
stable cross-translation-unit identity for each hidden holder. The prototype
therefore uses a stable offset in the expansion file for those holders rather
than placing the translation-unit-specific raw `SourceLocation` encoding in
their names. Namespace-scope holders can remain internal because
structured-binding declarations themselves cannot be declared `inline`.
This is sufficient for ordinary header definitions in the prototype, but a
production ABI should prefer an identity derived from the enclosing
decomposition and the nested structural path, particularly for declarations
generated by macros at different expansion locations.

A production AST may prefer a first-class representation for an unnamed
decomposition position rather than an implicit `BindingDecl`. In particular,
AST dumps and tooling should not expose an invented identifier as though the
user had declared it.

### Initialization Order Is Observable

Side-effecting `get` overloads make the recursive order observable. For:

```cpp
auto&& [[a, b], c] = expression;
```

the prototype evaluates the projection for the first outer element, then the
two projections for `a` and `b`, and only then the projection for `c`. This is
the depth-first, left-to-right order proposed above. A breadth-first model
would instead evaluate both outer projections before decomposing the first.
The standard wording needs to choose explicitly.

### ABI and Mangling

The Itanium ABI already mangles a decomposition declaration from the sequence
of its binding identifiers. The prototype recursively collects the source
leaf identifiers, so:

```cpp
auto [[x, y], z] = expression;
```

uses the same decomposition-name form as a hypothetical flat declaration with
the leaf sequence `x`, `y`, `z`. No new externally visible mangling production
is needed for the outer decomposition declaration.

Whether nesting shape should itself be encoded is still an ABI design
question. The prototype does not encode it. Since the externally visible
entities are the leaf bindings and their order is unchanged, leaf-only
mangling is the simpler model, but ABI groups should confirm that conclusion.

### Attribute Disambiguation

The implementation parses one possible attribute specifier under a reverting
tentative parse and checks whether a permitted declarator follows. This is
enough to distinguish a first nested element from an attribute sequence while
preserving existing diagnostics for malformed attributed bindings. Moving the
structured-binding lookahead ahead of attribute recovery changed unrelated
diagnostics, so the order of those operations matters.

The lookahead must recognize both an ordinary structured-binding declarator
and a nested one after an attribute:

```cpp
auto [[vendor::type_attribute]] [x, y] = expression;
auto [[vendor::type_attribute]] [[x, y], z] = expression;
```

It must also be restricted to declaration contexts in which a structured
binding declarator can occur. Applying the same heuristic in a type-id, such as
a `new` type-id, changes the interpretation of otherwise valid type
attributes.

### Pattern-Matching Integration

When nested structured bindings are used as declaration patterns, a compiler
can reuse an already-computed outer projection across arms. The nested
tuple-like projections still need declarations associated with the selected
arm, particularly when guards are present. The prototype currently shares the
outer projection and constructs the nested holding variables for each arm.
More aggressive sharing is an optimization and does not affect the ordinary
structured-binding semantics proposed by this paper.

Detection of declaration packs in an implicit template region must traverse
the recursive source tree. Looking only at the outer binding list misses a pack
such as `auto&& [[first, ...middle, last], tail]`, leaving its result type
undeduced until code generation.

### Debug Information

Debug locations for nested leaves cannot in general be described by applying
one immediate member or array offset to the storage of the outer decomposition.
Member and array nesting requires the complete projection path, while a
tuple-like projection can change the relevant storage to its materialized
`r_i` holder. The prototype avoids emitting an incorrect outer-relative
location for such leaves, but does not yet provide complete source-level debug
information for them. A production implementation should carry the projection
path and the storage-owning entity into debug-info generation.

# Wording Direction

Modify the structured-binding grammar in [dcl.struct.bind] so that an element
of a *structured-binding-list* is either an existing structured-binding
identifier, including the existing pack form, or another bracketed
*structured-binding-list*.

For a nested *structured-binding-list* in position `i`, define a recursive
initializer as follows:

- For array decomposition, the recursive initializer is the `i`th element of
  the forwarding expression of the decomposition entity.
- For tuple-like decomposition, the recursive initializer is
  `static_cast<U_i&&>(r_i)`, where `T_i`, `U_i`, and `r_i` are the entities
  already defined by [dcl.struct.bind].
- For member decomposition, the recursive initializer is member `m_i` selected
  from the forwarding expression of the decomposition entity.

The nested list introduces a structured-binding declaration as if its
*decl-specifier-seq* were `auto`, its *ref-qualifier* were `&&`, and its
initializer were the recursive initializer, except that all leaf bindings are
members of the same declaration and scope as the enclosing structured binding.

Specify that recursive decompositions and their associated entities are
initialized in depth-first, left-to-right order, and that every projection is
evaluated exactly once.

Add a syntactic disambiguation rule for `[[` following the outer
*decl-specifier-seq* and optional *ref-qualifier*: it begins an
*attribute-specifier-seq* only when the complete attribute sequence is followed
by a structured-binding declarator; otherwise the first `[` begins the
structured-binding declarator.

# Proposed Polls

## Poll 1

Forward the syntax and semantics of nested structured bindings described in
this paper to CWG for C++29.

## Poll 2

Nested structured-binding-lists should use implicit forwarding decomposition
and should not repeat `cvref-auto` at each nesting level.

# Acknowledgements

Thanks to the participants in the pattern-matching design discussions that
identified the interaction between recursive decomposition, structured-binding
forwarding, reference elements, member access, and attribute parsing.
