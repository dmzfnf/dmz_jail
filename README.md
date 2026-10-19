# dmz_jail

Standalone jail system for FiveM with a built-in NUI, JSON persistence, ACE permissions, and no framework or database dependency.

![dmz_jail preview](preview.gif)

## Installation :

Add the resource and permission to `server.cfg`:

```cfg
ensure dmz_jail
add_ace group.admin dmz.admin allow
```

Set `Config.DevMode = true` to grant access to everyone during development. Always disable it on a public server.

## Commands :

- `/jail [id] [minutes] [reason]`
- `/unjail [id]`
- `/jailmenu`
- `/jailtime`

All settings are available in `config.lua`. The ready-to-use interface is included in `web/`, so Node.js is not required on the server.