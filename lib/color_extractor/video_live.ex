defmodule ColorExtractorWeb.VideoLive do
  use ColorExtractorWeb, :live_view
  import ColorExtractor.VideoUtils
  require Logger

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
      |> assign(:uploaded_video, nil)

    {:ok, socket}
  end

  def handle_event("upload", _params, socket) do
    Logger.info("STARTING UPLOAD")
    uploaded_files = []
    try do
      uploaded_files = consume_uploaded_video(socket, :video)

      if Enum.empty?(uploaded_files) do
        raise "No files were uploaded."
      end

      video_name = List.first(uploaded_files)
      video_url = "/uploads/#{video_name}"

      socket = socket
        |> assign(:uploaded_files, uploaded_files)
        |> assign(:uploaded_video, video_url)
        |> put_flash(:info, "File uploaded successfully!")
        # |> process_video(List.first(uploaded_files))

      send(self(), {:process_video, video_name})
      {:noreply, socket}
    rescue e ->
      Logger.error("Upload failed: #{inspect(e)}")
      socket = socket
          |> assign(:uploaded_files, uploaded_files)
          |> put_flash(:error, "Failed to upload the video: #{e.message}")

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
    # require IEx
    # IEx.pry()
    Logger.info("Saving colors to file...")
    colors_by_second_file = Path.join(socket.assigns.video_metadata.extractiondir, "colors_by_second.json")
    File.write!(
      colors_by_second_file,
      Jason.encode!(color_map, pretty: true)
    )
    Logger.info("Colors saved to: #{colors_by_second_file}")
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


  @impl true
  def handle_info({:process_video, file_name}, socket) do
    socket = process_video(socket, file_name)
    liveview_pid = self()
    Task.start(fn ->
      extract_frames(file_name)
      send(liveview_pid, :frames_extraction_complete)
    end)
    {:noreply, socket}
  end


  defp process_video(socket, file_name) do
    Logger.info("Starting video processing...")
    file_name_no_ext = Path.rootname(file_name)
    extraction_dir = Path.join(extractions_path(), file_name_no_ext)
    File.mkdir_p!(extraction_dir)
    frames_dir = Path.join("/tmp", file_name_no_ext)
    File.mkdir_p!(frames_dir)
    watch_path = Path.expand(frames_dir)
    Logger.info("Watching path: #{inspect(watch_path)}")
    {:ok, watcher_pid} = FileSystem.start_link(dirs: [watch_path])
    FileSystem.subscribe(watcher_pid)

    socket
      |> assign(:loading, true)
      |> assign(:watcher, watcher_pid)
      |> assign(:color_map, %{})
      |> assign(:video_metadata, %{
        filename: file_name,
        filenamenoext: file_name_no_ext,
        extractiondir: extraction_dir,
        framesdir: frames_dir
      })
  end

end
