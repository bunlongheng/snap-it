// Drives the grid demo and the shortcut table. The layouts mirror the app's
// shipped defaults so the page cannot drift from the real thing.
(function () {
  "use strict";

  var LAYOUTS = [
    { name: "Left Half", key: "⌥⌘←", x: 0, y: 0, w: 0.5, h: 1 },
    { name: "Right Half", key: "⌥⌘→", x: 0.5, y: 0, w: 0.5, h: 1 },
    { name: "Top Half", key: "⌥⌘↑", x: 0, y: 0, w: 1, h: 0.5 },
    { name: "Bottom Half", key: "⌥⌘↓", x: 0, y: 0.5, w: 1, h: 0.5 },
    { name: "Maximize", key: "⌥⌘↩", x: 0, y: 0, w: 1, h: 1 },
    { name: "Center", key: "⌥⌘C", x: 0.125, y: 0.1, w: 0.75, h: 0.8 },
    { name: "Left Third", key: "⌥⌘1", x: 0, y: 0, w: 1 / 3, h: 1 },
    { name: "Center Third", key: "⌥⌘2", x: 1 / 3, y: 0, w: 1 / 3, h: 1 },
    { name: "Right Third", key: "⌥⌘3", x: 2 / 3, y: 0, w: 1 / 3, h: 1 },
    { name: "Left Two Thirds", key: "⌥⌘4", x: 0, y: 0, w: 2 / 3, h: 1 },
    { name: "Right Two Thirds", key: "⌥⌘5", x: 1 / 3, y: 0, w: 2 / 3, h: 1 },
    { name: "Top Left Quarter", key: "⌥⌘U", x: 0, y: 0, w: 0.5, h: 0.5 },
    { name: "Top Right Quarter", key: "⌥⌘I", x: 0.5, y: 0, w: 0.5, h: 0.5 },
    { name: "Bottom Left Quarter", key: "⌥⌘J", x: 0, y: 0.5, w: 0.5, h: 0.5 },
    { name: "Bottom Right Quarter", key: "⌥⌘K", x: 0.5, y: 0.5, w: 0.5, h: 0.5 }
  ];

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
    name.textContent = layout.name;
    keyLabel.textContent = layout.key;

    var active = rows.querySelectorAll("tr");
    for (var i = 0; i < active.length; i++) {
      active[i].setAttribute("aria-current", i === n ? "true" : "false");
    }
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
