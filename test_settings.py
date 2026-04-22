import pyautogui
import time
import sys

# Give you time to manually switch to the Emulator window
print(">>> Switch to the Emulator Extended Controls NOW! You have 3 seconds... <<<")
time.sleep(3)

print("Searching for 'settings_menu.png'...")

try:
    # Look for the image. grayscale=True helps ignore macOS True Tone color changes.
    icon_location = pyautogui.locateCenterOnsave_location_new.pngScreen('settings_menu.png', confidence=0.7, grayscale=True)

    if icon_location is None:
        print("❌ FAILURE: Could not find the image on screen.")
        print("Try taking a 'tighter' screenshot with less gray background.")
        sys.exit(1)

    print(f"✅ SUCCESS: Found image at raw pixel coordinates: X={icon_location[0]}, Y={icon_location[1]}")

    # --- RETINA DISPLAY HANDLING ---
    # If the mouse jumps way off target, change 'is_retina = False' to 'is_retina = True'
    is_retina = False

    if is_retina:
        click_x = int(icon_location[0] / 2)
        click_y = int(icon_location[1] / 2)
        print(f"Retina scaling applied. Clicking at: X={click_x}, Y={click_y}")
    else:
        click_x = int(icon_location[0])
        click_y = int(icon_location[1])
        print(f"Standard scaling. Clicking at: X={click_x}, Y={click_y}")

    pyautogui.click(click_x, click_y)
    print("Click sent!")

except pyautogui.ImageNotFoundException:
    print("❌ FAILURE: Image not found. (Confidence too low or image missing)")
except Exception as e:
    print(f"❌ ERROR: Something crashed: {e}")