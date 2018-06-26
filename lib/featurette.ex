defmodule Featurette do
  # register
  # unregister
end

defmodule Hata.Chain do
  defmodule Link do
    @type treatment :: String.t
    @callback init(opts :: any) :: {:ok, state :: any} | {:error, reason :: any}
    @callback run(context :: map, state ::any) ::
                    {:ok, result :: treatment} | {:error, reason :: any}
  end

  def new() do
    []
  end

  def add_link(chain, module, opts) do
    case module.init(opts) do
        {:ok, state} ->
          {:ok, chain ++ [{module, state}]}
        :error ->
          :error
    end
  end

  def add_link!(chain, module, opts) do
    case module.init(opts) do
        {:ok, state} ->
          chain ++ [{module, state}]
        :error ->
          raise "it bad"
    end
  end

  def execute([], context) do
    {:error, {:empty, context}}
  end
  def execute([link | rest], context) do
    case link do
      {module, state} when is_atom(module) ->
        case module.run(context, state) do
        {:decision, result} ->
          {:ok, result}
        :undecided ->
          execute(rest, context)
        end
      bad_link ->
        {:error, {:bad_link, bad_link, context}}
    end
  end
end

defmodule Hata.Link.Default do
  @behaviour Hata.Chain.Link
  def init(treatment) do
    {:ok, treatment}
  end

  def run(_context, state) do
    {:decision, state}
  end
end

defmodule Hata.Link.Member do
  @behaviour Hata.Chain.Link
  def init(opts) do
    key = Keyword.fetch!(opts, :key)
    collection = Keyword.fetch!(opts, :in)
    treatment = Keyword.fetch!(opts, :treatment)
    {:ok, %{key: key, collection: collection, treatment: treatment}}
  end

  def run(context, state) do
    case Map.fetch(context, state.key) do
      {:ok, value} ->
        if Enum.member?(state.collection, value) do
          {:decision, state.treatment}
        else
          :undecided
        end
      :error ->
        :undecided
    end
  end
end

defmodule Hata.Link.HashBucket do
  @behaviour Hata.Chain.Link
  def init(opts) do
    key = Keyword.fetch!(opts, :key)
    salt = Keyword.fetch!(opts, :salt)
    buckets = Keyword.fetch!(opts, :buckets)
    total = Enum.reduce(buckets, 0, fn({_treatment, weight}, total) -> total + weight end)

    %{key: key,
      salt: salt,
      buckets: buckets,
      total_weight: total}
  end

  def run(context, state) do
    case Map.fetch(context, state.key) do
      {:ok, value} ->
        normalized_value = hash({state.salt, value}, state.total_weight)
        case iterate(state.treatments, normalized_value) do
          {:ok, treatment} -> {:decision, treatment}
          :error -> :undecided
        end
      :error ->
        :undecided
    end
  end

  defp hash(value, total) do
    :erlang.phash2(value, total)
  end

  defp iterate([], _number) do
    :error
  end
  defp iterate([{treatment, weight} | _rest], number) when number < weight do
    {:ok, treatment}
  end
  defp iterate([{_treatment, weight} | rest], number) do
    iterate(rest, number - weight)
  end
end
