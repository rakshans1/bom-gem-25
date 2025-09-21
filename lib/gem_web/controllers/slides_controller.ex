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
