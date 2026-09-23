// Visual grammar:
//   * sibling cases form the only top-level sequence;
//   * every pattern is a frame containing the subject it receives;
//   * projection creates child subjects in child pattern frames;
//   * bindings and results stay in the frame that produced them.
// The renderer derives layout and timing from this recursive tree.
const TOKEN_WIDTH = 176;
const TOKEN_HEIGHT = 50;
const NODE_HEADER = 32;
const NODE_PADDING = 14;
const CHILD_GAP = 12;
const CASE_GAP = 18;

export function token(name, detail) {
  return {name, detail};
}

export function leaf(syntax, options = {}) {
  return {kind: "leaf", syntax, ...options};
}

export function project(projected, child, options = {}) {
  return {
    kind: "project",
    syntax: options.syntax ?? "{ P }",
    projected,
    children: [child],
    ...options,
  };
}

export function decompose(projected, children, options = {}) {
  if (projected.length !== children.length)
    throw new Error("decomposition needs one projected subject per child");
  return {
    kind: "decompose",
    syntax: options.syntax ?? "[ P... ]",
    projected,
    children,
    ...options,
  };
}

export function either(children, options = {}) {
  return {
    kind: "or",
    syntax: options.syntax ?? "P || Q",
    children,
    ...options,
  };
}

function escapeXml(value) {
  return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;");
}

function estimateTextWidth(value, fontSize = 15) {
  return String(value).length * fontSize * 0.61;
}

function prepareTree(root, subject) {
  let nextId = 0;

  function prepare(node, subject, depth = 0) {
    const prepared = {...node, id: nextId++, subject, depth};
    const children = node.children ?? [];

    if (node.kind === "leaf") {
      prepared.children = [];
      prepared.width = Math.max(310, estimateTextWidth(node.syntax) + 155);
      prepared.height = 116;
      return prepared;
    }

    let childSubjects;
    if (node.kind === "project") {
      childSubjects = [node.projected];
    } else if (node.kind === "decompose") {
      childSubjects = node.projected;
    } else {
      childSubjects = children.map(() => subject);
    }

    prepared.children = children.map((child, index) =>
      prepare(child, childSubjects[index], depth + 1));

    const childrenWidth = prepared.children.reduce(
      (sum, child) => sum + child.width, 0) +
      CHILD_GAP * Math.max(0, prepared.children.length - 1);
    const childrenHeight = Math.max(...prepared.children.map(child => child.height));

    prepared.width = Math.max(360, childrenWidth + 2 * NODE_PADDING);
    prepared.height = NODE_HEADER + TOKEN_HEIGHT + CHILD_GAP +
        childrenHeight + NODE_PADDING;
    return prepared;
  }

  return prepare(root, subject);
}

function placeTree(node, x, y) {
  node.x = x;
  node.y = y;
  node.subjectX = x + (node.width - TOKEN_WIDTH) / 2;
  node.subjectY = y + NODE_HEADER + 4;

  if (node.children.length === 0)
    return;

  const childrenWidth = node.children.reduce(
    (sum, child) => sum + child.width, 0) +
    CHILD_GAP * Math.max(0, node.children.length - 1);
  let childX = x + (node.width - childrenWidth) / 2;
  const childY = node.subjectY + TOKEN_HEIGHT + CHILD_GAP;

  for (const child of node.children) {
    placeTree(child, childX, childY);
    childX += child.width + CHILD_GAP;
  }
}

function inferResult(node) {
  if (node.result !== undefined)
    return node.result;
  if (node.kind === "or")
    return node.children.some(inferResult);
  return node.children.every(inferResult);
}

function markUnreached(node) {
  node.evaluated = false;
  for (const child of node.children)
    markUnreached(child);
}

function scheduleTree(node, start) {
  node.evaluated = true;
  node.enterAt = start;

  if (node.kind === "leaf") {
    node.resultAt = start + 6;
    return node.resultAt;
  }

  const childStart = start + 5;
  let childEnd = childStart;

  if (node.kind === "or") {
    // Or-patterns try their branches from left to right.
    let branchStart = childStart;
    let matched = false;
    for (const child of node.children) {
      if (matched) {
        markUnreached(child);
        continue;
      }
      child.revealAt = branchStart;
      childEnd = scheduleTree(child, branchStart);
      branchStart = childEnd + 3;
      matched = inferResult(child);
    }
  } else {
    // Decomposition children become visible together. This deliberately
    // avoids implying an evaluation order where the language specifies none.
    for (const child of node.children) {
      child.revealAt = childStart;
      childEnd = Math.max(childEnd, scheduleTree(child, childStart));
    }
  }

  node.resultAt = childEnd + 3;
  return node.resultAt;
}

function patternKind(node) {
  switch (node.kind) {
    case "project": return "ALTERNATIVE PATTERN";
    case "decompose": return "DECOMPOSITION PATTERN";
    case "or": return "OR-PATTERN";
    case "leaf": return "NESTED PATTERN";
    default: throw new Error(`unknown pattern kind: ${node.kind}`);
  }
}

function resultClass(result) {
  return result ? "success" : "failure";
}

function animationName(prefix, id) {
  return `${prefix}-${id}`;
}

function percent(value, total) {
  return Math.max(0, Math.min(100, value / total * 100)).toFixed(2);
}

function visibilityAnimation(name, at, total, opacity = 1) {
  const before = percent(Math.max(0, at - 1.5), total);
  const shown = percent(at, total);
  return `
    @keyframes ${name} {
      0%, ${before}% { opacity: 0; }
      ${shown}%, 100% { opacity: ${opacity}; }
    }`;
}

function resultAnimation(name, at, total, result) {
  const before = percent(Math.max(0, at - 1.5), total);
  const shown = percent(at, total);
  const fill = result ? "#ecf8f3" : "#fff4f2";
  const stroke = result ? "#19765c" : "#b5473c";
  return `
    @keyframes ${name} {
      0%, ${before}% { fill: #ffffff; stroke: #cbd2d9; }
      ${shown}%, 100% { fill: ${fill}; stroke: ${stroke}; }
    }`;
}

function highlightAnimation(name, at, total) {
  const before = percent(Math.max(0, at - 1.5), total);
  const shown = percent(at, total);
  return `
    @keyframes ${name} {
      0%, ${before}% { fill: #667085; }
      ${shown}%, 100% { fill: #19765c; }
    }`;
}

function renderToken(subject, x, y, classes = "", style = "") {
  return `
      <g class="subject-token ${classes}"${style ? ` style="${style}"` : ""}>
        <rect class="subject-box" x="${x}" y="${y}" width="${TOKEN_WIDTH}" height="${TOKEN_HEIGHT}" rx="7"/>
        <text class="subject-name code" x="${x + TOKEN_WIDTH / 2}" y="${y + 20}" text-anchor="middle">${escapeXml(subject.name)}</text>
        <text class="subject-detail code" x="${x + TOKEN_WIDTH / 2}" y="${y + 39}" text-anchor="middle">${escapeXml(subject.detail)}</text>
      </g>`;
}

function renderNode(node, total, animations, isRoot = false) {
  const result = inferResult(node);
  const evaluated = node.evaluated !== false;
  let frameStyle = "";
  if (evaluated) {
    const frameAnimation = animationName("node-result", node.id);
    animations.push(resultAnimation(frameAnimation, node.resultAt, total, result));
    frameStyle = ` style="animation: ${frameAnimation} 8s ease-in-out infinite"`;
  }

  let output = `
      <g class="pattern-node depth-${node.depth}">
        <rect class="pattern-frame ${evaluated ? resultClass(result) : ""}" x="${node.x}" y="${node.y}" width="${node.width}" height="${node.height}" rx="8"${frameStyle}/>
        <text class="node-kind" x="${node.x + 14}" y="${node.y + 20}">${patternKind(node)}</text>
        <text class="node-syntax code" x="${node.x + node.width - 14}" y="${node.y + 21}" text-anchor="end">${escapeXml(node.syntax)}</text>`;

  if (!isRoot && evaluated) {
    const revealAnimation = animationName("subject-reveal", node.id);
    animations.push(visibilityAnimation(revealAnimation, node.revealAt, total));
    output += renderToken(
      node.subject, node.subjectX, node.subjectY, "projected-subject",
      `animation: ${revealAnimation} 8s ease-in-out infinite`);
  }

  for (const child of node.children)
    output += renderNode(child, total, animations);

  if (node.kind === "leaf" && evaluated) {
    const statusAnimation = animationName("status-reveal", node.id);
    animations.push(visibilityAnimation(statusAnimation, node.resultAt, total));
    output += `
        <text class="node-status ${resultClass(result)}" x="${node.x + node.width - 12}" y="${node.y + node.height - 13}" text-anchor="end"
              style="animation: ${statusAnimation} 8s ease-in-out infinite">${result ? "MATCH" : "NO MATCH"}</text>`;

    if (node.binding) {
      const bindingAnimation = animationName("binding-reveal", node.id);
      animations.push(visibilityAnimation(bindingAnimation, node.resultAt + 2, total));
      output += `
        <text class="binding code" x="${node.x + 14}" y="${node.y + node.height - 13}"
              style="animation: ${bindingAnimation} 8s ease-in-out infinite">${escapeXml(node.binding)}</text>`;
    }
  }

  output += "\n      </g>";
  return output;
}

function rootTravelAnimation(cases, startY, total) {
  const points = [{at: 0, y: startY}];
  let previousY = startY;

  for (const matchCase of cases) {
    const targetY = matchCase.pattern.subjectY;
    points.push({at: Math.max(0, matchCase.enterAt - 3), y: previousY});
    points.push({at: matchCase.enterAt, y: targetY});
    points.push({at: matchCase.resultAt + 3, y: targetY});
    previousY = targetY;
  }
  points.push({at: total, y: previousY});

  return `
    @keyframes root-subject-travel {
${points.map(point => `      ${percent(point.at, total)}% { transform: translateY(${point.y - cases.at(-1).pattern.subjectY}px); }`).join("\n")}
    }`;
}

export function renderMatchAnimation(scene) {
  const heading = scene.heading ?? scene.title ?? "Pattern matching";
  const title = scene.title ?? heading;
  const description = scene.description ?? heading;
  const preparedCases = scene.cases.map(matchCase => ({
    ...matchCase,
    pattern: prepareTree(matchCase.pattern, scene.subject),
  }));

  const caseX = 55;
  const patternLeft = caseX + 35;
  const widestPattern = Math.max(
    ...preparedCases.map(matchCase => matchCase.pattern.width));
  const laneX = Math.max(400, patternLeft + widestPattern / 2);
  const patternRight = laneX + widestPattern / 2;
  const handlerX = patternRight + 70;
  const caseWidth = Math.max(990, handlerX + 330 - caseX);
  const canvasWidth = caseX + caseWidth + 55;
  const caseTop = 95;
  let y = caseTop;

  for (const matchCase of preparedCases) {
    const patternX = laneX - matchCase.pattern.width / 2;
    matchCase.y = y;
    matchCase.height = matchCase.pattern.height + 66;
    placeTree(matchCase.pattern, patternX, y + 42);
    y += matchCase.height + CASE_GAP;
  }

  let cursor = 8;
  for (const matchCase of preparedCases) {
    matchCase.enterAt = cursor;
    const patternEnd = scheduleTree(matchCase.pattern, cursor);
    matchCase.resultAt = patternEnd + 2;
    cursor = matchCase.resultAt + (inferResult(matchCase.pattern) ? 14 : 10);
  }
  const total = cursor + 10;
  const height = y - CASE_GAP + 25;
  const animations = [];

  const startY = 62;
  animations.push(rootTravelAnimation(preparedCases, startY, total));

  let body = "";
  for (let index = 0; index < preparedCases.length; ++index) {
    const matchCase = preparedCases[index];
    const result = inferResult(matchCase.pattern);
    const caseAnimation = animationName("case-result", index);
    animations.push(resultAnimation(
      caseAnimation, matchCase.resultAt, total, result));

    const statusAnimation = animationName("case-status", index);
    animations.push(visibilityAnimation(
      statusAnimation, matchCase.resultAt, total));

    let handlerStyle = "";
    if (result) {
      const handlerAnimation = animationName("handler-highlight", index);
      animations.push(highlightAnimation(
        handlerAnimation, matchCase.resultAt + 3, total));
      handlerStyle = ` style="animation: ${handlerAnimation} 8s ease-in-out infinite"`;
    }

    body += `
    <g class="match-case">
      <rect class="case-frame ${resultClass(result)}" x="${caseX}" y="${matchCase.y}" width="${caseWidth}" height="${matchCase.height}" rx="8"
            style="animation: ${caseAnimation} 8s ease-in-out infinite"/>
      <text class="case-label code" x="${caseX + 18}" y="${matchCase.y + 27}">case</text>
      <text class="handler code" x="${handlerX}" y="${matchCase.y + 28}"${handlerStyle}>=&gt; ${escapeXml(matchCase.handler)}</text>
      <text class="case-status ${resultClass(result)}" x="${caseX + caseWidth - 18}" y="${matchCase.y + 27}" text-anchor="end"
            style="animation: ${statusAnimation} 8s ease-in-out infinite">${result ? "SELECTED" : "CONTINUE"}</text>
${renderNode(matchCase.pattern, total, animations, true)}
    </g>`;

    if (!result) {
      const historyAnimation = animationName("root-history", index);
      animations.push(visibilityAnimation(
        historyAnimation, matchCase.resultAt + 3, total, 0.42));
      body += renderToken(
        scene.subject, matchCase.pattern.subjectX,
        matchCase.pattern.subjectY, "root-history",
        `animation: ${historyAnimation} 8s ease-in-out infinite`);
    }
  }

  const finalRoot = preparedCases.at(-1).pattern;
  const rootToken = renderToken(
    scene.subject, finalRoot.subjectX, finalRoot.subjectY, "root-subject",
    "animation: root-subject-travel 8s ease-in-out infinite");

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${canvasWidth} ${height}"
     role="img" aria-labelledby="title description">
  <title id="title">${escapeXml(title)}</title>
  <desc id="description">${escapeXml(description)}</desc>

  <style>
    text {
      fill: #1d2939;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      letter-spacing: 0;
    }
    .code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
    .canvas { fill: #fbfcfa; stroke: #d0d5dd; }
    .title { font-size: 22px; font-weight: 650; }
    .rail { stroke: #98a2b3; stroke-dasharray: 4 6; }
    .case-frame, .pattern-frame { fill: #fff; stroke: #cbd2d9; stroke-width: 2; }
    .pattern-frame { fill: #f8fafc; stroke-width: 1.5; }
    .case-frame.success, .pattern-frame.success { fill: #ecf8f3; stroke: #19765c; }
    .case-frame.failure, .pattern-frame.failure { fill: #fff4f2; stroke: #b5473c; }
    .case-label { font-size: 17px; font-weight: 650; }
    .handler { fill: #667085; font-size: 16px; font-weight: 600; }
    .case-status, .node-status { font-size: 11px; font-weight: 750; }
    .success { fill: #19765c; }
    .failure { fill: #b5473c; }
    .node-kind { fill: #667085; font-size: 10px; font-weight: 750; }
    .node-syntax { font-size: 14px; font-weight: 650; }
    .subject-box { fill: #293241; stroke: #18212f; stroke-width: 2; }
    .subject-name { fill: #fff; font-size: 14px; font-weight: 700; }
    .subject-detail { fill: #ffd98a; font-size: 12px; font-weight: 650; }
    .binding { fill: #19765c; font-size: 13px; font-weight: 700; }
    .root-subject { transform-box: fill-box; }
${animations.join("\n")}

    @media print, (prefers-reduced-motion: reduce) {
      .case-frame,
      .pattern-frame,
      .subject-token,
      .case-status,
      .node-status,
      .binding,
      .handler {
        animation: none !important;
      }
    }
  </style>

  <rect class="canvas" x="1" y="1" width="${canvasWidth - 2}" height="${height - 2}" rx="8"/>
  <text class="title" x="42" y="42">${escapeXml(heading)}</text>
  <line class="rail" x1="${laneX}" y1="58" x2="${laneX}" y2="${height - 18}"/>
${body}
${rootToken}
</svg>
`;
}
