export const ColorReceiverFlow = {
  mounted() {
    console.log("ColorReceiverFlow hook mounted!") 
    this.handleEvent("new_colors", ({ colors }) => {
      console.log("New colors received from server:", colors)
      const container = document.getElementById("colorsFlow")
      container.innerHTML = ""
      colors.forEach(color => {
        const div = document.createElement("div")
        div.style.width = "40px"
        div.style.height = "40px"
        div.style.backgroundColor = color
        div.title = color
        container.appendChild(div)
      })
    })
  }
}
