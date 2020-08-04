# YarnParser

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `yarn_parser` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:yarn_parser, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
input =
"""
# Some comment
key1, key2:
  val1: true
  subkey1:
    val2: 123
"""

YarnParser.parse(input)
%{
  "comments" => ["# Some comment"],
  "key1" => %{
    "val1" => true,
    "subkey1" => %{
      "val2" => 123
    }
  },
  "key2" => %{
    "val1" => true,
    "subkey1" => %{
      "val2" => 123
    }
  }
}
```

