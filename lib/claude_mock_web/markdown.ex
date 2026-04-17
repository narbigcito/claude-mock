defmodule ClaudeMockWeb.Markdown do
  @moduledoc """
  Renders trusted conversation content (stored by an admin) as HTML.
  Syntax highlighting is applied client-side via highlight.js — we only
  annotate code blocks with the `language-*` class that Earmark emits.
  """

  @earmark_options %Earmark.Options{
    gfm: true,
    breaks: true,
    code_class_prefix: "language-"
  }

  @doc """
  Converts a markdown string to safe HTML for rendering with `Phoenix.HTML.raw/1`.
  """
  def to_html(nil), do: ""
  def to_html(""),  do: ""

  def to_html(markdown) when is_binary(markdown) do
    case Earmark.as_html(markdown, @earmark_options) do
      {:ok, html, _} -> html
      {:error, html, _} -> html
    end
  end
end
