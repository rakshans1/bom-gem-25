ExUnit.start()

try do
  Ecto.Adapters.SQL.Sandbox.mode(Gem.Repo, :manual)
rescue
  RuntimeError -> :ok
end

Code.require_file("support/data_case.ex", __DIR__)
Code.require_file("support/conn_case.ex", __DIR__)

Application.ensure_all_started(:lazy_html)
