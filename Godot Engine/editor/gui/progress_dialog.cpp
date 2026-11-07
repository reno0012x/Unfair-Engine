/**************************************************************************/
/*  progress_dialog.cpp                                                   */
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

#include "progress_dialog.h"

#include "core/math/math_funcs.h"
#include "core/object/callable_mp.h"
#include "core/os/os.h"
#include "editor/editor_node.h"
#include "editor/gui/unfair_loading_card.h"
#include "editor/settings/editor_settings.h"
#include "editor/themes/editor_scale.h"
#include "main/main.h"
#include "scene/gui/panel_container.h"
#include "scene/main/scene_tree.h"
#include "scene/main/window.h"
#include "servers/display/display_server.h"

void BackgroundProgress::_add_task(const String &p_task, const String &p_label, int p_steps) {
	_THREAD_SAFE_METHOD_
	ERR_FAIL_COND_MSG(tasks.has(p_task), "Task '" + p_task + "' already exists.");
	BackgroundProgress::Task t;
	t.hb = memnew(HBoxContainer);
	Label *l = memnew(Label);
	l->set_text(p_label + " ");
	t.hb->add_child(l);
	t.progress = memnew(ProgressBar);
	t.progress->set_theme_type_variation("PopupProgressBar");
	t.progress->set_max(MAX(1, p_steps));
	t.progress->set_value(0);
	// Tasks without a known step count should communicate activity, not a false percentage.
	if (p_steps <= 0) {
		t.progress->set_show_percentage(false);
		t.progress->set_indeterminate(!bool(EDITOR_DEF("interface/editor/appearance/reduce_motion", false)));
	}
	Control *ec = memnew(Control);
	ec->set_h_size_flags(SIZE_EXPAND_FILL);
	ec->set_v_size_flags(SIZE_EXPAND_FILL);
	t.progress->set_anchors_and_offsets_preset(Control::PRESET_FULL_RECT);
	ec->add_child(t.progress);
	ec->set_custom_minimum_size(Size2(80, 5) * EDSCALE);
	t.hb->add_child(ec);

	add_child(t.hb);

	tasks[p_task] = t;
}

void BackgroundProgress::_update() {
	_THREAD_SAFE_METHOD_

	for (const KeyValue<String, int> &E : updates) {
		if (tasks.has(E.key)) {
			_task_step(E.key, E.value);
		}
	}

	updates.clear();
}

void BackgroundProgress::_task_step(const String &p_task, int p_step) {
	_THREAD_SAFE_METHOD_

	ERR_FAIL_COND(!tasks.has(p_task));

	Task &t = tasks[p_task];
	if (p_step < 0) {
		t.progress->set_value(t.progress->get_value() + 1);
	} else {
		t.progress->set_value(p_step);
	}
}

void BackgroundProgress::_end_task(const String &p_task) {
	_THREAD_SAFE_METHOD_

	ERR_FAIL_COND(!tasks.has(p_task));
	Task &t = tasks[p_task];

	memdelete(t.hb);
	tasks.erase(p_task);
}

void BackgroundProgress::add_task(const String &p_task, const String &p_label, int p_steps) {
	callable_mp(this, &BackgroundProgress::_add_task).call_deferred(p_task, p_label, p_steps);
}

void BackgroundProgress::task_step(const String &p_task, int p_step) {
	//this code is weird, but it prevents deadlock.
	bool no_updates = true;
	{
		_THREAD_SAFE_METHOD_
		no_updates = updates.is_empty();
	}

	if (no_updates) {
		callable_mp(this, &BackgroundProgress::_update).call_deferred();
	}

	{
		_THREAD_SAFE_METHOD_
		updates[p_task] = p_step;
	}
}

void BackgroundProgress::end_task(const String &p_task) {
	callable_mp(this, &BackgroundProgress::_end_task).call_deferred(p_task);
}

////////////////////////////////////////////////

ProgressDialog *ProgressDialog::singleton = nullptr;

void ProgressDialog::_notification(int p_what) {
	switch (p_what) {
		case NOTIFICATION_INTERNAL_PROCESS: {
			const float weight = MIN(1.0f, float(OS::get_singleton()->get_ticks_usec() - panel_transition_start) / 120000.0f);
			const float remaining = 1.0f - weight;
			const float eased = 1.0f - remaining * remaining * remaining;
			center_panel->set_modulate(Color(1, 1, 1, Math::lerp(0.82f, 1.0f, eased)));
			if (weight >= 1.0f) {
				set_process_internal(false);
			}
		} break;
		case NOTIFICATION_VISIBILITY_CHANGED: {
			// Animate only the panel's presentation. Modal input, Cancel, and task completion
			// remain immediate, including when a task finishes before this transition does.
			if (center_panel) {
				const bool animate = is_visible_in_tree() && !bool(EDITOR_DEF("interface/editor/appearance/reduce_motion", false));
				panel_transition_start = OS::get_singleton()->get_ticks_usec();
				center_panel->set_modulate(Color(1, 1, 1, animate ? 0.82f : 1.0f));
				set_process_internal(animate);
			}
			Window *base_window = get_window();
			if (base_window) {
				base_window->set_taskbar_progress_value(0.0);
				if (is_visible()) {
					base_window->set_taskbar_progress_state(DisplayServerEnums::PROGRESS_STATE_NORMAL);
				} else {
					base_window->set_taskbar_progress_state(DisplayServerEnums::PROGRESS_STATE_NOPROGRESS);
				}
			}
		} break;
		case NOTIFICATION_EXIT_TREE: {
			set_process_internal(false);
		} break;
		case NOTIFICATION_THEME_CHANGED: {
			// LoadingCard owns the image, rounded clipping and content margins.
			main_border_size = Size2(48, 48) * EDSCALE;
		} break;
	}
}

void ProgressDialog::_update_ui() {
	// Run main loop for two frames.
	if (is_inside_tree()) {
		DisplayServer::get_singleton()->process_events();
		Main::iteration();
	}
}

void ProgressDialog::_popup() {
	// Activate processing of all inputs in EditorNode, and the EditorNode::input method
	// will discard every key input.
	EditorNode::get_singleton()->set_process_input(true);
	// Disable all other windows to prevent interaction with them.
	for (ObjectID wid : host_windows) {
		Window *w = ObjectDB::get_instance<Window>(wid);
		if (w) {
			w->set_process_mode(PROCESS_MODE_DISABLED);
		}
	}

	Size2 ms = main->get_combined_minimum_size();
	ms.width = MAX(620 * EDSCALE, ms.width);
	ms += main_border_size;

	center_panel->set_custom_minimum_size(ms);

	if (is_ready()) {
		_reparent_and_show();
	} else {
		callable_mp(this, &ProgressDialog::_reparent_and_show).call_deferred();
	}
}

void ProgressDialog::_reparent_and_show() {
	Window *current_window = SceneTree::get_singleton()->get_root()->get_last_exclusive_window();
	ERR_FAIL_NULL(current_window);
	reparent(current_window);

	// Ensures that events are properly released before the dialog blocks input.
	bool window_is_input_disabled = current_window->is_input_disabled();
	current_window->set_disable_input(!window_is_input_disabled);
	current_window->set_disable_input(window_is_input_disabled);

	show();
}

void ProgressDialog::add_task(const String &p_task, const String &p_label, int p_steps, bool p_can_cancel) {
	if (MessageQueue::get_singleton()->is_flushing()) {
		ERR_PRINT("Do not use progress dialog (task) while flushing the message queue or using call_deferred()!");
		return;
	}

	ERR_FAIL_COND_MSG(tasks.has(p_task), "Task '" + p_task + "' already exists.");
	ProgressDialog::Task t;
	t.task = p_task;
	t.label = p_label;
	t.steps = p_steps;
	t.vb = memnew(VBoxContainer);
	VBoxContainer *vb2 = t.vb;
	Label *task_label = memnew(Label(p_label));
	task_label->set_clip_text(true);
	task_label->add_theme_color_override(SceneStringName(font_color), Color(0.96, 0.96, 0.96));
	vb2->add_child(task_label);
	t.progress = memnew(ProgressBar);
	t.progress->set_theme_type_variation("PopupProgressBar");
	t.progress->set_max(MAX(1, p_steps));
	t.progress->set_value(0);
	t.progress->set_show_percentage(false);
	if (p_steps <= 0) {
		t.progress->set_show_percentage(false);
		t.progress->set_indeterminate(!bool(EDITOR_DEF("interface/editor/appearance/reduce_motion", false)));
	}
	vb2->add_child(t.progress);
	t.count = memnew(Label(p_steps > 0 ? vformat(TTR("0 / %d steps"), p_steps) : TTR("Working...")));
	t.count->add_theme_color_override(SceneStringName(font_color), Color(0.82, 0.82, 0.82));
	vb2->add_child(t.count);
	t.state = memnew(Label);
	t.state->set_clip_text(true);
	t.state->add_theme_color_override(SceneStringName(font_color), Color(0.92, 0.92, 0.92));
	vb2->add_child(t.state);
	main->add_child(t.vb);
	loading_card->set_heading(p_task == "loading_editor_layout" || p_task == "load_scene" ? TTR("Opening project") : TTR("Preparing assets"));
	loading_card->set_stage(p_label);

	tasks[p_task] = t;
	if (p_can_cancel) {
		cancel_hb->show();
	} else {
		cancel_hb->hide();
	}
	cancel_hb->move_to_front();
	canceled = false;
	_popup();
	if (p_can_cancel) {
		cancel->grab_focus();
	}
	_update_ui();
}

bool ProgressDialog::task_step(const String &p_task, const String &p_state, int p_step, bool p_force_redraw) {
	ERR_FAIL_COND_V(!tasks.has(p_task), canceled);

	Task &t = tasks[p_task];
	if (!p_force_redraw) {
		uint64_t tus = OS::get_singleton()->get_ticks_usec();
		if (tus - t.last_progress_tick < 200000) { //200ms
			return canceled;
		}
	}
	if (p_step < 0) {
		t.progress->set_value(t.progress->get_value() + 1);
	} else {
		t.progress->set_value(p_step);
	}

	Window *base_window = get_window();
	if (base_window) {
		base_window->set_taskbar_progress_state(t.progress->is_indeterminate() ? DisplayServerEnums::PROGRESS_STATE_INDETERMINATE : DisplayServerEnums::PROGRESS_STATE_NORMAL);
		base_window->set_taskbar_progress_value(t.progress->get_as_ratio());
	}

	t.state->set_text(p_state);
	t.state->set_tooltip_text(p_state);
	t.count->set_text(t.steps > 0 ? vformat(TTR("%d / %d steps"), int(t.progress->get_value()), t.steps) : TTR("Working..."));
	loading_card->set_stage(t.label);
	t.last_progress_tick = OS::get_singleton()->get_ticks_usec();
	_update_ui();

	return canceled;
}

void ProgressDialog::end_task(const String &p_task) {
	ERR_FAIL_COND(!tasks.has(p_task));
	Task &t = tasks[p_task];

	memdelete(t.vb);
	tasks.erase(p_task);

	if (tasks.is_empty()) {
		hide();
		EditorNode::get_singleton()->set_process_input(false);
		for (ObjectID wid : host_windows) {
			Window *w = ObjectDB::get_instance<Window>(wid);
			if (w) {
				w->set_process_mode(PROCESS_MODE_INHERIT);
			}
		}
	} else {
		const Task &remaining = tasks.begin()->value;
		loading_card->set_heading(remaining.task == "loading_editor_layout" || remaining.task == "load_scene" ? TTR("Opening project") : TTR("Preparing assets"));
		loading_card->set_stage(remaining.label);
		_popup();
	}
}

void ProgressDialog::add_host_window(ObjectID p_window) {
	host_windows.push_back(p_window);
}

void ProgressDialog::remove_host_window(ObjectID p_window) {
	host_windows.erase(p_window);
}

void ProgressDialog::_cancel_pressed() {
	canceled = true;
}

ProgressDialog::ProgressDialog() {
	// We want to cover the entire screen to prevent the user from interacting with the Editor.
	set_anchors_and_offsets_preset(Control::PRESET_FULL_RECT);
	// Be sure it's the top most component.
	set_z_index(RSE::CANVAS_ITEM_Z_MAX);
	singleton = this;
	hide();

	loading_card = memnew(UnfairLoadingCard);
	loading_card->set_progress_visible(false);
	center_panel = loading_card;
	add_child(center_panel);
	center_panel->set_h_size_flags(SIZE_SHRINK_BEGIN);
	center_panel->set_v_size_flags(SIZE_SHRINK_BEGIN);

	main = loading_card->get_content_container();
	main_border_size = Size2(48, 48) * EDSCALE;

	cancel_hb = memnew(HBoxContainer);
	main->add_child(cancel_hb);
	cancel_hb->hide();
	cancel = memnew(Button);
	cancel_hb->add_spacer();
	cancel_hb->add_child(cancel);
	cancel->set_text(TTR("Cancel"));
	cancel_hb->add_spacer();
	cancel->connect(SceneStringName(pressed), callable_mp(this, &ProgressDialog::_cancel_pressed));
}

ProgressDialog::~ProgressDialog() {
	singleton = nullptr;
}
