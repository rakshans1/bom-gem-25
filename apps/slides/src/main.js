import Reveal from "reveal.js";
import Markdown from "reveal.js/plugin/markdown/markdown.esm.js";
import Highlight from "reveal.js/plugin/highlight/highlight.esm.js";
import "reveal.js/dist/reveal.css";
import "reveal.js/plugin/highlight/monokai.css";
import "./themes/custom.css";

// Initialize Reveal.js
const deck = new Reveal({
	hash: true,
	controls: true,
	progress: true,
	center: true,
	transition: "slide",
	plugins: [Markdown, Highlight],
});

deck.initialize();
