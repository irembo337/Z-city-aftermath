(function () {
  var state = {
    filesNeeded: 0,
    filesDownloaded: 0,
    serverName: "Z-City Aftermath RP",
    mapName: "Loading...",
    gameMode: "Z-City / DarkRP",
    status: "Connecting to server..."
  };

  function setText(id, value) {
    var element = document.getElementById(id);
    if (!element) {
      return;
    }

    element.textContent = value;
  }

  function updateProgress() {
    var bar = document.getElementById("progress-bar");
    if (!bar) {
      return;
    }

    var percent = 12;
    if (state.filesNeeded > 0) {
      percent = Math.max(12, Math.min(100, (state.filesDownloaded / state.filesNeeded) * 100));
    }

    bar.style.width = percent + "%";
  }

  function refresh() {
    setText("server-name", state.serverName);
    setText("map-name", state.mapName);
    setText("gamemode-name", state.gameMode);
    setText("server-mode", "Preparing " + state.gameMode + " session...");
    setText("status-text", state.status);
    updateProgress();
  }

  window.GameDetails = function (serverName, serverUrl, mapName, maxPlayers, steamId, gameMode) {
    state.serverName = serverName || state.serverName;
    state.mapName = mapName || state.mapName;
    state.gameMode = gameMode || state.gameMode;
    state.status = "Streaming content for " + (maxPlayers || "?") + " slots...";
    refresh();
  };

  window.SetFilesTotal = function (total) {
    state.filesNeeded = Number(total) || 0;
    refresh();
  };

  window.SetFilesNeeded = function (needed) {
    state.filesNeeded = Number(needed) || state.filesNeeded;
    refresh();
  };

  window.SetFilesDownloaded = function (downloaded) {
    state.filesDownloaded = Number(downloaded) || 0;
    refresh();
  };

  window.DownloadingFile = function (fileName) {
    state.status = fileName ? ("Downloading " + fileName) : "Downloading server content...";
    refresh();
  };

  window.SetStatusChanged = function (status) {
    state.status = status || state.status;
    refresh();
  };

  refresh();
})();
