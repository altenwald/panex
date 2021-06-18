defmodule Panex.Output.Docbook do
  @moduledoc """
  This module let us to output a parsed document to Docbook format.
  """

  def transform(parsed) do
    transform(parsed, "")
  end

  defp transform([], acc), do: acc
  defp transform([{:section1, title, attrs, contents}|rest], acc) do
    attrs = transform_attrs(attrs)
    title = transform(title)
    contents = transform(contents, "")
    acc = "#{acc}<section#{attrs}><title>#{title}</title>#{contents}</section>"
    transform(rest, acc)
  end
  defp transform([text|rest], acc) when is_binary(text) do
    transform(rest, acc <> text)
  end
  defp transform([{:emphasis, text}|rest], acc) do
    text = transform(text, "")
    acc = "#{acc}<emphasis>#{text}</emphasis>"
    transform(rest, acc)
  end
  defp transform([{:strong, text}|rest], acc) do
    text = transform(text, "")
    acc = "#{acc}<emphasis role='bold'>#{text}</emphasis>"
    transform(rest, acc)
  end
  defp transform([{:link, text, url}|rest], acc) do
    text = transform(text, "")
    url = transform(url, "")
    acc = "#{acc}<ulink url='#{url}'>#{text}</ulink>"
    transform(rest, acc)
  end
  defp transform([{:para, text}|rest], acc) do
    text = transform(text, "")
    acc = "#{acc}<para>#{String.trim(text)}</para>"
    transform(rest, acc)
  end
  defp transform([{:code, attrs, code}|rest], acc) do
    attrs = transform_attrs(attrs)
    acc = "#{acc}<programlisting#{attrs}><![CDATA[#{code}]]></programlisting>"
    transform(rest, acc)
  end
  defp transform([:br|rest], acc) do
    transform(rest, acc)
  end

  defp transform_attrs(attrs) do
    # FIXME: sanitize values
    List.foldl(attrs, "", fn {key, value}, "" ->
                                " #{key}=\"#{value}\""
                             {key, value}, others ->
                                "#{others} #{key}=\"#{value}\""
                          end)
  end
end
