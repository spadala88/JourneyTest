#!/bin/bash

# Define the codes using ANSI-C quoting
BOLD_GREEN=$'\033[1;32m'
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

# Helper function to run a test and log the result
run_journey() {
    local test_name=$1
    local filter_file=$2

    echo "${BOLD_GREEN}Running ${test_name}...${RESET}"

    # Run the test. We don't want the script to exit if gradlew fails, so we capture the exit code.
    JOURNEYS_FILTER="$filter_file" ./gradlew :app:testJourneysTestDefaultDebugTestSuite

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "        <tr><td>${test_name}</td><td class='pass'>PASS</td></tr>" >> $REPORT_FILE
    else
        echo "        <tr><td>${test_name}</td><td class='fail'>FAIL</td></tr>" >> $REPORT_FILE
    fi
}

# Run the tests using the helper function
run_journey "Call Emulation" "a_call_emulation.journey.xml"
run_journey "Airplane Mode" "b_airplane_mode_test.journey.xml"
run_journey "WiFi Test" "c_wifi_test.journey.xml"
run_journey "Mobile Data Test" "d_mobile_data_test.journey.xml"

# Close the HTML tags
cat <<EOT >> $REPORT_FILE
    </table>
</body>
</html>
EOT

echo "${BOLD_GREEN}All tests finished! Combined report generated at: $(pwd)/$REPORT_FILE${RESET}"