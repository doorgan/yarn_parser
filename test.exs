input =
  """
  block:
    good true
      bad true
  """

IO.inspect(YarnParser.parse(input))
