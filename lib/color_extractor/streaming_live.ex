defmodule ColorExtractorWeb.StreamingLive do
  use ColorExtractorWeb, :live_view
  import ColorExtractor.WebcamStream
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: subscribe()
    {:ok, assign(socket, dominant: "#000000", palette: [], last_updated: nil), temporary_assigns: [palette: []]}
  end

  @impl true
  def handle_info({:frame_colors, %{dominant: dom, palette: pal}}, socket) do
    {:noreply, assign(socket, dominant: dom, palette: pal, last_updated: DateTime.utc_now())}
  end

end
