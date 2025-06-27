defmodule ColorExtractor.VideoUtils do
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
end
