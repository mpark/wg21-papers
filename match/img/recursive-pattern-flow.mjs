import {
  leaf,
  project,
  renderMatchAnimation,
  token,
} from "../tools/pattern-animation.mjs";

const projected = token("int", "42");

const animation = {
  title: "Patterns match a variant from the outside in",
  heading: "Patterns match values from the outside in",
  description:
    "A variant of int or string moves through two cases. The alternative " +
    "pattern keeps the variant visible and creates a nested subject containing " +
    "int 42. The string declaration fails. The int declaration binds x to 42 " +
    "and runs print(x).",
  subject: token("value", "variant<int, string>"),
  cases: [
    {
      pattern: project(
        projected,
        leaf("std::string text", {result: false}),
      ),
      handler: "print(text);",
    },
    {
      pattern: project(
        projected,
        leaf("int x", {result: true, binding: "x = 42"}),
      ),
      handler: "print(x);",
    },
  ],
};

process.stdout.write(renderMatchAnimation(animation));
