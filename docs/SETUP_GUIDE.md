# DemonBlade2 — Local Setup Guide

This guide is written for someone who has never used Git or a terminal before.
Follow every step in order and you will have a working local copy of the game.

---

## What You Are Installing

| Tool | What It Does |
|---|---|
| **Git** | Downloads the project from GitHub and tracks changes |
| **VS Code** | The text editor used to view and edit code |
| **Roblox Studio** | The game engine used to test and play the game |
| **Rojo** | Connects VS Code files to Roblox Studio live |
| **Rojo Studio Plugin** | The Studio side of that connection |

---

## Step 1 — Install Git

1. Go to **https://git-scm.com/download/win**
2. Click the top download link (it detects Windows automatically)
3. Run the installer — click **Next** on every screen, do not change any options
4. When it finishes, close the installer

**Check it worked:** Press `Win + R`, type `cmd`, press Enter. In the black window type:
```
git --version
```
You should see something like `git version 2.x.x`. If you do, Git is installed.

---

## Step 2 — Install VS Code

1. Go to **https://code.visualstudio.com**
2. Click the big blue **Download for Windows** button
3. Run the installer — on the options screen, check **"Add to PATH"** and **"Open with Code"** if they appear
4. Finish the install and open VS Code at least once before continuing

---

## Step 3 — Install Roblox Studio

If you already have Roblox Studio installed, skip this step.

1. Go to **https://www.roblox.com/create**
2. Click **Start Creating** — it will prompt you to download and install Studio
3. Open Studio and log in with your Roblox account

---

## Step 4 — Install Rojo

Rojo is a small program that runs in the background and syncs files into Studio.

1. Go to **https://github.com/rojo-rbx/rojo/releases/tag/v7.6.1**
2. Under **Assets**, download the file named something like `rojo-7.6.1-windows-x86_64.zip`
3. Open the zip file and copy `rojo.exe` somewhere easy to find, for example: `C:\rojo\rojo.exe`
4. Add Rojo to your PATH so you can run it from anywhere:
   - Press `Win + S`, search for **"Edit the system environment variables"**, open it
   - Click **Environment Variables**
   - Under **User variables**, click **Path**, then **Edit**
   - Click **New** and type the folder path where you put `rojo.exe` (e.g. `C:\rojo`)
   - Click **OK** on all windows

**Check it worked:** Open a new `cmd` window and type:
```
rojo --version
```
You should see `rojo 7.6.1`.

---

## Step 5 — Install the Rojo Studio Plugin

This is the Roblox Studio side of the Rojo connection.

1. Open Roblox Studio
2. Go to the **Toolbox** (View → Toolbox)
3. Search for **"Rojo"** in the Marketplace tab
4. Install the official Rojo plugin by **rojo-rbx**

---

## Step 6 — Clone the Repository

"Cloning" means downloading a full copy of the project to your computer.

1. Open VS Code
2. Press `Ctrl + ~` to open the built-in terminal (a panel appears at the bottom)
3. Decide where you want the project to live on your computer, for example `C:\Projects`
   - In the terminal, navigate there by typing: `cd C:\Projects`
   - If that folder does not exist, create it first: `mkdir C:\Projects`
4. Run this command exactly as written:
```
git clone https://github.com/brycegreene20/demonblade2.git
```
5. Wait for it to finish — you will see files downloading
6. Then type:
```
cd demonblade2
```

You are now inside the project folder.

---

## Step 7 — Open the Project in VS Code

1. In the same terminal, type:
```
code .
```
(that is `code` then a space then a dot)

VS Code will reopen and show all the project files in the left sidebar.

---

## Step 8 — Connect to Roblox Studio With Rojo

Do this every time you want to work on the game.

1. In the VS Code terminal (press `Ctrl + ~` if it is not open), make sure you are in the `demonblade2` folder. The terminal prompt should end with `demonblade2>`. If it does not, type:
```
cd C:\Projects\demonblade2
```
2. Start Rojo by running:
```
rojo serve default.project.json
```
You will see a message like `Listening on port 34872`. Leave this terminal window open — **do not close it**.

3. Open Roblox Studio with your local testing place
4. In Studio, click the **Rojo plugin button** in the toolbar (top of Studio)
5. Click **Connect** — it will find the local Rojo server automatically
6. Studio will show you a list of changes it wants to make. Review them and click **Apply** to sync the project into Studio

---

## Step 9 — Verify Everything Is Working

After connecting, you should see the game's scripts and services appear in the **Explorer** panel in Roblox Studio. If you edit a `.luau` file in VS Code and save it (`Ctrl + S`), the change should appear in Studio within a second or two.

---

## Daily Workflow (After Setup)

Every time you sit down to work:

1. Open VS Code
2. Open the terminal (`Ctrl + ~`)
3. Run `rojo serve default.project.json`
4. Open Roblox Studio and connect the Rojo plugin
5. Make changes in VS Code → they sync into Studio automatically
6. Test in Studio

---

## Common Problems

**"git is not recognized"**
Git is not on your PATH. Restart your computer after installing Git and try again.

**"rojo is not recognized"**
Rojo is not on your PATH. Re-do Step 4, make sure you added the correct folder, and open a **new** terminal window after saving.

**Rojo shows a long list of deletions when connecting**
Do not accept if you see things like `Players/YourName` or `NetworkClient/ClientReplicator` in the delete list — those are normal Studio runtime objects, not project files. Only accept changes that relate to actual game scripts and assets.

If Rojo proposes deleting snowy terrain, village props, trees, or other `Workspace` map objects, stop. Open the correct snowy place and confirm `default.project.json` keeps `Workspace.$ignoreUnknownInstances` enabled with no Workspace `$path`.

**Studio does not show the Rojo plugin button**
The plugin was not installed. Re-do Step 5 and make sure you click **Install**, not just **Try**.

**VS Code terminal opens in the wrong folder**
Type `cd C:\Projects\demonblade2` (or wherever you cloned it) before running any commands.
