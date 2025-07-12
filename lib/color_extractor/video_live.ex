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
    socket =
      socket
      |> allow_upload(:video,
        accept: ~w(video/mp4 video/webm video/ogg),
        max_entries: 1,
        max_file_size: 100 * 1_024 * 1_024 # 100 MB
      )
      |> assign(:uploaded_files, [])

    {:ok, socket}
  end

  def handle_event("upload", _params, socket) do
    Logger.info("STARTING UPLOAD")
    uploaded_files = []
    try do
      uploaded_files =
        consume_uploaded_entries(socket, :video, fn %{path: path}, entry ->
          uploads_dir = Path.expand("priv/static/uploads")
          File.mkdir_p!(uploads_dir)

          unique_name =
            "#{Path.rootname(entry.client_name)}_#{DateTime.utc_now() |> DateTime.to_unix()}#{Path.extname(entry.client_name)}"

          dest_path = Path.join(uploads_dir, unique_name)
          Logger.info("Saving uploaded file to: #{dest_path}")
          File.cp!(path, dest_path)
          Logger.info("ENDING UPLOAD")
          {:ok, unique_name}
        end)

        socket = socket
          |> assign(:uploaded_files, uploaded_files)
          |> put_flash(:info, "File uploaded successfully!")

      {:noreply, socket}
    rescue e ->
      Logger.error("Upload failed: #{inspect(e)}")

      socket = socket
          |> assign(:uploaded_files, uploaded_files)
          |> put_flash(:info, "Failed to upload the video.")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    # No-op or update assigns if needed
    {:noreply, socket}
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

  # @impl true
  # def handle_event("extract-process-save", _params, socket) do
  #   Logger.info("Extracting frames")
  #   # extract_frames("landscape")
  #   image_paths = list_files_with_paths("tmp/landscape")
  #   color_map = %{}
  #   color_map = Enum.with_index(image_paths)
  #   |> Enum.reduce(%{}, fn {image_path, index}, acc_color_map ->
  #     Logger.info("Processing image (#{index}): #{image_path}")
  #     colors = extract_colors_python(image_path)
  #     Logger.info("Extracted colors: #{inspect(colors)}")
  #     Map.put(acc_color_map, index, colors)
  #   end)
  #   File.write!(
  #     "tmp/landscape/colors_by_second.json",
  #     Jason.encode!(color_map, pretty: true)
  #   )
  #   {:noreply, push_event(socket, "color_timeline", %{colors: color_map})}
  # end

  @impl true
  def handle_event("extract-process-save", _params, socket) do
    # Start watching the directory
    watch_path = Path.expand("/tmp/landscape")
    Logger.info("#{inspect(watch_path)}")
    {:ok, watcher_pid} = FileSystem.start_link(dirs: [watch_path])
    FileSystem.subscribe(watcher_pid)

    liveview_pid = self()
    Task.start(fn ->
      extract_frames("landscape")
      send(liveview_pid, :frames_extraction_complete)
    end)

    # Save initial state
    {:noreply,
      socket
      |> assign(:loading, true)
      |> assign(:watcher, watcher_pid)
      |> assign(:color_map, %{})}
  end

  @impl true
  def handle_info(
        {:file_event, _watcher_pid, {path, events}},
        %{assigns: %{color_map: color_map}} = socket
      ) do
    Logger.info("File event detected: #{inspect({path, events})}")
    # require IEx
    # IEx.pry()
    if Enum.any?(events, &(&1 in [:created])) and String.ends_with?(path, ".jpg") do
      unless Map.has_key?(color_map, path) do
        Logger.info("New frame detected: #{path}")
        # colors = extract_colors_python(path)
        colors = extract_colors_elixir(path)

        new_color_map = Map.put(color_map, map_size(color_map), colors)

        # require IEx
        # IEx.pry()

        # Push update to frontend


        #{:noreply, assign(socket, :color_map, new_color_map)}
        {:noreply, socket
          |> assign(:color_map, new_color_map)
          |> push_event("color_timeline", %{colors: new_color_map})}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:frames_extraction_complete, %{assigns: %{color_map: color_map}} = socket) do
    Logger.info("FRAMES EXTRACTION COMPLETE")
    # require IEx
    # IEx.pry()
    File.write!(
      "tmp/landscape/colors_by_second.json",
      Jason.encode!(color_map, pretty: true)
    )

    {:noreply, assign(socket, :loading, false)}
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
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.filter(fn path ->
          File.regular?(path) and
          (Path.extname(path) in [".jpg", ".jpeg", ".png"])
        end)

      {:error, reason} ->
        Logger.error("Failed to list files: #{reason}")
        []
    end
  end

end
