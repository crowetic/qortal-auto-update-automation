#!/bin/bash

# Check if version argument is passed
if [ -z "$1" ]; then
    echo "Usage: $0 <VERSION>"
    exit 1
fi

VERSION="$1"

# Repository and branch information
REPO="Qortal/qortal"
BRANCH="master"
WORKING_QORTAL_DIR='./qortal'

# Fetch the latest 100 commits
COMMITS_JSON=$(curl -s "https://api.github.com/repos/${REPO}/commits?sha=${BRANCH}&per_page=100")

# Extract bump version commits
BUMP_COMMITS=$(echo "$COMMITS_JSON" | jq -r '.[] | select(.commit.message | test("bump version to"; "i")) | .sha')

CURRENT_BUMP_COMMIT=$(echo "$COMMITS_JSON" | jq -r ".[] | select(.commit.message | test(\"bump version to ${VERSION}\"; \"i\")) | .sha" | head -n1)
PREV_BUMP_COMMIT=$(echo "$BUMP_COMMITS" | sed -n '2p')

if [ -z "$CURRENT_BUMP_COMMIT" ]; then
    echo "Error: Could not find bump commit for version ${VERSION} in ${REPO}/${BRANCH}"
    exit 1
fi

# Get changelog between previous and current commit
echo "Generating changelog between ${PREV_BUMP_COMMIT} and ${CURRENT_BUMP_COMMIT}..."
CHANGELOG=$(curl -s "https://api.github.com/repos/${REPO}/compare/${PREV_BUMP_COMMIT}...${CURRENT_BUMP_COMMIT}" | jq -r '.commits[] | "- " + .sha[0:7] + " " + .commit.message')

# Fetch latest commit timestamp from GitHub API for final file timestamping
COMMIT_API_URL="https://api.github.com/repos/${REPO}/commits?sha=${BRANCH}&per_page=1"
COMMIT_TIMESTAMP=$(curl -s "${COMMIT_API_URL}" | jq -r '.[0].commit.committer.date')

if [ -z "${COMMIT_TIMESTAMP}" ] || [ "${COMMIT_TIMESTAMP}" == "null" ]; then
    echo "Error: Unable to retrieve the latest commit timestamp from GitHub API."
    exit 1
fi

# Define file names
JAR_FILE="qortal/qortal.jar"
EXE_FILE="qortal.exe"
ZIP_FILE="qortal.zip"

calculate_hashes() {
    local file="$1"
    echo "Calculating hashes for ${file}..."
    MD5=$(md5sum "${file}" | awk '{print $1}')
    SHA1=$(sha1sum "${file}" | awk '{print $1}')
    SHA256=$(sha256sum "${file}" | awk '{print $1}')
    echo "MD5: ${MD5}, SHA1: ${SHA1}, SHA256: ${SHA256}"
}

# Hashes for qortal.jar
if [ -f "${JAR_FILE}" ]; then
    calculate_hashes "${JAR_FILE}"
    JAR_MD5=${MD5}
    JAR_SHA1=${SHA1}
    JAR_SHA256=${SHA256}
else
    echo "Error: ${JAR_FILE} not found."
    exit 1
fi

# Hashes for qortal.exe
if [ -f "${EXE_FILE}" ]; then
    calculate_hashes "${EXE_FILE}"
    EXE_MD5=${MD5}
    EXE_SHA1=${SHA1}
    EXE_SHA256=${SHA256}
else
    echo "Warning: ${EXE_FILE} not found. Skipping."
    EXE_MD5="<INPUT>"
    EXE_SHA1="<INPUT>"
    EXE_SHA256="<INPUT>"
fi

# Apply commit timestamp to files in qortal/
echo "Applying commit timestamp (${COMMIT_TIMESTAMP}) to files..."
mv qortal.exe ${WORKING_QORTAL_DIR} 2>/dev/null || true
find ${WORKING_QORTAL_DIR} -type f -exec touch -d "${COMMIT_TIMESTAMP}" {} \;
mv ${WORKING_QORTAL_DIR}/qortal.exe . 2>/dev/null || true

# Create qortal.zip
echo "Packing ${ZIP_FILE}..."
7z a -r -tzip "${ZIP_FILE}" ${WORKING_QORTAL_DIR}/ -stl
if [ $? -ne 0 ]; then
    echo "Error: Failed to create ${ZIP_FILE}."
    exit 1
fi

calculate_hashes "${ZIP_FILE}"
ZIP_MD5=${MD5}
ZIP_SHA1=${SHA1}
ZIP_SHA256=${SHA256}

# Generate release notes
cat <<EOF > release-notes.txt
### **_Qortal Core V${VERSION}_**

#### 🔄 Changes Included in This Release:

${CHANGELOG}

### [qortal.jar](https://github.com/Qortal/qortal/releases/download/v${VERSION}/qortal.jar)

\`MD5: ${JAR_MD5}\`  qortal.jar  
\`SHA1: ${JAR_SHA1}\`  qortal.jar  
\`SHA256: ${JAR_SHA256}\`  qortal.jar  

### [qortal.exe](https://github.com/Qortal/qortal/releases/download/v${VERSION}/qortal.exe)

\`MD5: ${EXE_MD5}\`  qortal.exe  
\`SHA1: ${EXE_SHA1}\`  qortal.exe  
\`SHA256: ${EXE_SHA256}\`  qortal.exe  

[VirusTotal report for qortal.exe](https://www.virustotal.com/gui/file/${EXE_SHA256}/detection)

### [qortal.zip](https://github.com/Qortal/qortal/releases/download/v${VERSION}/qortal.zip)

Contains bare minimum of:
* built \`qortal.jar\`  
* \`log4j2.properties\` from git repo  
* \`start.sh\` from git repo  
* \`stop.sh\` from git repo  
* \`qort\` script for linux/mac easy API utilization  
* \`printf "{\n}\n" > settings.json\`

All timestamps set to same date-time as commit.  
Packed with \`7z a -r -tzip qortal.zip qortal/\`

\`MD5: ${ZIP_MD5}\`  qortal.zip  
\`SHA1: ${ZIP_SHA1}\`  qortal.zip  
\`SHA256: ${ZIP_SHA256}\`  qortal.zip  
EOF

echo "Release notes generated: release-notes.txt"

