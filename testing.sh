#!/bin/bash

# Define the codes using ANSI-C quoting
BOLD_GREEN=$'\033[1;32m'
BOLD_BLUE=$'\033[1;34m'
BOLD_RED=$'\033[1;31m'
RESET=$'\033[0m'

# Define report file
REPORT_FILE="journey_results.html"

# Initialize HTML report
cat <<EOT > $REPORT_FILE
<!DOCTYPE html>
<html>
<head>
    <title>Journey Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        table { border-collapse: collapse; width: 50%; max-width: 600px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
    </style>
</head>
<body>
    <h1>Journey Test Execution Report</h1>
    <table>
        <tr>
            <th>Test Name</th>
            <th>Status</th>
        </tr>
EOT

# Helper function to open extended controls cross-platform
open_extended_controls() {
    echo -e "\033[1;34mOpening Extended Controls via UI Automation...\033[0m"

    # Execute inline Python script to handle cross-platform shortcuts
    python3 - <<'EOF'
import platform
import pyautogui
import time
import sys
import os

# SAFETY MEASURE: Force release all modifier keys in case a previous run got stuck
pyautogui.keyUp('command')
pyautogui.keyUp('shift')
pyautogui.keyUp('ctrl')
pyautogui.keyUp('alt')

try:
    os_name = platform.system()

    if os_name == 'Darwin':  # macOS
        print("Forcing Emulator to the foreground...")

        # AppleScript to force the application forward
        focus_script = """osascript -e '
        try
            tell application "Emulator" to activate
        on error
            tell application "System Events"
                set emuProcesses to (every process whose name contains "qemu-system" or name is "Emulator")
                if (count of emuProcesses) > 0 then
                    set the frontmost of item 1 of emuProcesses to true
                end if
            end tell
        end try
        '"""

        os.system(focus_script)
        time.sleep(2) # Wait for macOS window animations

        # Explicitly press and release keys to prevent the "stuck modifier" bug
        pyautogui.keyDown('command')
        pyautogui.keyDown('shift')
        pyautogui.press('u')
        pyautogui.keyUp('shift')
        pyautogui.keyUp('command')

        print("Sent Cmd + Shift + U")
        time.sleep(1) # Buffer before exit

    elif os_name in ['Windows', 'Linux']:
        print(">>> PLEASE CLICK THE EMULATOR WINDOW NOW! (You have 3 seconds) <<<")
        time.sleep(3)

        # Explicit keystrokes for Windows/Linux too
        pyautogui.keyDown('ctrl')
        pyautogui.keyDown('shift')
        pyautogui.press('u')
        pyautogui.keyUp('shift')
        pyautogui.keyUp('ctrl')

    else:
        print(f"Unsupported OS for automation: {os_name}")
        sys.exit(1)

except ImportError:
    print("Error: pyautogui is not installed. Please run: pip3 install pyautogui")
    sys.exit(1)
except Exception as e:
    print(f"UI Automation error: {e}")

    # Final safety net release on error
    pyautogui.keyUp('command')
    pyautogui.keyUp('shift')
    pyautogui.keyUp('ctrl')
    sys.exit(1)
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to open Extended Controls. Continuing test anyway..."
    fi

    sleep 2
}

# Helper function to run a test and log the result
run_journey() {
    local test_name=$1
    local filter_file=$2

    echo "${BOLD_GREEN}Running ${test_name}...${RESET}"

    # Run the test
    JOURNEYS_FILTER="$filter_file" ./gradlew :app:testJourneysTestDefaultDebugTestSuite

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "        <tr><td>${test_name}</td><td class='pass'>PASS</td></tr>" >> $REPORT_FILE
    else
        echo "        <tr><td>${test_name}</td><td class='fail'>FAIL</td></tr>" >> $REPORT_FILE
    fi
}




# Helper function to visually locate and click any UI element
click_ui_element() {
    local IMAGE_NAME="$1"

    # Safety check to ensure an image name was provided
    if [ -z "$IMAGE_NAME" ]; then
        echo "Error: Please provide a screenshot filename."
        echo "Usage: click_ui_element \"image_name.png\""
        return 1
    fi

    echo -e "\033[1;33mRunning Strict Click Action for '${IMAGE_NAME}'...\033[0m"

    # Pass the IMAGE_NAME variable to Python as an argument
    python3 - "$IMAGE_NAME" <<'EOF'
import sys
import time

try:
    import pyautogui
    import cv2
except ImportError as e:
    print(f"Import Error: {e}. Please ensure pyautogui and opencv-python are installed.")
    sys.exit(1)

# Read the image name passed from Bash
target_image = sys.argv[1]

print(">>> Switch to the Emulator Extended Controls NOW! You have 3 seconds... <<<")
time.sleep(3)

print(f"Searching strictly for '{target_image}'...")

try:
    # Use the dynamic target_image variable instead of a hardcoded string
    icon_location = pyautogui.locateCenterOnScreen(target_image, confidence=0.9)

    if icon_location is None:
        print(f"❌ FAILURE: Could not find '{target_image}' on screen.")
        print(f"Try retaking '{target_image}' to be tighter around the target.")
        sys.exit(1)

    print(f"✅ SUCCESS: Found image at raw pixel coordinates: X={icon_location[0]}, Y={icon_location[1]}")

    # Locked Retina Math to True (Divide by 2) to prevent driving off-screen
    click_x = int(icon_location[0] / 2)
    click_y = int(icon_location[1] / 2)

    print(f"Moving mouse to X={click_x}, Y={click_y}...")
    pyautogui.moveTo(click_x, click_y, duration=0.5)
    time.sleep(0.5)

    # Focus click
    print("Sending focus click...")
    pyautogui.click()
    time.sleep(0.3)

    # The Wiggle Click bypass
    print("Sending 'wiggle' click...")
    pyautogui.mouseDown()
    time.sleep(0.05)
    pyautogui.moveRel(1, 1)
    time.sleep(0.05)
    pyautogui.moveRel(-1, -1)
    pyautogui.mouseUp()

    print("Clicks complete!")

except pyautogui.ImageNotFoundException:
    print("❌ FAILURE: Image not found. (Confidence too low or image missing)")
except Exception as e:
    print(f"❌ ERROR: Something crashed: {e}")
EOF
}


# --- TEST EXECUTION ORDER ---

# 1. Open the controls
#open_extended_controls
click_ui_element "three_dots.png"
# Wait a moment for the new menu to load
sleep 1
# Click the Settings menu
click_ui_element "settings_menu.png"
sleep 1
# Click the snapshot menu
click_ui_element "snapshot.png"

# Close the HTML tags
cat <<EOT >> $REPORT_FILE
    </table>
</body>
</html>
EOT

echo "${BOLD_GREEN}All tests finished! Combined report generated at: $(pwd)/$REPORT_FILE${RESET}"