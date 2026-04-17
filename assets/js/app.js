// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

// Runs hljs.highlightElement on every <pre><code> inside the mounted element.
// highlight.js is loaded globally via CDN in root.html.heex.
Hooks.Highlight = {
  mounted()  { this.run() },
  updated()  { this.run() },
  run() {
    if (!window.hljs) return
    this.el.querySelectorAll("pre code").forEach((block) => {
      delete block.dataset.highlighted
      window.hljs.highlightElement(block)
    })
  }
}

// Auto-scroll a container to the bottom whenever content updates.
Hooks.ScrollBottom = {
  mounted() { this.el.scrollTop = this.el.scrollHeight },
  updated() { this.el.scrollTop = this.el.scrollHeight }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

topbar.config({barColors: {0: "#c96442"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket
