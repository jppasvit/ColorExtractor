defmodule ColorExtractor.WebcamStream do
  use GenServer
  require Logger


  @topic "video:colors"


  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  def subscribe, do: Phoenix.PubSub.subscribe(VideoColors.PubSub, @topic)


  def init(:ok) do
    stream_url = Application.get_env(:color_extractor, :camera_stream_url) || "http://host.docker.internal:5000/video"
    {:ok, cap} = Evision.VideoCapture.videoCapture(stream_url)
    if cap.isOpened do
      Logger.info("Camera stream opened: #{stream_url}")
      {:ok, %{cap: cap}, {:continue, :stream}}
    else
      Logger.error("Cannot open camera stream: #{stream_url}")
      {:stop, :no_camera}
    end
  end


  def handle_continue(:stream, state) do
    spawn(fn -> read_frames(state.cap) end)
    {:noreply, state}
  end


  defp read_frames(cap) do
    case Evision.VideoCapture.read(cap) do
    {:ok, false} -> Logger.info("Webcam disconnected")
    {:ok, frame} -> process_frame(frame); read_frames(cap)
    {:error, reason} -> Logger.error("Camera read error: #{inspect(reason)}")
    end
  end


  defp process_frame(frame) do
    rgb = Evision.cvtColor(frame, :COLOR_BGR2RGB)
    small = Evision.resize(rgb, {96, 96})

    {h, w, _c} = Evision.Mat.shape(small)
    pixels = Evision.Mat.reshape(small, h * w)
    tensor = Nx.from_binary(Evision.Mat.to_binary(pixels), {:u8, 3})
    bestLabels = Nx.new_axis(Nx.iota({h * w}), 1)

    {:ok, {_labels, centers}} =
    Evision.kmeans(
      tensor,
      6,
      bestLabels,
      {:MAX_ITER, 10, 1.0},   # or {:EPS, 10, 1.0}
      3,
      :KMEANS_PP_CENTERS
    )

    palette = Enum.map(centers, &to_hex/1)
    dominant = hd(palette)
    Phoenix.PubSub.broadcast(VideoColors.PubSub, @topic, {:frame_colors, %{dominant: dominant, palette: palette}})
  end


  defp to_hex({r, g, b}),
    do: "#" <> Enum.map_join([r, g, b], "", fn c -> Integer.to_string(c, 16) |> String.pad_leading(2, "0") end)
end
