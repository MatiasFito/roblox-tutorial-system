# Roblox Studio + Rojo Hybrid Workflow Guidelines

## 1. Active Studio Initialization (CRITICAL)
Before executing any tool calls that interact with the Roblox DataModel (such as reading the workspace, searching, or inserting assets), you must establish the active target session.
- Always run `list_roblox_studios` first to detect connected sessions.
- Immediately follow up by calling `set_active_studio` with the correct studio target ID to set it as active.
- Do not attempt to run tools like `get_services` or inspect instances until the active studio target is successfully set.

## 2. Strict Asset & Script Boundaries
We use a strict "Code Only" local repository workflow.
- **VS Code is for Scripts Only**: All local files must be `.luau` scripts, folder structures, or the `default.project.json`.
- **No Asset Serialization**: Never create `.model.json`, `.rbxmx`, or other asset serialization files in our local workspace.
- **Rojo is for Code Structure Only**: Only update `default.project.json` to account for script directories (e.g., adding a new folder for scripts or modules). Do not add entries for parts, models, sounds, or other physical assets.

## 3. Coding Conventions & Luau Type Assertions (Crucial)
When writing scripts that reference physical assets, models, or sounds inside the Roblox Studio place, you must use proper access patterns and **Luau type assertion (`::`)** to prevent LSP/linting warnings.

- **For Server-Stored Assets (ServerStorage)**: Use `FindFirstChild` and cast the result to its specific Roblox Class using `::`.
  Example:
  ```lua
  local ServerStorage = game:GetService("ServerStorage")
  local asset = ServerStorage:FindFirstChild("ChestModel") :: Model
  ```
- **For Shared/Client-Stored Assets (ReplicatedStorage)**: Use `WaitForChild` and cast the result to its specific Roblox Class using `::`.
  Example:
  ```lua
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local sound = ReplicatedStorage:WaitForChild("ExplosionSound") :: Sound
  ```
- **General References**: Always cast retrieved instances to their exact expected type (e.g., `:: Part`, `:: ScreenGui`, `:: RemoteEvent`, `:: Folder`) so the VS Code Luau LSP understands the correct properties are available. Never attempt to define these assets in `default.project.json` just to satisfy type checking.

## 4. After Task Succesfully Completed
- **Don't Print The Roblox Console Output In The Chat Window**: I can read the roblox console directly in studio, so don't add context to the task by printing the Roblox console output.
- **Never Run/Play The Game Inside Roblox Studio**: I can test the game mayself.

## 5. Execution Optimization
If your Roblox Studio MCP has a tool to run/execute a Luau script directly in Studio, write a clean generation script to build these 7 tools and execute it. Otherwise, build them step-by-step using your standard instance creation tools.