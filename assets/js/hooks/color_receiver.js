
export const ColorReceiver = {
  mounted() {
    console.log("ColorReceiver hook mounted!") 
    this.setupVideo()
    this.handleEvent("color_timeline", ({ colors }) => {
      console.log("Color timeline received:", colors)
      this.colorsMap = colors
      this.colorsContainer = document.getElementById("colors")
      this.colorsContainerCode = document.getElementById("colors-code")
    })
  },

  updated() {
    console.log("ColorReceiver hook updated!")
    if (this.video) {
      console.log("Video element already exists, reloading...")
      this.video.load()
    }
  },

  setupVideo() {
    this.checkInterval = setInterval(() => {
      console.log("Checking for video element...")
      this.video = document.getElementById("my-video")
      if (this.video) {
        console.log("Video element found!")
        clearInterval(this.checkInterval)
        this.setupTimeupdateListener()
      }
    }, 1000)
  },

  setupTimeupdateListener(){
    console.log("Adding timeupdate listener to video")
    this.video.addEventListener("timeupdate", () => {
        const index = Math.floor(this.video.currentTime)
        this.updateColors(this.colorsMap[index])
      })
  },

  updateColors(colors) {
    console.log("Colors:", colors)
    this.colorsContainer.innerHTML = ""
    this.colorsContainerCode.innerHTML = ""
    colors.forEach(color => {
      const colorDiv = this.createColorDiv(color)
      const colorCodeDiv = this.createColorCodeDiv(color)
      this.colorsContainer.appendChild(colorDiv)
      this.colorsContainerCode.appendChild(colorCodeDiv)
    })
  },

  createColorDiv(color) {
    const div = document.createElement("div")
    div.style.width = "154px"
    div.style.height = "50px"
    div.style.backgroundColor = color
    div.title = color
    return div
  },

  createColorCodeDiv(color) {
    const div = document.createElement("div")
    div.style.width = "154px"
    div.style.height = "50px"
    div.textContent = color
    div.classList = "flex justify-center text-black"
    return div
  },

  destroyed() {
    console.log("ColorReceiver hook destroyed!")
    if (this.video) {
      this.video.removeEventListener("timeupdate", this.updateColors)
      console.log("Removed timeupdate listener from video")
    }
    clearInterval(this.checkInterval)
    console.log("Cleared check interval")
  }
}
