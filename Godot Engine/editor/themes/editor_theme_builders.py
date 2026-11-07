"""Functions used to generate source files during build time"""

import os

import methods


def make_unfair_loading_header(target, source, env):
    buffer = methods.get_buffer(str(source[0]))
    with methods.generated_wrapper(str(target[0])) as file:
        file.write(f"""\
inline constexpr const unsigned char unfair_loading_background_png[] = {{
    {methods.format_buffer(buffer, 1)}
}};
""")


def make_fonts_header(target, source, env):
    with methods.generated_wrapper(str(target[0])) as file:
        for src in map(str, source):
            # Saving uncompressed, since FreeType will reference from memory pointer.
            buffer = methods.get_buffer(src)
            name = os.path.splitext(os.path.basename(src))[0]

            file.write(f"""\
inline constexpr int _font_{name}_size = {len(buffer)};
inline constexpr unsigned char _font_{name}[] = {{
	{methods.format_buffer(buffer, 1)}
}};

""")
