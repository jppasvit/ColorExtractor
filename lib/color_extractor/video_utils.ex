defmodule ColorExtractor.VideoUtils do
  require Logger
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

  defp parse_colors(histogram_output) do
    Regex.scan(~r/#([A-Fa-f0-9]{6})/, histogram_output)
    |> Enum.map(fn [_, hex] -> "##{hex}" end)
  end

  def extract_colors_python(path) do
    {json, 0} =
      System.cmd("python3", ["scripts/color-extractor.py", path])

    Jason.decode!(json)
  end

  def extract_colors_elixir(path) do
    image = Image.open!(path)
    case Image.dominant_color(image,[{:top_n, 5}]) do
      {:ok, colors} ->
        hex_colors = Enum.map(colors, fn color ->
          {:ok, hex_color} = Image.Color.rgb_to_hex(color)
          hex_color
        end)
        Logger.info("Extracted colors: #{inspect(hex_colors)}")
        hex_colors
      {:error, reason} ->
        Logger.error("Failed to extract colors: #{reason}")
        []
    end
  end

  def extract_frames(file_name) do
    File.mkdir_p!("tmp/#{file_name}")
    System.cmd("ffmpeg", [
      "-i", "priv/static/uploads/landscape.mp4",
      "-vf", "fps=1",
      "/tmp/#{file_name}/frame_%03d.jpg"
    ])
  end

end
