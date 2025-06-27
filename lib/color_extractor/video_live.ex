defmodule ColorExtractorWeb.VideoLive do
  use ColorExtractorWeb, :live_view
  import ColorExtractor.VideoUtils
  require Logger

  # @impl true
  # def mount(_, _, socket) do
  #   {:ok,
  #    allow_upload(socket, :video,
  #      accept: ~w(.mp4 .mov),
  #      max_entries: 1,
  #      max_file_size: 20_000_000
  #    )}
  # end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      port =
        Port.open(
          {:spawn, "ffmpeg -i ./priv/static/uploads/landscape.mp4 -vf fps=1 -f image2pipe -vcodec mjpeg -"},
          [:binary, :stream]
        )
        Logger.error("FFmpeg port opened successfully")
      {:ok, assign(socket, port: port)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info({port, {:data, frame}}, socket) do
    # Save the JPEG frame to disk (you can also process it in-memory)
    uuid = UUID.uuid4()
    Logger.error("#{uuid}")
    File.write!("tmp/frame_#{uuid}.jpg", frame)

    # Extract dominant colors using your own module/script
    # colors = extract_colors_python("tmp/frame_#{uuid}.jpg")
    # Logger.error(colors)

    # Push event to frontend (JS hook) or update LiveView assigns
    #push_event(socket, "new_colors", %{colors: colors})

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, %{assigns: %{port: port}}) do
    Port.close(port)
    :ok
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
