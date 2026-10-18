// hs-bridge — lets the Hammerspoon music widget like/unlike the current song.
// Connects to ws://localhost:7655/spotify (served by ~/.hammerspoon/widgets.lua):
//   receives "toggle" → toggles the heart; "state" → re-reports
//   sends {type:"heart", liked, uri} on connect, song change, after toggles and every 5s.
(function hsBridge() {
  const P = window.Spicetify && Spicetify.Player;
  if (!P || !P.getHeart || !P.addEventListener) { setTimeout(hsBridge, 500); return; }

  let ws;
  const report = () => {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    ws.send(JSON.stringify({ type: "heart", liked: !!P.getHeart(), uri: P.data && P.data.item && P.data.item.uri }));
  };

  function connect() {
    ws = new WebSocket("ws://localhost:7655/spotify");
    ws.onopen = report;
    ws.onmessage = (e) => {
      if (e.data === "toggle") { P.toggleHeart(); setTimeout(report, 400); }
      else if (e.data === "state") report();
    };
    ws.onclose = () => setTimeout(connect, 3000); // Hammerspoon restarted / not running yet
    ws.onerror = () => ws.close();
  }

  P.addEventListener("songchange", () => setTimeout(report, 300));
  setInterval(report, 5000); // also picks up likes made inside Spotify
  connect();
})();
