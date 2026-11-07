#!/usr/bin/env -S godot --headless --script
extends SceneTree

# Debug mode flag
var debug_mode = false
var operation_failed = false

func _init():
    var args = OS.get_cmdline_args()
    
    # Check for debug flag
    debug_mode = "--debug-godot" in args
    
    # Find the script argument and determine the positions of operation and params
    var script_index = args.find("--script")
    if script_index == -1:
        log_error("Could not find --script argument")
        operation_failed = true
        quit(1)
        return
    
    # The operation should be 2 positions after the script path (script_index + 1 is the script path itself)
    var operation_index = script_index + 2
    # The params should be 3 positions after the script path
    var params_index = script_index + 3
    
    if args.size() <= params_index:
        log_error("Usage: godot --headless --script godot_operations.gd <operation> <json_params>")
        log_error("Not enough command-line arguments provided.")
        operation_failed = true
        quit(1)
        return
    
    # Log all arguments for debugging
    log_debug("All arguments: " + str(args))
    log_debug("Script index: " + str(script_index))
    log_debug("Operation index: " + str(operation_index))
    log_debug("Params index: " + str(params_index))
    
    var operation = args[operation_index]
    var params_json = args[params_index]
    
    log_info("Operation: " + operation)
    log_debug("Params JSON: " + params_json)
    
    # Parse JSON using Godot 4.x API
    var json = JSON.new()
    var error = json.parse(params_json)
    var params = null
    
    if error == OK:
        params = json.get_data()
    else:
        log_error("Failed to parse JSON parameters: " + params_json)
        log_error("JSON Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
        operation_failed = true
        quit(1)
        return
    
    if not params:
        log_error("Failed to parse JSON parameters: " + params_json)
        operation_failed = true
        quit(1)
        return
    
    log_info("Executing operation: " + operation)
    
    match operation:
        "create_scene":
            create_scene(params)
        "add_node":
            add_node(params)
        "load_sprite":
            load_sprite(params)
        "export_mesh_library":
            export_mesh_library(params)
        "save_scene":
            save_scene(params)
        "get_uid":
            get_uid(params)
        "resave_resources":
            resave_resources(params)
        _:
            log_error("Unknown operation: " + operation)
            operation_failed = true
            quit(1)
            return
    
    quit(1 if operation_failed else 0)

# Logging functions
func log_debug(message):
    if debug_mode:
        print("[DEBUG] " + message)

func log_info(message):
    print("[INFO] " + message)

func log_error(message):
    operation_failed = true
    printerr("[ERROR] " + message)

# Get a script by registered class name.
# Only looks up names via the project's global class registry. Raw paths
# (e.g. "res://evil.gd") are intentionally not accepted here to prevent
# arbitrary script instantiation from agent-supplied input.
func get_script_by_name(name_of_class):
    if debug_mode:
        print("Attempting to get script for class: " + name_of_class)

    # Search for it in the global class registry if it's a class name
    var global_classes = ProjectSettings.get_global_class_list()
    if debug_mode:
        print("Searching through " + str(global_classes.size()) + " global classes")
    
    for global_class in global_classes:
        var found_name_of_class = global_class["class"]
        var found_path = global_class["path"]
        
        if found_name_of_class == name_of_class:
            if debug_mode:
                print("Found matching class in registry: " + found_name_of_class + " at path: " + found_path)
            var script = load(found_path) as Script
            if script:
                if debug_mode:
                    print("Successfully loaded script from registry")
                return script
            else:
                log_error("Failed to load script from registry path: " + found_path)
                break
    
    log_error("Could not find script for class: " + name_of_class)
    return null

# Instantiate a class by name
func instantiate_class(name_of_class):
    if name_of_class.is_empty():
        log_error("Cannot instantiate class: name is empty")
        return null
    
    var result = null
    if debug_mode:
        print("Attempting to instantiate class: " + name_of_class)
    
    # Check if it's a built-in class
    if ClassDB.class_exists(name_of_class):
        if debug_mode:
            print("Class exists in ClassDB, using ClassDB.instantiate()")
        if ClassDB.can_instantiate(name_of_class):
            result = ClassDB.instantiate(name_of_class)
            if result == null:
                log_error("ClassDB.instantiate() returned null for class: " + name_of_class)
        else:
            log_error("Class exists but cannot be instantiated: " + name_of_class)
            log_error("This may be an abstract class or interface that cannot be directly instantiated")
    else:
        # Try to get the script
        if debug_mode:
            print("Class not found in ClassDB, trying to get script")
        var script = get_script_by_name(name_of_class)
        if script is GDScript:
            if debug_mode:
                print("Found GDScript, creating instance")
            result = script.new()
        else:
            log_error("Failed to get script for class: " + name_of_class)
            return null
    
    if result == null:
        log_error("Failed to instantiate class: " + name_of_class)
    elif debug_mode:
        print("Successfully instantiated class: " + name_of_class + " of type: " + result.get_class())
    
    return result

# Runtime ResourceLoader only consults the UID cache. MCP-created files need
# their current on-disk metadata read before the next editor import populates it.
func read_resource_uid_on_disk(path):
    path = ProjectSettings.localize_path(path)
    if not FileAccess.file_exists(path):
        return -1
    var extension = path.get_extension().to_lower()
    if extension in ["tscn", "tres"]:
        var file = FileAccess.open(path, FileAccess.READ)
        if not file:
            log_error("Cannot read resource identity: " + path)
            return -1
        var prefix = file.get_buffer(mini(file.get_length(), 8192)).get_string_from_utf8()
        file.close()
        var first_line = prefix.get_slice("\n", 0)
        var pattern = RegEx.new()
        pattern.compile(r'(?:^|\s)uid="(uid://[^"\r\n]+)"')
        var matches = pattern.search_all(first_line)
        if matches.size() > 1:
            log_error("Ambiguous resource identity: " + path)
            return -1
        if matches.size() == 1:
            var id = ResourceUID.text_to_id(matches[0].get_string(1))
            if id == -1:
                log_error("Invalid resource identity: " + path)
            return id
        return -1
    if extension in ["res", "scn"]:
        var file = FileAccess.open(path, FileAccess.READ)
        if not file or file.get_length() < 32:
            log_error("Cannot read binary resource identity: " + path)
            return -1
        var magic = file.get_buffer(4).get_string_from_ascii()
        if magic != "RSRC":
            log_error("Compressed binary UID editing is unsupported; resource preserved: " + path)
            return -1
        var big_endian = file.get_32()
        file.get_32()
        file.big_endian = big_endian != 0
        file.get_32()
        file.get_32()
        file.get_32()
        var type_length = file.get_32()
        if type_length > 1024 or file.get_position() + type_length + 20 > file.get_length():
            log_error("Invalid binary resource header: " + path)
            return -1
        file.seek(file.get_position() + type_length)
        file.get_64()
        var flags = file.get_32()
        var id = file.get_64()
        file.close()
        return id if flags & 2 else -1
    var sidecar = path + ".uid"
    if FileAccess.file_exists(sidecar):
        var directory = DirAccess.open(sidecar.get_base_dir())
        var file = FileAccess.open(sidecar, FileAccess.READ) if directory and not directory.is_link(sidecar) else null
        if not file or file.get_length() > 1024:
            log_error("Unreadable or linked UID sidecar: " + path)
            return -1
        var id = ResourceUID.text_to_id(file.get_as_text().strip_edges())
        file.close()
        if id == -1:
            log_error("Invalid UID sidecar preserved: " + path)
        return id
    var import_path = path + ".import"
    if FileAccess.file_exists(import_path):
        var directory = DirAccess.open(import_path.get_base_dir())
        var file = FileAccess.open(import_path, FileAccess.READ) if directory and not directory.is_link(import_path) else null
        if not file or file.get_length() > 65536:
            log_error("Unreadable or linked import metadata: " + path)
            return -1
        var config = ConfigFile.new()
        var result = config.parse(file.get_as_text())
        file.close()
        if result != OK:
            log_error("Invalid import metadata: " + path)
            return -1
        return ResourceUID.text_to_id(str(config.get_value("remap", "uid", "")))
    return ResourceLoader.get_resource_uid(path) if not extension in ["gd", "gdshader", "gdshaderinc", "shader"] else -1

# Headless ResourceSaver has no EditorFileSystem UID callback. Keep the target
# resource UID explicitly; normal scene edits must not silently strip identity.
func save_resource_preserving_uid(resource, path):
    var extension = path.get_extension().to_lower()
    var embedded_uid = extension in ["tscn", "tres", "scn", "res"]
    var uid = read_resource_uid_on_disk(path)
    if operation_failed:
        return ERR_INVALID_DATA
    var error = ResourceSaver.save(resource, path)
    if error != OK:
        return error
    if embedded_uid:
        if uid == -1:
            uid = ResourceUID.create_id()
        if uid == -1:
            log_error("Could not allocate a resource UID.")
            return ERR_CANT_CREATE
        error = ResourceSaver.set_uid(path, uid)
        if error != OK:
            log_error("Could not persist the resource UID: " + path)
            return error
        if ResourceUID.has_id(uid):
            ResourceUID.set_id(uid, ProjectSettings.localize_path(path))
        else:
            ResourceUID.add_id(uid, ProjectSettings.localize_path(path))
        if read_resource_uid_on_disk(path) != uid:
            log_error("Saved resource UID did not match its original identity.")
            return ERR_FILE_CORRUPT
    if extension in ["tscn", "tres"]:
        return refresh_text_external_uids(path)
    return OK

func uid_dependency_is_project_local(path):
    if not path.begins_with("res://") or path.contains("\\"):
        return false
    var relative_path = path.substr(6)
    var parent_path = "res://"
    for part in relative_path.split("/", false):
        if part in [".", ".."] or part.contains(":"):
            return false
        var directory = DirAccess.open(parent_path)
        var next_path = parent_path.path_join(part)
        if not directory or directory.is_link(next_path):
            return false
        parent_path = next_path
    return FileAccess.file_exists(path)

# Only editor-generated ext_resource header lines are touched; node properties,
# scripts and every other serialized line are left byte-for-byte unchanged.
func refresh_text_external_uids(path):
    var file = FileAccess.open(path, FileAccess.READ)
    if not file or file.get_length() > 4194304:
        log_error("Text resource exceeds the UID refresh limit.")
        return ERR_INVALID_DATA
    var text = file.get_as_text()
    file.close()
    var path_pattern = RegEx.new()
    var uid_pattern = RegEx.new()
    if path_pattern.compile(r'(?:^|\s)path="((?:[^"\\]|\\.)*)"') != OK or uid_pattern.compile(r'(?:^|\s)uid="([^"\r\n]*)"') != OK:
        log_error("Could not prepare resource-header UID validation.")
        return ERR_INVALID_DATA
    var lines = text.split("\n")
    var changed = false
    for index in range(lines.size()):
        var line = lines[index]
        if not line.begins_with("[ext_resource "):
            continue
        if not line.trim_suffix("\r").ends_with("]"):
            log_error("Malformed external-resource header.")
            return ERR_FILE_CORRUPT
        var paths = path_pattern.search_all(line)
        var uids = uid_pattern.search_all(line)
        if paths.size() != 1 or uids.size() > 1:
            log_error("Ambiguous external-resource header.")
            return ERR_FILE_CORRUPT
        var dependency = paths[0].get_string(1).c_unescape()
        if not uid_dependency_is_project_local(dependency):
            log_error("External UID references must identify existing, unlinked project resources.")
            return ERR_INVALID_DATA
        var uid = read_resource_uid_on_disk(dependency)
        if operation_failed:
            return ERR_INVALID_DATA
        if uid == -1:
            # Not every resource type supports UIDs; preserve its existing header.
            continue
        var uid_text = ResourceUID.id_to_text(uid)
        if not uids.is_empty():
            var match_uid = uids[0]
            line = line.substr(0, match_uid.get_start(1)) + uid_text + line.substr(match_uid.get_end(1))
        else:
            var insertion = paths[0].get_start(0)
            line = line.substr(0, insertion) + ' uid="' + uid_text + '"' + line.substr(insertion)
        changed = changed or line != lines[index]
        lines[index] = line
    if changed:
        var updated = "\n".join(lines)
        if updated.to_utf8_buffer().size() > 4194304:
            log_error("Updated resource exceeds the UID refresh limit.")
            return ERR_INVALID_DATA
        file = FileAccess.open(path, FileAccess.WRITE)
        if not file:
            log_error("Cannot write external-resource UID headers.")
            return ERR_CANT_CREATE
        file.store_string(updated)
        var error = file.get_error()
        file.close()
        if error != OK:
            log_error("Could not persist external-resource UID headers.")
            return error
    return OK

# Create a new scene with a specified root node type
func create_scene(params):
    print("Creating scene: " + params.scene_path)
    
    # Get project paths and log them for debugging
    var project_res_path = "res://"
    var project_user_path = "user://"
    var global_res_path = ProjectSettings.globalize_path(project_res_path)
    var global_user_path = ProjectSettings.globalize_path(project_user_path)
    
    if debug_mode:
        print("Project paths:")
        print("- res:// path: " + project_res_path)
        print("- user:// path: " + project_user_path)
        print("- Globalized res:// path: " + global_res_path)
        print("- Globalized user:// path: " + global_user_path)
        
        # Print some common environment variables for debugging
        print("Environment variables:")
        var env_vars = ["PATH", "HOME", "USER", "TEMP", "GODOT_PATH"]
        for env_var in env_vars:
            if OS.has_environment(env_var):
                print("  " + env_var + " = " + OS.get_environment(env_var))
    
    # Normalize the scene path
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    if debug_mode:
        print("Scene path (with res://): " + full_scene_path)
    
    # Convert resource path to an absolute path
    var absolute_scene_path = ProjectSettings.globalize_path(full_scene_path)
    if debug_mode:
        print("Absolute scene path: " + absolute_scene_path)
    
    # Get the scene directory paths
    var scene_dir_res = full_scene_path.get_base_dir()
    var scene_dir_abs = absolute_scene_path.get_base_dir()
    if debug_mode:
        print("Scene directory (resource path): " + scene_dir_res)
        print("Scene directory (absolute path): " + scene_dir_abs)
    
    # Only do extensive testing in debug mode
    if debug_mode:
        # Try to create a simple test file in the project root to verify write access
        var initial_test_file_path = "res://godot_mcp_test_write.tmp"
        var initial_test_file = FileAccess.open(initial_test_file_path, FileAccess.WRITE)
        if initial_test_file:
            initial_test_file.store_string("Test write access")
            initial_test_file.close()
            print("Successfully wrote test file to project root: " + initial_test_file_path)
            
            # Verify the test file exists
            var initial_test_file_exists = FileAccess.file_exists(initial_test_file_path)
            print("Test file exists check: " + str(initial_test_file_exists))
            
            # Clean up the test file
            if initial_test_file_exists:
                var remove_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(initial_test_file_path))
                print("Test file removal result: " + str(remove_error))
        else:
            var write_error = FileAccess.get_open_error()
            log_error("Failed to write test file to project root: " + str(write_error))
            log_error("This indicates a serious permission issue with the project directory")
    
    # Use traditional if-else statement for better compatibility
    var root_node_type = "Node2D"  # Default value
    if params.has("root_node_type"):
        root_node_type = params.root_node_type
    if debug_mode:
        print("Root node type: " + root_node_type)
    
    # Create the root node
    var scene_root = instantiate_class(root_node_type)
    if not scene_root:
        log_error("Failed to instantiate node of type: " + root_node_type)
        log_error("Make sure the class exists and can be instantiated")
        log_error("Check if the class is registered in ClassDB or available as a script")
        operation_failed = true
        quit(1)
        return
    
    scene_root.name = "root"
    if debug_mode:
        print("Root node created with name: " + scene_root.name)
    
    # Set the owner of the root node to itself (important for scene saving)
    scene_root.owner = scene_root
    
    # Pack the scene
    var packed_scene = PackedScene.new()
    var result = packed_scene.pack(scene_root)
    if debug_mode:
        print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")
    
    if result == OK:
        # Only do extensive testing in debug mode
        if debug_mode:
            # First, let's verify we can write to the project directory
            print("Testing write access to project directory...")
            var test_write_path = "res://test_write_access.tmp"
            var test_write_abs = ProjectSettings.globalize_path(test_write_path)
            var test_file = FileAccess.open(test_write_path, FileAccess.WRITE)
            
            if test_file:
                test_file.store_string("Write test")
                test_file.close()
                print("Successfully wrote test file to project directory")
                
                # Clean up test file
                if FileAccess.file_exists(test_write_path):
                    var remove_error = DirAccess.remove_absolute(test_write_abs)
                    print("Test file removal result: " + str(remove_error))
            else:
                var write_error = FileAccess.get_open_error()
                log_error("Failed to write test file to project directory: " + str(write_error))
                log_error("This may indicate permission issues with the project directory")
                # Continue anyway, as the scene directory might still be writable
        
        # Ensure the scene directory exists using DirAccess
        if debug_mode:
            print("Ensuring scene directory exists...")
        
        # Get the scene directory relative to res://
        var scene_dir_relative = scene_dir_res.substr(6)  # Remove "res://" prefix
        if debug_mode:
            print("Scene directory (relative to res://): " + scene_dir_relative)
        
        # Create the directory if needed
        if not scene_dir_relative.is_empty():
            # First check if it exists
            var dir_exists = DirAccess.dir_exists_absolute(scene_dir_abs)
            if debug_mode:
                print("Directory exists check (absolute): " + str(dir_exists))
            
            if not dir_exists:
                if debug_mode:
                    print("Directory doesn't exist, creating: " + scene_dir_relative)
                
                # Try to create the directory using DirAccess
                var dir = DirAccess.open("res://")
                if dir == null:
                    var open_error = DirAccess.get_open_error()
                    log_error("Failed to open res:// directory: " + str(open_error))
                    
                    # Try alternative approach with absolute path
                    if debug_mode:
                        print("Trying alternative directory creation approach...")
                    var make_dir_error = DirAccess.make_dir_recursive_absolute(scene_dir_abs)
                    if debug_mode:
                        print("Make directory result (absolute): " + str(make_dir_error))
                    
                    if make_dir_error != OK:
                        log_error("Failed to create directory using absolute path")
                        log_error("Error code: " + str(make_dir_error))
                        operation_failed = true
                        quit(1)
                        return
                else:
                    # Create the directory using the DirAccess instance
                    if debug_mode:
                        print("Creating directory using DirAccess: " + scene_dir_relative)
                    var make_dir_error = dir.make_dir_recursive(scene_dir_relative)
                    if debug_mode:
                        print("Make directory result: " + str(make_dir_error))
                    
                    if make_dir_error != OK:
                        log_error("Failed to create directory: " + scene_dir_relative)
                        log_error("Error code: " + str(make_dir_error))
                        operation_failed = true
                        quit(1)
                        return
                
                # Verify the directory was created
                dir_exists = DirAccess.dir_exists_absolute(scene_dir_abs)
                if debug_mode:
                    print("Directory exists check after creation: " + str(dir_exists))
                
                if not dir_exists:
                    log_error("Directory reported as created but does not exist: " + scene_dir_abs)
                    log_error("This may indicate a problem with path resolution or permissions")
                    operation_failed = true
                    quit(1)
                    return
            elif debug_mode:
                print("Directory already exists: " + scene_dir_abs)
        
        # Save the scene
        if debug_mode:
            print("Saving scene to: " + full_scene_path)
        var save_error = save_resource_preserving_uid(packed_scene, full_scene_path)
        if debug_mode:
            print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")
        
        if save_error == OK:
            # Only do extensive testing in debug mode
            if debug_mode:
                # Wait a moment to ensure file system has time to complete the write
                print("Waiting for file system to complete write operation...")
                OS.delay_msec(500)  # 500ms delay
                
                # Verify the file was actually created using multiple methods
                var file_check_abs = FileAccess.file_exists(absolute_scene_path)
                print("File exists check (absolute path): " + str(file_check_abs))
                
                var file_check_res = FileAccess.file_exists(full_scene_path)
                print("File exists check (resource path): " + str(file_check_res))
                
                var res_exists = ResourceLoader.exists(full_scene_path)
                print("Resource exists check: " + str(res_exists))
                
                # If file doesn't exist by absolute path, try to create a test file in the same directory
                if not file_check_abs and not file_check_res:
                    log_error("Scene file not found after save. Trying to diagnose the issue...")
                    
                    # Try to write a test file to the same directory
                    var test_scene_file_path = scene_dir_res + "/test_scene_file.tmp"
                    var test_scene_file = FileAccess.open(test_scene_file_path, FileAccess.WRITE)
                    
                    if test_scene_file:
                        test_scene_file.store_string("Test scene directory write")
                        test_scene_file.close()
                        print("Successfully wrote test file to scene directory: " + test_scene_file_path)
                        
                        # Check if the test file exists
                        var test_file_exists = FileAccess.file_exists(test_scene_file_path)
                        print("Test file exists: " + str(test_file_exists))
                        
                        if test_file_exists:
                            # Directory is writable, so the issue is with scene saving
                            log_error("Directory is writable but scene file wasn't created.")
                            log_error("This suggests an issue with save_resource_preserving_uid() or the packed scene.")
                            
                            # Try saving with a different approach
                            print("Trying alternative save approach...")
                            var alt_save_error = save_resource_preserving_uid(packed_scene, test_scene_file_path + ".tscn")
                            print("Alternative save result: " + str(alt_save_error))
                            
                            # Clean up test files
                            DirAccess.remove_absolute(ProjectSettings.globalize_path(test_scene_file_path))
                            if alt_save_error == OK:
                                DirAccess.remove_absolute(ProjectSettings.globalize_path(test_scene_file_path + ".tscn"))
                        else:
                            log_error("Test file couldn't be verified. This suggests filesystem access issues.")
                    else:
                        var write_error = FileAccess.get_open_error()
                        log_error("Failed to write test file to scene directory: " + str(write_error))
                        log_error("This confirms there are permission or path issues with the scene directory.")
                    
                    # Return error since we couldn't create the scene file
                    log_error("Failed to create scene: " + params.scene_path)
                    operation_failed = true
                    quit(1)
                    return
                
                # If we get here, at least one of our file checks passed
                if file_check_abs or file_check_res or res_exists:
                    print("Scene file verified to exist!")
                    
                    # Try to load the scene to verify it's valid
                    var test_load = ResourceLoader.load(full_scene_path)
                    if test_load:
                        print("Scene created and verified successfully at: " + params.scene_path)
                        print("Scene file can be loaded correctly.")
                    else:
                        print("Scene file exists but cannot be loaded. It may be corrupted or incomplete.")
                        # Continue anyway since the file exists
                    
                    print("Scene created successfully at: " + params.scene_path)
                else:
                    log_error("All file existence checks failed despite successful save operation.")
                    log_error("This indicates a serious issue with file system access or path resolution.")
                    operation_failed = true
                    quit(1)
                    return
            else:
                # In non-debug mode, just check if the file exists
                var file_exists = FileAccess.file_exists(full_scene_path)
                if file_exists:
                    print("Scene created successfully at: " + params.scene_path)
                else:
                    log_error("Failed to create scene: " + params.scene_path)
                    operation_failed = true
                    quit(1)
                    return
        else:
            # Handle specific error codes
            var error_message = "Failed to save scene. Error code: " + str(save_error)
            
            if save_error == ERR_CANT_CREATE:
                error_message += " (ERR_CANT_CREATE - Cannot create the scene file)"
            elif save_error == ERR_CANT_OPEN:
                error_message += " (ERR_CANT_OPEN - Cannot open the scene file for writing)"
            elif save_error == ERR_FILE_CANT_WRITE:
                error_message += " (ERR_FILE_CANT_WRITE - Cannot write to the scene file)"
            elif save_error == ERR_FILE_NO_PERMISSION:
                error_message += " (ERR_FILE_NO_PERMISSION - No permission to write the scene file)"
            
            log_error(error_message)
            operation_failed = true
            quit(1)
            return
    else:
        log_error("Failed to pack scene: " + str(result))
        log_error("Error code: " + str(result))
        operation_failed = true
        quit(1)
        return

# Add a node to an existing scene
func add_node(params):
    print("Adding node to scene: " + params.scene_path)
    
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    if debug_mode:
        print("Scene path (with res://): " + full_scene_path)
    
    var absolute_scene_path = ProjectSettings.globalize_path(full_scene_path)
    if debug_mode:
        print("Absolute scene path: " + absolute_scene_path)
    
    if not FileAccess.file_exists(absolute_scene_path):
        log_error("Scene file does not exist at: " + absolute_scene_path)
        operation_failed = true
        quit(1)
        return
    
    var scene = load(full_scene_path)
    if not scene:
        log_error("Failed to load scene: " + full_scene_path)
        operation_failed = true
        quit(1)
        return
    
    if debug_mode:
        print("Scene loaded successfully")
    var scene_root = scene.instantiate()
    if debug_mode:
        print("Scene instantiated")
    
    # Use traditional if-else statement for better compatibility
    var parent_path = "root"  # Default value
    if params.has("parent_node_path"):
        parent_path = params.parent_node_path
    if debug_mode:
        print("Parent path: " + parent_path)
    
    var parent = scene_root
    if parent_path != "root":
        parent = scene_root.get_node(parent_path.replace("root/", ""))
        if not parent:
            log_error("Parent node not found: " + parent_path)
            operation_failed = true
            quit(1)
            return
    if debug_mode:
        print("Parent node found: " + parent.name)
    
    if debug_mode:
        print("Instantiating node of type: " + params.node_type)
    var new_node = instantiate_class(params.node_type)
    if not new_node:
        log_error("Failed to instantiate node of type: " + params.node_type)
        log_error("Make sure the class exists and can be instantiated")
        log_error("Check if the class is registered in ClassDB or available as a script")
        operation_failed = true
        quit(1)
        return
    new_node.name = params.node_name
    if debug_mode:
        print("New node created with name: " + new_node.name)
    
    if params.has("properties"):
        if debug_mode:
            print("Setting properties on node")
        var properties = params.properties
        for property in properties:
            if debug_mode:
                print("Setting property: " + property + " = " + str(properties[property]))
            var value = properties[property]
            if typeof(value) == TYPE_STRING and value.begins_with("res://"):
                value = load(value)
                if debug_mode:
                    print("Loaded resource for property: " + property + " -> " + str(value))
            new_node.set(property, value)
    
    parent.add_child(new_node)
    new_node.owner = scene_root
    if debug_mode:
        print("Node added to parent and ownership set")
    
    var packed_scene = PackedScene.new()
    var result = packed_scene.pack(scene_root)
    if debug_mode:
        print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")
    
    if result == OK:
        if debug_mode:
            print("Saving scene to: " + absolute_scene_path)
        var save_error = save_resource_preserving_uid(packed_scene, absolute_scene_path)
        if debug_mode:
            print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")
        if save_error == OK:
            if debug_mode:
                var file_check_after = FileAccess.file_exists(absolute_scene_path)
                print("File exists check after save: " + str(file_check_after))
                if file_check_after:
                    print("Node '" + params.node_name + "' of type '" + params.node_type + "' added successfully")
                else:
                    log_error("File reported as saved but does not exist at: " + absolute_scene_path)
            else:
                print("Node '" + params.node_name + "' of type '" + params.node_type + "' added successfully")
        else:
            log_error("Failed to save scene: " + str(save_error))
    else:
        log_error("Failed to pack scene: " + str(result))

# Load a sprite into a Sprite2D node
func load_sprite(params):
    print("Loading sprite into scene: " + params.scene_path)
    
    # Ensure the scene path starts with res:// for Godot's resource system
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    
    if debug_mode:
        print("Full scene path (with res://): " + full_scene_path)
    
    # Check if the scene file exists
    var file_check = FileAccess.file_exists(full_scene_path)
    if debug_mode:
        print("Scene file exists check: " + str(file_check))
    
    if not file_check:
        log_error("Scene file does not exist at: " + full_scene_path)
        # Get the absolute path for reference
        var absolute_path = ProjectSettings.globalize_path(full_scene_path)
        log_error("Absolute file path that doesn't exist: " + absolute_path)
        operation_failed = true
        quit(1)
        return
    
    # Ensure the texture path starts with res:// for Godot's resource system
    var full_texture_path = params.texture_path
    if not full_texture_path.begins_with("res://"):
        full_texture_path = "res://" + full_texture_path
    
    if debug_mode:
        print("Full texture path (with res://): " + full_texture_path)
    
    # Load the scene
    var scene = load(full_scene_path)
    if not scene:
        log_error("Failed to load scene: " + full_scene_path)
        operation_failed = true
        quit(1)
        return
    
    if debug_mode:
        print("Scene loaded successfully")
    
    # Instance the scene
    var scene_root = scene.instantiate()
    if debug_mode:
        print("Scene instantiated")
    
    # Find the sprite node
    var node_path = params.node_path
    if debug_mode:
        print("Original node path: " + node_path)
    
    if node_path.begins_with("root/"):
        node_path = node_path.substr(5)  # Remove "root/" prefix
        if debug_mode:
            print("Node path after removing 'root/' prefix: " + node_path)
    
    var sprite_node = null
    if node_path == "":
        # If no node path, assume root is the sprite
        sprite_node = scene_root
        if debug_mode:
            print("Using root node as sprite node")
    else:
        sprite_node = scene_root.get_node(node_path)
        if sprite_node and debug_mode:
            print("Found sprite node: " + sprite_node.name)
    
    if not sprite_node:
        log_error("Node not found: " + params.node_path)
        operation_failed = true
        quit(1)
        return
    
    # Check if the node is a Sprite2D or compatible type
    if debug_mode:
        print("Node class: " + sprite_node.get_class())
    if not (sprite_node is Sprite2D or sprite_node is Sprite3D or sprite_node is TextureRect):
        log_error("Node is not a sprite-compatible type: " + sprite_node.get_class())
        operation_failed = true
        quit(1)
        return
    
    # Load the texture
    if debug_mode:
        print("Loading texture from: " + full_texture_path)
    var texture = load(full_texture_path)
    if not texture:
        log_error("Failed to load texture: " + full_texture_path)
        operation_failed = true
        quit(1)
        return
    
    if debug_mode:
        print("Texture loaded successfully")
    
    # Set the texture on the sprite
    if sprite_node is Sprite2D or sprite_node is Sprite3D:
        sprite_node.texture = texture
        if debug_mode:
            print("Set texture on Sprite2D/Sprite3D node")
    elif sprite_node is TextureRect:
        sprite_node.texture = texture
        if debug_mode:
            print("Set texture on TextureRect node")
    
    # Save the modified scene
    var packed_scene = PackedScene.new()
    var result = packed_scene.pack(scene_root)
    if debug_mode:
        print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")
    
    if result == OK:
        if debug_mode:
            print("Saving scene to: " + full_scene_path)
        var error = save_resource_preserving_uid(packed_scene, full_scene_path)
        if debug_mode:
            print("Save result: " + str(error) + " (OK=" + str(OK) + ")")
        
        if error == OK:
            # Verify the file was actually updated
            if debug_mode:
                var file_check_after = FileAccess.file_exists(full_scene_path)
                print("File exists check after save: " + str(file_check_after))
                
                if file_check_after:
                    print("Sprite loaded successfully with texture: " + full_texture_path)
                    # Get the absolute path for reference
                    var absolute_path = ProjectSettings.globalize_path(full_scene_path)
                    print("Absolute file path: " + absolute_path)
                else:
                    log_error("File reported as saved but does not exist at: " + full_scene_path)
            else:
                print("Sprite loaded successfully with texture: " + full_texture_path)
        else:
            log_error("Failed to save scene: " + str(error))
    else:
        log_error("Failed to pack scene: " + str(result))

# Export a scene as a MeshLibrary resource
func export_mesh_library(params):
    print("Exporting MeshLibrary from scene: " + params.scene_path)
    
    # Ensure the scene path starts with res:// for Godot's resource system
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    
    if debug_mode:
        print("Full scene path (with res://): " + full_scene_path)
    
    # Ensure the output path starts with res:// for Godot's resource system
    var full_output_path = params.output_path
    if not full_output_path.begins_with("res://"):
        full_output_path = "res://" + full_output_path
    
    if debug_mode:
        print("Full output path (with res://): " + full_output_path)
    
    # Check if the scene file exists
    var file_check = FileAccess.file_exists(full_scene_path)
    if debug_mode:
        print("Scene file exists check: " + str(file_check))
    
    if not file_check:
        log_error("Scene file does not exist at: " + full_scene_path)
        # Get the absolute path for reference
        var absolute_path = ProjectSettings.globalize_path(full_scene_path)
        log_error("Absolute file path that doesn't exist: " + absolute_path)
        operation_failed = true
        quit(1)
        return
    
    # Load the scene
    if debug_mode:
        print("Loading scene from: " + full_scene_path)
    var scene = load(full_scene_path)
    if not scene:
        log_error("Failed to load scene: " + full_scene_path)
        operation_failed = true
        quit(1)
        return
    
    if debug_mode:
        print("Scene loaded successfully")
    
    # Instance the scene
    var scene_root = scene.instantiate()
    if debug_mode:
        print("Scene instantiated")
    
    # Create a new MeshLibrary
    var mesh_library = MeshLibrary.new()
    if debug_mode:
        print("Created new MeshLibrary")
    
    # Get mesh item names if provided
    var mesh_item_names = params.mesh_item_names if params.has("mesh_item_names") else []
    var use_specific_items = mesh_item_names.size() > 0
    
    if debug_mode:
        if use_specific_items:
            print("Using specific mesh items: " + str(mesh_item_names))
        else:
            print("Using all mesh items in the scene")
    
    # Process all child nodes
    var item_id = 0
    if debug_mode:
        print("Processing child nodes...")
    
    for child in scene_root.get_children():
        if debug_mode:
            print("Checking child node: " + child.name)
        
        # Skip if not using all items and this item is not in the list
        if use_specific_items and not (child.name in mesh_item_names):
            if debug_mode:
                print("Skipping node " + child.name + " (not in specified items list)")
            continue
            
        # Check if the child has a mesh
        var mesh_instance = null
        if child is MeshInstance3D:
            mesh_instance = child
            if debug_mode:
                print("Node " + child.name + " is a MeshInstance3D")
        else:
            # Try to find a MeshInstance3D in the child's descendants
            if debug_mode:
                print("Searching for MeshInstance3D in descendants of " + child.name)
            for descendant in child.get_children():
                if descendant is MeshInstance3D:
                    mesh_instance = descendant
                    if debug_mode:
                        print("Found MeshInstance3D in descendant: " + descendant.name)
                    break
        
        if mesh_instance and mesh_instance.mesh:
            if debug_mode:
                print("Adding mesh: " + child.name)
            
            # Add the mesh to the library
            mesh_library.create_item(item_id)
            mesh_library.set_item_name(item_id, child.name)
            mesh_library.set_item_mesh(item_id, mesh_instance.mesh)
            if debug_mode:
                print("Added mesh to library with ID: " + str(item_id))
            
            # Add collision shape if available
            var collision_added = false
            for collision_child in child.get_children():
                if collision_child is CollisionShape3D and collision_child.shape:
                    mesh_library.set_item_shapes(item_id, [collision_child.shape])
                    if debug_mode:
                        print("Added collision shape from: " + collision_child.name)
                    collision_added = true
                    break
            
            if debug_mode and not collision_added:
                print("No collision shape found for mesh: " + child.name)
            
            # Add preview if available
            if mesh_instance.mesh:
                mesh_library.set_item_preview(item_id, mesh_instance.mesh)
                if debug_mode:
                    print("Added preview for mesh: " + child.name)
            
            item_id += 1
        elif debug_mode:
            print("Node " + child.name + " has no valid mesh")
    
    if debug_mode:
        print("Processed " + str(item_id) + " meshes")
    
    # Create directory if it doesn't exist
    var dir = DirAccess.open("res://")
    if dir == null:
        log_error("Failed to open res:// directory")
        log_error("DirAccess error: " + str(DirAccess.get_open_error()))
        operation_failed = true
        quit(1)
        return
        
    var output_dir = full_output_path.get_base_dir()
    if debug_mode:
        print("Output directory: " + output_dir)
    
    if output_dir != "res://" and not dir.dir_exists(output_dir.substr(6)):  # Remove "res://" prefix
        if debug_mode:
            print("Creating directory: " + output_dir)
        var error = dir.make_dir_recursive(output_dir.substr(6))  # Remove "res://" prefix
        if error != OK:
            log_error("Failed to create directory: " + output_dir + ", error: " + str(error))
            operation_failed = true
            quit(1)
            return
    
    # Save the mesh library
    if item_id > 0:
        if debug_mode:
            print("Saving MeshLibrary to: " + full_output_path)
        var error = save_resource_preserving_uid(mesh_library, full_output_path)
        if debug_mode:
            print("Save result: " + str(error) + " (OK=" + str(OK) + ")")
        
        if error == OK:
            # Verify the file was actually created
            if debug_mode:
                var file_check_after = FileAccess.file_exists(full_output_path)
                print("File exists check after save: " + str(file_check_after))
                
                if file_check_after:
                    print("MeshLibrary exported successfully with " + str(item_id) + " items to: " + full_output_path)
                    # Get the absolute path for reference
                    var absolute_path = ProjectSettings.globalize_path(full_output_path)
                    print("Absolute file path: " + absolute_path)
                else:
                    log_error("File reported as saved but does not exist at: " + full_output_path)
            else:
                print("MeshLibrary exported successfully with " + str(item_id) + " items to: " + full_output_path)
        else:
            log_error("Failed to save MeshLibrary: " + str(error))
    else:
        log_error("No valid meshes found in the scene")

# Find files with a specific extension recursively
func find_files(path, extension):
    var files = []
    var dir = DirAccess.open(path)
    
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        
        while file_name != "":
            if dir.current_is_dir() and not file_name.begins_with("."):
                files.append_array(find_files(path + file_name + "/", extension))
            elif file_name.ends_with(extension):
                files.append(path + file_name)
            
            file_name = dir.get_next()
    
    return files

# Get UID for a specific file
func get_uid(params):
    if not params.has("file_path"):
        log_error("File path is required")
        operation_failed = true
        quit(1)
        return
    
    # Ensure the file path starts with res:// for Godot's resource system
    var file_path = params.file_path
    if not file_path.begins_with("res://"):
        file_path = "res://" + file_path
    
    print("Getting UID for file: " + file_path)
    if debug_mode:
        print("Full file path (with res://): " + file_path)
    
    # Get the absolute path for reference
    var absolute_path = ProjectSettings.globalize_path(file_path)
    if debug_mode:
        print("Absolute file path: " + absolute_path)
    
    # Ensure the file exists
    var file_check = FileAccess.file_exists(file_path)
    if debug_mode:
        print("File exists check: " + str(file_check))
    
    if not file_check:
        log_error("File does not exist at: " + file_path)
        log_error("Absolute file path that doesn't exist: " + absolute_path)
        operation_failed = true
        quit(1)
        return
    
    # Imported resources (textures, audio, etc.) store their UID in the import
    # metadata rather than a sibling .uid file. Let the engine resolve it first.
    var resource_uid = read_resource_uid_on_disk(file_path)
    if resource_uid != -1:
        print(JSON.stringify({
            "file": file_path,
            "absolutePath": absolute_path,
            "uid": ResourceUID.id_to_text(resource_uid),
            "exists": true
        }))
        return

    # Scripts and shaders may have a sidecar before the UID cache is populated.
    var uid_path = file_path + ".uid"
    if debug_mode:
        print("UID file path: " + uid_path)
    
    var uid_check = FileAccess.file_exists(uid_path)
    if debug_mode:
        print("UID file exists check: " + str(uid_check))
    
    var f = null
    var parent_directory = DirAccess.open(file_path.get_base_dir())
    if parent_directory and not parent_directory.is_link(uid_path) and uid_check:
        f = FileAccess.open(uid_path, FileAccess.READ)
    
    if f:
        if f.get_length() > 1024:
            f.close()
            log_error("UID sidecar exceeds its size limit.")
            return
        # Read the UID content
        var uid_content = f.get_as_text()
        f.close()
        if debug_mode:
            print("UID content read successfully")
        
        if ResourceUID.text_to_id(uid_content.strip_edges()) == -1:
            log_error("UID sidecar does not contain a valid UID.")
            return
        # Return the UID content
        var result = {
            "file": file_path,
            "absolutePath": absolute_path,
            "uid": uid_content.strip_edges(),
            "exists": true
        }
        if debug_mode:
            print("UID result: " + JSON.stringify(result))
        print(JSON.stringify(result))
    else:
        if debug_mode:
            print("UID file does not exist or could not be opened")
        
        # UID file doesn't exist
        var result = {
            "file": file_path,
            "absolutePath": absolute_path,
            "exists": false,
            "message": "No UID is registered for this resource. Import it or use update_project_uids to resave resources."
        }
        if debug_mode:
            print("UID result: " + JSON.stringify(result))
        print(JSON.stringify(result))

# Resave bounded resources inside the project selected by CLI --path.
func resave_resources(_params):
    var candidates = []
    var pending = [{"path": "res://", "depth": 0}]
    var visited = 0
    var total_bytes = 0
    var skipped_links = 0
    var extensions = ["tscn", "tres", "scn", "res", "gd", "gdshader", "gdshaderinc", "shader"]
    var started = Time.get_ticks_msec()
    while not pending.is_empty():
        var entry = pending.pop_back()
        var directory = DirAccess.open(entry.path)
        if not directory:
            log_error("Cannot scan a project resource directory.")
            return
        if directory.list_dir_begin() != OK:
            log_error("Cannot list a project resource directory.")
            return
        var name = directory.get_next()
        while name != "":
            visited += 1
            if visited > 5000 or Time.get_ticks_msec() - started > 25000:
                log_error("UID scan exceeds its entry/time limit; no resources were saved.")
                directory.list_dir_end()
                return
            var path = entry.path.path_join(name)
            if name.begins_with("."):
                name = directory.get_next()
                continue
            if directory.is_link(path):
                skipped_links += 1
                name = directory.get_next()
                continue
            if directory.current_is_dir():
                if entry.depth >= 16 or pending.size() >= 256:
                    log_error("UID scan exceeds its directory/depth limit; no resources were saved.")
                    directory.list_dir_end()
                    return
                pending.push_back({"path": path, "depth": entry.depth + 1})
            elif path.get_extension().to_lower() in extensions:
                if candidates.size() >= 512 or directory.is_link(path + ".uid"):
                    log_error("UID scan exceeds its resource limit or contains a linked UID sidecar.")
                    directory.list_dir_end()
                    return
                var file = FileAccess.open(path, FileAccess.READ)
                if not file:
                    log_error("A resource cannot be read before resaving.")
                    directory.list_dir_end()
                    return
                var size = file.get_length()
                file.close()
                total_bytes += size
                if size > 4194304 or total_bytes > 67108864:
                    log_error("UID resources exceed the 4 MiB per-file or 64 MiB batch limit.")
                    directory.list_dir_end()
                    return
                candidates.push_back(path)
            name = directory.get_next()
        directory.list_dir_end()

    # Materialize missing script/shader sidecars before reloading scenes and
    # resources, so the latter persist references to the newly assigned UIDs.
    var script_extensions = ["gd", "gdshader", "gdshaderinc", "shader"]
    candidates.sort_custom(func(a, b):
        var a_is_script = a.get_extension().to_lower() in script_extensions
        var b_is_script = b.get_extension().to_lower() in script_extensions
        if a_is_script != b_is_script:
            return a_is_script
        return a < b
    )
    var saved = 0
    var binary_saved = 0
    for path in candidates:
        if Time.get_ticks_msec() - started > 25000:
            log_error("UID resave reached its time limit; some resources may already have been saved.")
            return
        var directory = DirAccess.open(path.get_base_dir())
        if not directory or directory.is_link(path) or directory.is_link(path + ".uid"):
            log_error("A resource became unavailable or linked before saving.")
            return
        var resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
        if not resource:
            log_error("Failed to load resource for UID update: " + path)
            return
        var error = save_resource_preserving_uid(resource, path)
        if error != OK:
            log_error("Failed to save resource for UID update: " + path + ", error: " + str(error))
            return
        if read_resource_uid_on_disk(path) == -1 and path.get_extension().to_lower() in ["gd", "gdshader", "gdshaderinc", "shader"]:
            # Headless script savers do not create sidecars; that normally
            # happens in the editor filesystem. Create only a missing one.
            if not FileAccess.file_exists(path + ".uid"):
                var generated_uid = ResourceUID.create_id()
                if generated_uid == -1:
                    log_error("Could not allocate a UID for: " + path)
                    return
                var generated_file = FileAccess.open(path + ".uid", FileAccess.WRITE)
                if not generated_file:
                    log_error("Could not write UID sidecar for: " + path)
                    return
                generated_file.store_line(ResourceUID.id_to_text(generated_uid))
                var write_error = generated_file.get_error()
                generated_file.close()
                if write_error != OK:
                    log_error("Failed to persist UID sidecar for: " + path)
                    return
                ResourceUID.add_id(generated_uid, path)
        if read_resource_uid_on_disk(path) == -1:
            var uid_file = FileAccess.open(path + ".uid", FileAccess.READ)
            if not uid_file or uid_file.get_length() > 1024:
                log_error("Saved resource still has no valid UID: " + path)
                return
            var uid_text = uid_file.get_as_text().strip_edges()
            uid_file.close()
            if ResourceUID.text_to_id(uid_text) == -1:
                log_error("Saved resource UID sidecar is invalid: " + path)
                return
        if path.get_extension().to_lower() in ["tscn", "tres"]:
            if refresh_text_external_uids(path) != OK:
                return
        elif path.get_extension().to_lower() in ["scn", "res"]:
            binary_saved += 1
        saved += 1
    print("Resave operation complete")
    print(JSON.stringify({"project": "res://", "resources_saved": saved, "resources_scanned": candidates.size(), "entries_visited": visited, "skipped_links": skipped_links, "read_bytes": total_bytes, "binary_resources_saved": binary_saved, "binary_external_uid_refresh": false}))

# Save changes to a scene file
func save_scene(params):
    print("Saving scene: " + params.scene_path)
    
    # Ensure the scene path starts with res:// for Godot's resource system
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    
    if debug_mode:
        print("Full scene path (with res://): " + full_scene_path)
    
    # Check if the scene file exists
    var file_check = FileAccess.file_exists(full_scene_path)
    if debug_mode:
        print("Scene file exists check: " + str(file_check))
    
    if not file_check:
        log_error("Scene file does not exist at: " + full_scene_path)
        # Get the absolute path for reference
        var absolute_path = ProjectSettings.globalize_path(full_scene_path)
        log_error("Absolute file path that doesn't exist: " + absolute_path)
        operation_failed = true
        quit(1)
        return
    
    # Load the scene
    var scene = load(full_scene_path)
    if not scene:
        log_error("Failed to load scene: " + full_scene_path)
        operation_failed = true
        quit(1)
        return
    
    if debug_mode:
        print("Scene loaded successfully")
    
    # Instance the scene
    var scene_root = scene.instantiate()
    if debug_mode:
        print("Scene instantiated")
    
    # Determine save path
    var save_path = params.new_path if params.has("new_path") else full_scene_path
    if params.has("new_path") and not save_path.begins_with("res://"):
        save_path = "res://" + save_path
    
    if debug_mode:
        print("Save path: " + save_path)
    
    # Create directory if it doesn't exist
    if params.has("new_path"):
        var dir = DirAccess.open("res://")
        if dir == null:
            log_error("Failed to open res:// directory")
            log_error("DirAccess error: " + str(DirAccess.get_open_error()))
            operation_failed = true
            quit(1)
            return
            
        var scene_dir = save_path.get_base_dir()
        if debug_mode:
            print("Scene directory: " + scene_dir)
        
        if scene_dir != "res://" and not dir.dir_exists(scene_dir.substr(6)):  # Remove "res://" prefix
            if debug_mode:
                print("Creating directory: " + scene_dir)
            var error = dir.make_dir_recursive(scene_dir.substr(6))  # Remove "res://" prefix
            if error != OK:
                log_error("Failed to create directory: " + scene_dir + ", error: " + str(error))
                operation_failed = true
                quit(1)
                return
    
    # Create a packed scene
    var packed_scene = PackedScene.new()
    var result = packed_scene.pack(scene_root)
    if debug_mode:
        print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")
    
    if result == OK:
        if debug_mode:
            print("Saving scene to: " + save_path)
        var error = save_resource_preserving_uid(packed_scene, save_path)
        if debug_mode:
            print("Save result: " + str(error) + " (OK=" + str(OK) + ")")
        
        if error == OK:
            # Verify the file was actually created/updated
            if debug_mode:
                var file_check_after = FileAccess.file_exists(save_path)
                print("File exists check after save: " + str(file_check_after))
                
                if file_check_after:
                    print("Scene saved successfully to: " + save_path)
                    # Get the absolute path for reference
                    var absolute_path = ProjectSettings.globalize_path(save_path)
                    print("Absolute file path: " + absolute_path)
                else:
                    log_error("File reported as saved but does not exist at: " + save_path)
            else:
                print("Scene saved successfully to: " + save_path)
        else:
            log_error("Failed to save scene: " + str(error))
    else:
        log_error("Failed to pack scene: " + str(result))
