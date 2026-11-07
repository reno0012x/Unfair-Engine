/**************************************************************************/
/*  window_wrapper.cpp                                                    */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#include "window_wrapper.h"

#include "core/object/callable_mp.h"
#include "core/os/os.h"
#include "editor/editor_node.h"
#include "editor/editor_string_names.h"
#include "editor/gui/progress_dialog.h"
#include "editor/settings/editor_settings.h"
#include "editor/themes/editor_scale.h"
#include "scene/gui/box_container.h"
#include "scene/gui/label.h"
#include "scene/gui/panel.h"
#include "scene/gui/popup.h"
#include "scene/main/window.h"
#include "servers/display/display_server.h"

#ifdef WINDOWS_ENABLED
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dwmapi.h>
#endif

// WindowWrapper

Rect2 WindowWrapper::_get_default_window_rect() const {
	// Assume that the control rect is the desired one for the window.
	return wrapped_control ? wrapped_control->get_screen_rect() : Rect2();
}

Node *WindowWrapper::_get_wrapped_control_parent() const {
	if (margins) {
		return margins;
	}
	return window;
}

void WindowWrapper::_set_window_enabled_with_rect(bool p_visible, const Rect2 p_rect) {
	ERR_FAIL_NULL(wrapped_control);

	if (!is_window_available()) {
		return;
	}

	if (window->is_visible() == p_visible) {
		if (p_visible) {
			if (window->get_mode() == Window::MODE_MINIMIZED) {
				window->set_mode(Window::MODE_WINDOWED);
			}
			window->grab_focus();
		}
		return;
	}

	Node *parent = _get_wrapped_control_parent();

	if (wrapped_control->get_parent() != parent) {
		// Move the control to the window.
		wrapped_control->reparent(parent, false);

		_set_window_rect(p_rect);
		wrapped_control->set_anchors_and_offsets_preset(PRESET_FULL_RECT);

	} else if (!p_visible) {
		// Remove control from window.
		wrapped_control->reparent(this, false);
	}

	if (p_visible && window->get_mode() == Window::MODE_MINIMIZED) {
		window->set_mode(Window::MODE_WINDOWED);
	}
	const bool was_visible = window->is_visible();
	window->set_visible(p_visible);
	_queue_rounded_update();
	if (p_visible) {
		window->grab_focus();
	} else if (was_visible && is_inside_tree() && !EditorNode::get_singleton()->is_exiting()) {
		// Closing a floating dock returns focus to the original workspace.
		get_window()->grab_focus();
	}
	if (!p_visible && !override_close_request) {
		emit_signal("window_close_requested");
	}
	emit_signal("window_visibility_changed", p_visible);
}

void WindowWrapper::_set_window_rect(const Rect2 p_rect) {
	// Set the window rect even when the window is maximized to have a good default size
	// when the user remove the maximized mode.
	Rect2i rect = p_rect;
	if (rect.size.x <= 0 || rect.size.y <= 0) {
		const Rect2i current_usable = DisplayServer::get_singleton()->screen_get_usable_rect(get_window()->get_current_screen());
		rect = Rect2i(current_usable.position + current_usable.size / 4, current_usable.size / 2);
	}
	const int screen = DisplayServer::get_singleton()->get_screen_from_rect(rect);
	const Rect2i usable_rect = DisplayServer::get_singleton()->screen_get_usable_rect(screen < 0 ? get_window()->get_current_screen() : screen);
	// Keep the caption and resize handles reachable after monitor/layout changes.
	rect.size = rect.size.min(usable_rect.size);
	rect.position = rect.position.clamp(usable_rect.position, usable_rect.position + usable_rect.size - rect.size);
	window->set_position(rect.position);
	window->set_size(rect.size);

	if (EDITOR_GET("interface/multi_window/maximize_window")) {
		window->set_mode(Window::MODE_MAXIMIZED);
	}
}

void WindowWrapper::_window_size_changed() {
	_queue_rounded_update();
	emit_signal(SNAME("window_size_changed"));
}

void WindowWrapper::_queue_rounded_update() {
	if (rounded_content && !rounded_update_queued) {
		rounded_update_queued = true;
		callable_mp(this, &WindowWrapper::_update_rounded_window).call_deferred();
	}
}

void WindowWrapper::_apply_rounded_region(bool p_enabled) {
#ifdef WINDOWS_ENABLED
	if (!window || window->is_embedded() || window->get_window_id() == DisplayServerEnums::INVALID_WINDOW_ID) {
		return;
	}
	HWND handle = reinterpret_cast<HWND>(DisplayServer::get_singleton()->window_get_native_handle(DisplayServerEnums::WINDOW_HANDLE, window->get_window_id()));
	if (!handle) {
		return;
	}
	// A custom HWND region disables the modern DWM frame on Windows 10.
	// Keep the native frame intact; the client card clips its own rounded content.
	HRGN old_region = CreateRectRgn(0, 0, 0, 0);
	if (old_region) {
		if (GetWindowRgn(handle, old_region) != 0) {
			SetWindowRgn(handle, nullptr, TRUE);
		}
		DeleteObject(old_region);
	}
	DWMNCRENDERINGPOLICY policy = DWMNCRP_ENABLED;
	DwmSetWindowAttribute(handle, DWMWA_NCRENDERING_POLICY, &policy, sizeof(policy));
	// Windows 11 supports this hint; earlier Windows retains its normal frame.
	DWORD corner_preference = p_enabled ? 2 : 0; // DWMWCP_ROUND / DWMWCP_DEFAULT.
	DwmSetWindowAttribute(handle, 33, &corner_preference, sizeof(corner_preference));
#endif
}

void WindowWrapper::_update_rounded_window() {
	rounded_update_queued = false;
	if (!rounded_content || !window || !window->is_visible() || !window->is_inside_tree() || !window->is_ready() || !wrapped_control || !wrapped_control->is_ready()) {
		return;
	}
	if (!rounded_appearance_applied) {
		saved_wrap_controls = window->is_wrapping_controls();
		saved_min_size = window->get_min_size();
		saved_transparent_background = window->has_transparent_background();
		saved_transparent_flag = window->get_flag(Window::FLAG_TRANSPARENT);
		rounded_appearance_applied = true;
		window_background->show();
		if (margins) {
			// Keep the tree topology intact: removing this container would reparent
			// the wrapped dock during its theme/enter-tree propagation.
			const char *names[] = { "margin_left", "margin_top", "margin_right", "margin_bottom" };
			margins->begin_bulk_theme_override();
			for (int i = 0; i < 4; i++) {
				saved_rounded_margins[i] = margins->get_theme_constant(names[i]);
				margins->add_theme_constant_override(names[i], EDSCALE_RND(8));
			}
			margins->end_bulk_theme_override();
		}
		// Apply native changes only after the complete wrapped subtree is ready.
		window->set_wrap_controls(false);
		window->set_transparent_background(false);
		window->set_flag(Window::FLAG_TRANSPARENT, false);
	}
	if (window->get_mode() == Window::MODE_WINDOWED) {
		const Rect2i usable = DisplayServer::get_singleton()->screen_get_usable_rect(window->get_current_screen());
		Vector2i frame_extra;
		Vector2i frame_offset;
#ifdef WINDOWS_ENABLED
		HWND handle = reinterpret_cast<HWND>(DisplayServer::get_singleton()->window_get_native_handle(DisplayServerEnums::WINDOW_HANDLE, window->get_window_id()));
		RECT outer;
		RECT client;
		POINT client_origin = { 0, 0 };
		if (handle && GetWindowRect(handle, &outer) && GetClientRect(handle, &client) && ClientToScreen(handle, &client_origin)) {
			frame_extra = Vector2i(outer.right - outer.left - client.right, outer.bottom - outer.top - client.bottom);
			frame_offset = Vector2i(client_origin.x - outer.left, client_origin.y - outer.top);
		}
#endif
		const Size2i client_limit = (usable.size - frame_extra).max(Vector2i(1, 1));
		window->set_min_size((Size2i(360, 260) * EDSCALE).min(client_limit));
		const Size2i size = window->get_size().min(client_limit);
		if (size != window->get_size()) {
			window->set_size(size);
		}
		const Vector2i lowest = usable.position + frame_offset;
		const Vector2i highest = usable.position + usable.size - frame_extra - size + frame_offset;
		const Vector2i position = window->get_position().clamp(lowest, highest.max(lowest));
		if (position != window->get_position()) {
			window->set_position(position);
		}
	}
	_apply_rounded_region(true);
}

void WindowWrapper::set_rounded_content(bool p_enabled, int p_radius) {
	if (!window) {
		return;
	}
	rounded_content = p_enabled;
	rounded_radius = MAX(1, p_radius);
	if (p_enabled) {
		_queue_rounded_update();
	} else if (rounded_appearance_applied) {
		rounded_appearance_applied = false;
		_apply_rounded_region(false);
		window_background->show();
		if (margins) {
			const char *names[] = { "margin_left", "margin_top", "margin_right", "margin_bottom" };
			margins->begin_bulk_theme_override();
			for (int i = 0; i < 4; i++) {
				margins->add_theme_constant_override(names[i], saved_rounded_margins[i]);
			}
			margins->end_bulk_theme_override();
		}
		window->set_flag(Window::FLAG_TRANSPARENT, saved_transparent_flag);
		window->set_transparent_background(saved_transparent_background);
		window->set_min_size(saved_min_size);
		window->set_wrap_controls(saved_wrap_controls);
	}
}

void WindowWrapper::_window_close_request() {
	if (override_close_request) {
		emit_signal("window_close_requested");
	} else {
		set_window_enabled(false);
	}
}

void WindowWrapper::_bind_methods() {
	ADD_SIGNAL(MethodInfo("window_visibility_changed", PropertyInfo(Variant::BOOL, "visible")));
	ADD_SIGNAL(MethodInfo("window_close_requested"));
	ADD_SIGNAL(MethodInfo("window_size_changed"));
}

void WindowWrapper::_notification(int p_what) {
	if (!is_window_available()) {
		return;
	}
	switch (p_what) {
		case NOTIFICATION_VISIBILITY_CHANGED: {
			// Grab the focus when WindowWrapper.set_visible(true) is called
			// and the window is showing.
			grab_window_focus();
		} break;
		case NOTIFICATION_READY: {
			set_process_shortcut_input(true);
		} break;
		case NOTIFICATION_THEME_CHANGED: {
			window_background->add_theme_style_override(SceneStringName(panel), get_theme_stylebox("PanelForeground", EditorStringName(EditorStyles)));
			_queue_rounded_update();
		} break;
	}
}

void WindowWrapper::shortcut_input(const Ref<InputEvent> &p_event) {
	if (enable_shortcut.is_valid() && enable_shortcut->matches_event(p_event)) {
		set_window_enabled(true);
	}
}

void WindowWrapper::set_wrapped_control(Control *p_control, const Ref<Shortcut> &p_enable_shortcut) {
	ERR_FAIL_NULL(p_control);
	ERR_FAIL_COND(wrapped_control);

	wrapped_control = p_control;
	enable_shortcut = p_enable_shortcut;
	add_child(p_control);
}

Control *WindowWrapper::get_wrapped_control() const {
	return wrapped_control;
}

Control *WindowWrapper::release_wrapped_control() {
	set_window_enabled(false);
	set_rounded_content(false);
	if (wrapped_control) {
		Control *old_wrapped = wrapped_control;
		wrapped_control->get_parent()->remove_child(wrapped_control);
		wrapped_control = nullptr;

		return old_wrapped;
	}
	return nullptr;
}

bool WindowWrapper::is_window_available() const {
	return window != nullptr;
}

bool WindowWrapper::get_window_enabled() const {
	return is_window_available() ? window->is_visible() : false;
}

void WindowWrapper::set_window_enabled(bool p_enabled) {
	_set_window_enabled_with_rect(p_enabled, _get_default_window_rect());
}

Rect2i WindowWrapper::get_window_rect() const {
	ERR_FAIL_COND_V(!get_window_enabled(), Rect2i());
	return Rect2i(window->get_position(), window->get_size());
}

int WindowWrapper::get_window_screen() const {
	ERR_FAIL_COND_V(!get_window_enabled(), -1);
	return window->get_current_screen();
}

void WindowWrapper::restore_window(const Rect2i &p_rect, int p_screen) {
	ERR_FAIL_COND(!is_window_available());
	const int screen = p_screen < 0 ? get_window()->get_current_screen() : p_screen;
	ERR_FAIL_INDEX(screen, DisplayServer::get_singleton()->get_screen_count());

	window->set_current_screen(screen);
	_set_window_enabled_with_rect(true, p_rect);
}

void WindowWrapper::restore_window_from_saved_position(const Rect2 p_window_rect, int p_screen, const Rect2 p_screen_rect) {
	ERR_FAIL_COND(!is_window_available());

	Rect2 window_rect = p_window_rect;
	int screen = p_screen;
	Rect2 restored_screen_rect = p_screen_rect;

	if (screen < 0 || screen >= DisplayServer::get_singleton()->get_screen_count()) {
		// Fallback to the main window screen if the saved screen is not available.
		screen = get_window()->get_current_screen();
	}

	Rect2i real_screen_rect = DisplayServer::get_singleton()->screen_get_usable_rect(screen);

	if (restored_screen_rect == Rect2i()) {
		// Fallback to the target screen rect.
		restored_screen_rect = real_screen_rect;
	}

	if (window_rect == Rect2i()) {
		// Fallback to a standard rect.
		window_rect = Rect2i(restored_screen_rect.position + restored_screen_rect.size / 4, restored_screen_rect.size / 2);
	}

	// Adjust the window rect size in case the resolution changes.
	Vector2 screen_ratio = Vector2(real_screen_rect.size) / Vector2(restored_screen_rect.size);

	// The screen positioning may change, so remove the original screen position.
	window_rect.position -= restored_screen_rect.position;
	window_rect = Rect2i(window_rect.position * screen_ratio, window_rect.size * screen_ratio);
	window_rect.position += real_screen_rect.position;

	// Make sure to restore the window if the user minimized it the last time it was displayed.
	if (window->get_mode() == Window::MODE_MINIMIZED) {
		window->set_mode(Window::MODE_WINDOWED);
	}

	// All good, restore the window.
	window->set_current_screen(screen);
	if (window->is_visible()) {
		_set_window_rect(window_rect);
	} else {
		_set_window_enabled_with_rect(true, window_rect);
	}
}

void WindowWrapper::enable_window_on_screen(int p_screen, bool p_auto_scale) {
	int current_screen = Object::cast_to<Window>(get_viewport())->get_current_screen();
	int screen = p_screen < 0 ? current_screen : p_screen;

	bool auto_scale = p_auto_scale && !EDITOR_GET("interface/multi_window/maximize_window");

	if (auto_scale && current_screen != screen) {
		Rect2 control_rect = _get_default_window_rect();

		Rect2i source_screen_rect = DisplayServer::get_singleton()->screen_get_usable_rect(current_screen);
		Rect2i dest_screen_rect = DisplayServer::get_singleton()->screen_get_usable_rect(screen);

		// Adjust the window rect size in case the resolution changes.
		Vector2 screen_ratio = Vector2(dest_screen_rect.size) / Vector2(source_screen_rect.size);

		// The screen positioning may change, so remove the original screen position.
		control_rect.position -= source_screen_rect.position;
		control_rect = Rect2i(control_rect.position * screen_ratio, control_rect.size * screen_ratio);
		control_rect.position += dest_screen_rect.position;

		restore_window(control_rect, screen);
	} else {
		window->set_current_screen(screen);
		set_window_enabled(true);
	}
}

void WindowWrapper::set_window_title(const String &p_title) {
	if (!is_window_available()) {
		return;
	}
	window->set_title(p_title);
}

void WindowWrapper::set_margins_enabled(bool p_enabled) {
	if (!is_window_available()) {
		return;
	}

	if (!p_enabled && margins) {
		if (wrapped_control && wrapped_control->get_parent() == margins) {
			wrapped_control->reparent(window, false);
			wrapped_control->set_anchors_and_offsets_preset(PRESET_FULL_RECT);
		}
		margins->queue_free();
		margins = nullptr;
	} else if (p_enabled && !margins) {
		Size2 borders = Size2(4, 4) * EDSCALE;
		margins = memnew(MarginContainer);
		margins->add_theme_constant_override("margin_right", borders.width);
		margins->add_theme_constant_override("margin_top", borders.height);
		margins->add_theme_constant_override("margin_left", borders.width);
		margins->add_theme_constant_override("margin_bottom", borders.height);

		window->add_child(margins);
		margins->set_anchors_and_offsets_preset(PRESET_FULL_RECT);
		if (wrapped_control && wrapped_control->get_parent() == window) {
			wrapped_control->reparent(margins, false);
			wrapped_control->set_anchors_and_offsets_preset(PRESET_FULL_RECT);
		}
	}
}

Size2 WindowWrapper::get_margins_size() {
	if (!margins) {
		return Size2();
	}

	return Size2(margins->get_margin_size(SIDE_LEFT) + margins->get_margin_size(SIDE_RIGHT), margins->get_margin_size(SIDE_TOP) + margins->get_margin_size(SIDE_BOTTOM));
}

Size2 WindowWrapper::get_margins_top_left() {
	if (!margins) {
		return Size2();
	}

	return Size2(margins->get_margin_size(SIDE_LEFT), margins->get_margin_size(SIDE_TOP));
}

void WindowWrapper::grab_window_focus() {
	if (get_window_enabled() && is_visible()) {
		if (window->get_mode() == Window::MODE_MINIMIZED) {
			window->set_mode(Window::MODE_WINDOWED);
		}
		window->grab_focus();
	}
}

void WindowWrapper::set_override_close_request(bool p_enabled) {
	override_close_request = p_enabled;
}

WindowWrapper::WindowWrapper() {
	if (!EditorNode::get_singleton()->is_multi_window_enabled()) {
		return;
	}

	window = memnew(Window);
	window_id = window->get_instance_id();
	window->set_wrap_controls(true);
	window->set_title(TTR("Unfair Workspace"));
	window->set_flag(Window::FLAG_MINIMIZE_DISABLED, false);
	window->set_flag(Window::FLAG_MAXIMIZE_DISABLED, false);
	window->set_flag(Window::FLAG_RESIZE_DISABLED, false);
	window->set_propagate_shortcuts_to_parent(true);
	window->hide();

	window->connect("close_requested", callable_mp(this, &WindowWrapper::_window_close_request));
	window->connect("size_changed", callable_mp(this, &WindowWrapper::_window_size_changed));
	window->connect("files_dropped", callable_mp(EditorNode::get_singleton(), &EditorNode::_dropped_files));

	window_background = memnew(Panel);
	window_background->set_anchors_and_offsets_preset(PRESET_FULL_RECT);
	window->add_child(window_background);

	add_child(window);

	ProgressDialog::get_singleton()->add_host_window(window_id);
}

WindowWrapper::~WindowWrapper() {
	if (ProgressDialog::get_singleton()) {
		ProgressDialog::get_singleton()->remove_host_window(window_id);
	}
}

// ScreenSelect

void ScreenSelect::_build_advanced_menu() {
	// Clear old screen list.
	while (screen_list->get_child_count(false) > 0) {
		Node *child = screen_list->get_child(0);
		screen_list->remove_child(child);
		child->queue_free();
	}

	// Populate screen list.
	const real_t height = real_t(get_theme_font_size(SceneStringName(font_size))) * 1.5;

	int current_screen = get_window()->get_current_screen();
	for (int i = 0; i < DisplayServer::get_singleton()->get_screen_count(); i++) {
		Button *button = memnew(Button);

		Size2 screen_size = Size2(DisplayServer::get_singleton()->screen_get_size(i));
		Size2 button_size = Size2(height * (screen_size.x / screen_size.y), height);
		button->set_custom_minimum_size(button_size);
		screen_list->add_child(button);

		button->set_text(itos(i));
		button->set_text_alignment(HORIZONTAL_ALIGNMENT_CENTER);
		button->set_tooltip_text(vformat(TTR("Make this panel floating in the screen %d."), i));

		if (i == current_screen) {
			Color accent_color = get_theme_color("accent_color", EditorStringName(Editor));
			button->add_theme_color_override(SceneStringName(font_color), accent_color);
		}

		button->connect(SceneStringName(pressed), callable_mp(this, &ScreenSelect::_emit_screen_signal).bind(i));
		button->connect(SceneStringName(pressed), callable_mp(static_cast<BaseButton *>(this), &ScreenSelect::set_pressed).bind(false));
		button->connect(SceneStringName(pressed), callable_mp(static_cast<Window *>(popup), &Popup::hide));
	}
}

void ScreenSelect::_emit_screen_signal(int p_screen_idx) {
	if (!is_disabled()) {
		emit_signal("request_open_in_screen", p_screen_idx);
	}
}

void ScreenSelect::_bind_methods() {
	ADD_SIGNAL(MethodInfo("request_open_in_screen", PropertyInfo(Variant::INT, "screen")));
}

void ScreenSelect::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_READY: {
			connect(SceneStringName(gui_input), callable_mp(this, &ScreenSelect::_handle_mouse_shortcut));
		} break;
		case NOTIFICATION_THEME_CHANGED: {
			set_button_icon(get_editor_theme_icon("MakeFloating"));

			const real_t popup_height = real_t(get_theme_font_size(SceneStringName(font_size))) * 2.0;
			popup->set_min_size(Size2(0, popup_height * 3));
		} break;
	}
}

void ScreenSelect::_handle_mouse_shortcut(const Ref<InputEvent> &p_event) {
	const Ref<InputEventMouseButton> mouse_button = p_event;
	if (mouse_button.is_valid()) {
		if (mouse_button->is_pressed() && mouse_button->get_button_index() == MouseButton::LEFT) {
			_emit_screen_signal(get_window()->get_current_screen());
			accept_event();
		}
	}
}

void ScreenSelect::_show_popup() {
	// Adapted from /scene/gui/menu_button.cpp::show_popup
	if (!get_viewport()) {
		return;
	}

	Size2 size = get_size() * get_viewport()->get_canvas_transform().get_scale();

	popup->set_size(Size2(size.width, 0));
	Point2 gp = get_screen_position();
	gp.y += size.y;
	if (is_layout_rtl()) {
		gp.x += size.width - popup->get_size().width;
	}
	popup->set_position(gp);
	popup->popup();
}

void ScreenSelect::pressed() {
	if (popup->is_visible()) {
		popup->hide();
		return;
	}

	_build_advanced_menu();
	_show_popup();
}

ScreenSelect::ScreenSelect() {
	set_button_mask(MouseButtonMask::RIGHT);
	set_theme_type_variation(SceneStringName(FlatButton));
	set_toggle_mode(true);
	set_focus_mode(FOCUS_NONE);
	set_action_mode(ACTION_MODE_BUTTON_PRESS);

	if (!EditorNode::get_singleton()->is_multi_window_enabled()) {
		set_disabled(true);
		set_tooltip_text(EditorNode::get_singleton()->get_multiwindow_support_tooltip_text());
	} else {
		set_tooltip_text(TTR("Make this panel floating.") + "\n" + TTR("Right-click to open the screen selector."));
	}

	// Create the popup.
	const Size2 borders = Size2(4, 4) * EDSCALE;

	popup = memnew(PopupPanel);
	popup->connect("popup_hide", callable_mp(static_cast<BaseButton *>(this), &ScreenSelect::set_pressed).bind(false));
	add_child(popup);

	MarginContainer *popup_root = memnew(MarginContainer);
	popup_root->add_theme_constant_override("margin_right", borders.width);
	popup_root->add_theme_constant_override("margin_top", borders.height);
	popup_root->add_theme_constant_override("margin_left", borders.width);
	popup_root->add_theme_constant_override("margin_bottom", borders.height);
	popup->add_child(popup_root);

	VBoxContainer *vb = memnew(VBoxContainer);
	vb->set_alignment(BoxContainer::ALIGNMENT_CENTER);
	popup_root->add_child(vb);

	Label *description = memnew(Label(TTR("Select Screen")));
	description->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER);
	vb->add_child(description);

	screen_list = memnew(HBoxContainer);
	screen_list->set_alignment(BoxContainer::ALIGNMENT_CENTER);
	vb->add_child(screen_list);

	popup_root->set_anchors_and_offsets_preset(PRESET_FULL_RECT);
}
