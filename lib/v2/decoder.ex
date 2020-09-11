defmodule YarnParser.V2.Decoder do
  @behaviour YarnParser.Decoder

  @impl true
  def decode(string) do
    case YamlElixir.read_from_string(string) do
      {:ok, result} -> {:ok, post_process(result)}
      {:error, err} -> {:error, err.message}
    end
  end

  defp post_process(result) do
    {metadata, dependencies} = Map.pop(result, "__metadata", %{"version" => 2})

    dependencies = Enum.reduce(dependencies, %{}, fn {key, value}, acc ->
      keys = String.split(key, ~r/,(\s*)?/, trim: true)
      Map.new(keys, fn k -> {k, value} end)
      |> Map.merge(acc)
    end)

    %YarnParser.YarnLock{
      metadata: metadata,
      dependencies: dependencies
    }
  end
end
