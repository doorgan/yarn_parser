defmodule YarnParser.YarnLock do

  @type t :: %YarnParser.YarnLock{
    metadata: map(),
    dependencies: map()
  }

  defstruct metadata: %{}, dependencies: %{}

end
