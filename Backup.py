import os
import shutil
import psutil
from datetime import datetime

# Define the source and destination directories
SOURCE_DIR = '/path/to/your/project'
DEST_DIR = '/path/to/backup/location'

def is_in_use(directory):
    """Check if any file in the directory is currently open or in use."""
    for proc in psutil.process_iter(['pid', 'name', 'open_files']):
        for file in proc.info['open_files'] or []:
            if file.path.startswith(directory):
                return True
    return False

def backup_files():
    """Backup the project directory to the destination."""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_subdir = os.path.join(DEST_DIR, f'{os.path.basename(SOURCE_DIR)}_{timestamp}')

    if not os.path.exists(backup_subdir):
        os.makedirs(backup_subdir)

    for root, dirs, files in os.walk(SOURCE_DIR):
        for file in files:
            source_file = os.path.join(root, file)
            relative_path = os.path.relpath(source_file, SOURCE_DIR)
            dest_file = os.path.join(backup_subdir, relative_path)

            os.makedirs(os.path.dirname(dest_file), exist_ok=True)
            shutil.copy2(source_file, dest_file)

if not is_in_use(SOURCE_DIR):
    backup_files()
else:
    print('Source directory is in use. Backup aborted.')
