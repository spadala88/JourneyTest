import pyautogui
import time
import sys

print("Starting visual test... Do not move the mouse.")
time.sleep(2)
pyautogui.PAUSE = 1.0

try:
    # 1. Find and click the three dots
    three_dots = pyautogui.locateCenterOnScreen('three_dots_icon.png', confidence=0.8)
    if not three_dots:
        raise Exception("Could not find the Three Dots icon.")
    pyautogui.click(three_dots)
    time.sleep(2)

    # 2. Find and click the Camera tab
    camera_tab = pyautogui.locateCenterOnScreen('camera_icon.png', confidence=0.8)
    if not camera_tab:
        raise Exception("Could not find the Camera icon.")
    pyautogui.click(camera_tab)

    print("Visual automation complete!")
    sys.exit(0) # Tells Bash: SUCCESS

except Exception as e:
    print(f"Visual Test Failed: {e}")
    sys.exit(1) # Tells Bash: FAILURE