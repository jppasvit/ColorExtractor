export const ColorReceiver = {
  mounted() {
    this.handleEvent("new_colors", ({ colors }) => {
      const container = document.getElementById("colors")
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
