---
title: "Nested Structured Bindings"
document: D0000R0
date: 2024-06-12
audience: Evolution
author:
  - name: Michael Park
    email: <mcypark@gmail.com>
toc: true
toc-depth: 4
---

# Introduction

Structured bindings as proposed in [@P0144R2] was accepted into C++17, and has
been a very useful and convenient feature. There have been several additions
made to it since then, including lambda captures, constexpr support, and even
introducing a pack. The discussion of nested structured bindings has been on
hold in part due to its connection to pattern matching as a language feature.

It's been many years now, with more experience with structured bindings, and
significant amount of thought and discussions for pattern matching. It's quite
clear that pattern matching is going to remain parallel and inherit the features
of structured bindings. Previous pattern matching proposals upto [@P1371R3]
included nested structured bindings. [@P2688R1] takes a minimal approach to
pattern matching. It has a trimmed down feature set, and a focus on the larger,
structural parts of pattern matching.

Given the usefulness, orthogonality, and a clear path to integration with
pattern matching, I believe that we should consider nested structured bindings
as a small, separate feature for inclusion in C++26.

[@P0144R2] discussed this feature as a future extension:

> 3.9 Should there be support for recursive destructuring?
> 
> For example:
> 
> ```cpp
> std::tuple<T1, std::pair<T2, T3>, T4> f();
> 
> auto [ w, [x, y], z ] = f(); // NOT proposed: types are T1, T2, T3, T4
> ```
> 
> We think the answer should be “not yet.” This could be a future extension,
> following experience with the basic feature and in languages like Python.

# Motivation and Scope



# Comparison Table

::: cmptable

### C++23

```cpp
for (const auto& [key, point], keyed_points) {
  const auto& [x, y] = point;
}

```

### This Proposal

```cpp
```

:::

# Real Examples

::: cmptable

### C++23

```cpp
for (const auto& [codes, value]: *get_multicode_table()) {
  String key = encode_as_utf8(codes.first);
  key += encode_as_utf8(codes.second);

  char buffer[32];
  snprintf(buffer, sizeof(buffer), "&%s", value.c_str());
  ret.set(key, String(buffer, CopyString));
}
```

---

### This Proposal

```cpp
for (const auto& [[code1, code2], value] : *get_multicode_table()) {
  String key = encode_as_utf8(code1);
  key += encode_as_utf8(code2);

  char buffer[32];
  snprintf(buffer, sizeof(buffer), "&%s", value.c_str());
  ret.set(key, String(buffer, CopyString));
}
``` 

From: https://github.com/facebook/hhvm/blob/e8e9028007807a87993c3a852d001f2876ccad01/hphp/runtime/ext/string/ext_string.cpp#L2499-L2507

:::