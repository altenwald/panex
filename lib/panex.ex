defmodule Panex do
  @moduledoc """
  Panex is a way to convert Markdown rich format in Docbook to make easier
  the way to write articles, essays, reports and books. Mainly books actually.

  Docbook is too rich and it has some specific advantages which are not present
  by default in some specific Markdown formats (like admonitions or callouts).
  The proposed Rich Markdown version proposed here is a recopilation from other
  formats which use in some way these formats and some custom parts where the
  features were no found in other Markdown syntaxes.

  ## Examples

      iex> Panex.translate \"""
      ...>                 #(id=installation) Installation
      ...>                 After check some parts of the _installation_ I could see:
      ...>                 ```language=bash
      ...>                 ls -1
      ...>                 ```
      ...>                 \"""
      "<section id=\\"installation\\"><title>Installation</title><para>After check some parts of the <emphasis>installation</emphasis> I could see:</para><programlisting language=\\"bash\\"><![CDATA[ls -1]]></programlisting></section>"
  """

  @default_parser_module Panex.Parser.Markdown
  @default_output_module Panex.Output.Docbook

  def translate(markdown_text, opts \\ []) do
    parser = opts[:parser_module] || @default_parser_module
    output = opts[:output_module] || @default_output_module
    markdown_text
    |> parser.parse()
    |> output.transform()
  end

end
