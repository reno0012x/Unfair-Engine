#include "unfair_ai_assistance_dock.h"

#include "unfair_ai_private_config.h"

#include "core/config/project_settings.h"
#include "core/io/dir_access.h"
#include "core/io/file_access.h"
#include "core/io/json.h"
#include "core/object/callable_mp.h"
#include "core/object/class_db.h"
#include "core/os/os.h"
#include "editor/docks/editor_dock_manager.h"
#include "editor/editor_node.h"
#include "editor/gui/editor_file_dialog.h"
#include "editor/gui/window_wrapper.h"
#include "editor/settings/editor_settings.h"
#include "editor/themes/editor_scale.h"
#include "scene/gui/box_container.h"
#include "scene/gui/button.h"
#include "scene/gui/label.h"
#include "scene/gui/line_edit.h"
#include "scene/gui/margin_container.h"
#include "scene/gui/panel_container.h"
#include "scene/gui/scroll_container.h"
#include "scene/gui/tab_container.h"
#include "scene/gui/tree.h"
#include "scene/main/window.h"
#include "scene/resources/style_box_flat.h"
#include "servers/display/display_server.h"

static Ref<StyleBoxFlat> ai_round_style(const Color &p_color, const Color &p_border, int p_radius = 12) {
	Ref<StyleBoxFlat> style;
	style.instantiate();
	style->set_bg_color(p_color);
	style->set_border_color(p_border);
	style->set_border_width_all(1);
	style->set_corner_radius_all(EDSCALE_RND(p_radius));
	style->set_content_margin_all(EDSCALE_RND(10));
	return style;
}

String UnfairAIAssistanceDock::_bridge_path() const {
	return OS::get_singleton()->get_executable_path().get_base_dir().path_join("unfair_ai/unfair_mcp_bridge.py");
}

bool UnfairAIAssistanceDock::_write_config() {
	const String directory = ProjectSettings::get_singleton()->globalize_path(ProjectSettings::get_singleton()->get_project_data_path()).path_join("editor/unfair_ai");
	if (DirAccess::make_dir_recursive_absolute(directory) != OK) {
		status_message = TTR("Could not create the connection settings directory.");
		return false;
	}
	const String candidate = directory.path_join(vformat("connection-%d-%d.json", OS::get_singleton()->get_process_id(), OS::get_singleton()->get_ticks_usec()));
	Dictionary config;
	config["host"] = "127.0.0.1";
	config["port"] = bridge->get_port();
	config["token"] = bridge->get_token();
	config["project_root"] = ProjectSettings::get_singleton()->get_resource_path();
	if (unfair_ai_write_private_config(candidate, JSON::stringify(config, "\t")) != OK) {
		status_message = TTR("Could not create private connection settings.");
		return false;
	}
	config_path = candidate;
	return true;
}

void UnfairAIAssistanceDock::_toggle_bridge() {
	if (bridge->is_running()) {
		_stop_bridge();
		return;
	}
	status_message = String();
	if (bridge->start() != OK) {
		status_message = TTR("Could not start the local connection. Try enabling it again.");
	} else if (!_write_config()) {
		bridge->stop();
	}
	last_signature = String();
	_refresh();
}

void UnfairAIAssistanceDock::_stop_bridge() {
	bridge->stop();
	if (!config_path.is_empty()) {
		DirAccess::remove_absolute(config_path);
		config_path = String();
	}
	last_signature = String();
	_refresh();
}

void UnfairAIAssistanceDock::_copy_config() {
	if (!bridge->is_running() || config_path.is_empty()) {
		return;
	}
	if (!FileAccess::exists(_bridge_path())) {
		status_message = TTR("The MCP companion is missing from the Unfair installation.");
		last_signature = String();
		_refresh();
		return;
	}
	String command = python_path->get_text().strip_edges();
	if (command.is_empty()) {
		command = "python";
	}
	EditorSettings::get_singleton()->set("interface/ai_assistance/python_executable", command);
	Array arguments;
	arguments.push_back(_bridge_path());
	arguments.push_back("--config");
	arguments.push_back(config_path);
	Dictionary server;
	server["command"] = command;
	server["args"] = arguments;
	Dictionary servers;
	servers["unfair"] = server;
	Dictionary configuration;
	configuration["mcpServers"] = servers;
	DisplayServer::get_singleton()->clipboard_set(JSON::stringify(configuration, "\t"));
	status_message = TTR("MCP configuration copied. Add it to your AI client's MCP settings.");
	last_signature = String();
	_refresh();
}

void UnfairAIAssistanceDock::_compact() {
	tabs->set_visible(!tabs->is_visible());
	compact_dot->set_tooltip_text(tabs->is_visible() ? TTR("Collapse activity") : TTR("Expand activity"));
	compact_dot->set_accessibility_name(tabs->is_visible() ? TTRC("Collapse activity") : TTRC("Expand activity"));
}

void UnfairAIAssistanceDock::_toggle_advanced() {
	advanced_content->set_visible(advanced_button->is_pressed());
	advanced_button->set_button_icon(get_editor_theme_icon(advanced_button->is_pressed() ? SNAME("GuiTreeArrowDown") : SNAME("GuiTreeArrowRight")));
}

void UnfairAIAssistanceDock::_float() {
	if (EditorNode::get_singleton()->is_multi_window_enabled()) {
		EditorDockManager::get_singleton()->make_dock_floating(this);
		EditorDockManager::get_singleton()->focus_dock(this);
	}
}

void UnfairAIAssistanceDock::_filter_tools(const String &p_query) {
	tools_tree->clear();
	TreeItem *root = tools_tree->create_item();
	for (const Variant &entry : bridge->get_catalog()) {
		Dictionary tool = entry;
		String name = tool.get("name", "");
		String description = tool.get("description", "");
		if (!p_query.is_empty() && !name.containsn(p_query) && !description.containsn(p_query)) {
			continue;
		}
		TreeItem *item = tools_tree->create_item(root);
		item->set_text(0, name);
		item->set_text(1, description);
		item->set_tooltip_text(1, description);
		item->set_metadata(0, tool);
	}
	tools_empty->set_visible(root->get_child_count() == 0);
	tools_tree->set_visible(root->get_child_count() != 0);
}

void UnfairAIAssistanceDock::_tool_selected() {
	TreeItem *item = tools_tree->get_selected();
	if (item) {
		Dictionary tool = item->get_metadata(0);
		detail_label->set_text(String(tool.get("description", "")) + "\n" + JSON::stringify(tool.get("inputSchema", Dictionary())));
	}
}

void UnfairAIAssistanceDock::_activity_selected() {
	TreeItem *item = activity_tree->get_selected();
	if (item) {
		Dictionary event = item->get_metadata(0);
		detail_label->set_text(String(event.get("target", "")) + "\n" + String(event.get("summary", "")));
	}
}

void UnfairAIAssistanceDock::_refresh() {
	Array sessions = bridge->get_sessions();
	Array activity = bridge->get_activity();
	Dictionary stats = bridge->get_stats();
	String signature = JSON::stringify(sessions) + JSON::stringify(activity) + JSON::stringify(stats) + status_message;
	if (signature == last_signature) {
		return;
	}
	last_signature = signature;
	int connected = 0;
	sessions_tree->clear();
	TreeItem *session_root = sessions_tree->create_item();
	for (const Variant &entry : sessions) {
		Dictionary session = entry;
		String status = session.get("status", "disconnected");
		connected += status == "connected";
		TreeItem *item = sessions_tree->create_item(session_root);
		item->set_text(0, session.get("name", TTR("Unknown client")));
		item->set_text(1, status.capitalize());
		String model = session.get("model", "");
		item->set_text(2, model.is_empty() ? TTR("Not reported") : model);
		item->set_tooltip_text(0, TTR("Client-reported identity") + "\n" + String(session.get("version", "")) + "\n" + String(session.get("provider", "")));
	}
	const bool running = bridge->is_running();
	String state = !running ? TTR("Offline") : (connected ? vformat(TTR("%d connected"), connected) : TTR("Ready"));
	status_label->set_text(state);
	status_label->set_tooltip_text(running && !connected ? TTR("Ready - waiting for an AI client") : state);
	enable_button->set_text(running ? TTR("Disconnect") : TTR("Connect"));
	enable_button->set_tooltip_text(running ? TTR("Disconnect all AI clients and stop the local bridge") : TTR("Enable the local connection for an AI client"));
	sessions_empty->set_visible(sessions.is_empty());
	sessions_empty->set_text(running ? TTR("No clients yet. Add the MCP config to your AI client.") : TTR("Connect to allow an AI client to read this project."));
	sessions_tree->set_visible(!sessions.is_empty());
	sessions_tree->set_custom_minimum_size(Size2(0, 30 + MIN(sessions.size(), 4) * 26) * EDSCALE);
	copy_button->set_disabled(!running);
	stop_dot->set_disabled(!running);
	summary_label->set_text(vformat(TTR("Read-only  |  %d calls  |  %d errors"), int(stats.get("calls", 0)), int(stats.get("errors", 0))) + (status_message.is_empty() ? String() : "\n" + status_message));
	activity_tree->clear();
	TreeItem *activity_root = activity_tree->create_item();
	for (int i = activity.size() - 1; i >= 0; i--) {
		Dictionary event = activity[i];
		TreeItem *item = activity_tree->create_item(activity_root);
		item->set_text(0, event.get("client", ""));
		item->set_text(1, event.get("tool", ""));
		String target = event.get("target", "");
		if (event.has("start_line")) {
			target += vformat(":%d-%d", int(event["start_line"]), int(event.get("end_line", event["start_line"])));
		}
		item->set_text(2, target);
		item->set_text(3, String(event.get("status", "")).capitalize());
		const bool dark = get_theme_color("background", "Editor").get_luminance() < 0.5;
		item->set_custom_color(3, String(event.get("status", "")) == "error" ? (dark ? Color(1, 0.47, 0.44) : Color(0.65, 0.16, 0.14)) : (dark ? Color(0.5, 0.85, 0.65) : Color(0.12, 0.4, 0.24)));
		item->set_text(4, vformat("%d ms", int(event.get("duration_msec", 0))));
		item->set_tooltip_text(2, target);
		item->set_metadata(0, event);
	}
	activity_empty->set_visible(activity.is_empty());
	activity_tree->set_visible(!activity.is_empty());
	emit_signal("bridge_status_changed");
}

Dictionary UnfairAIAssistanceDock::get_bridge_status() const {
	Dictionary status = bridge->get_stats();
	status["enabled"] = bridge->is_running();
	status["sessions"] = bridge->get_sessions();
	status["activity"] = bridge->get_activity();
	return status;
}

void UnfairAIAssistanceDock::_export_requested() {
	export_dialog->set_current_file("unfair-ai-activity.md");
	export_dialog->popup_file_dialog();
}

void UnfairAIAssistanceDock::_export_markdown(const String &p_path) {
	Ref<FileAccess> file = FileAccess::open(p_path, FileAccess::WRITE);
	if (file.is_null()) {
		status_message = TTR("Could not export activity.");
	} else {
		file->store_string("# Unfair AI Assistance\n\nRead-only activity observed through this editor bridge. Client identity is self-reported.\n\n| Client | Tool | Target | Status | Duration |\n| --- | --- | --- | --- | --- |\n");
		for (const Variant &entry : bridge->get_activity()) {
			Dictionary event = entry;
			String row;
			for (const String &key : { "client", "tool", "target", "status" }) {
				String value = event.get(key, "");
				if (key == "target" && event.has("start_line")) {
					value += vformat(":%d-%d", int(event["start_line"]), int(event.get("end_line", event["start_line"])));
				}
				value = value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("[", "\\[").replace("]", "\\]");
				row += "| " + value.replace("|", "\\|").replace("\n", " ").replace("\r", " ") + " ";
			}
			file->store_string(row + vformat("| %d ms |\n", int(event.get("duration_msec", 0))));
		}
		status_message = TTR("Activity exported.");
	}
	last_signature = String();
	_refresh();
}

void UnfairAIAssistanceDock::_apply_appearance() {
	const bool dark = get_theme_color("background", "Editor").get_luminance() < 0.5;
	const Color background = dark ? Color(0.075, 0.08, 0.09) : Color(0.96, 0.97, 0.98);
	const Color border = dark ? Color(0.22, 0.23, 0.25) : Color(0.76, 0.78, 0.81);
	const Color muted = dark ? Color(0.64, 0.66, 0.7) : Color(0.37, 0.39, 0.43);
	surface->add_theme_style_override("panel", ai_round_style(background, border, 18));
	surface->set_clip_children_mode(CanvasItem::CLIP_CHILDREN_AND_DRAW);
	heading->add_theme_font_override("font", get_theme_font("bold", "EditorFonts"));
	heading->add_theme_font_size_override("font_size", EDSCALE_RND(18));
	for (Label *label : { sessions_empty, activity_empty, tools_empty, detail_label, summary_label }) {
		label->add_theme_color_override("font_color", muted);
	}
	for (Tree *tree : { sessions_tree, activity_tree, tools_tree }) {
		tree->add_theme_style_override("panel", ai_round_style(dark ? background.darkened(0.18) : Color(1, 1, 1), border, 6));
	}
	for (Button *button : { copy_button, advanced_button }) {
		button->add_theme_style_override("normal", ai_round_style(background.lightened(dark ? 0.08 : 0.01), border, 10));
		button->add_theme_style_override("hover", ai_round_style(background.lightened(dark ? 0.2 : 0.03), dark ? Color(0.65, 0.67, 0.72) : Color(0.4, 0.42, 0.46), 10));
		button->add_theme_style_override("pressed", ai_round_style(dark ? Color(0.35, 0.37, 0.4) : Color(0.72, 0.75, 0.8), border, 10));
	}
	const Color primary = dark ? Color(0.94, 0.95, 0.97) : Color(0.13, 0.14, 0.17);
	const Color primary_text = dark ? Color(0.09, 0.1, 0.12) : Color(0.98, 0.98, 0.99);
	enable_button->add_theme_style_override("normal", ai_round_style(primary, primary, 10));
	enable_button->add_theme_style_override("hover", ai_round_style(dark ? Color(1, 1, 1) : primary.lightened(0.15), primary, 10));
	enable_button->add_theme_style_override("pressed", ai_round_style(dark ? primary.darkened(0.15) : primary.lightened(0.25), primary, 10));
	for (const StringName &state : { SNAME("font_color"), SNAME("font_hover_color"), SNAME("font_pressed_color"), SNAME("font_focus_color") }) {
		enable_button->add_theme_color_override(state, primary_text);
	}
	status_label->add_theme_color_override("font_color", muted);
	status_label->add_theme_style_override("normal", ai_round_style(background.lightened(dark ? 0.06 : 0.01), border, 10));
	advanced_button->set_button_icon(get_editor_theme_icon(advanced_button->is_pressed() ? SNAME("GuiTreeArrowDown") : SNAME("GuiTreeArrowRight")));
	Button *dots[] = { stop_dot, compact_dot, float_dot };
	Color colors[] = { Color(1, 0.37, 0.34), Color(1, 0.75, 0.28), Color(0.19, 0.81, 0.34) };
	for (int i = 0; i < 3; i++) {
		Ref<StyleBoxFlat> style = ai_round_style(colors[i], colors[i].darkened(0.15), 8);
		style->set_content_margin_all(0);
		Ref<StyleBoxFlat> hover_style = ai_round_style(colors[i].lightened(0.2), colors[i], 8);
		hover_style->set_content_margin_all(0);
		Ref<StyleBoxFlat> pressed_style = ai_round_style(colors[i].darkened(0.25), colors[i], 8);
		pressed_style->set_content_margin_all(0);
		dots[i]->add_theme_style_override("normal", style);
		dots[i]->add_theme_style_override("hover", hover_style);
		dots[i]->add_theme_style_override("pressed", pressed_style);
		dots[i]->add_theme_style_override("disabled", style);
	}
}

void UnfairAIAssistanceDock::_sync_window_surface() {
	if (!is_inside_tree() || !is_ready() || !surface_tree_ready) {
		return;
	}
	Window *native_window = get_window();
	WindowWrapper *wrapper = native_window ? Object::cast_to<WindowWrapper>(native_window->get_parent()) : nullptr;
	if (wrapper && wrapper->get_wrapped_control() == this) {
		wrapper->set_rounded_content(true, 18);
	}
}

void UnfairAIAssistanceDock::_notification(int p_what) {
	if (p_what == NOTIFICATION_POST_ENTER_TREE) {
		surface_tree_ready = true;
	} else if (p_what == NOTIFICATION_EXIT_TREE) {
		surface_tree_ready = false;
	}
	if (p_what == NOTIFICATION_POST_ENTER_TREE || p_what == NOTIFICATION_PARENTED) {
		callable_mp(this, &UnfairAIAssistanceDock::_sync_window_surface).call_deferred();
	}
	if (p_what == NOTIFICATION_READY || p_what == NOTIFICATION_THEME_CHANGED) {
		if (controls_ready && is_inside_tree()) {
			_apply_appearance();
			_filter_tools(tool_search->get_text());
			last_signature = String();
			_refresh();
		}
	} else if (p_what == NOTIFICATION_PROCESS) {
		bridge->poll();
		refresh_elapsed += get_process_delta_time();
		if (refresh_elapsed >= 0.25) {
			refresh_elapsed = 0;
			_refresh();
		}
	}
}

void UnfairAIAssistanceDock::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_connection_config_path"), &UnfairAIAssistanceDock::get_connection_config_path);
	ClassDB::bind_method(D_METHOD("get_bridge_status"), &UnfairAIAssistanceDock::get_bridge_status);
	ADD_SIGNAL(MethodInfo("bridge_status_changed"));
}

UnfairAIAssistanceDock::UnfairAIAssistanceDock() {
	set_name("UnfairAIAssistance");
	set_title(TTRC("AI Assistance"));
	set_layout_key("UnfairAIAssistance");
	set_icon_name("UnfairAI");
	set_default_slot(DOCK_SLOT_RIGHT_BL);
	set_available_layouts(DOCK_LAYOUT_ALL);
	set_closable(true);
	set_custom_minimum_size(Size2(320, 260) * EDSCALE);
	bridge.instantiate();
	set_process(true);
	surface = memnew(PanelContainer);
	surface->set_name("UnfairAIRoundedSurface");
	surface->set_v_size_flags(SIZE_EXPAND_FILL);
	surface->set_clip_children_mode(CanvasItem::CLIP_CHILDREN_AND_DRAW);
	add_child(surface);
	VBoxContainer *shell = memnew(VBoxContainer);
	shell->add_theme_constant_override("separation", EDSCALE_RND(10));
	surface->add_child(shell);
	HBoxContainer *header = memnew(HBoxContainer);
	header->add_theme_constant_override("separation", EDSCALE_RND(8));
	shell->add_child(header);
	HBoxContainer *window_controls = memnew(HBoxContainer);
	window_controls->add_theme_constant_override("separation", EDSCALE_RND(8));
	header->add_child(window_controls);
	stop_dot = memnew(Button);
	compact_dot = memnew(Button);
	float_dot = memnew(Button);
	stop_dot->set_name("UnfairAIRedStop");
	compact_dot->set_name("UnfairAIYellowCompact");
	float_dot->set_name("UnfairAIGreenFloat");
	for (Button *dot : { stop_dot, compact_dot, float_dot }) {
		dot->set_custom_minimum_size(Size2(16, 16) * EDSCALE);
		dot->set_v_size_flags(SIZE_SHRINK_CENTER);
		window_controls->add_child(dot);
	}
	stop_dot->set_tooltip_text(TTR("Disconnect all AI clients"));
	compact_dot->set_tooltip_text(TTR("Collapse or expand activity"));
	float_dot->set_tooltip_text(TTR("Open AI Assistance in a separate window"));
	stop_dot->set_accessibility_name(TTRC("Disconnect all AI clients"));
	compact_dot->set_accessibility_name(TTRC("Collapse activity"));
	float_dot->set_accessibility_name(TTRC("Detach AI Assistance"));
	stop_dot->connect("pressed", callable_mp(this, &UnfairAIAssistanceDock::_stop_bridge));
	compact_dot->connect("pressed", callable_mp(this, &UnfairAIAssistanceDock::_compact));
	float_dot->connect("pressed", callable_mp(this, &UnfairAIAssistanceDock::_float));
	heading = memnew(Label(TTRC("AI Assistance")));
	heading->set_clip_text(true);
	heading->set_theme_type_variation("HeaderSmall");
	heading->set_h_size_flags(SIZE_EXPAND_FILL);
	header->add_child(heading);
	status_label = memnew(Label);
	status_label->set_name("UnfairAIConnectionStatus");
	status_label->set_clip_text(true);
	status_label->set_custom_minimum_size(Size2(100, 32) * EDSCALE);
	status_label->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER);
	status_label->set_text_overrun_behavior(TextServer::OVERRUN_TRIM_ELLIPSIS);
	header->add_child(status_label);
	HBoxContainer *actions = memnew(HBoxContainer);
	shell->add_child(actions);
	ScrollContainer *body_scroll = memnew(ScrollContainer);
	body_scroll->set_name("UnfairAIBodyScroll");
	body_scroll->set_h_size_flags(SIZE_EXPAND_FILL);
	body_scroll->set_v_size_flags(SIZE_EXPAND_FILL);
	body_scroll->set_horizontal_scroll_mode(ScrollContainer::SCROLL_MODE_DISABLED);
	body_scroll->set_vertical_scroll_mode(ScrollContainer::SCROLL_MODE_AUTO);
	body_scroll->set_follow_focus(true);
	shell->add_child(body_scroll);
	VBoxContainer *body = memnew(VBoxContainer);
	body->set_h_size_flags(SIZE_EXPAND_FILL);
	body->add_theme_constant_override("separation", EDSCALE_RND(10));
	body_scroll->add_child(body);
	Label *intro = memnew(Label(TTRC("Connect an AI client to inspect this project and follow its tool activity.")));
	intro->set_custom_minimum_size(Size2(0, 34) * EDSCALE);
	intro->set_autowrap_mode(TextServer::AUTOWRAP_WORD_SMART);
	intro->set_max_lines_visible(2);
	intro->set_clip_text(true);
	body->add_child(intro);
	enable_button = memnew(Button(TTRC("Connect")));
	enable_button->set_custom_minimum_size(Size2(140, 0) * EDSCALE);
	enable_button->set_theme_type_variation("UnfairPrimaryButton");
	enable_button->set_name("UnfairAIEnable");
	enable_button->connect("pressed", callable_mp(this, &UnfairAIAssistanceDock::_toggle_bridge));
	actions->add_child(enable_button);
	copy_button = memnew(Button(TTRC("Copy MCP config")));
	copy_button->set_name("UnfairAICopyConfig");
	copy_button->connect("pressed", callable_mp(this, &UnfairAIAssistanceDock::_copy_config));
	actions->add_child(copy_button);
	python_path = memnew(LineEdit);
	python_path->set_placeholder(TTRC("Python executable"));
	python_path->set_tooltip_text(TTR("Python 3.10 or newer is required by the MCP companion. Enter python or the path to your Python executable."));
	python_path->set_h_size_flags(SIZE_EXPAND_FILL);
	python_path->set_name("UnfairAIPythonPath");
	const String bundled_python = OS::get_singleton()->get_executable_path().get_base_dir().path_join("runtime/python/python.exe");
	const String default_python = FileAccess::exists(bundled_python) ? bundled_python : String("python");
	String configured_python = EDITOR_DEF("interface/ai_assistance/python_executable", default_python);
	if (FileAccess::exists(bundled_python) && (configured_python.is_empty() || configured_python == "python")) {
		configured_python = bundled_python;
	}
	python_path->set_text(configured_python);
	python_path->set_expand_to_text_length_enabled(false);
	advanced_button = memnew(Button(TTRC("Connection settings")));
	advanced_button->set_name("UnfairAIAdvanced");
	advanced_button->set_toggle_mode(true);
	advanced_button->set_text_alignment(HORIZONTAL_ALIGNMENT_LEFT);
	advanced_button->set_tooltip_text(TTR("Configure the Python executable used by the MCP companion"));
	advanced_button->connect("pressed", callable_mp(this, &UnfairAIAssistanceDock::_toggle_advanced));
	body->add_child(advanced_button);
	advanced_content = memnew(VBoxContainer);
	advanced_content->hide();
	body->add_child(advanced_content);
	Label *python_label = memnew(Label(TTRC("Python executable")));
	advanced_content->add_child(python_label);
	advanced_content->add_child(python_path);
	tabs = memnew(TabContainer);
	tabs->set_custom_minimum_size(Size2(0, 240) * EDSCALE);
	tabs->set_v_size_flags(SIZE_EXPAND_FILL);
	body->add_child(tabs);
	VBoxContainer *activity_page = memnew(VBoxContainer);
	activity_page->set_name(TTRC("Activity"));
	tabs->add_child(activity_page);
	activity_page->add_theme_constant_override("separation", EDSCALE_RND(8));
	activity_page->add_child(memnew(Label(TTRC("Connected clients"))));
	sessions_empty = memnew(Label);
	sessions_empty->set_name("UnfairAISessionsEmpty");
	sessions_empty->set_autowrap_mode(TextServer::AUTOWRAP_WORD_SMART);
	sessions_empty->set_max_lines_visible(2);
	sessions_empty->set_clip_text(true);
	sessions_empty->set_custom_minimum_size(Size2(0, 44) * EDSCALE);
	activity_page->add_child(sessions_empty);
	sessions_tree = memnew(Tree);
	sessions_tree->set_name("UnfairAISessions");
	sessions_tree->set_columns(3);
	for (int column = 0; column < 3; column++) {
		sessions_tree->set_column_clip_content(column, true);
		sessions_tree->set_column_custom_minimum_width(column, EDSCALE_RND(36));
	}
	sessions_tree->set_column_titles_visible(true);
	sessions_tree->set_column_title(0, TTRC("Client"));
	sessions_tree->set_column_title(1, TTRC("Connection"));
	sessions_tree->set_column_title(2, TTRC("Model (reported)"));
	sessions_tree->set_hide_root(true);
	sessions_tree->set_custom_minimum_size(Size2(0, 90) * EDSCALE);
	activity_page->add_child(sessions_tree);
	activity_page->add_child(memnew(Label(TTRC("Recent activity"))));
	activity_empty = memnew(Label(TTRC("No activity yet. Tool calls will appear here as your AI client works.")));
	activity_empty->set_name("UnfairAIActivityEmpty");
	activity_empty->set_autowrap_mode(TextServer::AUTOWRAP_WORD_SMART);
	activity_empty->set_max_lines_visible(3);
	activity_empty->set_clip_text(true);
	activity_empty->set_v_size_flags(SIZE_EXPAND_FILL);
	activity_empty->set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER);
	activity_empty->set_custom_minimum_size(Size2(0, 92) * EDSCALE);
	activity_page->add_child(activity_empty);
	activity_tree = memnew(Tree);
	activity_tree->set_name("UnfairAIActivity");
	activity_tree->set_columns(5);
	activity_tree->set_custom_minimum_size(Size2(0, 120) * EDSCALE);
	activity_tree->set_column_titles_visible(true);
	const String titles[] = { TTRC("Client"), TTRC("Tool"), TTRC("File / node / lines"), TTRC("Status"), TTRC("Duration") };
	for (int i = 0; i < 5; i++) {
		activity_tree->set_column_title(i, titles[i]);
		activity_tree->set_column_clip_content(i, true);
		activity_tree->set_column_custom_minimum_width(i, EDSCALE_RND(24));
	}
	activity_tree->set_hide_root(true);
	activity_tree->set_v_size_flags(SIZE_EXPAND_FILL);
	activity_tree->connect("item_selected", callable_mp(this, &UnfairAIAssistanceDock::_activity_selected));
	activity_page->add_child(activity_tree);
	VBoxContainer *tools_page = memnew(VBoxContainer);
	tools_page->set_name(TTRC("Tool directory"));
	tabs->add_child(tools_page);
	tool_search = memnew(LineEdit);
	tool_search->set_placeholder(TTRC("Find a tool by name or purpose..."));
	tool_search->connect("text_changed", callable_mp(this, &UnfairAIAssistanceDock::_filter_tools));
	tools_page->add_child(tool_search);
	tools_empty = memnew(Label(TTRC("No tools match your search.")));
	tools_empty->set_name("UnfairAIToolsEmpty");
	tools_empty->set_clip_text(true);
	tools_empty->set_custom_minimum_size(Size2(0, 72) * EDSCALE);
	tools_page->add_child(tools_empty);
	tools_tree = memnew(Tree);
	tools_tree->set_columns(2);
	for (int column = 0; column < 2; column++) {
		tools_tree->set_column_clip_content(column, true);
		tools_tree->set_column_custom_minimum_width(column, EDSCALE_RND(40));
	}
	tools_tree->set_custom_minimum_size(Size2(0, 160) * EDSCALE);
	tools_tree->set_hide_root(true);
	tools_tree->set_v_size_flags(SIZE_EXPAND_FILL);
	tools_tree->connect("item_selected", callable_mp(this, &UnfairAIAssistanceDock::_tool_selected));
	tools_page->add_child(tools_tree);
	detail_label = memnew(Label(TTRC("Only activity sent through this bridge is visible here. Client and model names are self-reported.")));
	detail_label->set_custom_minimum_size(Size2(0, 34) * EDSCALE);
	detail_label->set_autowrap_mode(TextServer::AUTOWRAP_WORD_SMART);
	detail_label->set_max_lines_visible(2);
	detail_label->set_clip_text(true);
	body->add_child(detail_label);
	// A box assigns the expanding summary a real width before wrapping.
	HBoxContainer *footer = memnew(HBoxContainer);
	footer->set_name("UnfairAIFixedFooter");
	shell->add_child(footer);
	summary_label = memnew(Label);
	summary_label->set_h_size_flags(SIZE_EXPAND_FILL);
	summary_label->set_custom_minimum_size(Size2(0, EDSCALE_RND(40)));
	summary_label->set_autowrap_mode(TextServer::AUTOWRAP_WORD_SMART);
	summary_label->set_max_lines_visible(2);
	summary_label->set_clip_text(true);
	footer->add_child(summary_label);
	Button *export_button = memnew(Button(TTRC("Export activity...")));
	export_button->set_h_size_flags(SIZE_SHRINK_END);
	export_button->set_name("UnfairAIExport");
	export_button->connect("pressed", callable_mp(this, &UnfairAIAssistanceDock::_export_requested));
	footer->add_child(export_button);
	export_dialog = memnew(EditorFileDialog);
	export_dialog->set_name("UnfairAIExportDialog");
	export_dialog->set_file_mode(EditorFileDialog::FILE_MODE_SAVE_FILE);
	export_dialog->set_access(EditorFileDialog::ACCESS_FILESYSTEM);
	export_dialog->add_filter("*.md", TTRC("Markdown"));
	export_dialog->connect("file_selected", callable_mp(this, &UnfairAIAssistanceDock::_export_markdown));
	add_child(export_dialog);
	controls_ready = true;
}

UnfairAIAssistanceDock::~UnfairAIAssistanceDock() {
	bridge->stop();
	if (!config_path.is_empty()) {
		DirAccess::remove_absolute(config_path);
	}
}
