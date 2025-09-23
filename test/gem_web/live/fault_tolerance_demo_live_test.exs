defmodule GemWeb.FaultToleranceDemoLiveTest do
  use GemWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "fault tolerance demo" do
    test "renders controls and default state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/demo/fault-tolerance")

      assert has_element?(view, "button#start-system", "Start")
      assert has_element?(view, "button#trigger-db[disabled]")
      assert has_element?(view, "div", "Supervisor tree ready")
    end

    test "starting the system transitions workers to running", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/demo/fault-tolerance")

      view |> element("button#start-system") |> render_click()

      eventually(fn ->
        assert has_element?(view, "button#trigger-db:not([disabled])")
        assert has_element?(view, "button#trigger-cache:not([disabled])")
        assert has_element?(view, "button#trigger-api:not([disabled])")
      end)

      assert has_element?(view, "#event-stream div", "System online")
    end

    test "crashing workers respects restart policies", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/demo/fault-tolerance")

      view |> element("button#start-system") |> render_click()
      eventually(fn -> assert has_element?(view, "button#trigger-db:not([disabled])") end)

      # Crash DB Worker (permanent) - restarts and re-enables button
      view |> element("button#trigger-db") |> render_click()
      eventually(fn -> assert has_element?(view, "#event-stream div", "DB Worker crashed") end)
      eventually(fn -> assert has_element?(view, "#event-stream div", "DB Worker restarted") end)
      eventually(fn -> assert has_element?(view, "button#trigger-db:not([disabled])") end)

      # Change crash type to normal for cache worker
      params = %{"controls" => %{"crash_type" => "normal", "strategy" => "one_for_one"}}

      view
      |> element(~s(select[name="controls[crash_type]"]))
      |> render_change(params)

      view |> element("button#trigger-cache") |> render_click()
      eventually(fn -> assert has_element?(view, "#event-stream div", "Cache Worker stopped") end)
      eventually(fn -> assert has_element?(view, "button#trigger-cache[disabled]") end)
    end
  end

  defp eventually(assert_fun, attempts \\ 10)

  defp eventually(assert_fun, attempts) when attempts > 0 do
    assert_fun.()
  rescue
    _error in [ExUnit.AssertionError] ->
      Process.sleep(100)
      eventually(assert_fun, attempts - 1)
  end

  defp eventually(assert_fun, 0), do: assert_fun.()
end
