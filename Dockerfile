FROM ubuntu:22.04

# 1. Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libfontconfig \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libxi6 \
    libgl1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 2. Define Godot Version (MUST match your local version!)
ARG GODOT_VERSION=4.4
ARG GODOT_VERSION_STATUS=stable

# 3. Download Godot Engine (Headless)
RUN wget https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_VERSION_STATUS}/Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_linux.x86_64.zip \
    && unzip Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_linux.x86_64.zip \
    && mv Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_linux.x86_64 /usr/local/bin/godot \
    && rm Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_linux.x86_64.zip

# 4. Download & Install Export Templates (CRITICAL FIX)
RUN wget https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_VERSION_STATUS}/Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_export_templates.tpz \
    && mkdir -p ~/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_VERSION_STATUS} \
    && unzip Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_export_templates.tpz \
    && mv templates/* ~/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_VERSION_STATUS}/ \
    && rm -rf templates Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_export_templates.tpz

# 5. Set working directory
WORKDIR /app

# 6. Copy project files
COPY . .

# 7. Create build directory and Export
# Ensure the preset name "Linux/X11" matches exactly what is in your export_presets.cfg
RUN mkdir -p build/linux
RUN godot --headless --export-release "Linux/X11" build/linux/server.x86_64

# 8. Run the server
EXPOSE 8080
CMD ["/app/build/linux/server.x86_64", "--server", "--headless"]