# Ultimate Powers test builds

Test builds of the Ultimate Powers tuning mod for Company of Heroes 2, ahead of the Steam Workshop release. Each release is one build: `ultimatepowers.sga`, `build.txt` (build name, SHA256, date) and the changelog for that build.

## Update

Close Company of Heroes 2, then paste this into PowerShell:

```powershell
irm https://raw.githubusercontent.com/Voragore/ultimatepowers-builds/main/update.ps1 | iex
```

It downloads the newest build and checks it against its SHA256. It keeps your old file in `Documents\My Games\Company of Heroes 2\ultimatepowers_backup`, then installs the new one as `Documents\My Games\Company of Heroes 2\mods\tuning\ultimatepowers.sga`. You can read [update.ps1](update.ps1) first.

To install a particular build, e.g. to go back one, put its release name at the end:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Voragore/ultimatepowers-builds/main/update.ps1))) up7_lua
```

Everyone in a match must run the same build, or the match desyncs.
