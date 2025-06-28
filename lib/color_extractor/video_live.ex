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

  # @impl true
  # def mount(_params, _session, socket) do
  #   if connected?(socket) do
  #     port =
  #       Port.open(
  #         {:spawn, "ffmpeg -i ./priv/static/uploads/landscape.mp4 -vf fps=1 -f image2pipe -vcodec mjpeg -"},
  #         [:binary, :stream]
  #       )
  #       Logger.error("FFmpeg port opened successfully")
  #     {:ok, assign(socket, port: port)}
  #   else
  #     {:ok, socket}
  #   end
  # end

  # @impl true
  # def mount(_params, _session, socket) do
  #   # Example list of hex colors (1 per second)
  #   colors = ["#ff0000", "#00ff00", "#0000ff", "#3333ff", "#ffcc00"]
  #   socket = push_event(socket, "color_timeline", %{colors: colors})
  #   {:ok, assign(socket, colors: colors)}
  # end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("extract", _params, socket) do
    extract_frames("landscape")
    {:noreply, socket}
  end

  @impl true
  def handle_event("process", _params, socket) do
    image_paths = list_files_with_paths("tmp/landscape")
    send(self(), {:process_colors, image_paths})
    {:noreply, socket}
  end

  @impl true
  def handle_event("extract-process-save", _params, socket) do
    Logger.info("Extracting frames")
    # extract_frames("landscape")
    image_paths = list_files_with_paths("tmp/landscape")
    color_map = %{}
    color_map = Enum.with_index(image_paths)
    |> Enum.reduce(%{}, fn {image_path, index}, acc_color_map ->
      Logger.info("Processing image (#{index}): #{image_path}")
      colors = extract_colors_python(image_path)
      Logger.info("Extracted colors: #{inspect(colors)}")
      Map.put(acc_color_map, index, colors)
    end)
    # File.write!(
    #   "tmp/landscape/colors_by_second.json",
    #   Jason.encode!(color_map, pretty: true)
    # )
    {:noreply, push_event(socket, "color_timeline", %{colors: color_map})}
  end

  @impl true
  def handle_info({:process_colors, [path | rest]}, socket) do
    colors = extract_colors_python(path)
    Logger.info("Pushing colors: #{inspect(colors)}")
    socket = push_event(socket, "new_colors", %{colors: colors})
    send(self(), {:process_colors, rest})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:process_colors, []}, socket) do
    Logger.info("All colors processed.")
    {:noreply, socket}
  end

  def list_files_with_paths(dir) do
    Logger.error(dir)
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.map(&Path.join(dir, &1))

      {:error, reason} ->
        IO.puts("Failed to list files: #{reason}")
        []
    end
  end

end
