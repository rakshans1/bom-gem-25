defmodule Gem.Demo.PingPongMailbox.ProcessWorkerTest do
  use ExUnit.Case, async: true

  alias Gem.Demo.PingPongMailbox.Message
  alias Gem.Demo.PingPongMailbox.ProcessWorker

  describe "enqueue" do
    test "processes messages sequentially" do
      session_ref = "test-session"

      {:ok, pid} =
        ProcessWorker.start_link(parent: self(), session_ref: session_ref, key: :a, interval: 10)

      message = Message.new(:ping, from: :process_b, to: :process_a)
      ProcessWorker.enqueue(pid, message)

      assert_receive {:ppm_processing_started, ^session_ref, :a, ^message}, 100
      assert_receive {:ppm_processing_complete, ^session_ref, :a, ^message}, 100
    end

    test "pausing defers future messages" do
      session_ref = "test-session"

      {:ok, pid} =
        ProcessWorker.start_link(parent: self(), session_ref: session_ref, key: :a, interval: 10)

      ProcessWorker.pause(pid)
      message = Message.new(:ping, from: :process_b, to: :process_a)
      ProcessWorker.enqueue(pid, message)

      refute_receive {:ppm_processing_started, ^session_ref, :a, ^message}, 30

      ProcessWorker.resume(pid)

      assert_receive {:ppm_processing_started, ^session_ref, :a, ^message}, 100
      assert_receive {:ppm_processing_complete, ^session_ref, :a, ^message}, 100
    end
  end
end
