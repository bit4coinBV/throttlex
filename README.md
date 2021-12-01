# Throttlex

Throttlex is an efficient Elixir rate limiter based on erlang ETS.

## Instalation
1. Add Throttlex to your `mix.exs` dependencies:

    ```elixir
    def deps do
      [{:throttlex, git: "git@github.com:bit4coinBV/throttlex.git"}]
    end
    ```

2.  Start Throttlex as a process inside your app:

    ```elixir
    def application do
      [applications: [:throttlex]]
    end
    ```

## Usage

**Check rate**:

The `Throttlex.check_rate` function will return `{:allow, available_tokens}` if the user's request could be allowed, otherwise will return `:deny`. For one bucket,
same `rate_per_second`, `max_accumulated` should be passed to `&check/5`.

 - `bucket`: an atom representing bucket name (also an ETS table).
 - `id`: id.
 - `cost`(optional): costs of each request.


```elixir
iex> Throttlex.check_rate(:user_rate_web, 1)
:ok
iex> Throttlex.check_rate(:user_rate_web, 1)
:ok
iex> Throttlex.check_rate(:user_rate_web, 1)
:error
```

For user id 1, one extra request will be added to bucket, maximum accumulated requests number
is 4, and every request will cost 1 token. First request will be permitted.
Second request is permitted also since we allowed 2 requests maximum.
If the third request is made within 1 second (the recovery time), it will return :error.
