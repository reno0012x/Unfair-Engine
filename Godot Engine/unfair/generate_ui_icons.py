"""Original consistent 16px stroke icons for Unfair's navigation and tools."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
icons = {
    'Back': '<path d="m10 3-5 5 5 5M5 8h9"/>',
    'Forward': '<path d="m6 3 5 5-5 5M2 8h9"/>',
    'ArrowUp': '<path d="m3 7 5-5 5 5M8 2v12"/>',
    'Reload': '<path d="M13 6a5 5 0 1 0 0 4M13 2v4H9"/>',
    'Search': '<circle cx="6.5" cy="6.5" r="4.5"/><path d="m10 10 4 4"/>',
    'Folder': '<path d="M2 4h5l1.5 2H14v7H2ZM2 4V2.5h4L8 4"/>',
    'MakeFloating': '<path d="M7 2h7v7H7ZM4 5H2v9h9v-2"/>',
    'ToolSelect': '<path d="m3 2 10 7-5 1-2 4Z"/>',
    'ToolMove': '<path d="M8 1v14M1 8h14M5 4l3-3 3 3M5 12l3 3 3-3M4 5 1 8l3 3M12 5l3 3-3 3"/>',
    'ToolRotate': '<path d="M13 5a5.5 5.5 0 1 0 .2 6M13 1v4H9"/>',
    'ToolScale': '<path d="M9 2h5v5M14 2 7 9M6 5H2v9h9v-4"/>',
    'MainPlay': '<path fill="#fff" stroke="none" d="M4 2v12l10-6Z"/>',
    'Pause': '<path d="M5 3v10M11 3v10" stroke-width="3"/>',
    'Stop': '<rect x="3" y="3" width="10" height="10" rx="1"/>',
}
for name, shape in icons.items():
    path = root/'editor/icons'/f'{name}.svg'
    if not path.exists():
        continue
    backup = root/'unfair/original-assets/editor/icons'/path.name
    if not backup.exists():
        backup.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,backup)
    path.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><g fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'+shape+'</g></svg>\n',encoding='utf-8')
print('Generated Unfair navigation, transform and transport icons.')
