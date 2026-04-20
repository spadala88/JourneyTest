#!/bin/bash

# Define the codes using ANSI-C quoting
BOLD_GREEN=$'\033[1;32m'
RESET=$'\033[0m'

# ONLY this specific line gets the formatting
echo "${BOLD_GREEN}Running call emulation...${RESET}"
JOURNEYS_FILTER=a_call_emulation.journey.xml ./gradlew :app:testJourneysTestDefaultDebugTestSuite


# ONLY this specific line gets the formatting
echo "${BOLD_GREEN}Running airplane mode test...${RESET}"
JOURNEYS_FILTER=b_airplane_mode_test.journey.xml ./gradlew :app:testJourneysTestDefaultDebugTestSuite

# ONLY this specific line gets the formatting
echo "${BOLD_GREEN}Running wifi test...${RESET}"
JOURNEYS_FILTER=c_wifi_test.journey.xml ./gradlew :app:testJourneysTestDefaultDebugTestSuite

# ONLY this specific line gets the formatting
echo "${BOLD_GREEN}Running mobile data test...${RESET}"
JOURNEYS_FILTER=d_mobile_data_test.journey.xml ./gradlew :app:testJourneysTestDefaultDebugTestSuite

# ONLY this specific line gets the formatting
echo "${BOLD_GREEN}All tests finished!${RESET}"