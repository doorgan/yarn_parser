defmodule YarnParser.V1.Decoder do
  @moduledoc false

  @behaviour YarnParser.Decoder

  import NimbleParsec

  @impl true
  def decode(input) do
    case do_parse(input, context: [indent: 0]) do
      {:ok, tree, "", _, _, _} ->
        {:ok, emit_map(tree) |> post_process()}

      {:ok, _, rest, context, {line, _}, byte_offset} ->
        # Something went wrong then , however, because of repeat, the error is
        # discarded, so we call do_parse again to get an error message.
        {:error, message, _rest, _context, _, _byte_offset} =
          do_parse(rest, context: context, line: line, byte_offset: byte_offset)

        {:error, message}

      {:error, message, _rest, _context, _, _byte_offset} ->
        {:error, message}
    end
  end

  defp post_process(result) do
    version = get_version(result)

    %YarnParser.YarnLock{
      metadata: %{"version" => version},
      dependencies: Map.drop(result, ["comments"])
    }
  end

  defp get_version(%{"comments" => comments}) do
    result =
      Enum.find_value(comments, fn comment ->
        Regex.run(~r/yarn lockfile v(\d+)/, comment)
      end)

    case result do
      nil -> nil
      [_, version] -> String.to_integer(version)
    end
  end
  defp get_version(%{}), do: nil

  defp emit_map(tree, map \\ %{})
  defp emit_map([], map), do: map
  defp emit_map([{:comment, comment} | rest], map) do
    comment = List.to_string(comment)
    map = Map.update(map, "comments", [comment], fn comments ->
      comments ++ [comment]
    end)
    emit_map(rest, map)
  end
  defp emit_map([{:key_value, keyvalue} | rest], map) do
    keys = Keyword.get(keyvalue, :keys)
    [{_type, value}] = Keyword.get(keyvalue , :value)

    map =
      for {_type, key} <- keys, into: %{} do
        {"#{key}", value}
      end
      |> Map.merge(map)

    emit_map(rest, map)
  end
  defp emit_map([{:simple_block, block} | rest], map) do
    keys = Keyword.get(block, :keys)
    value =
      case Keyword.get(block , :value) do
        [{_type, value}] -> value
        nil -> %{}
      end

    map =
      for {_type, key} <- keys, into: %{} do
        {"#{key}", value}
      end
      |> Map.merge(map)

    emit_map(rest, map)
  end
  defp emit_map([{:block, block} | rest], map) do
    keys = Keyword.get(block, :keys)
    content = Keyword.get(block, :content) |> emit_map()

    map =
      for {_type, key} <- keys, into: %{} do
        {"#{key}", content}
      end
      |> Map.merge(map)

    emit_map(rest, map)
  end

  number =
    integer(min: 1)
    |> unwrap_and_tag(:number)
    |> label("number")

  boolean =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])
    |> unwrap_and_tag(:boolean)
    |> label("boolean")

  quoted_string =
    ignore(utf8_char([?"]))
    |> repeat(
      lookahead_not(utf8_char([?"]))
      |> utf8_char([])
    )
    |> ignore(utf8_char([?"]))

  unquoted_string =
    utf8_char([?a..?z, ?A..?Z, ?/, ?., ?-, ?_])
    |> repeat(
      lookahead_not(utf8_char([?:, ?\s, ?\n, ?\r, ?,]))
      |> utf8_char([])
    )

  string =
    choice([quoted_string, unquoted_string])
    |> post_traverse(:emit_string)
    |> unwrap_and_tag(:string)
    |> label("string")

  defp emit_string(_, string, context, _, _) do
    string = Enum.reverse(string)
    {[List.to_string(string)], context}
  end

  value =
    choice([boolean, number, string])
    |> tag(:value)

  colon =
    ascii_char([?:])
    |> tag(:colon)
    |> label("colon")

  comma =
    ascii_char([?,])
    |> tag(:comma)
    |> label("comma")

  newline =
    choice([
      concat(ascii_char([?\r]), ascii_char([?\n])),
      ascii_char([?\n, ?\r])
    ])
    |> label("newline")

  whitespace =
    ascii_string([?\s], min: 0)
    |> label("whitespace")

  indent =
    ascii_string([?\s], min: 0)
    |> post_traverse(:process_indent)

  defp process_indent(_, [spaces], context, _, _) do
    len = String.length(spaces)
    level = div(len, 2)
    if rem(len, 2) > 0 do
      {:error, "Invalid indentation, expected a multiple of 2, got #{len}"}
    else
      {[indent: level], context}
    end
  end

  defcombinatorp :comment,
    ascii_char([?#])
    |> concat(
      repeat(
        lookahead_not(newline)
        |> utf8_char([])
      )
    )
    |> lookahead(newline)
    |> tag(:comment)

  defcombinatorp :keysequence,
    choice([
      string
      |> ignore(comma)
      |> ignore(whitespace)
      |> concat(parsec(:keysequence)),
      string
    ])

  defcombinatorp :key,
    parsec(:keysequence)
    |> tag(:keys)


  defcombinatorp :key_value,
    parsec(:key)
    |> ignore(whitespace)
    |> concat(value)
    |> tag(:key_value)

  defcombinatorp :block_start,
    parsec(:key)
    |> ignore(colon)
    |> tag(:block_start)

  defcombinatorp :block,
    parsec(:block_start)
    |> ignore(newline)
    |> post_traverse(:start_block)
    |> repeat_while(
      indent
      |> post_traverse(:remove_indent)
      |> choice([
        parsec(:block),
        parsec(:key_value)
      ])
      |> optional(ignore(newline)),
      :not_dedent
    )
    |> post_traverse(:end_block)
    |> tag(:block)

  defcombinatorp :simple_block,
    parsec(:block_start)
    |> ignore(newline)
    |> concat(indent)
    |> post_traverse(:remove_indent)
    |> optional(value)
    |> ignore(newline)
    |> post_traverse(:emit_simple_block)
    |> tag(:simple_block)

  defp not_dedent(rest, context, _, _) do
    indents = count_spaces(rest)
    if indents < context.indent do
      {:halt, context}
    else
      {:cont, context}
    end
  end

  defp start_block(_, args, context, _, _) do
    context = update_in(context.indent, &(&1 + 1))
    {args, context}
  end
  defp end_block(_, args, context, _, _) do
    {start, elements} = List.pop_at(args, -1)
    {:block_start, [{:keys, keys}]} = start
    context = update_in(context.indent, &(&1 - 1))
    {[{:keys, keys}, content: elements], context}
  end

  defp emit_simple_block(_, block, context, _, _) do
    value = Keyword.get(block, :value)
    [{:keys, keys}] = Keyword.get(block, :block_start)
    {[{:keys, keys}, value: value], context}
  end

  defp count_spaces(string, count \\ 0)
  defp count_spaces(<<?\s, ?\s, rest::binary>>, count) do
    count_spaces(rest, count + 1)
  end
  defp count_spaces(_, count) do
    count
  end

  defparsecp :do_parse,
    indent
    |> post_traverse(:remove_indent)
    |> choice([
      parsec(:simple_block),
      parsec(:block),
      parsec(:comment),
      parsec(:key_value),
      ignore(newline)
    ])
    |> optional(ignore(newline))
    |> times(min: 1)

  defp remove_indent(_, args, context, _, _) do
    args = args
    |> Enum.reject(fn
      {:indent, _} -> true
      _ -> false
    end)
    {args, context}
  end
end
