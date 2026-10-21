FROM node:20-slim

WORKDIR /app

# Install ffmpeg for audio conversion (OGG/Opus for WhatsApp mobile PTT)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy package descriptors
COPY package*.json ./

# Install clean production dependencies
RUN npm install --omit=dev

# Copy application source code
COPY . .

# Expose HTTP port
EXPOSE 3000

ENV NODE_ENV=production \
    PORT=3000

CMD ["node", "server.js"]
