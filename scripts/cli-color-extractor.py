import asyncio
import argparse
from pathlib import Path
from colorthief import ColorThief
from concurrent.futures import ProcessPoolExecutor
import time

class TimeMeasurement:
    def __init__(self):
        self.start_time = 0
        self.end_time = 0
        self.elapsed_time = 0
    
    def start(self):
        self.start_time = time.perf_counter()
    
    def stop(self):
        self.end_time = time.perf_counter()
        self.elapsed_time = self.end_time - self.start_time

    def elapsed(self):
        return self.elapsed_time

class ColorExtractor:
    def __init__(self):
        pass
    
    def get_dominant_color(self, image_path: str):
        try:
            ct = ColorThief(image_path)
            palette = ct.get_palette(color_count=5)
            # Convert RGB tuples to hex
            colors = ['#%02x%02x%02x' % color for color in palette]
            return Path(image_path).name, colors
        except Exception as e:
            return Path(image_path).name, f"Error: {e}"
    
    async def extract_colors_concurrently(self, image_paths, max_workers=12):
        loop = asyncio.get_running_loop()
        with ProcessPoolExecutor(max_workers=max_workers) as executor:
            tasks = [
                loop.run_in_executor(executor, self.get_dominant_color, str(path))
                for path in image_paths
            ]
            return await asyncio.gather(*tasks)

    def main(self):
        parser = argparse.ArgumentParser(description="Extract dominant colors in parallel.")
        parser.add_argument("folder", type=str, help="Path to folder with images")
        parser.add_argument("--workers", type=int, default=12, help="Number of parallel workers (default: 12)")
        args = parser.parse_args()

        folder = Path(args.folder)
        if not folder.is_dir():
            print(f"Invalid folder: {folder}")
            return

        image_files = list(folder.glob("*.jpg"))

        if not image_files:
            print("No images found.")
            return
        tm = TimeMeasurement()
        tm.start()
        results = asyncio.run(self.extract_colors_concurrently(image_files, max_workers=args.workers))
        tm.stop()
        print(f"Time taken: {tm.elapsed()} seconds")
        for name, color in results:
            print(f"{name}: {color}")

if __name__ == "__main__":
    ce = ColorExtractor()
    ce.main()
