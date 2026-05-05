#!/usr/bin/env python3
import os
import sys
from PIL import Image

# Recursive resize and optimize images for board game cards
# Usage: python optimize_images.py <src_dir> <dest_dir>

def main():
    if len(sys.argv) < 3:
        print("Usage: optimize_images.py <src_dir> <dest_dir>")
        sys.exit(1)
        
    src_root = sys.argv[1]
    dest_root = sys.argv[2]
    
    # 800x800 bounding box is enough for 300 DPI poker half-art
    max_size = (800, 800)
    
    # os.walk traverses the directory tree top-down
    for root, dirs, files in os.walk(src_root):
        # Calculate destination path relative to src_root
        rel_path = os.path.relpath(root, src_root)
        target_dir = os.path.join(dest_root, rel_path)
        
        # Ensure the subdirectory exists in destination
        os.makedirs(target_dir, exist_ok=True)
        
        for filename in files:
            if not filename.lower().endswith(('.png', '.jpg', '.jpeg')):
                continue
                
            src_path = os.path.join(root, filename)
            dest_path = os.path.join(target_dir, filename)
            
            # Skip if destination file is newer than source (basic optimization)
            if os.path.exists(dest_path) and os.path.getmtime(dest_path) > os.path.getmtime(src_path):
                continue

            try:
                with Image.open(src_path) as img:
                    # Convert to RGB if it has alpha channel to save space
                    if img.mode in ('RGBA', 'P'):
                        img = img.convert('RGB')
                    
                    # Resize keeping aspect ratio
                    img.thumbnail(max_size, Image.Resampling.LANCZOS)
                    
                    # Save optimized
                    if filename.lower().endswith('.png'):
                        img.save(dest_path, optimize=True)
                    else:
                        img.save(dest_path, quality=85, optimize=True)
                        
                    print(f"Optimized: {os.path.join(rel_path, filename)}")
            except Exception as e:
                print(f"Failed to process {filename}: {e}")

if __name__ == '__main__':
    main()