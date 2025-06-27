defmodule ColorExtractorWeb.VideoLive do
  use ColorExtractorWeb, :live_view
  import ColorExtractor.VideoUtils

  @impl true
  def mount(_, _, socket) do
    {:ok,
     allow_upload(socket, :video,
       accept: ~w(.mp4 .mov),
       max_entries: 1,
       max_file_size: 20_000_000
     )}
  end

  @impl true
  def handle_event("upload", _params, socket) do
    consume_uploaded_entries(socket, :video, fn %{path: path}, _entry ->
      dest = Path.join("priv/static/uploads", Path.basename(path))
      File.cp!(path, dest)
      extract_frame(dest)
      colors = extract_colors("frame.jpg")
      {:ok, %{colors: colors}}
    end)
    |> case do
      %{colors: colors} -> {:noreply, assign(socket, colors: colors)}
    end
  end

  @impl true
  def handle_event("extract", _params, socket) do
    extract_frame("priv/static/uploads/landscape.mp4")
    colors = extract_colors("frame.jpg")
    # {:ok, %{colors: colors}}
    {:noreply, socket}
  end


end
