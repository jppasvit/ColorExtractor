import asyncio
import argparse
from pathlib import Path
from colorthief import ColorThief
from concurrent.futures import ProcessPoolExecutor
import time
import json

class TimeMeasurement:
    def __init__(self):
        self.start_time = 0
        self.end_time = 0
        self.elapsed_time = 0
    
    def start(self):
        self.start_time = time.perf_counter() * 1000  # milliseconds
    
    def stop(self):
        self.end_time = time.perf_counter() * 1000  # milliseconds
        self.elapsed_time = self.end_time - self.start_time # milliseconds

    def elapsed(self):
        return self.elapsed_time

class ColorExtractor:
    def __init__(self):
        pass
    
    def get_dominant_color(self, image_path: str, index: int):
        try:
            ct = ColorThief(image_path)
            palette = ct.get_palette(color_count=5)
            # Convert RGB tuples to hex
            colors = ['#%02x%02x%02x' % color for color in palette]
            return index, colors
        except Exception as e:
            return Path(image_path).name, f"Error: {e}"
    
    async def extract_colors_concurrently(self, image_paths: str, max_workers: int=12):
        loop = asyncio.get_running_loop()
        with ProcessPoolExecutor(max_workers=max_workers) as executor:
            tasks = [
                loop.run_in_executor(executor, self.get_dominant_color, str(path), index) for index, path in enumerate(image_paths)
            ]
            return await asyncio.gather(*tasks)

    def save_colors_to_file(self, data, filename="cli_colors_by_second_file_python.json"):
        with open(filename, "w") as file:
            json.dump(data, file, indent=4)

    def main(self):
        parser = argparse.ArgumentParser(description="Extract dominant colors in parallel.")
        parser.add_argument("folder", type=str, help="Path to folder with images")
        parser.add_argument("--workers", type=int, default=12, help="Number of parallel workers (default: 12)")
        args = parser.parse_args()

        folder = Path(args.folder)
        if not folder.is_dir():
            print(f"Invalid folder: {folder}")
            return
        
        print(f"Extracting colors from {args.folder}")

        image_files = list(folder.glob("*.jpg"))

        if not image_files:
            print("No images found.")
            return
        tm = TimeMeasurement()
        tm.start()
        results = asyncio.run(self.extract_colors_concurrently(image_files, max_workers=args.workers))
        tm.stop()
        if results is not None and len(results) > 0:
            print(f"Colors extracted successfully")
            print(f"Color extraction completed in {tm.elapsed():.3f} ms")
            self.save_colors_to_file(dict(results))
        else:
            print("Error during color extraction")

if __name__ == "__main__":
    ce = ColorExtractor()
    ce.main()
