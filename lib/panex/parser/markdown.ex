defmodule Panex.Parser.Markdown do
  @moduledoc """
  The parser is in charge to transform the Markdown syntax in a token format.
  This help us to detect the format in use for the document and the translation
  to Docbook (XML) later.
  """

  def parse(""), do: []
  def parse(text) do
    {_, meta, parsed} = parse(text, %{level: :body, line: 1, meta: []}, [])
    change_references(parsed, meta.meta)
  end

  defp change_references(parsed, meta) do
    change_references(parsed, meta, [])
  end

  defp change_references([], _meta, parsed), do: parsed
  defp change_references([binary|rest], meta, parsed) when is_binary(binary) do
    change_references(rest, meta, parsed ++ [binary])
  end
  defp change_references([{:ref_link, text, [num]}|rest], meta, parsed) do
    {^num, url} = List.keyfind(meta, num, 0)
    change_references(rest, meta, parsed ++ [{:link, text, [url]}])
  end
  defp change_references([{:section1, title, attrs, contents}|rest], meta, parsed) do
    title = change_references(title, meta)
    contents = change_references(contents, meta)
    section1 = [{:section1, title, attrs, contents}]
    change_references(rest, meta, parsed ++ section1)
  end
  defp change_references([{:link, _} = link|rest], meta, parsed) do
    change_references(rest, meta, parsed ++ [link])
  end
  defp change_references([{id, contents}|rest], meta, parsed) do
    tag = [{id, change_references(contents, meta)}]
    change_references(rest, meta, parsed ++ tag)
  end
  defp change_references([{id, attrs, contents}|rest], meta, parsed) do
    tag = [{id, attrs, change_references(contents, meta)}]
    change_references(rest, meta, parsed ++ tag)
  end

  defguardp is_numeric?(a) when (a in ?0..?9)
  defguardp is_alphanum?(a) when ((a in ?A..?Z) or (a in ?a..?z) or (a in ?0..?9))
  defguardp is_space?(a) when (a in ' \t')

  defp inc_line(%{line: line} = meta, inc \\ 1), do: %{meta | line: line + inc}

  ## Parsing final
  defp parse("", meta, parsed), do: {"", meta, parsed}
  defp parse("\n", meta, parsed), do: {"", inc_line(meta), parsed}

  ## Parsing end of line
  defp parse("  \n" <> rest, %{level: :para} = meta, parsed) do
    {"\n" <> rest, meta, parsed ++ [:br]}
  end
  defp parse("\n\n" <> rest, %{level: :para} = meta, parsed) do
    {rest, inc_line(meta, 2), parsed}
  end
  defp parse("\n" <> rest, meta, parsed) do
    parse(rest, inc_line(meta), parsed)
  end

  ## Parsing section 1
  defp parse("# " <> rest, %{level: :body} = meta, parsed) do
    {title, rest} = rest_of_line(rest)
    {rest, meta, content} = parse(rest, inc_line(meta), [])
    parse(rest, meta, parsed ++ [{:section1, title, [], content}])
  end
  defp parse("#(" <> rest, %{level: :body} = meta, parsed) do
    {attrs, rest} = rest_of_line(rest, ")")
    attrs = parse_attrs(attrs)
    {title, rest} = rest_of_line(rest)
    title = depth_parse(title)
    {rest, meta, content} =
      parse(rest, inc_line(%{meta | level: :section1}), [])
    parsed = parsed ++ [{:section1, title, attrs, content}]
    parse(rest, %{meta | level: :body}, parsed)
  end
  defp parse("# " <> rest, meta, parsed) do
    {"# " <> rest, meta, parsed}
  end
  defp parse("#(" <> rest, meta, parsed) do
    {"#(" <> rest, meta, parsed}
  end

  defp parse("! " <> rest, meta, parsed) do
    {rest, meta, content} = parse(rest, inc_line(meta), [])
    parse(rest, meta, parsed ++ [{:note, [], content}])
  end
  defp parse("!(" <> rest, meta, parsed) do
    {attrs, rest} = rest_of_line(rest, ")")
    attrs = parse_attrs(attrs)
    {rest, meta, content} = parse(rest, inc_line(meta), [])
    parse(rest, meta, parsed ++ [{:note, attrs, content}])
  end

  ## Parsing link
  defp parse(<<"[", a :: integer-size(8), "]: ", rest :: binary()>>,
             meta, parsed) when is_numeric?(a) do
    {url, rest} = rest_of_line(rest)
    num = <<a :: integer-size(8)>>
    parse(rest, %{meta | meta: [{num, url}|meta.meta]}, parsed)
  end
  defp parse(<<"[", a :: integer-size(8), b :: integer-size(8), "]: ",
               rest :: binary()>>,
             meta, parsed) when is_numeric?(a) and is_numeric?(b) do
    {url, rest} = rest_of_line(rest)
    num = <<a :: integer-size(8), b :: integer-size(8)>>
    parse(rest, %{meta | meta: [{num, url}|meta.meta]}, parsed)
  end

  ## Parsing block-code
  defp parse("```" <> rest, meta, parsed) do
    {attrs, rest} = rest_of_line(rest)
    attrs = parse_attrs(attrs)
    ## FIXME parse code to get real lines
    {code, rest} = rest_of_line(rest, "\n```")
    parse(rest, inc_line(meta), parsed ++ [{:code, attrs, [code]}])
  end

  ## Parsing text
  defp parse(<<a :: integer-size(8), _ :: binary()>> = text, meta, parsed)
       when is_alphanum?(a) do
    {rest, meta, parsed_para} = parse_para(text, meta, "")
    {rest, meta, parsed ++ parsed_para}
  end

  defp parse_para("# " <> rest, meta, para) do
    {"# " <> rest, meta, [{:para, depth_parse(para)}]}
  end
  defp parse_para("#(" <> rest, meta, para) do
    {"#(" <> rest, meta, [{:para, depth_parse(para)}]}
  end
  defp parse_para("```" <> rest, meta, para) do
    parse("```" <> rest, meta, [{:para, depth_parse(para)}])
  end
  defp parse_para(<<"[", a :: integer-size(8), "]: ", _ :: binary()>> = rest,
                  meta, para) when is_numeric?(a) do
    parse(rest, meta, [{:para, depth_parse(para)}])
  end
  defp parse_para(<<"[", a :: integer-size(8), b :: integer-size(8), "]: ", _ :: binary()>> = rest,
                  meta, para) when is_numeric?(a) and is_numeric?(b) do
    parse(rest, meta, [{:para, depth_parse(para)}])
  end
  defp parse_para(text, meta, para) do
    case rest_of_line(text) do
      {another_para, "\n" <> rest} ->
        para = para <> " " <> another_para
        parse(rest, inc_line(meta, 2), [{:para, depth_parse(para)}])
      {another_para, nil} ->
        para = para <> " " <> another_para
        parse("", meta, [{:para, depth_parse(para)}])
      {another_para, rest} -> 
        para = para <> " " <> another_para
        parse_para(rest, inc_line(meta), para)
    end
  end

  defp depth_parse(para) do
    [
      {~r/_([^_]+)_/, :emphasis, 1},
      {~r/\*([^*]+)\*/, :strong, 1},
      {~r/`([^`]+)`/, :truetype, 1},
      {~r/\[([^\]]+)\]\[([^\]])+\]/, :ref_link, 2},
      {~r/\[([^\]]+)\]\(([^)]+)\)/, :link, 2},
    ]
    |> List.foldl([para], fn data, acc ->
                            acc
                            |> Enum.map(&(depth_parse(data, &1)))
                            |> List.flatten()
                          end)
  end

  defp depth_parse(_, acc) when is_tuple(acc), do: acc
  defp depth_parse({reg, id, num}, acc) do
    depth_parse(reg, Regex.split(reg, acc, [:global, include_captures: true]), id, num, [])
  end

  defp depth_parse(_, [], _, _, acc), do: List.flatten(acc)
  defp depth_parse(_, [last], _, _, acc), do: List.flatten(acc ++ [last])
  defp depth_parse(reg, [keep, to_parse|rest], id, 1, acc) do
    [para] = Regex.run(reg, to_parse, [:global, {:capture, :all_but_first}])
    acc = acc ++ [keep, {id, List.flatten(depth_parse(para))}]
    depth_parse(reg, rest, id, 1, acc)
  end
  defp depth_parse(reg, [keep, to_parse|rest], id, 2, acc) do
    [part1, part2] = Regex.run(reg, to_parse, [:global, {:capture, :all_but_first}])
    acc = acc ++ [keep, {id, List.flatten(depth_parse(part1)),
                             List.flatten(depth_parse(part2))}]
    depth_parse(reg, rest, id, 2, acc)
  end

  defp parse_attrs(attrs) do
    attrs
    |> String.split(" ")
    |> Stream.map(&(String.split(&1, "=")))
    |> Enum.map(fn [k, v] -> {String.to_atom(String.trim(k)), String.trim(v)} end)
  end

  defp rest_of_line(text, sep \\ "\n") do
    case String.split(text, sep, parts: 2) do
      [text, rest] -> {String.trim(text), rest}
      [text] -> {String.trim(text), nil}
    end
  end
end
