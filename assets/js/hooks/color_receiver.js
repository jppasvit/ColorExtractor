
export const ColorReceiver = {
  mounted() {
    console.log("ColorReceiver hook mounted!") 
    this.setupVideo()
    this.handleEvent("color_timeline", ({ colors }) => {
      console.log("Color timeline received:", colors)
      this.colorsMap = colors
      this.container = document.getElementById("colors")
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
    this.container.innerHTML = ""
    colors.forEach(color => {
      const div = document.createElement("div")
      div.style.width = "216px"
      div.style.height = "50px"
      div.style.backgroundColor = color
      div.title = color
      this.container.appendChild(div)
    })
  }
}
