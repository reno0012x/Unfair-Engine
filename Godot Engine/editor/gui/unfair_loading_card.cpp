#include "unfair_loading_card.h"

#include "core/config/project_settings.h"
#include "core/io/file_access.h"
#include "core/io/image.h"
#include "core/math/math_funcs.h"
#include "core/os/os.h"
#include "core/version.h"
#include "editor/editor_string_names.h"
#include "editor/settings/editor_settings.h"
#include "editor/themes/editor_scale.h"
#include "editor/themes/unfair_loading_background.gen.h"
#include "scene/gui/box_container.h"
#include "scene/gui/color_rect.h"
#include "scene/gui/label.h"
#include "scene/gui/margin_container.h"
#include "scene/gui/progress_bar.h"
#include "scene/gui/texture_rect.h"
#include "scene/resources/image_texture.h"
#include "scene/resources/style_box_flat.h"

void UnfairLoadingCard::_notification(int p_what) {
	if (p_what == NOTIFICATION_THEME_CHANGED || p_what == NOTIFICATION_READY) {
		// Theme notifications can occur during tree entry, before the children's
		// theme caches are ready. Never mutate children during construction/exit.
		if (!is_inside_tree() || !is_ready() || applying_theme || !brand || !heading || !project_label || !stage || !count || !credit) {
			return;
		}
		applying_theme = true;
		Ref<Texture2D> logo = get_editor_theme_icon(SNAME("UnfairBrand"));
		Ref<Image> logo_image = logo.is_valid() ? logo->get_image() : Ref<Image>();
		if (logo_image.is_valid() && !logo_image->is_empty()) {
			logo_image->convert(Image::FORMAT_RGBA8);
			for (int y = 0; y < logo_image->get_height(); y++) {
				for (int x = 0; x < logo_image->get_width(); x++) {
					logo_image->set_pixel(x, y, Color(1, 1, 1, logo_image->get_pixel(x, y).a));
				}
			}
			brand->set_texture(ImageTexture::create_from_image(logo_image));
		}
		for (Label *label : { heading, project_label, stage, count, credit }) {
			label->add_theme_color_override(SceneStringName(font_color), label == credit ? Color(0.75, 0.75, 0.75) : Color(0.96, 0.96, 0.96));
		}
		heading->add_theme_font_override(SceneStringName(font), get_theme_font(SNAME("bold"), EditorStringName(EditorFonts)));
		heading->add_theme_font_size_override(SceneStringName(font_size), (compact ? 18 : 25) * EDSCALE);
		project_label->add_theme_font_override(SceneStringName(font), get_theme_font(SNAME("bold"), EditorStringName(EditorFonts)));
		credit->add_theme_font_size_override(SceneStringName(font_size), 11 * EDSCALE);
		applying_theme = false;
	}
}

void UnfairLoadingCard::set_heading(const String &p_heading) {
	heading->set_text(p_heading);
	String name = ProjectSettings::get_singleton()->get_setting("application/config/name", "");
	project_label->set_text(name.is_empty() ? TTR("Unfair project") : name);
}

void UnfairLoadingCard::set_stage(const String &p_stage) {
	stage->set_text(p_stage);
	stage->set_tooltip_text(p_stage);
}

void UnfairLoadingCard::set_progress(double p_value, double p_total) {
	const bool known = Math::is_finite(p_total) && p_total > 0 && Math::is_finite(p_value);
	progress->set_show_percentage(false);
	progress->set_indeterminate(!known && !bool(EDITOR_DEF("interface/editor/appearance/reduce_motion", false)));
	progress->set_max(known ? p_total : 1.0);
	progress->set_value(known ? CLAMP(p_value, 0.0, p_total) : 0.0);
	count->set_text(known ? vformat(TTR("%d / %d steps"), int64_t(progress->get_value()), int64_t(p_total)) : TTR("Working..."));
}

void UnfairLoadingCard::set_fraction(double p_fraction) {
	if (!Math::is_finite(p_fraction) || p_fraction < 0) {
		set_progress(0, 0);
		return;
	}
	progress->set_indeterminate(false);
	progress->set_max(100.0);
	progress->set_value(CLAMP(p_fraction, 0.0, 1.0) * 100.0);
	count->set_text(vformat(TTR("Scan progress: %d%%"), int(progress->get_value())));
}

void UnfairLoadingCard::set_progress_visible(bool p_visible) {
	progress->set_visible(p_visible);
	count->set_visible(p_visible);
}

void UnfairLoadingCard::set_compact(bool p_compact) {
	compact = p_compact;
	set_custom_minimum_size(Size2(0, compact ? 230 : 290) * EDSCALE);
	heading->add_theme_font_size_override(SceneStringName(font_size), (compact ? 18 : 25) * EDSCALE);
	credit->set_text(String(compact ? GODOT_VERSION_NAME " v" GODOT_VERSION_NUMBER : GODOT_VERSION_FULL_NAME) + "\nBuilt on Godot Engine.");
}

UnfairLoadingCard::UnfairLoadingCard() {
	set_mouse_filter(MOUSE_FILTER_PASS);
	set_clip_children_mode(CLIP_CHILDREN_AND_DRAW);
	Ref<StyleBoxFlat> panel;
	panel.instantiate();
	panel->set_bg_color(Color(0.04, 0.04, 0.05));
	panel->set_corner_radius_all(14 * EDSCALE);
	panel->set_border_width_all(0);
	panel->set_content_margin_all(0);
	add_theme_style_override(SceneStringName(panel), panel);
	TextureRect *background = memnew(TextureRect);
	background->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE);
	background->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_COVERED);
	background->set_mouse_filter(MOUSE_FILTER_IGNORE);
	Ref<Image> image;
	image.instantiate();
	const String installed_background = OS::get_singleton()->get_executable_path().get_base_dir().path_join("assets/loading/unfair-loading-background.png");
	if (!FileAccess::exists(installed_background) || image->load(installed_background) != OK) {
		image = memnew(Image(unfair_loading_background_png, sizeof(unfair_loading_background_png)));
	}
	if (!image->is_empty()) {
		background->set_texture(ImageTexture::create_from_image(image));
	}
	add_child(background);
	ColorRect *tint = memnew(ColorRect);
	tint->set_color(Color(0.015, 0.02, 0.03, 0.65));
	tint->set_mouse_filter(MOUSE_FILTER_IGNORE);
	add_child(tint);
	MarginContainer *margin = memnew(MarginContainer);
	for (const StringName &side : { SNAME("margin_left"), SNAME("margin_top"), SNAME("margin_right"), SNAME("margin_bottom") }) {
		margin->add_theme_constant_override(side, 24 * EDSCALE);
	}
	margin->set_mouse_filter(MOUSE_FILTER_PASS);
	add_child(margin);
	content = memnew(VBoxContainer);
	content->add_theme_constant_override("separation", 10 * EDSCALE);
	margin->add_child(content);
	HBoxContainer *masthead = memnew(HBoxContainer);
	masthead->add_theme_constant_override("separation", 12 * EDSCALE);
	content->add_child(masthead);
	brand = memnew(TextureRect);
	brand->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE);
	brand->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_CENTERED);
	brand->set_custom_minimum_size(Size2(32, 32) * EDSCALE);
	masthead->add_child(brand);
	heading = memnew(Label(TTR("Opening project")));
	heading->set_clip_text(true);
	heading->set_h_size_flags(SIZE_EXPAND_FILL);
	masthead->add_child(heading);
	project_label = memnew(Label);
	project_label->set_clip_text(true);
	content->add_child(project_label);
	stage = memnew(Label);
	stage->set_clip_text(true);
	stage->set_accessibility_live(AccessibilityServerEnums::LIVE_POLITE);
	content->add_child(stage);
	progress = memnew(ProgressBar);
	progress->set_show_percentage(false);
	progress->set_custom_minimum_size(Size2(0, 5) * EDSCALE);
	Ref<StyleBoxFlat> track;
	track.instantiate();
	track->set_bg_color(Color(0.2, 0.2, 0.22));
	track->set_corner_radius_all(3 * EDSCALE);
	Ref<StyleBoxFlat> fill = track->duplicate();
	fill->set_bg_color(Color(0.94, 0.94, 0.94));
	progress->add_theme_style_override("background", track);
	progress->add_theme_style_override("fill", fill);
	content->add_child(progress);
	count = memnew(Label);
	content->add_child(count);
	credit = memnew(Label);
	// This label has an explicit credit line. Automatic wrapping at its initial
	// zero width would inflate the first progress dialog's minimum height.
	credit->set_autowrap_mode(TextServer::AUTOWRAP_OFF);
	credit->set_clip_text(true);
	content->add_child(credit);
	set_compact(false);
	set_heading(TTR("Opening project"));
	set_progress(0, 0);
}
