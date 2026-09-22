// Drives the grid demo and the shortcut table. The layouts mirror the app's
// shipped defaults so the page cannot drift from the real thing.
(function () {
  "use strict";

/* defaults:start */
  var LAYOUTS = [
    { name: "Left Half", key: "⌥⌘←", x: 0, y: 0, w: 0.5, h: 1 },
    { name: "Right Half", key: "⌥⌘→", x: 0.5, y: 0, w: 0.5, h: 1 },
    { name: "Maximize", key: "⌥⌘↑", x: 0, y: 0, w: 1, h: 1 },
    { name: "Top Half", key: "⌃⌥⌘↑", x: 0, y: 0, w: 1, h: 0.5 },
    { name: "Bottom Half", key: "⌃⌥⌘↓", x: 0, y: 0.5, w: 1, h: 0.5 },
    { name: "Left Third", key: "⌥⌘1", x: 0, y: 0, w: 0.333333, h: 1 },
    { name: "Center Third", key: "⌥⌘3", x: 0.333333, y: 0, w: 0.333333, h: 1 },
    { name: "Right Third", key: "⌥⌘5", x: 0.666667, y: 0, w: 0.333333, h: 1 },
    { name: "Right Two Thirds", key: "⌥⌘2", x: 0.333333, y: 0, w: 0.666667, h: 1 },
    { name: "Center Two Thirds", key: "⌃⌥⌘C", x: 0.166667, y: 0, w: 0.666667, h: 1 }
  ];
/* defaults:end */

  // Same ten steps as the row colours in styles.css, in the same order.
  var HUES = ["#ef4444", "#f97316", "#eab308", "#84cc16", "#22c55e",
              "#14b8a6", "#06b6d4", "#3b82f6", "#8b5cf6", "#ec4899"];

  var tile = document.getElementById("tile");
  var rows = document.getElementById("rows");
  var cells = document.getElementById("cells");
  var name = document.getElementById("demo-name");
  var keyLabel = document.getElementById("demo-key");
  if (!tile || !rows || !cells) return;

  for (var i = 0; i < 36; i++) cells.appendChild(document.createElement("i"));

  var index = 0;
  var timer = null;
  var still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function show(n) {
    var layout = LAYOUTS[n];
    index = n;
    tile.style.left = "calc(8px + " + layout.x * 100 + "% - " + layout.x * 16 + "px)";
    tile.style.top = "calc(8px + " + layout.y * 100 + "% - " + layout.y * 16 + "px)";
    tile.style.width = "calc(" + layout.w * 100 + "% - " + layout.w * 16 + "px)";
    tile.style.height = "calc(" + layout.h * 100 + "% - " + layout.h * 16 + "px)";
    tile.style.setProperty("--tile", HUES[n % HUES.length]);
    name.textContent = layout.name;
    keyLabel.textContent = layout.key;
    keyLabel.style.color = HUES[n % HUES.length];

    var active = rows.querySelectorAll("tr");
    for (var i = 0; i < active.length; i++) {
      active[i].setAttribute("aria-current", i === n ? "true" : "false");
    }
  }

  function mini(layout) {
    return '<span class="mini" aria-hidden="true" style="' +
      "--mx:" + layout.x + ";--my:" + layout.y +
      ";--mw:" + layout.w + ";--mh:" + layout.h + '"><i></i></span>';
  }

  function percent(value) {
    return Math.round(value * 100) + "%";
  }

  LAYOUTS.forEach(function (layout, n) {
    var row = document.createElement("tr");
    row.tabIndex = 0;
    row.innerHTML =
      "<td>" + layout.name + "</td>" +
      "<td><kbd>" + layout.key + "</kbd></td>" +
      "<td>" + mini(layout) + "</td>" +
      "<td>" + percent(layout.w) + " × " + percent(layout.h) + "</td>";
    row.addEventListener("mouseenter", function () { stop(); show(n); });
    row.addEventListener("focus", function () { stop(); show(n); });
    rows.appendChild(row);
  });

  function stop() {
    if (timer) { clearInterval(timer); timer = null; }
  }

  show(0);
  if (!still) {
    timer = setInterval(function () { show((index + 1) % LAYOUTS.length); }, 1900);
  }

  var copy = document.getElementById("copy");
  copy.addEventListener("click", function () {
    var text = document.getElementById("cmd").textContent;
    navigator.clipboard.writeText(text).then(function () {
      copy.classList.add("done");
      setTimeout(function () { copy.classList.remove("done"); }, 1600);
    }, function () {
      copy.classList.remove("done");
    });
  });
})();
