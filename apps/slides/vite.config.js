import { defineConfig } from "vite";
import { viteStaticCopy } from "vite-plugin-static-copy";

export default defineConfig({
	plugins: [
		viteStaticCopy({
			targets: [
				{
					src: "src/slides/*.md",
					dest: ".",
				},
			],
			watch: {
				reloadPageOnChange: true,
			},
		}),
	],
	build: {
		outDir: "../../priv/static/slides",
		emptyOutDir: true,
		rollupOptions: {
			output: {
				entryFileNames: "assets/[name]-[hash].js",
				chunkFileNames: "assets/[name]-[hash].js",
				assetFileNames: "assets/[name]-[hash].[ext]",
			},
		},
	},
	base: "/slides/",
	server: {
		watch: {
			include: ["src/**/*"],
		},
	},
});
