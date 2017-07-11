#!/bin/ash

# Check for agreement to EULA
if [ ! -f "$MINECRAFT_HOME/eula.txt" ]; then
  if [ "$EULA" == "true" ]; then
    echo "[+] Updating $MINECRAFT_HOME/eula.txt"
    echo "# Generated by Docker" > "$MINECRAFT_HOME/eula.txt"
    echo "# $(date)" >> "$MINECRAFT_HOME/eula.txt"
    echo "eula=$EULA" >> "$MINECRAFT_HOME/eula.txt"
    echo "[+] Done."
  else
    echo >&2 "[-] You need to agree to the EULA in order to run the server."
    echo >&2 "[-]   (https://account.mojang.com/documents/minecraft_eula)"
    echo >&2 "[-]   Please set the EULA variable."
    exit 1
  fi
fi

# Check for OP
if [ -z "$DEFAULT_OP" ]; then
  echo >&2 "[-] Please set DEFAULT_OP to continue booting."
  exit 1
fi

# Determine Minecraft version
VERSIONS_URL="https://launchermeta.mojang.com/mc/game/version_manifest.json"
case "$VERSION" in
  'latest')
    VERSION=`curl -sL "$VERSIONS_URL" | jq .latest.release | sed 's/\"//g'`
  ;;
  'snapshot')
    VERSION=`curl -sL "$VERSIONS_URL" | jq .latest.snapshot | sed 's/\"//g'`
  ;;
  [1-9]*)
    VERSION="$VERSION"
  ;;
  *)
    VERSION=`curl -sL "$VERSIONS_URL" | jq .latest.release | sed 's/\"//g'`
  ;;
esac

JAR_FILE=${JAR_FILE:-"minecraft_server.$VERSION.jar"}
SERVER_URL="https://s3.amazonaws.com/Minecraft.Download/versions/$VERSION/$JAR_FILE"

# Download Minecraft server
if [ ! -f "$MINECRAFT_HOME/$JAR_FILE" ]; then
  echo "[+] Downloading ${JAR_FILE}..."
  curl -sSf "$SERVER_URL" -o "$MINECRAFT_HOME/$JAR_FILE"
  if [ $? -ne 0 ]; then
    echo >&2 "[-] Failed downloading ${JAR_FILE}"
    exit 1
  fi
  mv "$MINECRAFT_HOME/$JAR_FILE" "$MINECRAFT_HOME/minecraft_server.jar"
  echo "[+] Done."
fi

# Add OP users
if [ ! -f "$MINECRAFT_HOME/ops.json" -a ! -f "$MINECRAFT_HOME/ops.txt.converted" ]; then
  echo "[+] Adding $DEFAULT_OP to the ops list..."

  # ignored in versions after 1.7.8 but will be converted to JSON in
  # later versions
  echo "$DEFAULT_OP" | awk -v RS=, '{print}' >> "$MINECRAFT_HOME/ops.txt"

  echo "[+]  Done."
fi

# This simple loop reads the template file and writes out the environment
# values to a servers.properties file.
if [ ! -f "$MINECRAFT_HOME/server.properties" ]; then
  echo "[+] Adding server properties..."
  while read SETTING
  do
    eval echo "$SETTING"
  done < /tmp/server.properties.template > "$MINECRAFT_HOME/server.properties"
  echo "[+] Done."
fi

# Create user
USER_EXISTS=`id -u mineuser > /dev/null 2>&1; echo $?`
if [ "$USER_EXISTS" -eq "1" ]; then
  adduser -HD mineuser
fi

# Set proper permissions
chown -R mineuser:mineuser "$MINECRAFT_HOME"
