defmodule YarnParser do
  @moduledoc """
  A parser for Yarn lock files
  """

  @v1_regex ~r/^(#.*(\r?\n))*?#\s+yarn\s+lockfile\s+v1\r?\n/i

  @doc """
  Parses a lock file

  ## Examples
      iex> input =
      ...>   \"""
      ...>   # yarn lockfile v1
      ...>   prop1 val1
      ...>   block1:
      ...>     prop2 true
      ...>   prop3 123
      ...>   \"""
      iex> YarnParser.decode(input)
      {:ok, %YarnParser.YarnLock{
        dependencies: %{
          "prop1" => "val1",
          "block1" => %{
            "prop2" => true
          },
          "prop3" => 123
        },
        metadata: %{
          "version" => 1
        }
      }}
  """

  @spec decode(binary, keyword) :: {:ok, YarnParser.YarnLock.t()} | {:error, String.t()}
  def decode(input, opts \\ []) do
    decoder = Keyword.get(opts, :decoder, get_decoder(input))
    decoder.decode(input)
  end

  defp get_decoder(input) do
    if Regex.match?(@v1_regex, input) do
      YarnParser.V1.Decoder
    else
      YarnParser.V2.Decoder
    end
  end


  @doc """
  Encodes a map into a yarn lockfile format

  ## Options
  - `:version` The yarn lockfile version. Defaults to `1`.
  - `:no_header` If true, it skips header comments. Defaults to `false`.

  ## Examples
      iex> map = %{"prop1" => 1,"block1" => %{"prop2" => true}}
      iex> YarnParser.encode(map, no_header: true)
      "block1:\\n  prop2 true\\n\\nprop1 1"

  """
  @spec encode(map(), keyword()) :: String.t()
  def encode(map, opts \\ []), do: YarnParser.V1.Encoder.encode(map, opts)

  @doc """
  Extracts the version from the comments on a parsed lockfile
  """
  @spec get_version(YarnParser.YarnLock.t()) :: nil | integer()
  def get_version(yarn_lock) do
    Map.get(yarn_lock.metadata, "version")
  end
end
