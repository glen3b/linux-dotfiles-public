# Linux Dotfiles
My dotfiles, with a focus on relatively interesting scripts (and comparatively little git-tracked configuration)

## Repository Setup
My utility scripts, tracked in git!

Note that there are some hardcoded references to (e.g.) my setup, my username, my home directory, and whatnot.
While I don't actively intend to make this hard to generalize, and try not to hardcode paths when it's simple, my priority is not general usability.

Users are expected to tweak the scripts to their own needs. You'll see that, for instance, I don't have configuration files for many of my scriptlets.
This is because I expect users to edit the source code.

### Install Tooling


## FAQ
### What is this, really?
These are some of the utility scripts I use on my desktop, omvee.
I hope some are useful to others, I suspect other scripts are not.

### What's omvee's setup?
In essence, omvee is a dual-monitor Arch machine which runs a Windows VM to which the graphics card is passed through.
Synergy 1 Pro is used for mouse pointer synchronization, and tooling (both on the Windows side and the Linux side) helps facilitate integration.

Arch on omvee uses i3blocks on i3-gaps with a relatively not-super-customized config for the desktop.
The systemctl user session is used for running most of the custom long-running session services.

### What's in this repository?

This repository has a few of the tools for my VM integration, and contains reference to some of the tools that are present on the Windows side.
Lots of the tooling is written natively: of note, lots of .NET tools exist for Windows, and there is an event receiving service in C on the Linux side.
Neither of those are tracked in this repository.

This repository also has a nifty script to install from the repository directory hierarchy into the correct system folders.

Additionally, there's a "private" submodule, which contains things managed by this install script which I'm not comfortable publicizing for whatever reason.
If you see a reference to a script in ~/bin or likewise which isn't tracked here, it's probably private.


### What are the most generalizable scripts here?
I've got plenty of miscellanous scripts in here, more so than specifically to facilitate my VM setup.
Some generalizable highlights include:
- `mpdmenu` + `mediaplayer-status-blocklet`: control of and interaction with `mpd` via the dmenu and i3blocks.
- `mpc-single-oneshot`: (Hackily) allow MPD to "pause after current song, only once"
- Some tweaked stock i3blocklets
- A screenshot script, a "kill window by mouseclick" script
- Tooling to "open Zoom window if running, else launch"

Note that in general I bias against including the least generalizable scripts here (and instead leave them private).

## License

MIT. Have fun. (If you have something useful or interesting or improvements to anything here, you're encouraged to share, but not obliged to.)
