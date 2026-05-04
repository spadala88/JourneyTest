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
    time.sleep(0.2)
    print("Sending deliberate Android tap...")
    # 2. Simulate a human tap (ACTION_DOWN -> wait 100ms -> ACTION_UP)
    pyautogui.mouseDown()
    time.sleep(0.1)
    pyautogui.mouseUp()

    print("Clicks complete!")

except pyautogui.ImageNotFoundException:
    print("❌ FAILURE: Image not found. (Confidence too low or image missing)")
except Exception as e:
    print(f"❌ ERROR: Something crashed: {e}")
EOF
}

# Helper function to visually locate and click any UI text using EasyOCR (Cross-Platform)
click_text_element() {
    local TARGET_TEXT="$1"

    # Safety check to ensure target text was provided
    if [ -z "$TARGET_TEXT" ]; then
        echo "Error: Please provide target text to search for."
        echo "Usage: click_text_element \"Settings\""
        return 1
    fi

    # STEALTH FIX: Removed the exact target text from the terminal output
    echo -e "\033[1;33mRunning Strict Text Click Action (Target hidden to prevent self-reading)...\033[0m"

    # Pass the TARGET_TEXT variable to Python as an argument
    python3 - "$TARGET_TEXT" <<'EOF'
import sys
import time
import os
import tempfile
import platform

try:
    import pyautogui
    import easyocr
except ImportError as e:
    print(f"Import Error: {e}. Please ensure pyautogui and easyocr are installed.")
    sys.exit(1)

target_text = sys.argv[1]

print(">>> Switch to the Emulator Extended Controls NOW! You have 3 seconds... <<<")
time.sleep(3)

# STEALTH FIX: Removed target text from this print statement
print("Taking screenshot...")

try:
    # 1. Use an OS-Agnostic Temporary Directory
    temp_dir = tempfile.gettempdir()
    screenshot_path = os.path.join(temp_dir, "temp_screen_ocr.png")

    is_mac = platform.system() == 'Darwin'

    # 2. Hybrid Screenshot Logic to bypass macOS strict permission inheritance
    if is_mac:
        os.system(f"screencapture -x {screenshot_path}")
    else:
        pyautogui.screenshot(screenshot_path)

    if not os.path.exists(screenshot_path):
        print(f"❌ FAILURE: The system could not save the screenshot to {screenshot_path}")
        sys.exit(1)

    # Now that the screenshot is taken, it is safe to print what we are looking for!
    print(f"Searching screenshot for '{target_text}'...")

    # 3. Initialize EasyOCR
    reader = easyocr.Reader(['en'], gpu=False, verbose=False)
    results = reader.readtext(screenshot_path)

    found_bbox = None
    found_text = None
    found_prob = 0.0

    # 4. Search the AI's results
    for (bbox, text, prob) in results:
        if target_text.lower() in text.lower():
            found_bbox = bbox
            found_text = text
            found_prob = prob
            break

    # Clean up the temporary screenshot
    if os.path.exists(screenshot_path):
        os.remove(screenshot_path)

    # 5. Handle Failure
    if found_bbox is None:
        print(f"❌ FAILURE: Could not find text matching '{target_text}' on screen.")
        sys.exit(1)

    print(f"✅ SUCCESS: Found '{found_text}' with {int(found_prob * 100)}% confidence!")

    # 6. Calculate Center Coordinates from the Bounding Box
    raw_x = int((found_bbox[0][0] + found_bbox[2][0]) / 2)
    raw_y = int((found_bbox[0][1] + found_bbox[2][1]) / 2)

    # 7. Dynamic OS Resolution Scaling (Retina Math)
    divisor = 2 if is_mac else 1

    click_x = int(raw_x / divisor)
    click_y = int(raw_y / divisor)

    print(f"Moving mouse to X={click_x}, Y={click_y}...")
    pyautogui.moveTo(click_x, click_y, duration=0.5)
    time.sleep(0.5)

    # Focus click
    print("Sending focus click...")
    pyautogui.click()
    time.sleep(0.2)
    print("Sending deliberate Android tap...")
    # 2. Simulate a human tap (ACTION_DOWN -> wait 100ms -> ACTION_UP)
    pyautogui.mouseDown()
    time.sleep(0.1)
    pyautogui.mouseUp()

    print("Clicks complete!")


except Exception as e:
    print(f"❌ ERROR: Something crashed: {e}")
EOF
}

# Helper function to launch an Android Emulator silently
launch_emulator() {
    local AVD_NAME="$1"

    # Safety check
    if [ -z "$AVD_NAME" ]; then
        echo "❌ Error: Please provide the exact name of the emulator to launch."
        echo "To see a list of your available emulators, run: emulator -list-avds"
        return 1
    fi

    echo -e "\033[1;34mBooting up Android Emulator: '${AVD_NAME}'...\033[0m"

    # Launch in background AND send all logs to the void
    emulator -avd "$AVD_NAME" -no-boot-anim > emulator_debug.log 2>&1 &

    # Emulators take time to boot. Give it a generous buffer before the script continues.
    echo "Waiting 5 seconds for the Android OS to fully boot..."
    sleep 5
}

# Helper function to verify if a specific app is currently on the screen
verify_snapshot_state() {
    local EXPECTED_PACKAGE="$1"

    echo "Checking if snapshot loaded correctly (Looking for: $EXPECTED_PACKAGE)..."

    # Use ADB to ask Android what window is currently in focus
    # Note: Depending on your OS setup, you may need to specify the full path to adb
    local CURRENT_FOCUS=$(adb shell dumpsys window | grep mCurrentFocus)

    # Check if the expected package name is in the output
    if [[ "$CURRENT_FOCUS" == *"$EXPECTED_PACKAGE"* ]]; then
        echo -e "\033[1;32m✅ SUCCESS: Snapshot verified. $EXPECTED_PACKAGE is on screen.\033[0m"
        return 0 # Success
    else
        echo -e "\033[1;31m❌ FAILURE: Snapshot mismatch or cold boot. Expected $EXPECTED_PACKAGE.\033[0m"
        echo "Current focus is: $CURRENT_FOCUS"
        return 1 # Failure
    fi
}





download_system_image() {
    # 1. Authenticate
    echo "Running uplink-helper login..."
    uplink-helper login || return 1

    # 2. Define the exact Staging URL based on the filename the CLI exposed
    local ZIP_NAME="arm64-v8a-playstore-ps16k-CANARY_r11.zip"
    local FULL_URL="http://adt-proxy.uplink2.goog:999/rapid/h5ub4nb5-zzka-r44z-w36z-fukmdt4c3wox/android/repository/sys-img/google_apis_playstore/${ZIP_NAME}"

    # Adjust this to where your SDK actually lives
    local SDK_PATH="$HOME/Library/Android/sdk"
    local DEST_DIR="$SDK_PATH/system-images/android-CANARY/google_apis_playstore_ps16k/arm64-v8a"

    echo -e "${BOLD_BLUE}Bypassing CLI and downloading directly from staging...${RESET}"

    # --- ADDED: Print the exact URL being used ---
    echo -e "${BOLD_GREEN}Target Download URL: ${FULL_URL}${RESET}"

    # 3. Create the directory structure manually
    mkdir -p "$DEST_DIR"

    # 4. Download directly via curl
    curl -L -o "./$ZIP_NAME" "$FULL_URL"

    if [ $? -ne 0 ]; then
        echo -e "${BOLD_RED}❌ FAILURE: Direct download failed.${RESET}"
        return 1
    fi

    # 5. Extract into the SDK folder
    echo "Extracting system image to SDK folder..."
    unzip -q "./$ZIP_NAME" -d "$DEST_DIR"

    # 6. Cleanup
    rm "./$ZIP_NAME"
    echo -e "${BOLD_GREEN}✅ SUCCESS: System image downloaded and extracted successfully.${RESET}"
}

download_system_image_android() {
    local API_LEVEL="$1"
    local SYS_IMG_TAG="$2"
    local ABI="$3"

    # 1. Safety check
    if [ -z "$API_LEVEL" ] || [ -z "$SYS_IMG_TAG" ] || [ -z "$ABI" ]; then
        echo -e "${BOLD_RED}❌ Error: Missing configuration parameters.${RESET}"
        return 1
    fi

    local PACKAGE_PATH="system-images;android-${API_LEVEL};${SYS_IMG_TAG};${ABI}"
    local ANDROID_CMD="android"

    echo -e "${BOLD_BLUE}Preparing to download: ${PACKAGE_PATH}...${RESET}"

    if ! command -v "$ANDROID_CMD" &> /dev/null; then
        echo -e "${BOLD_RED}❌ Error: Could not find 'android' cli in the system PATH.${RESET}"
        return 1
    fi

    # 2. NUKE THE CACHE
    echo "Clearing global SDK cache..."
    rm -rf ~/.android/cache
    rm -rf ./.temp

    # 3. Authenticate
    echo "Running uplink-helper login..."
    uplink-helper login
    if [ $? -ne 0 ]; then
        echo -e "${BOLD_RED}❌ FAILURE: uplink-helper login failed.${RESET}"
        return 1
    fi

    # 4. Target the Staging XML directly (Without forcing JVM proxy tunnels)
    echo "Pointing CLI to staging manifests..."

    local STAGING_URL="http://adt-proxy.uplink2.goog:999/rapid/h5ub4nb5-zzka-r44z-w36z-fukmdt4c3wox/android/repository/"

    export SDK_TEST_BASE_URL="$STAGING_URL"
    # Removed the proxyHost flags to prevent the SSL crash, kept the custom.url flag
    export _JAVA_OPTIONS="-DSDK_TEST_BASE_URL=$STAGING_URL -Dandroid.sdk.custom.url=${STAGING_URL}sys-img2-1.xml"

    # 5. Execute
    echo "Downloading system image..."
    yes | "$ANDROID_CMD" sdk install --canary "$PACKAGE_PATH"

    if [ $? -eq 0 ]; then
        echo -e "${BOLD_GREEN}✅ SUCCESS: System image downloaded successfully.${RESET}"
    else
        echo -e "${BOLD_RED}❌ FAILURE: Failed to download system image.${RESET}"
        return 1
    fi
}

download_system_image_sdkmanager() {
    local API_LEVEL="$1"
    local SYS_IMG_TAG="$2"
    local ABI="$3"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Executing download_system_image: API=$API_LEVEL, TAG=$SYS_IMG_TAG, ABI=$ABI" >> "$LOG_FILE"

    # 1. Safety check
    if [ -z "$API_LEVEL" ] || [ -z "$SYS_IMG_TAG" ] || [ -z "$ABI" ]; then
        echo -e "${BOLD_RED}❌ Error: Missing configuration parameters.${RESET}"
        return 1
    fi

    local PACKAGE_PATH="system-images;android-${API_LEVEL};${SYS_IMG_TAG};${ABI}"
    local SDKMANAGER_CMD="./cmdline-tools/latest/bin/sdkmanager"

    echo -e "${BOLD_BLUE}Preparing to download: ${PACKAGE_PATH}...${RESET}"

    if [ ! -f "$SDKMANAGER_CMD" ]; then
        echo -e "${BOLD_RED}❌ Error: Could not find local sdkmanager.${RESET}"
        return 1
    fi

    # 2. Clean up the temp folder just in case the previous script runs left garbage behind
    echo "Clearing temporary cache..."
    rm -rf ./.temp

    # 3. Accept licenses silently so it doesn't prompt you
    echo "Accepting Android SDK licenses..."
    yes | "$SDKMANAGER_CMD" --licenses > /dev/null 2>&1

    # 4. Run EXACTLY the command from your screenshot (No extra flags, no pipes)
    echo "Downloading system image..."
    "$SDKMANAGER_CMD" "$PACKAGE_PATH"

    if [ $? -eq 0 ]; then
        echo -e "${BOLD_GREEN}✅ SUCCESS: System image downloaded successfully.${RESET}"
    else
        echo -e "${BOLD_RED}❌ FAILURE: Failed to download system image.${RESET}"
        return 1
    fi
}

# Helper function to create an AVD using precise system image
create_avd() {
    local AVD_NAME="$1"
    local DEVICE_PROFILE="$2"
    local API_LEVEL="$3"
    local SYS_IMG_TAG="$4"
    local ABI="$5"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Executing create_avd: NAME=$AVD_NAME, DEVICE=$DEVICE_PROFILE, API=$API_LEVEL, TAG=$SYS_IMG_TAG, ABI=$ABI"

    # 1. Safety check
    if [ -z "$AVD_NAME" ] || [ -z "$DEVICE_PROFILE" ] || [ -z "$API_LEVEL" ] || [ -z "$SYS_IMG_TAG" ] || [ -z "$ABI" ]; then
        echo -e "${BOLD_RED}❌ Error: Missing configuration parameters.${RESET}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Missing configuration parameters."
        return 1
    fi

    # 2. Agentic Architecture Auto-Correction for Apple Silicon
    if [ "$(uname)" == "Darwin" ] && [ "$(uname -m)" == "arm64" ]; then
        if [ "$ABI" == "x86_64" ]; then
            echo -e "${BOLD_BLUE}⚠️ Apple Silicon detected! Auto-correcting ABI from x86_64 to arm64-v8a...${RESET}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] Apple Silicon detected! Auto-correcting ABI from x86_64 to arm64-v8a."
            ABI="arm64-v8a"
        fi
    fi

    # 3. Set strict local paths and environment variables
    local SDK_ROOT="$(pwd)"
    export ANDROID_SDK_ROOT="$SDK_ROOT"

    local SDKMANAGER_CMD="./cmdline-tools/latest/bin/sdkmanager"
    local AVDMANAGER_CMD="./cmdline-tools/latest/bin/avdmanager"

    if [ ! -f "$AVDMANAGER_CMD" ] || [ ! -f "$SDKMANAGER_CMD" ]; then
        echo -e "${BOLD_RED}❌ ERROR: Command line tools missing at project root.${RESET}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Command line tools missing at project root."
        return 1
    fi

    echo -e "${BOLD_BLUE}Creating Android Virtual Device: '${AVD_NAME}' (API: ${API_LEVEL})...${RESET}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Creating Android Virtual Device: $AVD_NAME"

    local PLATFORM_PATH="platforms;android-${API_LEVEL}"
    local PACKAGE_PATH="system-images;android-${API_LEVEL};${SYS_IMG_TAG};${ABI}"

    # FIX: Accept licenses here as well just in case this function is run independently
    echo "Accepting Android SDK licenses for AVD creation..."
    yes | "$SDKMANAGER_CMD" --licenses --sdk_root="$SDK_ROOT" > /dev/null 2>&1

    echo "Ensuring required SDK platform and system image are installed using root tools..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Executing sdkmanager to verify platform and image."

    # 4. Execute root sdkmanager without 'yes |' stream piping
    "$SDKMANAGER_CMD" --sdk_root="$SDK_ROOT" --channel=3 "$PLATFORM_PATH" "$PACKAGE_PATH" > /dev/null 2>&1

    echo "Building the emulator..."
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Building the AVD via avdmanager..."

    # 5. Build the AVD using root avdmanager (removed 'echo no |' to prevent piping crashes)
    "$AVDMANAGER_CMD" create avd -n "$AVD_NAME" -k "$PACKAGE_PATH" -d "$DEVICE_PROFILE" --force

    if [ $? -eq 0 ]; then
        echo -e "${BOLD_GREEN}✅ SUCCESS: AVD created successfully with $PACKAGE_PATH.${RESET}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] AVD created successfully."
    else
        echo -e "${BOLD_RED}❌ FAILURE: Failed to create AVD via avdmanager.${RESET}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] Failed to create AVD via avdmanager."
        return 1
    fi
}

# Helper function to authenticate and configure staging SDK URLs
setup_staging_env() {
    echo -e "${BOLD_BLUE}Configuring internal staging environment URLs...${RESET}"

    # 1. Authenticate the proxy connection
    echo "Running uplink-helper login (This may require manual interaction)..."
    uplink-helper login

    # Check if the login was successful
    if [ $? -ne 0 ]; then
        echo -e "${BOLD_RED}❌ FAILURE: uplink-helper login failed. Cannot access staging repository.${RESET}"
        return 1
    fi

    # 2. Export the staging URL variable
    # By exporting this, sdkmanager and avdmanager will automatically use this URL instead of the public one
    export SDK_TEST_BASE_URL="http://adt-proxy.uplink2.goog:999/rapid/h5ub4nb5-zzka-r44z-w36z-fukmdt4c3wox/android/repository/"

    echo -e "${BOLD_GREEN}✅ SUCCESS: SDK_TEST_BASE_URL exported successfully.${RESET}"
}

# --- TEST EXECUTION ORDER ---
# Click the Settings menu
#setup_staging_env

# download the  system image before creating the AVD:
#download_system_image_sdkmanager "CANARY" "google_apis_playstore_ps16k" "arm64-v8a"

# Create the emulator using an image we know is already installed and valid
create_avd "Pixel_7_Pro_API_36" "pixel_7_pro" "CANARY" "google_apis_playstore_ps16k" "arm64-v8a"

# Launch in background and save logs to a file
launch_emulator "Pixel_7_Pro_API_36"

sleep 30

# Click the Settings menu
click_text_element "YouTube"
sleep 1
#open_extended_controls
click_ui_element "three_dots.png"
# Wait a moment for the new menu to load
sleep 1
# Click the Settings menu
click_text_element "Snapshots"
sleep 1
# Click the Settings menu
click_text_element "TAKE SNAPSHOT"
sleep 1
#open_extended_controls
click_ui_element "close_emu.png"
sleep 10
# Launch in background and save logs to a file
launch_emulator "Pixel_7_Pro_API_36"
sleep 5
verify_snapshot_state "com.google.android.youtube"
# Run the tests using the helper function
run_journey "Call Emulation" "a_call_emulation.journey.xml"
#run_journey "Airplane Mode" "b_airplane_mode_test.journey.xml"
#run_journey "WiFi Test" "c_wifi_test.journey.xml"
#run_journey "Mobile Data Test" "d_mobile_data_test.journey.xml"

#sleep 1
# Click the snapshot menu
#click_ui_element "close_emu.png"
#run_journey
# Close the HTML tags
cat <<EOT >> $REPORT_FILE
    </table>
</body>
</html>
EOT

echo "${BOLD_GREEN}All tests finished! Combined report generated at: $(pwd)/$REPORT_FILE${RESET}"