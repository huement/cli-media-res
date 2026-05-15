import { SvJs } from "svjs";

/**
 * Gets a random number between a minimum and maximum value.
 */
function random(min, max, integer = true) {
  let random = Math.random() * (max - min) + min;
  let number = integer ? Math.floor(random) : random;
  return number;
}

// Create some global variables.
const svgSize =
  window.innerWidth > window.innerHeight
    ? window.innerHeight
    : window.innerWidth;
const bgColor = "#181818";
// Create an object to store some of our randomised parameters.
const randomised = {
  hue: random(0, 360),
  rotation: random(-180, 180),
  iterations: random(10, 100),
};

// Parent SVG.
const svg = new SvJs().addTo(document.getElementById("container"));
// Parent SVG.

svg.set({ width: svgSize, height: svgSize, viewBox: "0 0 1000 1000" });
// Background.
svg.create("rect").set({
  x: 0,
  y: 0,
  width: 1000,
  height: 1000,
  fill: "#181818",
});

// Arrays to contain our shapes and their colours.
let palette = ["#34d399", "#6ee7b7", "#a7f3d0", "#d1fae5"];
let shapes = [];
// Initialise our four shapes.
for (let i = 0; i < 4; i += 1) {
  let size = 500 - i * 125;
  let position = 250 + i * 62.5;
  let shape = svg.create("rect").set({
    x: position,
    y: position,
    width: size,
    height: size,
    fill: palette[i],
    transform_origin: "50% 50%",
    transform: "rotate(45)",
  });
  shapes.push(shape);
}

// Set an id for our first shape.
shapes[0].set({ id: "cssShape" });
// Animate this shape with CSS.
svg.create("style").content(`
  @keyframes scaleRotate {
    0% { transform: rotate(0) scale(1, 1) }
    50% { transform: rotate(180deg) scale(0.5, 1.5) }
    100% { transform: rotate(360deg) scale(1, 1) }
}
  #cssShape {
    animation-name: scaleRotate;
    animation-duration: 5s;
    animation-iteration-count: infinite;
        animation-timing-function: linear;
  }
`);

svg.create("style").content(`
  ...
  #cssShape {
    animation: scaleRotate 5s infinite linear;
} `);
