defmodule ClaudeMockWeb.EmbedHTML do
  use ClaudeMockWeb, :html

  alias ClaudeMockWeb.ChatComponents

  embed_templates "embed_html/*"
end
