defmodule YarnParser do
  import NimbleParsec

  newline =
    choice([
      concat(ascii_char([?\r]), ascii_char([?\n])),
      ascii_char([?\n, ?\r])
    ])
    |> tag(:newline)

  comment =
    ascii_char([?#])
    |> concat(
      repeat(
        lookahead_not(newline)
        |> utf8_char([])
      )
    )
    |> lookahead(newline)
    |> tag(:comment)

  indent =
    ascii_string([?\s], min: 1)
    |> post_traverse({:process_indent, []})
    |> tag(:indent)

  defp process_indent(_rest, [indent], context, _line, _offset) do
    len = String.length(indent)
    level = div(len, 2)
    block_level = Map.get(context, :block_level, 1)

    if rem(len, 2) > 0 || level > block_level do
      {:error, "Invalid indentation"}
    else
      context = if level < block_level do
        Map.put(context, :block_level, block_level - 1)
      end || context
      {[{:indent, level}], context}
    end
  end

  quoted_string =
    ignore(ascii_char([?"]))
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> utf8_char([])
    )
    |> ignore(ascii_char([?"]))

  unquoted_string =
    ascii_char([?a..?z, ?A..?Z, ?/, ?., ?-])
    |> optional(repeat(
      lookahead_not(ascii_char([?:, ?\s, ?\n, ?\r, ?,]))
      |> ascii_char([])
    ))

  string =
    choice([quoted_string, unquoted_string])
    |> tag(:string)

  number =
    integer(min: 1)
    |> unwrap_and_tag(:number)

  boolean =
    choice([
      string("true"),
      string("false")
    ])
    |> post_traverse({:parse_boolean, []})
    |> unwrap_and_tag(:boolean)

  value =
    choice([boolean, number, string])
    |> tag(:value)

  defp parse_boolean(_, [text], context, _, _) do
    bool = case text do
      "true" -> true
      "false" -> false
    end
    {[bool], context}
  end

  colon =
    ascii_char([?:])
    |> tag(:colon)

  comma =
    ascii_char([?,])
    |> tag(:comma)

  whitespace = ignore(ascii_char([?\s]))

  defcombinatorp :keysequence,
    choice([
      string
      |> concat(ignore(comma))
      |> optional(whitespace)
      |> concat(parsec(:keysequence)),
      string
    ])

  defcombinatorp :key,
    parsec(:keysequence)
    |> tag(:key)

  defcombinatorp :keyvalue,
    parsec(:key)
    |> optional(whitespace)
    |> concat(value)
    |> optional(ignore(newline))
    |> tag(:keyvalue)

  defcombinatorp :blockstart,
    parsec(:key)
    |> ignore(colon)
    |> ignore(newline)
    |> post_traverse({:parse_blockstart, []})
    |> tag(:block_key)

  defp parse_blockstart(_, args, context, _, _) do
    block_level = Map.get(context, :block_level, 1)
    context = Map.put(context, :block_level, block_level + 1)
    {args, context}
  end

  defcombinatorp :block,
    parsec(:blockstart)
    |> repeat(
      indent
      |> choice([
        parsec(:block),
        parsec(:keyvalue)
      ])
    )
    |> tag(:block)

  defparsec :parse_input,
    repeat(choice([
      parsec(:block),
      parsec(:keyvalue),
      comment,
      ignore(newline)
    ]))

  def parse(input) do
    with {:ok, parsed, "", _, _, _} <- parse_input(input) do
      {:ok, format(parsed)}
    else
      _ -> {:error, :invalid_format}
    end
  end

  defp format(elems) do
    Enum.reduce(elems, %{}, fn
      {:comment, value}, acc ->
        value = List.to_string(value)
        if Map.has_key?(acc, "comments") do
          %{acc | "comments" => acc["comments"] ++ [value]}
        else
          Map.put(acc, "comments", [value])
        end

      {:indent, _}, acc -> acc

      {:keyvalue, val}, acc ->
        keys = Keyword.get(val, :key)

        [value] = Keyword.get(val, :value)
        for {_type, key} <- keys, into: %{} do
          {"#{key}", format_value(value)}
        end
        |> Map.merge(acc)

      {:block, subelems}, acc ->
        [{:block_key, key: keys} | elems] = subelems
        for {_type, key} <- keys, into: %{} do
          {"#{key}", format(elems)}
        end
        |> Map.merge(acc)
    end)
  end

  defp format_value({:string, val}), do: List.to_string(val)
  defp format_value({_type, val}), do: val
end
