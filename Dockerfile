# Use a lightweight Linux image
FROM ubuntu:22.04

# Install dependencies for Godot
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

# Download Godot 4.4 (Headless/Server version is standard in 4.x)
# NOTE: Ensure this version matches your local Godot version exactly!
ARG GODOT_VERSION=4.4
ARG GODOT_VERSION_STATUS=stable
RUN wget https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_VERSION_STATUS}/Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_linux.x86_64.zip \
	&& unzip Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_linux.x86_64.zip \
	&& mv Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_linux.x86_64 /usr/local/bin/godot \
	&& rm Godot_v${GODOT_VERSION}-${GODOT_VERSION_STATUS}_linux.x86_64.zip

# Set working directory
WORKDIR /app

# Copy project files into the image
COPY . .

# Export the game as a dedicated server (pck file)
# We need to create the directory first
RUN mkdir -p build/linux
RUN godot --headless --export-release "Linux/X11" build/linux/server.x86_64

# Expose the port
EXPOSE 8080

# Run the server
CMD ["/app/build/linux/server.x86_64", "--server", "--headless"]
