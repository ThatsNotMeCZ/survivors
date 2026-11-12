export type ToolDef = {
  name: string;
  description: string;
  timeoutMs?: number;
};

const SLOW_MS = 60_000;

/** Plugin JSON-RPC methods this bridge exposes as MCP tools. */
export const ALLOWLIST: ToolDef[] = [
  { name: "get_project_info", description: "Godot project name, version, renderer, viewport, autoloads." },
  { name: "get_filesystem_tree", description: "Project directory tree. Optional path, filter (*.gd / *.tscn), max_depth." },
  { name: "get_project_settings", description: "Read Project Settings." },
  { name: "set_project_setting", description: "Write a Project Setting (viewport, stretch, main scene, etc.)." },
  { name: "add_autoload", description: "Register an autoload singleton." },
  { name: "get_input_actions", description: "List InputMap actions." },
  { name: "set_input_action", description: "Define or update an InputMap action and its events." },
  { name: "simulate_action", description: "Press a named InputMap action in the running game." },
  { name: "play_scene", description: "Play current, main, or a scene path.", timeoutMs: SLOW_MS },
  { name: "stop_scene", description: "Stop the running game.", timeoutMs: SLOW_MS },
  { name: "get_game_screenshot", description: "Screenshot of the running game.", timeoutMs: SLOW_MS },
  { name: "get_editor_screenshot", description: "Screenshot of the editor.", timeoutMs: SLOW_MS },
  { name: "capture_frames", description: "Capture several game frames.", timeoutMs: SLOW_MS },
  { name: "get_game_scene_tree", description: "Live runtime scene tree." },
  { name: "get_game_node_properties", description: "Runtime properties of a node." },
  { name: "validate_script", description: "Parse-check a GDScript file without running it." },
  { name: "get_editor_errors", description: "Editor Output + compile errors." },
  { name: "get_output_log", description: "Editor Output panel text." },
  { name: "create_scene", description: "Create a packed scene via the editor (UndoRedo). Params: path, root_type, root_name, force." },
  { name: "open_scene", description: "Open a .tscn in the editor." },
  { name: "save_scene", description: "Save the current edited scene." },
  { name: "get_scene_tree", description: "Edited scene node tree." },
  { name: "add_scene_instance", description: "Instance a PackedScene under a parent." },
  { name: "add_node", description: "Add a child node. Params: type, parent_path, name, properties." },
  { name: "delete_node", description: "Delete a node in the edited scene." },
  { name: "duplicate_node", description: "Duplicate a node." },
  { name: "move_node", description: "Reparent or reorder a node." },
  { name: "rename_node", description: "Rename a node." },
  { name: "update_property", description: "Set an inspector property (Vector2, Color, etc. as strings)." },
  { name: "get_node_properties", description: "Read inspector properties of a node." },
  { name: "add_resource", description: "Assign a Resource (shape, texture) on a node." },
  { name: "set_anchor_preset", description: "Control layout preset (full_rect, center, …)." },
  { name: "connect_signal", description: "Connect a signal to a callable." },
  { name: "attach_script", description: "Attach a .gd script to a node." },
  { name: "create_script", description: "Create res://src/** or res://scenes/** GDScript. Prefer Cursor file tools for the body." },
  { name: "edit_script", description: "Edit res://src/** or res://scenes/** GDScript." },
  { name: "list_scripts", description: "List project scripts." },
  { name: "read_script", description: "Read a script file from the editor." },
];

export const ALLOWED_NAMES = new Set(ALLOWLIST.map((t) => t.name));

const SCRIPT_METHODS = new Set(["create_script", "edit_script"]);

export function assertScriptPath(method: string, params: Record<string, unknown>): void {
  if (!SCRIPT_METHODS.has(method)) {
    return;
  }
  const path = typeof params.path === "string" ? params.path : "";
  if (path.startsWith("res://src/") || path.startsWith("res://scenes/")) {
    return;
  }
  throw new Error(
    `${method} only allows path under res://src/ or res://scenes/ (got ${path || "(missing path)"})`,
  );
}

export function timeoutFor(method: string): number {
  return ALLOWLIST.find((t) => t.name === method)?.timeoutMs ?? 30_000;
}
