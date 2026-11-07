#include "unfair_ai_bridge_server.h"

#include "core/config/engine.h"
#include "core/config/project_settings.h"
#include "core/io/dir_access.h"
#include "core/io/file_access.h"
#include "core/io/json.h"
#include "core/math/math_funcs.h"
#include "core/object/class_db.h"
#include "core/os/os.h"
#include "core/os/thread.h"
#include "editor/editor_data.h"
#include "editor/editor_interface.h"
#include "editor/file_system/editor_file_system.h"
#include "scene/main/node.h"

#ifdef WINDOWS_ENABLED
#include <windows.h>
#endif

namespace {
constexpr int MAX_CONNECTIONS = 8;
constexpr int MAX_LINE_BYTES = 256 * 1024;
constexpr int MAX_QUEUE_BYTES = 512 * 1024;
constexpr int MAX_OUTPUT_BYTES = 256 * 1024;
constexpr int MAX_FILE_BYTES = 64 * 1024;
constexpr int MAX_ACTIVITY = 200;

bool json_integer(const Variant &p_value) {
	if (p_value.get_type() != Variant::INT && p_value.get_type() != Variant::FLOAT) {
		return false;
	}
	// JSON numbers arrive as FLOAT in this engine version. Accept only integers
	// representable exactly by both JSON clients and IEEE-754 double precision.
	const double value = p_value;
	return Math::is_finite(value) && value >= -9007199254740991.0 && value <= 9007199254740991.0 && Math::floor(value) == value;
}

String brief(const Variant &p_value, const String &p_secret) {
	String text = p_value.get_type() == Variant::STRING ? String(p_value) : String();
	return text.replace(p_secret, "[redacted]").replace("\n", " ").replace("\r", " ").replace("\t", " ").left(80);
}

Dictionary node_info(Node *p_node, Node *p_root) {
	Dictionary result;
	result["node"] = p_root == p_node ? String(".") : String(p_root->get_path_to(p_node));
	result["name"] = String(p_node->get_name());
	result["type"] = p_node->get_class();
	result["instance_id"] = int64_t(p_node->get_instance_id());
	result["child_count"] = p_node->get_child_count(false);
	result["scene"] = p_root->get_scene_file_path();
	return result;
}

#ifdef WINDOWS_ENABLED
String canonical_handle_path(HANDLE p_handle) {
	WCHAR buffer[32768];
	const DWORD length = GetFinalPathNameByHandleW(p_handle, buffer, 32768, FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
	if (length == 0 || length >= 32768) {
		return String();
	}
	return String::utf16(reinterpret_cast<const char16_t *>(buffer), length).replace_char('\\', '/').to_lower();
}
#endif
} // namespace

void UnfairAIBridgeServer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start"), &UnfairAIBridgeServer::start);
	ClassDB::bind_method(D_METHOD("stop"), &UnfairAIBridgeServer::stop);
	ClassDB::bind_method(D_METHOD("poll"), &UnfairAIBridgeServer::poll);
	ClassDB::bind_method(D_METHOD("is_running"), &UnfairAIBridgeServer::is_running);
	ClassDB::bind_method(D_METHOD("get_port"), &UnfairAIBridgeServer::get_port);
	ClassDB::bind_method(D_METHOD("get_sessions"), &UnfairAIBridgeServer::get_sessions);
	ClassDB::bind_method(D_METHOD("get_activity"), &UnfairAIBridgeServer::get_activity);
	ClassDB::bind_method(D_METHOD("get_catalog"), &UnfairAIBridgeServer::get_catalog);
	ClassDB::bind_method(D_METHOD("get_stats"), &UnfairAIBridgeServer::get_stats);
}

Error UnfairAIBridgeServer::start() {
	ERR_FAIL_COND_V(!Thread::is_main_thread(), ERR_UNAUTHORIZED);
	if (is_running()) {
		return OK;
	}
	crypto = Ref<Crypto>(Crypto::create());
	if (crypto.is_null()) {
		return ERR_UNAVAILABLE;
	}
	const PackedByteArray secret = crypto->generate_random_bytes(32);
	if (secret.size() != 32) {
		return ERR_CANT_CREATE;
	}
	listener.instantiate();
	const Error error = listener->listen(0, IPAddress("127.0.0.1"));
	if (error != OK) {
		listener.unref();
		return error;
	}
	token = String::hex_encode_buffer(secret.ptr(), secret.size());
	port = listener->get_local_port();
	return OK;
}

void UnfairAIBridgeServer::_disconnect(Connection &p_connection, const String &p_status) {
	if (p_connection.authenticated) {
		p_connection.session["status"] = p_status;
		p_connection.session["last_seen_msec"] = int64_t(p_connection.last_seen_msec);
	}
	if (p_connection.peer.is_valid()) {
		p_connection.peer->disconnect_from_host();
	}
}

void UnfairAIBridgeServer::stop() {
	for (int i = 0; i < connections.size(); i++) {
		_disconnect(connections.write[i], "stopped");
	}
	connections.clear();
	if (listener.is_valid()) {
		listener->stop();
		listener.unref();
	}
	token = String();
	port = 0;
}

bool UnfairAIBridgeServer::is_running() const {
	return listener.is_valid() && listener->is_listening();
}

int UnfairAIBridgeServer::get_port() const {
	return port;
}
String UnfairAIBridgeServer::get_token() const {
	return token;
}
Array UnfairAIBridgeServer::get_sessions() const {
	return sessions.duplicate(true);
}
Array UnfairAIBridgeServer::get_activity() const {
	return activity.duplicate(true);
}

Dictionary UnfairAIBridgeServer::get_stats() const {
	Dictionary stats;
	stats["calls"] = int64_t(call_count);
	stats["errors"] = int64_t(error_count);
	stats["bytes_returned"] = int64_t(bytes_returned);
	int active = 0;
	for (const Connection &connection : connections) {
		active += connection.authenticated ? 1 : 0;
	}
	stats["session_count"] = active;
	return stats;
}

Dictionary UnfairAIBridgeServer::_protocol_error(const Variant &p_id, int p_code, const String &p_message) {
	error_count++;
	Dictionary error;
	error["code"] = p_code;
	error["message"] = p_message;
	Dictionary response;
	response["id"] = p_id;
	response["error"] = error;
	return response;
}

Dictionary UnfairAIBridgeServer::_tool_error(const String &p_message) {
	Dictionary result;
	result["error"] = p_message;
	return result;
}

bool UnfairAIBridgeServer::_queue(Connection &p_connection, const Dictionary &p_response) {
	const CharString encoded = (JSON::stringify(p_response) + "\n").utf8();
	if (encoded.length() > MAX_OUTPUT_BYTES || p_connection.outgoing.size() + encoded.length() > MAX_QUEUE_BYTES) {
		return false;
	}
	const int offset = p_connection.outgoing.size();
	p_connection.outgoing.resize(offset + encoded.length());
	memcpy(p_connection.outgoing.ptrw() + offset, encoded.get_data(), encoded.length());
	return true;
}

void UnfairAIBridgeServer::poll() {
	ERR_FAIL_COND(!Thread::is_main_thread());
	if (!is_running()) {
		return;
	}
	const uint64_t now = OS::get_singleton()->get_ticks_msec();
	for (int accepted = 0; accepted < MAX_CONNECTIONS && listener->is_connection_available(); accepted++) {
		Ref<StreamPeerTCP> peer = listener->take_connection();
		if (peer.is_null()) {
			break;
		}
		if (connections.size() >= MAX_CONNECTIONS || peer->get_connected_host() != IPAddress("127.0.0.1")) {
			peer->disconnect_from_host();
			continue;
		}
		Connection connection;
		connection.peer = peer;
		connection.accepted_msec = now;
		connection.last_seen_msec = now;
		peer->set_no_delay(true);
		connections.push_back(connection);
	}
	int request_budget = 4; // Bound synchronous editor queries per UI frame.
	for (int i = connections.size() - 1; i >= 0; i--) {
		Connection &connection = connections.write[i];
		connection.peer->poll();
		bool alive = connection.peer->get_status() == StreamPeerSocket::STATUS_CONNECTED;
		// An initialized MCP client can remain idle while its model works. Keep a
		// healthy authenticated socket until EOF/stop; only handshakes time out.
		alive = alive && (connection.authenticated || now - connection.last_seen_msec < 10000U);
		if (alive && connection.outgoing.size() > connection.sent) {
			int sent = 0;
			const int amount = MIN(16384, connection.outgoing.size() - connection.sent);
			alive = connection.peer->put_partial_data(connection.outgoing.ptr() + connection.sent, amount, sent) == OK;
			connection.sent += sent;
			bytes_returned += sent;
			if (connection.sent == connection.outgoing.size()) {
				connection.outgoing.clear();
				connection.sent = 0;
			}
		}
		const int available = alive ? MIN(connection.peer->get_available_bytes(), 16384) : 0;
		if (available > 0) {
			uint8_t buffer[16384];
			int received = 0;
			alive = connection.peer->get_partial_data(buffer, available, received) == OK;
			if (received > 0 && connection.incoming.size() + received <= MAX_LINE_BYTES) {
				const int offset = connection.incoming.size();
				connection.incoming.resize(offset + received);
				memcpy(connection.incoming.ptrw() + offset, buffer, received);
			} else if (received > 0) {
				alive = false;
			}
		}
		while (alive && request_budget > 0) {
			int newline = connection.incoming.find('\n');
			if (newline < 0) {
				break;
			}
			String line;
			const Error decoded = line.append_utf8(reinterpret_cast<const char *>(connection.incoming.ptr()), newline);
			connection.incoming = connection.incoming.slice(newline + 1);
			request_budget--;
			const Dictionary response = decoded == OK ? _request(connection, line) : _protocol_error(Variant(), -32700, "Invalid UTF-8 request.");
			alive = _queue(connection, response);
		}
		if (connection.incoming.size() >= MAX_LINE_BYTES) {
			alive = false;
		}
		if (!alive) {
			_disconnect(connection, "disconnected");
			connections.remove_at(i);
		}
	}
}

Dictionary UnfairAIBridgeServer::_request(Connection &p_connection, const String &p_line) {
	Ref<JSON> json;
	json.instantiate();
	if (json->parse(p_line) != OK || json->get_data().get_type() != Variant::DICTIONARY) {
		return _protocol_error(Variant(), -32700, "Invalid JSON request object.");
	}
	const Dictionary request = json->get_data();
	const Variant id = request.get("id", Variant());
	if (!json_integer(id) && (id.get_type() != Variant::STRING || String(id).length() > 128)) {
		return _protocol_error(Variant(), -32600, "Request id must be an integer or a short string.");
	}
	const Variant supplied = request.get("token", Variant());
	if (supplied.get_type() != Variant::STRING || !crypto->constant_time_compare(token.to_utf8_buffer(), String(supplied).to_utf8_buffer())) {
		return _protocol_error(id, -32001, "Authentication failed.");
	}
	if (request.get("method", Variant()).get_type() != Variant::STRING) {
		return _protocol_error(id, -32600, "method must be a string.");
	}
	const String method = request["method"];
	const Variant raw_params = request.get("params", Dictionary());
	if (raw_params.get_type() != Variant::DICTIONARY) {
		return _protocol_error(id, -32602, "params must be an object.");
	}
	const Dictionary params = raw_params;
	Dictionary response;
	response["id"] = id;
	p_connection.last_seen_msec = OS::get_singleton()->get_ticks_msec();
	if (method == "connect") {
		if (!p_connection.authenticated) {
			if (params.get("clientInfo", Variant()).get_type() != Variant::DICTIONARY || params.get("agent", Dictionary()).get_type() != Variant::DICTIONARY) {
				return _protocol_error(id, -32602, "clientInfo and agent must be objects.");
			}
			const Dictionary client = params["clientInfo"];
			const Dictionary agent = params.get("agent", Dictionary());
			Dictionary session;
			session["id"] = "session-" + itos(++next_session);
			session["name"] = brief(client.get("name", "Local MCP client"), token);
			session["version"] = brief(client.get("version", ""), token);
			session["provider"] = brief(agent.get("provider", ""), token);
			session["model"] = brief(agent.get("model", ""), token);
			session["status"] = "connected";
			session["last_seen_msec"] = int64_t(p_connection.last_seen_msec);
			p_connection.session = session;
			p_connection.authenticated = true;
			if (sessions.size() >= 64) {
				for (int i = 0; i < sessions.size(); i++) {
					const Dictionary previous = sessions[i];
					if (String(previous.get("status", "")) != "connected") {
						sessions.remove_at(i);
						break;
					}
				}
			}
			sessions.push_back(session);
		}
		Dictionary result;
		result["session_id"] = p_connection.session["id"];
		Dictionary server_info;
		server_info["name"] = "Unfair";
		server_info["version"] = "1";
		result["serverInfo"] = server_info;
		result["protocol"] = "unfair-jsonl-v1";
		response["result"] = result;
		return response;
	}
	if (!p_connection.authenticated) {
		return _protocol_error(id, -32002, "Connect before issuing requests.");
	}
	p_connection.session["last_seen_msec"] = int64_t(p_connection.last_seen_msec);
	if (method == "ping") {
		Dictionary result;
		result["status"] = "ready";
		response["result"] = result;
	} else if (method == "catalog") {
		Dictionary result;
		result["tools"] = get_catalog();
		response["result"] = result;
	} else if (method == "call") {
		if (params.get("name", Variant()).get_type() != Variant::STRING) {
			return _protocol_error(id, -32602, "Tool name must be a string.");
		}
		const String name = params["name"];
		if (params.get("arguments", Dictionary()).get_type() != Variant::DICTIONARY) {
			return _protocol_error(id, -32602, "arguments must be an object.");
		}
		const Dictionary arguments = params.get("arguments", Dictionary());
		call_count++;
		Dictionary event;
		event["id"] = "call-" + itos(++next_call);
		event["session_id"] = p_connection.session["id"];
		event["client"] = p_connection.session["name"];
		String logged_name = "unknown";
		for (const Variant &entry : get_catalog()) {
			const Dictionary descriptor = entry;
			if (String(descriptor["name"]) == name) {
				logged_name = name;
				break;
			}
		}
		event["tool"] = logged_name;
		const String requested_path = arguments.get("path", Variant()).get_type() == Variant::STRING ? String(arguments["path"]) : String();
		event["target"] = _allowed_resource_path(requested_path) ? requested_path.replace(token, "[redacted]").left(256) : String();
		event["status"] = "running";
		const uint64_t started = OS::get_singleton()->get_ticks_msec();
		event["started_msec"] = int64_t(started);
		event["duration_msec"] = 0;
		event["summary"] = "Reading editor context";
		if (activity.size() >= MAX_ACTIVITY) {
			activity.remove_at(0);
		}
		activity.push_back(event);
		bool failed = false;
		Dictionary data = _tool(name, arguments, failed);
		String text = JSON::stringify(data);
		if (text.utf8().length() > MAX_FILE_BYTES * 2) {
			failed = true;
			data = _tool_error("Result exceeds the response limit. Narrow the query.");
			text = JSON::stringify(data);
		}
		Dictionary block;
		block["type"] = "text";
		block["text"] = text;
		Array content;
		content.push_back(block);
		Dictionary result;
		result["content"] = content;
		result["structuredContent"] = data;
		result["isError"] = failed;
		response["result"] = result;
		if ((JSON::stringify(response) + "\n").utf8().length() > MAX_OUTPUT_BYTES) {
			failed = true;
			data = _tool_error("Encoded result exceeds the response limit. Narrow the query.");
			block["text"] = JSON::stringify(data);
			content[0] = block;
			result["content"] = content;
			result["structuredContent"] = data;
			result["isError"] = true;
			response["result"] = result;
		}
		if (!failed && data.has("start_line")) {
			event["start_line"] = data["start_line"];
		}
		if (!failed && data.has("end_line")) {
			event["end_line"] = data["end_line"];
		}
		if (!failed && (name == "scene.inspect" || name == "editor.selection")) {
			const String scene = data.get("scene", "");
			const Array nodes = data.get("nodes", Array());
			if (!nodes.is_empty()) {
				const Dictionary first = nodes[0];
				const String node = first.get("node", "");
				const String target = (_allowed_resource_path(scene) ? scene : String("[unsaved scene]")) + "::" + node;
				event["target"] = target.replace(token, "[redacted]").left(256);
			}
		}
		event["status"] = failed ? "error" : "completed";
		event["duration_msec"] = int64_t(OS::get_singleton()->get_ticks_msec() - started);
		event["summary"] = failed ? "Read-only query rejected or unavailable" : "Read-only query completed";
		if (failed) {
			error_count++;
		}
	} else {
		return _protocol_error(id, -32601, "Unknown bridge method.");
	}
	return response;
}

Array UnfairAIBridgeServer::get_catalog() const {
	Array tools;
	const char *names[] = { "project.overview", "scene.inspect", "editor.selection", "files.search", "files.read", "tools.search" };
	const char *descriptions[] = {
		"Read project name, engine version and currently open editor scenes.",
		"Inspect the current edited scene's node names and types, without executing scripts.",
		"Read the editor's selected nodes and their scene-relative paths.",
		"Search the editor's cached resource filenames, never scanning arbitrary disk folders.",
		"Read a bounded UTF-8 text file inside res://, excluding hidden, sensitive and linked paths.",
		"Search read-only tool descriptions; optionally include complete input schemas."
	};
	for (int i = 0; i < 6; i++) {
		Dictionary properties;
		Dictionary string_property;
		string_property["type"] = "string";
		Dictionary integer_property;
		integer_property["type"] = "integer";
		integer_property["minimum"] = 1;
		Dictionary limit_property = integer_property.duplicate();
		limit_property["maximum"] = i == 1 ? 256 : 100;
		Array required;
		if (i == 1 || i == 4) {
			properties["path"] = string_property;
		}
		if (i == 1 || i == 3) {
			properties["limit"] = limit_property;
		}
		if (i == 3 || i == 5) {
			properties["query"] = string_property;
		}
		if (i == 4) {
			required.push_back("path");
			Dictionary start_line = integer_property.duplicate();
			start_line["maximum"] = 1000000;
			properties["start_line"] = start_line;
			Dictionary line_count = integer_property.duplicate();
			line_count["maximum"] = 200;
			properties["line_count"] = line_count;
		}
		if (i == 5) {
			Dictionary boolean_property;
			boolean_property["type"] = "boolean";
			properties["include_schemas"] = boolean_property;
		}
		Dictionary schema;
		schema["type"] = "object";
		schema["properties"] = properties;
		schema["additionalProperties"] = false;
		if (!required.is_empty()) {
			schema["required"] = required;
		}
		Dictionary annotations;
		annotations["readOnlyHint"] = true;
		annotations["destructiveHint"] = false;
		annotations["idempotentHint"] = true;
		Dictionary tool;
		tool["name"] = names[i];
		tool["description"] = descriptions[i];
		tool["inputSchema"] = schema;
		tool["annotations"] = annotations;
		tools.push_back(tool);
	}
	return tools;
}

bool UnfairAIBridgeServer::_allowed_resource_path(const String &p_path) {
	if (!p_path.begins_with("res://") || p_path.length() > 1024 || p_path.contains("\\") || p_path.contains("%") || p_path.contains("\n") || p_path.contains("\r")) {
		return false;
	}
	for (int i = 0; i < p_path.length(); i++) {
		if (p_path[i] < 32) {
			return false;
		}
	}
	const String relative = p_path.trim_prefix("res://");
	if (relative.contains(":") || relative.is_absolute_path()) {
		return false;
	}
	for (const String &part : relative.split("/", false)) {
		const String lower = part.to_lower();
		if (lower.begins_with(".") || lower.contains("secret") || lower.contains("credential") || lower.contains("password") || lower.contains("token") || lower.contains("private_key") || lower == "id_rsa" || lower == "id_ed25519" || lower == "secrets" || lower == "export_presets.cfg" || lower == "node_modules") {
			return false;
		}
	}
	return true;
}

bool UnfairAIBridgeServer::_safe_path(const String &p_path, String &r_absolute, String &r_error) const {
	if (!_allowed_resource_path(p_path)) {
		r_error = "Only non-hidden, non-sensitive res:// paths are permitted.";
		return false;
	}
	const String root = ProjectSettings::get_singleton()->get_resource_path().simplify_path().trim_suffix("/");
	r_absolute = ProjectSettings::get_singleton()->globalize_path(p_path).simplify_path();
	if (!r_absolute.begins_with(root + "/") || r_absolute == root) {
		r_error = "Path must identify a file inside the project.";
		return false;
	}
	Ref<DirAccess> directory = DirAccess::create(DirAccess::ACCESS_FILESYSTEM);
	if (directory.is_null() || directory->is_link(root)) {
		r_error = "Linked project roots are not readable by this bridge.";
		return false;
	}
	String component = root;
	for (const String &part : p_path.trim_prefix("res://").split("/", false)) {
		component = component.path_join(part);
		if (directory->is_link(component)) {
			r_error = "Symbolic links and reparse points are not readable by this bridge.";
			return false;
		}
	}
	return true;
}

Dictionary UnfairAIBridgeServer::_tool(const String &p_name, const Dictionary &p_arguments, bool &r_error) {
	r_error = false;
	Dictionary descriptor;
	for (const Variant &entry : get_catalog()) {
		const Dictionary candidate = entry;
		if (String(candidate["name"]) == p_name) {
			descriptor = candidate;
			break;
		}
	}
	if (descriptor.is_empty()) {
		r_error = true;
		return _tool_error("Unknown read-only tool.");
	}
	const Dictionary schema = descriptor["inputSchema"];
	const Dictionary properties = schema["properties"];
	for (const Variant &key : p_arguments.keys()) {
		if (!properties.has(key)) {
			r_error = true;
			return _tool_error("An unsupported argument was provided.");
		}
		const Dictionary property = properties[key];
		const String type = property["type"];
		const Variant value = p_arguments[key];
		if ((type == "string" && value.get_type() != Variant::STRING) || (type == "integer" && !json_integer(value)) || (type == "boolean" && value.get_type() != Variant::BOOL)) {
			r_error = true;
			return _tool_error("An argument does not match its input schema.");
		}
		if (type == "integer" && ((property.has("minimum") && int64_t(value) < int64_t(property["minimum"])) || (property.has("maximum") && int64_t(value) > int64_t(property["maximum"])))) {
			r_error = true;
			return _tool_error("An argument is outside the permitted range.");
		}
	}
	if (schema.has("required")) {
		const Array required = schema["required"];
		for (const Variant &key : required) {
			if (!p_arguments.has(key)) {
				r_error = true;
				return _tool_error("A required argument is missing.");
			}
		}
	}
	EditorInterface *editor = EditorInterface::get_singleton();
	Dictionary data;
	if (p_name == "tools.search") {
		const String query = String(p_arguments.get("query", "")).left(128).to_lower();
		const bool full = p_arguments.get("include_schemas", false);
		Array matches;
		for (const Variant &value : get_catalog()) {
			Dictionary descriptor = value;
			if (query.is_empty() || String(descriptor["name"]).contains(query) || String(descriptor["description"]).to_lower().contains(query)) {
				if (!full) {
					descriptor.erase("inputSchema");
				}
				matches.push_back(descriptor);
			}
		}
		data["tools"] = matches;
		return data;
	}
	if (!editor) {
		r_error = true;
		return _tool_error("The editor is not available.");
	}
	Node *root = editor->get_edited_scene_root();
	if (p_name == "project.overview") {
		data["name"] = ProjectSettings::get_singleton()->get_setting("application/config/name", "");
		data["engine"] = Engine::get_singleton()->get_version_info();
		data["open_scenes"] = editor->get_open_scenes();
		data["current_scene"] = root ? root->get_scene_file_path() : String();
		data["path"] = "res://";
		data["read_only"] = true;
		return data;
	}
	if (p_name == "scene.inspect" || p_name == "editor.selection") {
		Array nodes;
		if (!root) {
			data["nodes"] = nodes;
			data["scene"] = String();
			return data;
		}
		bool truncated = false;
		if (p_name == "editor.selection") {
			EditorSelection *selection = editor->get_selection();
			if (selection) {
				for (Node *node : selection->get_full_selected_node_list()) {
					if (nodes.size() >= 256) {
						truncated = true;
						break;
					}
					if (node == root || root->is_ancestor_of(node)) {
						nodes.push_back(node_info(node, root));
					}
				}
			}
		} else {
			const String node_path = p_arguments.get("path", ".");
			if (node_path.begins_with("/") || node_path.contains("..") || node_path.contains(":")) {
				r_error = true;
				return _tool_error("Node paths must be relative to the edited scene root.");
			}
			Node *target = root->get_node_or_null(NodePath(node_path));
			if (!target) {
				r_error = true;
				return _tool_error("Node not found in the edited scene.");
			}
			const int limit = CLAMP(int(p_arguments.get("limit", 128)), 1, 256);
			Vector<Node *> pending;
			pending.push_back(target);
			for (int index = 0; index < pending.size() && nodes.size() < limit; index++) {
				Node *node = pending[index];
				nodes.push_back(node_info(node, root));
				for (int child = 0; child < node->get_child_count(false); child++) {
					if (pending.size() >= 512) {
						truncated = true;
						break;
					}
					pending.push_back(node->get_child(child, false));
				}
			}
			truncated = truncated || pending.size() > nodes.size();
		}
		data["nodes"] = nodes;
		data["scene"] = root->get_scene_file_path();
		data["truncated"] = truncated;
		data["captured_msec"] = int64_t(OS::get_singleton()->get_ticks_msec());
		return data;
	}
	if (p_name == "files.search") {
		EditorFileSystem *filesystem = EditorFileSystem::get_singleton();
		if (!filesystem || !filesystem->get_filesystem()) {
			r_error = true;
			return _tool_error("The cached editor filesystem is not ready.");
		}
		const String query = String(p_arguments.get("query", "")).left(128).to_lower();
		const int limit = CLAMP(int(p_arguments.get("limit", 50)), 1, 100);
		Array matches;
		Vector<EditorFileSystemDirectory *> pending;
		pending.push_back(filesystem->get_filesystem());
		int visited = 0;
		bool truncated = false;
		for (int index = 0; index < pending.size() && matches.size() < limit && visited < 5000; index++) {
			EditorFileSystemDirectory *directory = pending[index];
			for (int file = 0; file < directory->get_file_count() && matches.size() < limit && visited < 5000; file++) {
				visited++;
				const String path = directory->get_file_path(file);
				if (!_allowed_resource_path(path) || (!query.is_empty() && !path.to_lower().contains(query))) {
					continue;
				}
				Dictionary match;
				match["path"] = path;
				match["type"] = String(directory->get_file_type(file));
				match["revision"] = int64_t(directory->get_file_modified_time(file));
				matches.push_back(match);
			}
			for (int child = 0; child < directory->get_subdir_count(); child++) {
				if (pending.size() >= 1024) {
					truncated = true;
					break;
				}
				EditorFileSystemDirectory *subdir = directory->get_subdir(child);
				if (_allowed_resource_path(subdir->get_path())) {
					pending.push_back(subdir);
				}
			}
		}
		data["files"] = matches;
		data["truncated"] = truncated || matches.size() >= limit || visited >= 5000;
		data["cache_scanning"] = filesystem->is_scanning();
		return data;
	}
	if (p_name == "files.read") {
		const String path = p_arguments.get("path", "");
		String absolute;
		String reason;
		if (!_safe_path(path, absolute, reason)) {
			r_error = true;
			return _tool_error(reason);
		}
		const String extension = path.get_extension().to_lower();
		const PackedStringArray text_extensions = String("godot,gd,gdshader,gdshaderinc,tscn,tres,json,cfg,ini,txt,md,csv,xml,yaml,yml,shader,glsl,cs,cpp,h,hpp,c,py,js,ts,html,css,svg").split(",");
		if (!text_extensions.has(extension)) {
			r_error = true;
			return _tool_error("Only recognized project text files can be read.");
		}
		Vector<uint8_t> bytes;
#ifdef WINDOWS_ENABLED
		// Validate and read the SAME file handle. A junction swap between path
		// checking and opening cannot turn this request into an out-of-root read.
		const String project_root = ProjectSettings::get_singleton()->get_resource_path();
		HANDLE root_handle = CreateFileW(reinterpret_cast<LPCWSTR>(project_root.utf16().get_data()), 0, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, nullptr);
		HANDLE file_handle = CreateFileW(reinterpret_cast<LPCWSTR>(absolute.utf16().get_data()), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
		bool valid = root_handle != INVALID_HANDLE_VALUE && file_handle != INVALID_HANDLE_VALUE;
		if (valid) {
			const String canonical_root = canonical_handle_path(root_handle).trim_suffix("/") + "/";
			const String canonical_file = canonical_handle_path(file_handle);
			BY_HANDLE_FILE_INFORMATION info = {};
			LARGE_INTEGER size = {};
			valid = canonical_root.length() > 1 && canonical_file.begins_with(canonical_root) && GetFileInformationByHandle(file_handle, &info) && !(info.dwFileAttributes & (FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DIRECTORY)) && GetFileSizeEx(file_handle, &size) && size.QuadPart >= 0 && size.QuadPart <= MAX_FILE_BYTES;
			if (valid) {
				bytes.resize(int(size.QuadPart));
				DWORD read = 0;
				valid = ReadFile(file_handle, bytes.ptrw(), DWORD(bytes.size()), &read, nullptr) && read == DWORD(bytes.size());
			}
		}
		if (root_handle != INVALID_HANDLE_VALUE) {
			CloseHandle(root_handle);
		}
		if (file_handle != INVALID_HANDLE_VALUE) {
			CloseHandle(file_handle);
		}
		if (!valid) {
			r_error = true;
			return _tool_error("The file is unavailable, linked, outside the project, or larger than 64 KiB.");
		}
#else
		Ref<FileAccess> file = FileAccess::open(absolute, FileAccess::READ);
		if (file.is_null() || file->get_length() > MAX_FILE_BYTES) {
			r_error = true;
			return _tool_error("The text file is unavailable or larger than 64 KiB.");
		}
		bytes = file->get_buffer(file->get_length());
#endif
		String text;
		if (bytes.find(0) >= 0 || text.append_utf8(reinterpret_cast<const char *>(bytes.ptr()), bytes.size()) != OK) {
			r_error = true;
			return _tool_error("The file is not UTF-8 text.");
		}
		const PackedStringArray lines = text.split("\n");
		const int start = CLAMP(int(p_arguments.get("start_line", 1)), 1, 1000000);
		const int count = CLAMP(int(p_arguments.get("line_count", 200)), 1, 200);
		const int end = MIN(lines.size(), start - 1 + count);
		PackedStringArray selected;
		for (int index = start - 1; index < end; index++) {
			selected.push_back(lines[index]);
		}
		data["path"] = path;
		data["start_line"] = start;
		data["end_line"] = selected.is_empty() ? start - 1 : end;
		data["total_lines"] = lines.size();
		data["text"] = String("\n").join(selected);
		data["revision"] = text.sha256_text();
		data["truncated"] = end < lines.size();
		return data;
	}
	r_error = true;
	return _tool_error("Unknown read-only tool.");
}

UnfairAIBridgeServer::~UnfairAIBridgeServer() {
	stop();
}
