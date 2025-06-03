# Hyper Focus

Hyper Focus is a command line tool that watches your computer activity and prevents you from doing distracting things.

In other words, if you are obsessive about personal productivity you can define what you want a productive day to look like and then use Hyper Focus to enforce it.

This is my first/only project in Swift, so feel to submit PRs to fix obvious things that should be better. [Here's what I learned while building this project.](http://mikebian.co/learning-swift-development-for-macos-by-building-a-website-blocker/)

## Why do this?

Time is the most valuable + scarce asset. Companies are incentivized to steal your time. Fight back.

- https://marco.org/2015/10/30/automatic-social-discipline
- http://mikebian.co/tag/digital-minimalism/

## Installation

```shell
brew install iloveitaly/tap/hyper-focus
```

You can then start the service as a daemon:

```shell
brew services start iloveitaly/tap/hyper-focus
```

Or run it directly:

```shell
hyper-focus

# you may want to run as root if your scripts are modifying system files, like /etc/hosts
sudo hyper-focus --configuration ~/.config/focus/config.json

# for debugging/tinkering, it's helpful to tee the logs
LOG_LEVEL=debug hyper-focus 2>&1 | tee hyper-focus.log
```

When running via a brew service, the logs are located in `$(brew --prefix)/var/log/`. You can tail the logs:

```shell
tail -f $(brew --prefix)/var/log/hyper_focus.log
```

Or, download a release build and run it manually.

### Accessibility Permissions

You'll need to grant accessibility permissions to the binary, which you can find via `brew which hyper-focus`. If scripts you have defined require root access, you'll also need to grant full disk access to the binary as well.

If permissions get into a weird state, close the app, remove the application from the system permissions list, and then re-add it to the system permissions list.

Also, remember that if you are building the binary locally and running it in your terminal, your _terminal application_ needs accessibility permissions.

### Running a Brew Service as Root

You may want to run Hyper Focus as root. For instance, [if you are modifying the `/etc/hosts` file on wake](https://github.com/iloveitaly/dotfiles/blob/7209676edb8417436bf9e56f1137a0b23bfadf76/.config/focus/wake.sh#L23),
you need to run Hyper Focus as root.

Here's how to do it:

```shell
sudo brew services start iloveitaly/tap/hyper-focus
```

<!--
Couple notes:

- Notification language when starting the process via brew is confusing

- Start the non-root service using `brew services start hyper-focus`
- Copy the existing plist `cat ~/Library/LaunchAgents/homebrew.mxcl.hyper-focus.plist | pbcopy`
- Stop the non-root service `brew services stop hyper-focus`
- Create the root service `sudo sh -c "pbpaste > /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist"`
- Start the process as root `sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist`

Here's a script:

```shell
brew services start hyper-focus
cat ~/Library/LaunchAgents/homebrew.mxcl.hyper-focus.plist | pbcopy
brew services stop hyper-focus

sudo sh -c "pbpaste > /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist"
sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist
```

To unload

```shell
sudo launchctl unload /Library/LaunchDaemons/homebrew.mxcl.hyper-focus.plist
```
-->

<!--
(TODO: still need to ensure that this works on restart, since it seems to do the same operation as `sudo brew services ...`)
(TODO: note about permissions, needing to remove logfiles, when switching between non-root and root)
TODO add something about the full disk permissions and accessibility permissions
(TODO I think we can remove this when https://github.com/Homebrew/homebrew-services/issues/554 is resolved)
-->

### Usage

```shell
hyper-focus --help

OVERVIEW: A daemon process which helps you focus on your work.

USAGE: hyper-focus [--version] [--configuration <configuration>]

OPTIONS:
  --version               Print out the version of the application.
  -c, --configuration <configuration>
                          Path to the configuration file
  -h, --help              Show help information.
```

### Configuration

If you are running as root, you'll want to specify the full path to any shell scripts.

## Features

- Fast, CLI-oriented tool
- [UI via Raycast](https://www.raycast.com/iloveitaly/hyper-focus)
- Configuration in a simple JSON file ([here's an example](https://github.com/iloveitaly/dotfiles/blob/master/.config/focus/config.json)). You can [add comments to this JSON](https://json5.org)!
- Very memory efficient, even over long periods of time
- No weird hangs or freezes (Focus app had this issue)
- Run scripts on sleep events (you don't need to rely on the abandoned sleepwatcher tool)
- Treat long periods of no activity as sleep, and execute relevant scripts
- Ability to run as root (if you need to modify system files, like `/etc/hosts`)

### Sleepwatching

- Run a script on first wake of the day (custom algorithm to determine first wake)
- Treats long periods of no activity as sleep
- Run a script on each wake
- Run script as privileged in order to edit key system files like `/etc/hosts`

#### What is 'first wake'?

'First wake' means the first time the computer is woken from sleep for the current day.

Having a first wake script allows you to tie into something like [clean browsers](https://github.com/iloveitaly/clean-browser) and [todoist scheduler](https://github.com/iloveitaly/todoist-scheduler) to setup your workspace and todo list for the day.

### Scheduling

- Allow multiple blocking profiles that can be enabled at different times
- Ability to pause any active blocking for a period of time
- Ability to enable blocking for a period of time if no blocking is enabled

### Blocking

- Block macOS applications without quitting them. This is implemented by hiding them when you switch to them. They stay
  open so you don't lose your work, but you can't see them.
- "Block" websites by redirecting Chrome and Safari browsers to a page of your choosing when a banned URL is encountered.
- Block hosts. Automatically adds `www.` variants to non-regex block hosts. If you block `youtube.com` it will also block `www.youtube.com`.
- Block specific URLs, ignoring anchors, and allowing a partial/subset match on query strings. For instance, you may
  want to allow google.com but block google news. You can setup a block url of `https://www.google.com/search?tbm=nws` to
  achieve this. The `tbm=nws` query string indicates the google news tab. As long as that query param exists, the page
  will be blocked.
- Regex support when matching against URLs. <!-- for instance -->
- Allow mode. Block everything by default, except a whitelist of URLs and/or apps.

#### Regex

Regex support is a bit weird: add trailing and leading `/` to the block entry to indicate it's a regex. Think `sed`-style.

Example:

```json
{
  "block_hosts": [
    // normal
    "google.com",
    // regex!
    "/.*google..*/"
  ]
}
```

## Non-Features

- Executing scripts for other system states, like other sleep watcher tools. For instance, screen dim/wake or lid close/open.
- Kill/quit applications if they are open. This can be done via a wake script or schedule initialization script (`osascript -e 'quit app "App Name"'`).
- Notification when a new schedule is enabled. You could do this via a schedule initialization script.
- Native macOS application.

## HTTP API

Instead of UI, I've opted to a simple HTTP API that can be used to power a [Raycast](https://www.raycast.com/iloveitaly/hyper-focus)-based UI.

- `/reload` reload the configuration file without restarting the process
- `/pause` pause the currently running schedule
- `/resume` resume the currently running schedule
- `/override` force a blocking profile to run for a period of time
- `/ping` is this thing on?
- `/configurations` array of names of all blocking profiles. To change the order of the results, change the order of the inputs in your config file.

You can hit the API locally for testing using: `http localhost:9029/status`

## Development

- Run the binary manually `swift run`
- Copy local config `cp ./config.json ~/.config/focus/config.json`
- Generate a new release `git tag v0.1.3 && git push --tags origin HEAD`

## Tests

This is a fun personal tool. Tests are boring, so I didn't write many of them.

Plus, writing tests in Swift seems to be a massive pain (no dynamic mocks!).

## Inspiration / Related

- https://github.com/qiuosier/SleepTight
- https://heyfocus.com
- https://github.com/ActivityWatch/aw-watcher-window
- https://ebb.cool
