#!/usr/bin/env python3
"""
Generate base64 encoded icon data for the CloudToLocalLLM tray daemon.

This script converts the existing monochrome tray icons to base64 encoded strings
that can be embedded directly in the Python daemon code.
"""

import os
import sys
import base64
from pathlib import Path
from PIL import Image, ImageDraw

def create_simple_icon(size=16, state="idle"):
    """Create a simple monochrome icon programmatically"""
    # Create a transparent image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Define colors for different states
    colors = {
        "idle": (128, 128, 128, 255),      # Gray
        "connected": (0, 128, 0, 255),     # Green
        "error": (128, 0, 0, 255)          # Red
    }
    
    color = colors.get(state, colors["idle"])
    
    # Draw a simple circle icon
    margin = 2
    draw.ellipse([margin, margin, size-margin, size-margin], 
                fill=color, outline=color)
    
    # Add a small dot in the center for connected state
    if state == "connected":
        center = size // 2
        dot_size = 2
        draw.ellipse([center-dot_size, center-dot_size, 
                     center+dot_size, center+dot_size], 
                    fill=(255, 255, 255, 255))
    
    # Add an X for error state
    elif state == "error":
        margin = 4
        draw.line([margin, margin, size-margin, size-margin], 
                 fill=(255, 255, 255, 255), width=2)
        draw.line([margin, size-margin, size-margin, margin], 
                 fill=(255, 255, 255, 255), width=2)
    
    return img

def image_to_base64(img):
    """Convert PIL Image to base64 string"""
    import io
    buffer = io.BytesIO()
    img.save(buffer, format='PNG')
    img_data = buffer.getvalue()
    return base64.b64encode(img_data).decode('utf-8')

def load_existing_icon(icon_path):
    """Load an existing icon file and convert to base64"""
    try:
        if os.path.exists(icon_path):
            with open(icon_path, 'rb') as f:
                img_data = f.read()
            return base64.b64encode(img_data).decode('utf-8')
    except Exception as e:
        print(f"Failed to load {icon_path}: {e}")
    return None

def generate_icon_data():
    """Generate base64 icon data for all states"""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    assets_dir = project_root / "assets" / "images"
    
    icons = {}
    
    # Try to use existing monochrome icons first
    icon_files = {
        "idle": "tray_icon_mono_16.png",
        "connected": "tray_icon_contrast_16.png", 
        "error": "tray_icon_dark_16.png"
    }
    
    for state, filename in icon_files.items():
        icon_path = assets_dir / filename
        base64_data = load_existing_icon(icon_path)
        
        if base64_data:
            print(f"✓ Loaded existing icon for {state}: {filename}")
            icons[state] = base64_data
        else:
            print(f"⚠ Creating fallback icon for {state}")
            img = create_simple_icon(16, state)
            icons[state] = image_to_base64(img)
    
    return icons

def generate_python_code(icons):
    """Generate Python code with embedded icon data"""
    code = '''    def _get_icon_data(self, state: str = "idle") -> bytes:
        """Get base64 encoded icon data for different states"""
        # Base64 encoded monochrome icons (16x16 PNG)
        # Generated from CloudToLocalLLM assets
        icons = {
'''
    
    for state, data in icons.items():
        # Split long base64 strings into multiple lines for readability
        lines = [data[i:i+80] for i in range(0, len(data), 80)]
        code += f'            "{state}": (\n'
        for line in lines[:-1]:
            code += f'                "{line}"\n'
        code += f'                "{lines[-1]}"\n'
        code += '            ),\n'
    
    code += '''        }
        
        icon_b64 = icons.get(state, icons["idle"])
        return base64.b64decode(icon_b64)'''
    
    return code

def main():
    """Main function"""
    print("CloudToLocalLLM Tray Icon Generator")
    print("=" * 40)
    
    # Generate icon data
    icons = generate_icon_data()
    
    # Generate Python code
    python_code = generate_python_code(icons)
    
    # Print the generated code
    print("\nGenerated Python code:")
    print("-" * 40)
    print(python_code)
    print("-" * 40)
    
    # Save to file
    output_file = Path(__file__).parent / "generated_icon_code.py"
    with open(output_file, 'w') as f:
        f.write("# Generated icon code for CloudToLocalLLM tray daemon\n")
        f.write("import base64\n\n")
        f.write(python_code)
    
    print(f"\n✓ Generated code saved to: {output_file}")
    print("\nTo use this code:")
    print("1. Copy the _get_icon_data method to tray_daemon.py")
    print("2. Replace the existing _get_icon_data method")
    print("3. Rebuild the daemon executable")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
