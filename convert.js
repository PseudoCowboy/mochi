import Color from "https://esm.sh/colorjs.io";

const calm = new Color("oklch(78% 0.13 165)").to("srgb");
const okay = new Color("oklch(82% 0.14 95)").to("srgb");
const stressed = new Color("oklch(75% 0.16 50)").to("srgb");
const over = new Color("oklch(68% 0.18 25)").to("srgb");

console.log(`calm: R: ${calm.coords[0].toFixed(3)}, G: ${calm.coords[1].toFixed(3)}, B: ${calm.coords[2].toFixed(3)}`);
console.log(`okay: R: ${okay.coords[0].toFixed(3)}, G: ${okay.coords[1].toFixed(3)}, B: ${okay.coords[2].toFixed(3)}`);
console.log(`stressed: R: ${stressed.coords[0].toFixed(3)}, G: ${stressed.coords[1].toFixed(3)}, B: ${stressed.coords[2].toFixed(3)}`);
console.log(`over: R: ${over.coords[0].toFixed(3)}, G: ${over.coords[1].toFixed(3)}, B: ${over.coords[2].toFixed(3)}`);
