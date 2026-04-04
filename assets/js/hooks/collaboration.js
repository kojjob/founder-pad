const Collaboration = {
  mounted() {
    this.handleEvent("presence_diff", ({joins, leaves}) => {
      // Presence updates are handled server-side via LiveView assigns
      // This hook can be extended for cursor position sharing
    })
  }
}

export default Collaboration
