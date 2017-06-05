# Throttlex

Throttlex is an efficient Elixir rate limiter based on erlang ETS.

## Instalation
1. Add Throttlex to your `mix.exs` dependencies:

    ```elixir
    def deps do
      [{:throttlex, "~> 0.0.1"}]
    end
    ```

2. List `:throttlex` in your application dependencies:

    ```elixir
    def application do
      [applications: [:throttlex]]
    end
    ```

## Usage

**Create tables**:

Sometimes different endpoints or different routes would want their own rate-limiter with specified rates and cost, in 
order to check rate, tables must be created first, you can create multiple tables by passing an array of atoms.

  ```elixir
  iex> Throttlex.create_tables([:user_rate_web, :user_rate_ios])
  nil
  ```

**Check rate**:

The `Throttlex.check` function will return `:ok` if the user's request could be allowed, otherwise will return `:error`. For one bucket,
same `rate_per_second`, `max_accumulated` should be passed to `&check/5`.

 - `bucket`: an atom representing bucket name (also an ETS table).
 - `id`: id.
 - `rate_per_second`: how many rates should be added to bucket per second.
 - `max_accumulated`: maximum rates allowed in the bucket.
 - `cost`: costs of each request.


```elixir
iex> Throttlex.check(:user_rate_web, 1, 1, 2, 1)
:ok
iex> Throttlex.check(:user_rate_web, 1, 1, 2, 1)
:ok
iex> Throttlex.check(:user_rate_web, 1, 1, 2, 1)
:error
```

For user id 1, one extra request will be added to bucket, maximum accumulated requests number
is 4, and every request will cost 1 token. First request will be permitted.
Second request is permitted also since we allowed 2 requests maximum.
If the third request is made within 1 second (the recovery time), it will return :error.

```elixir
iex> Throttlex.clear(:user_rate_web)
:ok

iex> Throttlex.clear([:user_rate_web, user_rate_ios])
:ok
```

Clear given table/tables, will always return :ok.


## Concurrency

Ideally it would be nice to store configs(`rate_per_second`, `max_accumulated`) as we create tables, there are 2 ways to achieve this

1. use GenServer to store configs for each table.

2. store configs in ETS table, and do an extra lookup for config each time we call `check`.

As we may have concurrent request go through `check`, GenServer will limit the performance to one process' ability, so `check` now requires all config
variable on each call.

## Testing

```elixir
mix test
```
