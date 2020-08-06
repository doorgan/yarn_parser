defmodule YarnParser do
  @moduledoc """
  A parser for Yarn lock files
  """

  alias YarnParser.{Encoder, Decoder}

  @doc """
  Parses a lock file

  ## Examples
      iex> input =
      ...>   \"""
      ...>   prop1 val1
      ...>   block1:
      ...>     prop2 true
      ...>   prop3 123
      ...>   \"""
      iex> YarnParser.decode(input)
      {:ok, %{
        "prop1" => "val1",
        "block1" => %{
          "prop2" => true
        },
        "prop3" => 123
      }}
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, String.t()}
  def decode(input), do: Decoder.parse(input)


  @doc """
  Encodes a map into a yarn lockfile format

  ## Options
  - `:version` The yarn lockfile version. Defaults to `1`.
  - `:no_header` If true, it skips header comments. Defaults to `false`.

  ## Examples
      iex> map = %{"prop1" => 1,"block1" => %{"prop2" => true}}
      iex> YarnParser.Encoder.encode(map, no_header: true)
      "block1:\\n  prop2 true\\n\\nprop1 1"

  """
  @spec encode(map(), keyword()) :: String.t()
  def encode(map, opts \\ []), do: Encoder.encode(map, opts)
  %{"prop1" => 1,"block1" => %{"prop2" => true, "prop3" => %{"a" => "b"}, "prop4" => false}}

  @doc """
  Extracts the version from the comments on a parsed lockfile
  """
  @spec get_version(map()) :: nil | integer()
  def get_version(%{"comments" => comments}) do
    result =
      Enum.find_value(comments, fn comment ->
        Regex.run(~r/yarn lockfile v(\d+)/, comment)
      end)

    case result do
      nil -> nil
      [_, version] -> String.to_integer(version)
    end
  end
  def get_version(%{}), do: nil
end
