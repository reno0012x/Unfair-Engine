#pragma once

#include "unfair_ai_bridge_server.h"

#include "editor/docks/editor_dock.h"

class Button;
class EditorFileDialog;
class Label;
class LineEdit;
class PanelContainer;
class TabContainer;
class Tree;
class VBoxContainer;

class UnfairAIAssistanceDock : public EditorDock {
	GDCLASS(UnfairAIAssistanceDock, EditorDock);

	Ref<UnfairAIBridgeServer> bridge;
	PanelContainer *surface = nullptr;
	Label *status_label = nullptr;
	Label *summary_label = nullptr;
	Label *detail_label = nullptr;
	Label *sessions_empty = nullptr;
	Label *activity_empty = nullptr;
	Label *tools_empty = nullptr;
	Label *heading = nullptr;
	VBoxContainer *advanced_content = nullptr;
	Button *advanced_button = nullptr;
	Button *enable_button = nullptr;
	Button *copy_button = nullptr;
	Button *stop_dot = nullptr;
	Button *compact_dot = nullptr;
	Button *float_dot = nullptr;
	LineEdit *python_path = nullptr;
	LineEdit *tool_search = nullptr;
	Tree *sessions_tree = nullptr;
	Tree *activity_tree = nullptr;
	Tree *tools_tree = nullptr;
	TabContainer *tabs = nullptr;
	EditorFileDialog *export_dialog = nullptr;
	String config_path;
	String last_signature;
	String status_message;
	double refresh_elapsed = 0;
	bool surface_tree_ready = false;
	bool controls_ready = false;

	void _toggle_bridge();
	void _stop_bridge();
	void _copy_config();
	void _compact();
	void _float();
	void _toggle_advanced();
	void _refresh();
	void _apply_appearance();
	void _sync_window_surface();
	void _filter_tools(const String &p_query);
	void _tool_selected();
	void _activity_selected();
	void _export_requested();
	void _export_markdown(const String &p_path);
	bool _write_config();
	String _bridge_path() const;

protected:
	static void _bind_methods();
	void _notification(int p_what);

public:
	String get_connection_config_path() const { return config_path; }
	Dictionary get_bridge_status() const;
	UnfairAIAssistanceDock();
	~UnfairAIAssistanceDock();
};
