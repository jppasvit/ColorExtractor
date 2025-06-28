export const ColorReceiver = {
  mounted() {
    console.log("ColorReceiver hook mounted!") 
    this.handleEvent("color_timeline", ({ colors }) => {
      console.log("Color timeline received:", colors)
      this.colorsMap = colors
      this.video = document.getElementById("my-video")
      this.container = document.getElementById("colors")

      this.video.addEventListener("timeupdate", () => {
        const index = Math.floor(this.video.currentTime)
        this.updateColors(this.colorsMap[index])
      })
    })
  },

  updateColors(colors) {
    console.log("Colors:", colors)
    this.container.innerHTML = ""
    colors.forEach(color => {
      const div = document.createElement("div")
      div.style.width = "40px"
      div.style.height = "40px"
      div.style.backgroundColor = color
      div.title = color
      this.container.appendChild(div)
    })
  }
}
