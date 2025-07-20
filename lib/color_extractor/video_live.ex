defmodule ColorExtractorWeb.VideoLive do
  use ColorExtractorWeb, :live_view
  import ColorExtractor.VideoUtils
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    videos_to_select = list_files_with_paths(uploads_path(), [".mp4", ".webm", ".ogg"])
    socket =
      socket
      |> allow_upload(:video,
        accept: ~w(video/mp4 video/webm video/ogg),
        max_entries: 1,
        max_file_size: 100 * 1_024 * 1_024, # 100 MB
        auto_upload: true,
        progress: &handle_progress/3
      )
      |> assign(:uploaded_video, nil)
      |> assign(:videos_to_select, videos_to_select)
      |> assign(:loading, false)
      |> assign(:option, :elixir)
      |> assign(:elixir_duration, nil)
      |> assign(:python_duration, nil)

    {:ok, socket}
  end

  def handle_progress(:video, entry, socket) do
    if entry.done? do
      # File finished uploading, trigger the event
      send(self(), :start_upload)
    end
    # Reset durations if the option has changed
    socket = reset_times(socket)
    {:noreply, socket
      |> assign(:loading, true)}
  end

  # @impl true
  # def handle_event("upload", _params, socket) do
  #   liveview_pid = self()
  #   Task.start(fn ->
  #     send(liveview_pid, :start_upload)
  #   end)
  #   {:noreply, socket
  #     |> assign(:loading, true)}
  # end

  @impl true
  def handle_event("set_option", %{"selected_option" => option}, socket) do
    if option == "elixir" do
      {:noreply, socket
        |> assign(:option, :elixir)}
    else
      {:noreply, socket
        |> assign(:option, :python)}
    end
  end

  @impl true
  def handle_event("select_video", %{"video" => video_selected}, socket) do
    videos_to_select = list_files_with_paths(uploads_path(), [".mp4", ".webm", ".ogg"])
    file_name = Path.basename(video_selected)
    video = "/uploads/#{file_name}"
    new_color_map = load_color_file(file_name)
    {:noreply,
      socket
        |> assign(videos_to_select: videos_to_select, uploaded_video: video)
        |> push_event("color_timeline", %{colors: new_color_map})}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    # No-op or update assigns if needed
    {:noreply, socket}
  end

  # @impl true
  # def handle_event("extract", _params, socket) do
  #   extract_frames("landscape")
  #   {:noreply, socket}
  # end

  # @impl true
  # def handle_event("process", _params, socket) do
  #   image_paths = list_files_with_paths("tmp/landscape")
  #   send(self(), {:process_colors, image_paths})
  #   {:noreply, socket}
  # end

  # @impl true
  # def handle_event("extract-process-save", _params, socket) do
  #   # Start watching the directory
  #   watch_path = Path.expand("/tmp/landscape")
  #   Logger.info("#{inspect(watch_path)}")
  #   {:ok, watcher_pid} = FileSystem.start_link(dirs: [watch_path])
  #   FileSystem.subscribe(watcher_pid)

  #   liveview_pid = self()
  #   Task.start(fn ->
  #     extract_frames("landscape")
  #     send(liveview_pid, :frames_extraction_complete)
  #   end)

  #   # Save initial state
  #   {:noreply,
  #     socket
  #     |> assign(:watcher, watcher_pid)
  #     |> assign(:color_map, %{})}
  # end

  @impl true
  def handle_info(
        {:file_event, _watcher_pid, {path, events}},
        %{assigns: %{color_map: color_map, option: option}} = socket
      ) do
    # Logger.info("File event detected: #{inspect({path, events})}")
    # require IEx
    # IEx.pry()
    extract_colors = if option == :elixir, do: &extract_colors_elixir/1, else: &extract_colors_python/1
    if Enum.any?(events, &(&1 in [:created])) and String.ends_with?(path, ".jpg") do
      unless Map.has_key?(color_map, path) do
        Logger.info("New frame detected: #{path}")
        colors = extract_colors.(path)
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
    duration = end_timer(socket)
    socket = link_time(socket, duration)
    Logger.info("Saving colors to file...")
    colors_by_second_file = Path.join(socket.assigns.video_metadata.extractiondir, "colors_by_second.json")
    File.write!(
      colors_by_second_file,
      Jason.encode!(color_map, pretty: true)
    )
    Logger.info("Colors saved to: #{colors_by_second_file}")

    videos_to_select = list_files_with_paths(uploads_path(), [".mp4", ".webm", ".ogg"])
    {:noreply, socket
                  |> assign(videos_to_select: videos_to_select)}
  end

  @impl true
  def handle_info(:start_upload, socket) do
    Logger.info("Starting video upload...")
    try do
      uploaded_files = consume_uploaded_video(socket, :video)

      if Enum.empty?(uploaded_files) do
        raise "No files were uploaded."
      end

      video_name = List.first(uploaded_files)
      video_url = "/uploads/#{video_name}"

      socket = socket
        |> assign(:uploaded_video, video_url)
        |> put_flash(:info, "File uploaded successfully!")

      send(self(), {:process_video, video_name})
      {:noreply, socket}
    rescue e ->
      Logger.error("Upload failed: #{inspect(e)}")
      socket = socket
          |> put_flash(:error, "Failed to upload the video: #{e.message}")

      {:noreply, socket}
    end
  end

  # @impl true
  # def handle_info({:process_colors, [path | rest]}, socket) do
  #   colors = extract_colors_python(path)
  #   Logger.info("Pushing colors: #{inspect(colors)}")
  #   socket = push_event(socket, "new_colors", %{colors: colors})
  #   send(self(), {:process_colors, rest})
  #   {:noreply, socket}
  # end

  # @impl true
  # def handle_info({:process_colors, []}, socket) do
  #   Logger.info("All colors processed.")
  #   {:noreply, socket}
  # end

  @impl true
  def handle_info({:process_video, file_name}, socket) do
    socket = process_video(socket, file_name)
    socket = start_timer(socket) # Start time for processing
    liveview_pid = self()
    Task.start(fn ->
      extract_frames(file_name)
      send(liveview_pid, :frames_extraction_complete)
    end)
    {:noreply, socket
      |> assign(:loading, false)}
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
      |> assign(:watcher, watcher_pid)
      |> assign(:color_map, %{})
      |> assign(:video_metadata, %{
        filename: file_name,
        filenamenoext: file_name_no_ext,
        extractiondir: extraction_dir,
        framesdir: frames_dir
      })
  end

  defp start_timer(socket) do
    start_time = System.monotonic_time()
    Logger.info("Timer started at: #{start_time}")
    socket
      |> assign(:start_time, start_time)
  end

  defp end_timer(socket) do
    end_time = System.monotonic_time()
    duration = System.convert_time_unit(end_time - socket.assigns.start_time, :native, :millisecond)
    Logger.info("Timer ended at: #{end_time}, Duration: #{duration} ms")
    duration
  end

  defp link_time(socket, duration) do
    %{option: option} = socket.assigns
    socket =
        if option == :elixir do
          assign(socket, :elixir_duration, duration)
        else
          assign(socket, :python_duration, duration)
        end
    socket
  end

  defp reset_times(socket) do
    %{elixir_duration: elixir_duration, python_duration: python_duration, option: option} = socket.assigns
    socket =
      if elixir_duration != nil and option == :elixir do
        assign(socket, :elixir_duration, nil)
      else
        socket
      end

    socket =
      if python_duration != nil and option == :python do
        assign(socket, :python_duration, nil)
      else
        socket
      end

      socket
  end

end
