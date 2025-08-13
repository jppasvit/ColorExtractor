package main

import (
  "fmt"
  "image"
   _ "image/jpeg"
   _ "image/png"
  "os"
  "sync"
  "path/filepath"

  "github.com/EdlinOrg/prominentcolor"
)

const N_PREDOMINANT_COLORS = 5

type Result struct {
    FileName string
    Index    int
    Colors   []string
    Err      error
}

func extractColorsFromFile(filePath string, numColors int, index int, wg *sync.WaitGroup, results chan<- Result) ([]string, error) {
  defer wg.Done()

  file, err := os.Open(filePath)
  if err != nil {
    results <- Result{FileName: filePath, Err: err}
    return nil, err
  }
  defer file.Close()

  img, _, err := image.Decode(file)
  if err != nil {
    results <- Result{FileName: filePath, Err: err}
    return nil, err
  }
  colors, err := prominentcolor.KmeansWithAll(
    numColors,
    img,
    prominentcolor.ArgumentDefault,
    prominentcolor.DefaultSize,
    prominentcolor.GetDefaultMasks())

  if err != nil {
    results <- Result{FileName: filePath, Err: err}
    return nil, err
  }

  var hexColors []string
  for _, c := range colors {
      hexColors = append(hexColors, fmt.Sprintf("#%02x%02x%02x", c.Color.R, c.Color.G, c.Color.B))
  }
  results <- Result{FileName: filePath, Index: index, Colors: hexColors, Err: err}
  return hexColors, nil
}

func extractColorsFromFolder(folder string, numColors int) {
  files, err := os.ReadDir(folder)
  if err != nil {
    return
  }
  results := make(chan Result, len(files))

  var wg sync.WaitGroup

  for index, file := range files {
      if !file.IsDir() {
          fullPath := filepath.Join(folder, file.Name())
          wg.Add(1)
          go extractColorsFromFile(fullPath, numColors, index, &wg, results)
      }
  }

  wg.Wait()
  close(results)
  
  for res := range results {
    fmt.Printf("File: %s - Colors: %s - Index: %d\n", res.FileName, res.Colors, res.Index)
  }
}

func main() {
  if len(os.Args) < 2 {
    fmt.Println("Usage: go run main.go <image-path>")
    return
  }
  extractColorsFromFolder(os.Args[1], N_PREDOMINANT_COLORS)
}
