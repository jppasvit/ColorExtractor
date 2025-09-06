package main

import (
  "encoding/json"
  "fmt"
  "image"
   _ "image/jpeg"
   _ "image/png"
  "os"
  "sync"
  "path/filepath"
  "time"
  "github.com/EdlinOrg/prominentcolor"
  "sort"
  "strconv"
)

const N_PREDOMINANT_COLORS = 5

type Result struct {
    FileName string
    Index    int
    Colors   []string
    Err      error
}

type PairKV struct {
    Key   string
	  Value interface{}
}

type OrderedMap []PairKV

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

func extractColorsFromFolder(folder string, numColors int) ([]Result, error) {
  files, err := os.ReadDir(folder)
  if err != nil {
    return nil, err
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
  
  // for res := range results {
  //   fmt.Printf("File: %s - Colors: %s - Index: %d\n", res.FileName, res.Colors, res.Index)
  // }

  var allResults []Result
  for res := range results {
    allResults = append(allResults, res)
  }

  return allResults, nil
}

func (om OrderedMap) MarshalJSON() ([]byte, error) {
	out := []byte{'{'}
	for i, kv := range om {
		k, _ := json.Marshal(kv.Key)
		v, _ := json.Marshal(kv.Value)
		out = append(out, k...)
		out = append(out, ':')
		out = append(out, v...)
		if i < len(om) - 1 {
			out = append(out, ',')
		}
	}
	out = append(out, '}')
	return out, nil
}


func getColorsFromRestults(results []Result) OrderedMap {
  colorsMap := make(map[int][]string)
  keys := make([]int, 0, len(results))
  for _, res := range results {
    keys = append(keys, res.Index)
    colorsMap[res.Index] = res.Colors
  }
  sort.Ints(keys)
  orderedColorsMap := OrderedMap{}
  for _, k := range keys {
    orderedColorsMap = append(orderedColorsMap, PairKV{
      Key: strconv.Itoa(k), 
      Value: colorsMap[k],
    })
  }
  return orderedColorsMap;
}



func saveResultsToFile(results []Result, outputPath string) error {
  absPath, err := filepath.Abs(outputPath)
  if err != nil {
    return err
  }
  colorsMap := getColorsFromRestults(results)
  data, err := json.MarshalIndent(colorsMap, "", "  ")
  if err != nil {
    return err
  }
  return os.WriteFile(absPath, data, 0644)
}

func main() {
  if len(os.Args) < 2 {
    fmt.Println("Usage: go run main.go <image-path>")
    return
  }
  fmt.Println("Extracting colors from images in folder:", os.Args[1])
  start := time.Now().UnixNano()
  results, colorErr := extractColorsFromFolder(os.Args[1], N_PREDOMINANT_COLORS)
  if colorErr != nil {
    fmt.Printf("Failed to extract colors: %v\n", colorErr)
    return
  }
  fmt.Println("Colors extracted successfully")
  err := saveResultsToFile(results, "./cli_colors_by_second_file_go.json")
  if err != nil {
    fmt.Printf("Failed to save results: %v\n", err)
    return
  }
  elapsed := time.Now().UnixNano() - start
  fmt.Printf("Color extraction completed in %.3f ms\n", float64(elapsed) / 1e6 )
}
