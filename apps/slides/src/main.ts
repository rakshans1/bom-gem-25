import type { Options } from "reveal.js";
import Reveal from "reveal.js";
import Highlight from "reveal.js/plugin/highlight/highlight.esm.js";
import Markdown from "reveal.js/plugin/markdown/markdown.esm.js";
import Notes from "reveal.js/plugin/notes/notes.esm.js";
import "reveal.js/dist/reveal.css";
import "reveal.js/plugin/highlight/monokai.css";
import "./themes/custom.css";

// Initialize Reveal.js
const config: Options = {
	hash: true,
	controls: true,
	progress: true,
	center: true,
	transition: "slide",
	plugins: [Markdown, Highlight, Notes],
};

const deck = new Reveal(config);

deck.initialize();
