defmodule Hata do
  defmodule Server do
    # server is responsible for storing, loading, serving feature configs

    def start(name) do
      GenServer.start(__MODULE__, %{}, name: name)
    end

    def get_all_features(name) do
      GenServer.call(name, :get_all_features)
    end

    def put_feature(name, feature_name, feature) do
      GenServer.cast(name, {:put_feature, feature_name, feature})
    end

    ### Callbacks
    def init(feature_map) do
      {:ok, feature_map}
    end

    def handle_call(:get_all_features, _from, features) do
      {:reply, features, features}
    end
    def handle_cast({:put_feature, feature_name, feature}, features) do
      {:noreply, Map.put(features, feature_name, feature)}
    end
  end

  defmodule Client do
    use GenServer

    def start(opts) do
      GenServer.start(__MODULE__, opts, name: __MODULE__)
    end

    def test(name, context) do
      GenServer.call(__MODULE__, {:test, name, context})
    end

    # client is responsible for fetching and updating from server
    def init(opts) do
      server = Keyword.fetch!(opts, :server)
      case connect(server) do
        {:ok, connection} ->
          case :timer.send_interval(:timer.seconds(5), :update) do
            {:ok, timer} ->
              {:ok, %{features: Server.get_all_features(connection),
                connection: connection,
                update_timer: timer}}
            {:error, reason} ->
              {:error, {:bad_timer, reason}}
          end
        bad_thing ->
          {:error, bad_thing}
      end
    end

    def handle_call({:test, name, context}, _from, state) do
      case get_chain(state, name) do
        {:ok, chain} -> {:reply, Hata.Chain.execute(chain, context), state}
        :error -> {:reply, {:error, :bad_name}, state}
      end
    end

    def handle_info(:update, state) do
      state = %{state | features: Server.get_all_features(state.connection)}
      {:noreply, state}
    end

    defp get_chain(state, name) do
      Map.fetch(state.features, name)
    end

    defp connect(server) do
      {:ok, server}
    end
  end

  def test do
    {:ok, _server_pid} = Server.start(ShantiFeatures)

    chain = Hata.Chain.new() |> Hata.Chain.add_link!(Hata.Link.Default, "off")

    Server.put_feature(ShantiFeatures, "hello", chain)
    {:ok, _client_pid} = Client.start(server: ShantiFeatures)
    Client.test("hello", %{})
  end
end
