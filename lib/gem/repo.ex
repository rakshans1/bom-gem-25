defmodule Gem.Repo do
  use Ecto.Repo,
    otp_app: :gem,
    adapter: Ecto.Adapters.SQLite3
end
