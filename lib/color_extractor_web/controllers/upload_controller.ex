defmodule ColorExtractorWeb.UploadController do
  use ColorExtractorWeb, :controller

  def new(conn, _params) do
    render(conn, :upload_view)
  end

  def create(conn, %{"video" => %Plug.Upload{filename: filename, path: tmp_path}}) do
    uploads_dir = Path.expand("priv/static/uploads")
    File.mkdir_p!(uploads_dir)

    unique_name =
      "#{Path.rootname(filename)}_#{DateTime.utc_now() |> DateTime.to_unix()}#{Path.extname(filename)}"

    dest_path = Path.join(uploads_dir, unique_name)
    File.cp!(tmp_path, dest_path)

    conn
    |> put_flash(:info, "Uploaded #{unique_name} successfully")
    |> redirect(to: ~p"/upload")
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "No video file selected!")
    |> redirect(to: ~p"/upload")
  end
end
