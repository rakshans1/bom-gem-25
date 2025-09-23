// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/gem";
import topbar from "../vendor/topbar";

const SVG_NS = "http://www.w3.org/2000/svg";

const SimpleConnector = {
	mounted() {
		this.svg = this.el.querySelector("[data-role='connector-layer']");
		this.draw = this.draw.bind(this);
		this.handleResize = () => {
			if (this.timeout) clearTimeout(this.timeout);
			this.timeout = setTimeout(this.draw, 16);
		};
		window.addEventListener("resize", this.handleResize);
		this.draw();
	},

	updated() {
		this.draw();
	},

	destroyed() {
		window.removeEventListener("resize", this.handleResize);
		if (this.timeout) clearTimeout(this.timeout);
	},

	draw() {
		if (!this.svg) return;
		if (this.timeout) {
			clearTimeout(this.timeout);
			this.timeout = null;
		}

		const supervisor = this.el.querySelector("[data-node-key='supervisor']");
		if (!supervisor) return;

		const container = this.el.getBoundingClientRect();
		this.svg.setAttribute("width", container.width);
		this.svg.setAttribute("height", container.height);
		this.svg.setAttribute(
			"viewBox",
			`0 0 ${container.width} ${container.height}`,
		);
		this.svg.innerHTML = "";

		const defs = document.createElementNS(SVG_NS, "defs");
		const gradient = document.createElementNS(SVG_NS, "linearGradient");
		gradient.setAttribute("id", "worker-connector-gradient");
		gradient.setAttribute("x1", "0%");
		gradient.setAttribute("y1", "0%");
		gradient.setAttribute("x2", "100%");
		gradient.setAttribute("y2", "100%");

		const stopStart = document.createElementNS(SVG_NS, "stop");
		stopStart.setAttribute("offset", "0%");
		stopStart.setAttribute("stop-color", "#84a0c6");
		stopStart.setAttribute("stop-opacity", "0.45");
		gradient.appendChild(stopStart);

		const stopEnd = document.createElementNS(SVG_NS, "stop");
		stopEnd.setAttribute("offset", "100%");
		stopEnd.setAttribute("stop-color", "#b4be82");
		stopEnd.setAttribute("stop-opacity", "0.4");
		gradient.appendChild(stopEnd);

		defs.appendChild(gradient);
		this.svg.appendChild(defs);

		const supervisorRect = supervisor.getBoundingClientRect();
		const supervisorX =
			supervisorRect.left + supervisorRect.width / 2 - container.left;
		const supervisorY = supervisorRect.bottom - container.top;

		const workers = this.el.querySelectorAll(
			"[data-node-key]:not([data-node-key='supervisor'])",
		);

		workers.forEach((worker) => {
			const workerRect = worker.getBoundingClientRect();
			const workerX = workerRect.left + workerRect.width / 2 - container.left;
			const workerY = workerRect.top - container.top;

			const midY = (supervisorY + workerY) / 2;
			const curveStrength = Math.max(
				40,
				Math.abs(workerX - supervisorX) * 0.25,
			);
			const direction = workerX >= supervisorX ? 1 : -1;
			const controlX =
				supervisorX + curveStrength * (direction === 0 ? 1 : direction);

			const path = document.createElementNS(SVG_NS, "path");
			path.setAttribute(
				"d",
				`M ${supervisorX} ${supervisorY} Q ${controlX} ${midY} ${workerX} ${workerY}`,
			);
			path.setAttribute("fill", "none");
			path.setAttribute("stroke", "url(#worker-connector-gradient)");
			path.setAttribute("stroke-width", "3");
			path.setAttribute("stroke-linecap", "round");

			const connectorClass = worker.dataset.connectorClass;
			if (connectorClass) {
				path.setAttribute("class", connectorClass);
			}

			this.svg.appendChild(path);
		});
	},
};

const csrfToken = document
	.querySelector("meta[name='csrf-token']")
	.getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
	longPollFallbackMs: 2500,
	params: { _csrf_token: csrfToken },
	hooks: { ...colocatedHooks, ConnectorCanvas: SimpleConnector },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
	window.addEventListener(
		"phx:live_reload:attached",
		({ detail: reloader }) => {
			// Enable server log streaming to client.
			// Disable with reloader.disableServerLogs()
			reloader.enableServerLogs();

			// Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
			//
			//   * click with "c" key pressed to open at caller location
			//   * click with "d" key pressed to open at function component definition location
			let keyDown;
			window.addEventListener("keydown", (e) => (keyDown = e.key));
			window.addEventListener("keyup", (_e) => (keyDown = null));
			window.addEventListener(
				"click",
				(e) => {
					if (keyDown === "c") {
						e.preventDefault();
						e.stopImmediatePropagation();
						reloader.openEditorAtCaller(e.target);
					} else if (keyDown === "d") {
						e.preventDefault();
						e.stopImmediatePropagation();
						reloader.openEditorAtDef(e.target);
					}
				},
				true,
			);

			window.liveReloader = reloader;
		},
	);
}
