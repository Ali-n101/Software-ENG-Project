# MediQueue: Self-Service Clinic Kiosk

Software Engineering course project: a hospital reception kiosk where patients identify themselves with their National ID, choose a clinic, pick an available time and get a booking reference.

## Quick start for team members

### 1. Get the project
In VS Code: `Ctrl+Shift+P` → **Git: Clone** → paste:
```
https://github.com/Ali-n101/Software-ENG-Project
```
Open the cloned folder, and choose **Yes, I trust the authors** if asked.
VS Code will offer to install **Extension Pack for Java**. Click **Install**.

### 2. Run the setup (once)
Double-click **`setup.bat`** in the project folder (or run `.\setup.bat` in the VS Code terminal). It:

| Step | What it does |
|---|---|
| Java | Checks for JDK 23+, installs Temurin JDK 25 if missing |
| VS Code | Installs Extension Pack for Java |
| MySQL | Checks for MySQL, installs it if missing, then creates the `mediqueue` database with test data |
| JavaFX | Downloads the JavaFX libraries into `MediQueue/lib/javafx` |

If it installs Java or MySQL, finish that installer (for MySQL, choose a **root password** in MySQL Configurator), then **run `setup.bat` again**.

> Creating the database deletes any existing `mediqueue` database. Answer **N** if you want to keep your bookings.

### 3. Run the kiosk
In the VS Code terminal:
```
.\MediQueue\run-gui.bat
```
Or press `Ctrl+Shift+D`, choose **MediQueue Kiosk (GUI)**, and press **F5**.

Log in with MySQL user `root` and your password, then try National ID **`1000000001`**.
Other test IDs: `1000000002`, `1000000003`, `1000000004`, `2000000005`.

### Getting updates
Click the sync icon 🔄 next to `main` in the bottom-left of VS Code (or `Ctrl+Shift+P` → **Git: Pull**), then run the kiosk again.

## Project layout

| Path | Contents |
|---|---|
| `MediQueue/src/UI` | JavaFX screens (setup, identify, clinic, time, confirmation) |
| `MediQueue/src/Services` | Booking rules and validation |
| `MediQueue/src/Dao` | Database queries |
| `MediQueue/src/Main.java` | Original console version (`MediQueue/run.bat`) |
| `database/` | `schema.sql`, `seed.sql` and database notes |
| `milestones/` | Course deliverables |

## Troubleshooting

| Message | Fix |
|---|---|
| `No suitable driver found` | Run with `run-gui.bat` or F5, not the ▶ button at the top right of the editor |
| `Access denied for user 'root'` | Wrong MySQL password |
| `Unknown database 'mediqueue'` | Run `setup.bat` again and answer **Y** to create the database |
| `'javac' is not recognized` | Java is missing or not on PATH: run `setup.bat`, then restart VS Code |
| Red underlines in `UI` files | Run `run-gui.bat` once, then `Ctrl+Shift+P` → **Java: Clean Java Language Server Workspace** |
