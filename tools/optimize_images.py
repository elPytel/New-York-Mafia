#!/usr/bin/env python3
import os
import sys
from PIL import Image

# Resize and optimize images for board game cards
# Usage: python optimize_images.py <src_dir> <dest_dir>

def main():
    if len(sys.argv) < 3:
        print("Usage: optimize_images.py <src_dir> <dest_dir>")
        sys.exit(1)
        
    src_dir = sys.argv[1]
    dest_dir = sys.argv[2]
    
    os.makedirs(dest_dir, exist_ok=True)
    
    # 800x800 bounding box is enough for 300 DPI poker half-art
    max_size = (800, 800)
    
    for filename in os.listdir(src_dir):
        if not filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
            
        src_path = os.path.join(src_dir, filename)
        dest_path = os.path.join(dest_dir, filename)
        
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
                    
                print(f"Optimized: {filename}")
        except Exception as e:
            print(f"Failed to process {filename}: {e}")

if __name__ == '__main__':
    main()