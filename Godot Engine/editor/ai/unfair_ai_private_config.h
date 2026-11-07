#pragma once

#include "core/error/error_list.h"
#include "core/string/ustring.h"

// Creates a new private UTF-8 file. Never truncates or follows an existing file.
Error unfair_ai_write_private_config(const String &p_path, const String &p_text);
