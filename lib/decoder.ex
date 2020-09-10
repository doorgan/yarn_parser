defmodule YarnParser.Decoder do
  @callback decode(Sring.t()) :: {:ok, map()} | {:error, String.t()}
end
