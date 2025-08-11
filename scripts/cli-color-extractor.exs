#!/usr/bin/env elixir

Mix.install([
  {:image, "~> 0.61.0"},
  {:jason, "~> 1.2"}
])

defmodule ColorExtractor do
  @moduledoc """
  A CLI tool to extract colors from images.
  """

  def main(args) do
    case args do
      [] ->
        IO.puts("Usage: cli-color-extractor <images_path>")
      [images_path] ->
          %{elapsed: elapsed, fun_result: fun_result} =
          TimeMeasurement.measure(fn ->
            extract_colors(images_path)
          end)
          IO.puts("Color extraction completed in #{elapsed} ms")

          sorted_json =
            fun_result
            |> Enum.sort_by(fn {index, _colors} -> index end)
            |> Jason.OrderedObject.new()

          File.write!(
            "./cli_colors_by_second_file_elixir.json",
            Jason.encode!(sorted_json, pretty: true)
          )
      _ ->
        IO.puts("Invalid arguments. Usage: cli-color-extractor <images_path>")
    end
  end

  defp extract_colors(images_path) do
    IO.puts("Extracting colors from #{images_path}...")
    frames = File.ls!(images_path)
    resutls =
      frames
      |> Task.async_stream(fn filename ->
        full_path = Path.join(images_path, filename)
        extract_colors_from_frame(full_path)
      end, max_concurrency: 12, timeout: :infinity)
      |> Enum.to_list()

      sucesses = for {:ok, colors} <- resutls, do: colors
      failures = for {:error, reason} <- resutls, do: reason

      case {sucesses, failures} do
        {[], []} ->
          IO.puts("No colors extracted.")
          []
        {[], _} ->
          IO.puts("Failed to extract colors: #{inspect(failures)}")
          []
        {colors, []} ->
          IO.puts("Colors extracted successfully")
          #IO.puts("Colors extracted successfully: #{inspect(colors)}")
          colors
      end
      |> Enum.with_index()
      |> Enum.into(%{}, fn {color, index} ->
        {index, color}
      end)
  end

  defp extract_colors_from_frame(frame_path) do
    image = Image.open!(frame_path)
    case Image.dominant_color(image,[{:top_n, 5}]) do
      {:ok, colors} ->
        hex_colors = Enum.map(colors, fn color ->
          {:ok, hex_color} = Image.Color.rgb_to_hex(color)
          hex_color
        end)
        hex_colors
      {:error, reason} ->
        IO.puts("Failed to extract colors: #{reason}")
        []
    end
  end


end

defmodule TimeMeasurement do
  @moduledoc """
  A module to measure execution time of functions.
  """

  @doc """
  Measures the execution time of a function and returns the time taken in milliseconds
  and the function's result.
  """
  @spec measure(fun) :: {integer, any}
  def measure(fun) when is_function(fun, 0) do
    start_time = System.monotonic_time(:millisecond)
    fun_result = fun.()
    end_time = System.monotonic_time(:millisecond)
    elapsed = end_time - start_time
    %{elapsed: elapsed, fun_result: fun_result}
  end
end

ColorExtractor.main(System.argv())
