defmodule ThrottlexTest do
  use ExUnit.Case, async: true

  @bucket bucket_name: :bucket_name, max_accumulated: 4, rate_per_second: 10
  @id :id
  @cost 1

  setup do
    start_supervised!({Throttlex, @bucket})

    :ok
  end

  describe "check_rate/3" do
    test "check rate" do
      assert {:allow, 3} == Throttlex.check_rate(:bucket_name, @id, @cost)
      assert {:allow, 2} == Throttlex.check_rate(:bucket_name, @id, @cost)
      assert {:allow, 1} == Throttlex.check_rate(:bucket_name, @id, @cost)
      assert {:allow, 0} == Throttlex.check_rate(:bucket_name, @id, @cost)

      assert :deny = Throttlex.check_rate(:bucket_name, @id, @cost)

      # by this time, has recovered 1 token
      :timer.sleep(100)
      assert {:allow, _} = Throttlex.check_rate(:bucket_name, @id, @cost)
      assert :deny = Throttlex.check_rate(:bucket_name, @id, @cost)
    end
  end

  describe "get_available_tokens/2" do
    test "returns amount of available tokens" do
      assert {:allow, 3} == Throttlex.check_rate(:bucket_name, @id, @cost)

      assert 3 == Throttlex.get_available_tokens(:bucket_name, @id)
    end
  end

  describe "increment_available_tokens/2" do
    test "increments available tokens bypassing the rate check" do
      assert {:allow, 2} == Throttlex.check_rate(:bucket_name, @id, 2)
      assert :ok = Throttlex.increment_available_tokens(:bucket_name, @id, 2)

      :timer.sleep(2)

      assert 4 == Throttlex.get_available_tokens(:bucket_name, @id)
    end

    test "decrements available tokens bypassing the rate check" do
      assert :ok = Throttlex.increment_available_tokens(:bucket_name, @id, -2)

      :timer.sleep(2)

      assert 2 == Throttlex.get_available_tokens(:bucket_name, @id)
    end
  end
end
