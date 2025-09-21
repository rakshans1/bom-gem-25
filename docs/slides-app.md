# Slides App Documentation

The slides app is a Reveal.js-based presentation system built with Vite and integrated into the Phoenix application.

## Overview

The slides app allows you to create presentations using Markdown files and custom themes. It's built using:
- **Reveal.js**: Presentation framework
- **Vite**: Build tool and development server
- **Markdown**: For writing slide content
- **Custom themes**: Iceberg-based styling

## Directory Structure

```
apps/slides/
├── src/
│   ├── main.js             # Entry point, initializes Reveal.js
│   ├── themes/
│   │   └── custom.css      # Custom Iceberg theme
│   └── slides/
│       └── presentation.md # Markdown slide files
├── index.html              # HTML template
├── package.json            # Dependencies and scripts
├── vite.config.js          # Vite configuration
└── tsconfig.json           # TypeScript configuration
```

## Configuration

### Vite Configuration (`vite.config.js`)

```javascript
import { defineConfig } from "vite";
import { viteStaticCopy } from 'vite-plugin-static-copy';

export default defineConfig({
  plugins: [
    viteStaticCopy({
      targets: [
        {
          src: 'src/slides/*.md',
          dest: '.'
        }
      ]
    })
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
});
```

### Package Configuration

```json
{
  "name": "slides",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "clean": "rm -rf ../../priv/static/slides"
  },
  "dependencies": {
    "reveal.js": "^5.1.0"
  },
  "devDependencies": {
    "vite": "^6.0.1",
    "@types/reveal.js": "^4.3.2",
    "vite-plugin-static-copy": "^1.0.6"
  }
}
```

## Phoenix Integration

### Controller (`lib/gem_web/controllers/slides_controller.ex`)

```elixir
defmodule GemWeb.SlidesController do
  use GemWeb, :controller

  def app(conn, _params) do
    index_path = Application.app_dir(:gem, "priv/static/slides/index.html")

    if File.exists?(index_path) do
      html_content = File.read!(index_path)

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, html_content)
    else
      # Development fallback when build hasn't run yet
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(503, """
        <html>
          <head><title>Building...</title></head>
          <body style="font-family: system-ui; display: flex; align-items: center; justify-content: center; height: 100vh;">
            <div style="text-align: center;">
              <h1>Compiling...</h1>
              <p>This page will refresh automatically</p>
            </div>
          </body>
          <script>setTimeout(() => location.reload(), 2000)</script>
        </html>
      """)
    end
  end
end
```

### Routes (`lib/gem_web/router.ex`)

```elixir
get "/slides", SlidesController, :app
get "/slides/*path", SlidesController, :app
```

### Development Watcher (`config/dev.exs`)

```elixir
pnpm: ["run", "build:watch", cd: Path.expand("../apps/slides", __DIR__)]
```

## Creating Presentations

### Markdown Slides

Create markdown files in `src/slides/` directory:

```markdown
# Welcome to Reveal.js

A framework for easily creating beautiful presentations using HTML

---

## Slide 2

This is the second slide

Note: Speaker notes can go here

---

## Markdown Features

- Bullet points
- **Bold text**
- *Italic text*
- `Code snippets`

---

## Code Example

```javascript
function hello() {
    console.log("Hello World!");
}
```

---

## Vertical Slides

Use `---` for horizontal slides

--

Use `--` for vertical slides

--

Navigate with arrow keys:
- ← Previous
- → Next
- ↓ Down
- ↑ Up
```

### Slide Separators

- `---`: Horizontal slide break
- `--`: Vertical slide break
- `Note:`: Speaker notes (press 'S' to view)

## Custom Theme

The slides use a custom Iceberg-inspired theme with:

### Color Palette
- Background: `#161821` (dark blue-gray)
- Text: `#c6c8d1` (light gray)
- Headings: `#d2d4de` (bright gray)
- Links: `#84a0c6` (blue)
- Code blocks: `#2e3244` (dark gray background)

### Typography
- Main font: Inter
- Code font: Fira Code
- Gradient headings for visual hierarchy

### Custom Classes
- `.text-center`: Center align text
- `.text-right`: Right align text
- `.highlight`: Highlight text with background

## Development Workflow

### Local Development
```bash
# Start development server
cd apps/slides
pnpm dev

# Or from project root
pnpm --filter slides dev
```

### Building for Production
```bash
# Build slides app
cd apps/slides
pnpm build

# Or from project root
pnpm --filter slides build
```

### Accessing Slides
- Development: `http://localhost:4000/slides`
- Production: `https://yourapp.com/slides`

## Reveal.js Features

### Navigation
- Arrow keys: Navigate slides
- Space: Next slide
- ESC: Slide overview
- S: Speaker notes
- F: Fullscreen

### Plugins
- Markdown: Parse markdown content
- Notes: Speaker notes support
- Highlight: Code syntax highlighting (can be added)

### Configuration
Reveal.js is configured in `src/main.js`:

```javascript
const deck = new Reveal({
  hash: true,           // URL hash navigation
  controls: true,       // Show navigation controls
  progress: true,       // Show progress bar
  center: true,         // Center slides vertically
  transition: 'slide',  // Transition style
  plugins: [Markdown],  // Enabled plugins
});
```

## Adding New Presentations

1. Create new markdown file in `src/slides/`
2. Update `index.html` to reference the new file:
   ```html
   <section data-markdown="/slides/new-presentation.md"
            data-separator="^---"
            data-separator-vertical="^--"
            data-separator-notes="^Note:">
   </section>
   ```
3. Build and deploy

## Troubleshooting

### Common Issues

1. **404 on markdown files**: Ensure `vite-plugin-static-copy` is copying markdown files correctly
2. **Theme not loading**: Check that `custom.css` is imported in `main.js`
3. **Build fails**: Verify all dependencies are installed with `pnpm install`
4. **Phoenix not serving**: Ensure controller and routes are properly configured

### Development Tips

- Use browser dev tools to inspect generated HTML structure
- Check network tab for failed resource requests
- Use `pnpm build` to test production builds locally
- Verify markdown files are copied to build output