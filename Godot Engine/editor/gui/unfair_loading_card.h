#pragma once

#include "scene/gui/panel_container.h"

class Label;
class ProgressBar;
class TextureRect;
class VBoxContainer;

// Editor-only loading presentation. Progress values always come from the caller.
class UnfairLoadingCard : public PanelContainer {
	GDCLASS(UnfairLoadingCard, PanelContainer);

	VBoxContainer *content = nullptr;
	Label *heading = nullptr;
	Label *project_label = nullptr;
	Label *stage = nullptr;
	Label *count = nullptr;
	Label *credit = nullptr;
	TextureRect *brand = nullptr;
	ProgressBar *progress = nullptr;
	bool compact = false;
	bool applying_theme = false;

protected:
	static void _bind_methods() {}
	void _notification(int p_what);

public:
	VBoxContainer *get_content_container() const { return content; }
	ProgressBar *get_progress_bar() const { return progress; }
	void set_heading(const String &p_heading);
	void set_stage(const String &p_stage);
	void set_progress(double p_value, double p_total);
	void set_fraction(double p_fraction);
	void set_progress_visible(bool p_visible);
	void set_compact(bool p_compact);
	UnfairLoadingCard();
};
