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
	width: 1920,
	height: 1080,
	hash: true,
	controls: false,
	controlsLayout: "edges",
	progress: true,
	navigationMode: "linear",
	// center: true,
	transition: "slide",
	plugins: [Markdown, Highlight, Notes],
	markdown: {
		smartypants: true,
	},
};

const deck = new Reveal(config);

deck.initialize();
