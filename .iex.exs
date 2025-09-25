import_file_if_available("~/.iex.exs")

IEx.configure(
  default_prompt: "%prefix(\e[0;32mbom-gem\e[0m):%counter>",
  alive_prompt: "%prefix(\e[0;32mbom-gem\e[0m):%counter>"
)

IEx.configure(auto_reload: true)
