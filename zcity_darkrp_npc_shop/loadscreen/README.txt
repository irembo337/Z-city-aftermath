Z-City loadscreen package

Files:
- index.html
- styles.css
- script.js
- assets/zcity_loading.gif

How to deploy:
1. Upload the whole "loadscreen" folder to any public web host or CDN.
2. Keep the files together so index.html can load ./styles.css, ./script.js and ./assets/zcity_loading.gif.
3. After upload, set this in your server cfg:

   sv_loadingurl "https://your-public-host.example/zcity-loadscreen/index.html"

4. Restart the server or changelevel.

Notes:
- The page already supports standard Garry's Mod loading callbacks such as GameDetails, SetFilesNeeded and DownloadingFile.
- The public URL is intentionally left as a placeholder so you can insert your own host later.
