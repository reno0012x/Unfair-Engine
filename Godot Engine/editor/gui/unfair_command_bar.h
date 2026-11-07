#pragma once

#include "scene/gui/container.h"

// Keep workspace navigation centered independently of the unequal tool groups.
class UnfairCommandBar : public Container {
	GDCLASS(UnfairCommandBar, Container);

protected:
	void _notification(int p_what);

public:
	virtual Size2 get_minimum_size() const override;
};
