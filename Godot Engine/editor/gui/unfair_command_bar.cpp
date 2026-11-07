#include "unfair_command_bar.h"

Size2 UnfairCommandBar::get_minimum_size() const {
	Size2 minimum;
	int count = 0;
	for (int i = 0; i < get_child_count(); i++) {
		Control *child = as_sortable_control(get_child(i));
		if (child) {
			const Size2 size = child->get_combined_minimum_size();
			minimum.x += size.x;
			minimum.y = MAX(minimum.y, size.y);
			count++;
		}
	}
	minimum.x += MAX(0, count - 1) * get_theme_constant("separation", "HBoxContainer");
	return minimum;
}

void UnfairCommandBar::_notification(int p_what) {
	if (p_what != NOTIFICATION_SORT_CHILDREN || get_child_count() != 3) {
		return;
	}
	Control *left = Object::cast_to<Control>(get_child(0));
	Control *center = Object::cast_to<Control>(get_child(1));
	Control *right = Object::cast_to<Control>(get_child(2));
	const float width = get_size().x;
	const float height = get_size().y;
	const float gap = get_theme_constant("separation", "HBoxContainer");
	const float left_width = left->get_combined_minimum_size().x;
	const float right_width = right->get_combined_minimum_size().x;
	const float center_width = center->get_combined_minimum_size().x;
	const float center_x = CLAMP((width - center_width) * 0.5f, left_width + gap, MAX(left_width + gap, width - right_width - gap - center_width));
	Rect2 regions[] = { Rect2(0, 0, left_width, height), Rect2(center_x, 0, center_width, height), Rect2(width - right_width, 0, right_width, height) };
	for (int i = 0; i < 3; i++) {
		if (is_layout_rtl()) {
			regions[i].position.x = width - regions[i].get_end().x;
		}
		fit_child_in_rect(Object::cast_to<Control>(get_child(i)), regions[i]);
	}
}
