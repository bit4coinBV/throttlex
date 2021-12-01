defmodule Throttlex do
  @moduledoc """
  Throttlex implements leaky bucket algorithm for rate limiting, it uses erlang ETS for storage.
  """
  use GenServer

  @type key :: integer | binary | tuple | atom

  defstruct [:bucket_name, :rate_per_second, :max_accumulated]

  @doc """
  Check the rate.
  """
  def check_rate(bucket_name, id, cost),
    do: GenServer.call(server_name(bucket_name), {:check_rate, id, cost})

  @doc """
  Returns amount of available tokens.
  """
  def get_available_tokens(bucket_name, id) do
    GenServer.call(server_name(bucket_name), {:get_available_tokens, id})
  end

  @doc """
  Increments (or decrements by passing negative amount) current rate bypassing the check.
  """
  def increment_available_tokens(bucket_name, id, amount) do
    GenServer.cast(server_name(bucket_name), {:increment_tokens_left, id, amount})
  end

  def start_link(opts) do
    bucket_name = Keyword.fetch!(opts, :bucket_name)
    max_accumulated = Keyword.fetch!(opts, :max_accumulated)
    rate_per_second = Keyword.fetch!(opts, :rate_per_second)

    GenServer.start_link(
      __MODULE__,
      %__MODULE__{
        bucket_name: bucket_name,
        max_accumulated: max_accumulated,
        rate_per_second: rate_per_second
      },
      name: server_name(bucket_name)
    )
  end

  @impl GenServer
  def init(%__MODULE__{} = state) do
    create_ets_table(state)

    {:ok, state}
  end

  defp create_ets_table(%__MODULE__{} = state) do
    :ets.new(state.bucket_name, [
      :named_table,
      :set
    ])
  end

  defp server_name(bucket_name), do: :"throttlex_#{bucket_name}"

  @impl GenServer
  def handle_cast({:increment_tokens_left, id, amount}, state) do
    now = :erlang.system_time(:milli_seconds)
    table = state.bucket_name

    case :ets.lookup(table, id) do
      [] ->
        :ets.insert(table, {id, state.max_accumulated + amount, now})

        :ok

      [{id, tokens, last_time}] ->
        accumulated_tokens = calculate_accumulated_tokens(tokens, now, last_time, state)
        tokens_left = (accumulated_tokens + amount) |> IO.inspect()

        :ets.update_element(table, id, [{2, tokens_left}, {3, now}])
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_available_tokens, id}, _from, %__MODULE__{} = state) do
    available_tokens =
      case :ets.lookup(state.bucket_name, id) do
        [] -> nil
        [{_id, tokens_left, _last_inserted_at}] -> tokens_left
      end

    {:reply, available_tokens, state}
  end

  def handle_call({:check_rate, id, cost}, _from, %__MODULE__{} = state) do
    now = :erlang.system_time(:milli_seconds)
    table = state.bucket_name

    response =
      case :ets.lookup(table, id) do
        [] ->
          tokens_left = state.max_accumulated - cost

          :ets.insert(table, {id, tokens_left, now})

          {:allow, tokens_left}

        [{id, tokens, last_time}] ->
          accumulated_tokens = calculate_accumulated_tokens(tokens, now, last_time, state)
          tokens_left = accumulated_tokens - cost

          if tokens_left < 0 do
            :deny
          else
            :ets.update_element(table, id, [{2, tokens_left}, {3, now}])

            {:allow, tokens_left}
          end
      end

    {:reply, response, state}
  end

  defp calculate_accumulated_tokens(tokens, now, last_inserted_at, %__MODULE__{} = state) do
    accumulated_tokens = tokens + (now - last_inserted_at) / 1000 * state.rate_per_second

    if accumulated_tokens > state.max_accumulated do
      state.max_accumulated
    else
      accumulated_tokens
    end
  end
end
