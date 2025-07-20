defmodule ColorExtractor.VideoUtils do
  require Logger

  # Directory to store uploaded files
  def uploads_path do
    Path.expand("priv/static/uploads")
  end

  # Directory to store color extractions
  def extractions_path do
    Path.expand("extractions")
  end

  # File name for colors by second
  def colors_file_name do
    "colors_by_second.json"
  end

  # Extract one frame using FFmpeg
  def extract_frame(video_path) do
    System.cmd("ffmpeg", [
      "-i", video_path,
      "-ss", "00:00:01",
      "-vframes", "1",
      "-y", "frame.jpg"
    ])
  end

  # Extract dominant colors from frame using ImageMagick
  def extract_colors(image_path) do
    {output, 0} =
      System.cmd("convert", [
        image_path,
        "-resize", "100x100",
        "-format", "%c",
        "-depth", "8",
        "-colors", "5",
        "histogram:info:histogram.txt"
      ])

    parse_colors(output)
  end

  # Parse colors from histogram output
  defp parse_colors(histogram_output) do
    Regex.scan(~r/#([A-Fa-f0-9]{6})/, histogram_output)
    |> Enum.map(fn [_, hex] -> "##{hex}" end)
  end

  # Extract colors using Python script
  def extract_colors_python(path) do
    Logger.info("Extracting colors using Python for: #{path}")
    {json, 0} =
      System.cmd("python3", ["scripts/color-extractor.py", path])

    Jason.decode!(json)
  end

  # Extract colors using Elixir Image library
  def extract_colors_elixir(path) do
    Logger.info("Extracting colors using Elixir for: #{path}")
    image = Image.open!(path)
    case Image.dominant_color(image,[{:top_n, 5}]) do
      {:ok, colors} ->
        hex_colors = Enum.map(colors, fn color ->
          {:ok, hex_color} = Image.Color.rgb_to_hex(color)
          hex_color
        end)
        # Logger.info("Extracted colors: #{inspect(hex_colors)}")
        hex_colors
      {:error, reason} ->
        Logger.error("Failed to extract colors: #{reason}")
        []
    end
  end

  # Extract frames from video using FFmpeg
  def extract_frames(file_name) do
    file_name_no_ext = Path.rootname(file_name)
    System.cmd("ffmpeg", [
      "-i", "priv/static/uploads/#{file_name}",
      "-vf", "fps=1",
      "/tmp/#{file_name_no_ext}/frame_%03d.jpg"
    ])
  end

  # List all files in a directory with their full paths
  def list_files_with_paths(dir, file_extensions \\ [".jpg", ".jpeg", ".png"] ) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.filter(fn path ->
          File.regular?(path) and
          (Path.extname(path) in file_extensions)
        end)

      {:error, reason} ->
        Logger.error("Failed to list files: #{reason}")
        []
    end
  end

  # Consume uploaded video file
  def consume_uploaded_video(socket, video_name \\ :video) do
      Phoenix.LiveView.consume_uploaded_entries(socket, video_name, fn %{path: path}, entry ->
        uploads_dir = uploads_path()
        File.mkdir_p!(uploads_dir)
        unique_name = unique_file_name(entry.client_name)
        dest_path = Path.join(uploads_dir, unique_name)
        Logger.info("Saving uploaded file to: #{dest_path}")
        File.cp!(path, dest_path)
        {:ok, unique_name}
      end)
  end

  # Generate a unique file name based on the original file name
  # @spec unique_file_name(String.t()) :: String.t() # TODO: Add type spec in all functions
  def unique_file_name(file_name) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    unique_id = UUID.uuid4()
    "#{Path.rootname(file_name)}_#{unique_id}_#{timestamp}#{Path.extname(file_name)}"
  end

  # Load color file from extractions directory
  def load_color_file(file_name) do
    file_path = Path.join(extractions_path(), file_name |> Path.rootname()) |> Path.join(colors_file_name())
    case File.read(file_path) do
      {:ok, content} ->
        Jason.decode!(content)

      {:error, reason} ->
        Logger.error("Failed to read color file: #{reason}")
        []
    end
  end



end
