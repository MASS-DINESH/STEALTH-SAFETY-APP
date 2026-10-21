const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
} = require('@whiskeysockets/baileys');
const qrcodeTerminal = require('qrcode-terminal');
const pino = require('pino');
const fs = require('fs');
const path = require('path');
const os = require('os');
const ffmpeg = require('fluent-ffmpeg');
const ffmpegInstaller = require('@ffmpeg-installer/ffmpeg');

// Use bundled ffmpeg binary (works on Render & Windows)
ffmpeg.setFfmpegPath(ffmpegInstaller.path);

let sock = null;
let latestQr = null;
let isReady = false;

const authDir = path.join(__dirname, '.baileys_auth');
fs.mkdirSync(authDir, { recursive: true });

async function connectToWhatsApp() {
  const { state, saveCreds } = await useMultiFileAuthState(authDir);
  const { version, isLatest } = await fetchLatestBaileysVersion().catch(() => ({
    version: [2, 3000, 1015901307],
    isLatest: false,
  }));

  console.log(`Using WhatsApp Baileys version ${version.join('.')} (latest: ${isLatest})`);

  sock = makeWASocket({
    version,
    auth: state,
    logger: pino({ level: 'silent' }),
    printQRInTerminal: false,
    browser: ['Personal Safety Server', 'Chrome', '1.0.0'],
    connectTimeoutMs: 60000,
    keepAliveIntervalMs: 25000,
  });

  sock.ev.on('creds.update', saveCreds);

  sock.ev.on('connection.update', (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      latestQr = qr;
      console.log('\n=========================================');
      console.log(' SCAN THIS QR CODE WITH YOUR WHATSAPP   ');
      console.log(' WhatsApp > Settings > Linked Devices    ');
      console.log(' (Or open /qr in your browser)           ');
      console.log('=========================================\n');
      qrcodeTerminal.generate(qr, { small: true });
    }

    if (connection === 'close') {
      isReady = false;
      const shouldReconnect =
        lastDisconnect?.error?.output?.statusCode !== DisconnectReason.loggedOut;
      const reason = lastDisconnect?.error?.output?.statusCode;
      console.log(`⚠️ Connection closed due to: ${reason}, reconnecting: ${shouldReconnect}`);

      if (shouldReconnect) {
        setTimeout(connectToWhatsApp, 3000);
      } else {
        console.log('❌ Logged out of WhatsApp. Reinitializing auth...');
        try {
          fs.rmSync(authDir, { recursive: true, force: true });
        } catch (_) {}
        setTimeout(connectToWhatsApp, 3000);
      }
    } else if (connection === 'open') {
      isReady = true;
      latestQr = null;
      console.log('\n✅ WhatsApp connection established and ready! (RAM: ~28MB)\n');
    }
  });
}

// Start connection
connectToWhatsApp().catch((err) => console.error('Baileys startup error:', err));

/**
 * Format a phone number to WhatsApp JID.
 * Input:  "+919876543210" or "919876543210"
 * Output: "919876543210@s.whatsapp.net"
 */
function toJid(number) {
  const digits = number.replace(/\D/g, '');
  return `${digits}@s.whatsapp.net`;
}

/** Send a plain text message */
async function sendText(to, body) {
  const jid = toJid(to);
  if (!isReady || !sock) {
    console.log(`[MOCK WHATSAPP] Sending Text to ${jid}: ${body}`);
    return;
  }
  await sock.sendMessage(jid, { text: body });
}

/**
 * Send an image as original photo
 */
async function sendImage(to, filePath, caption) {
  const jid = toJid(to);
  if (!fs.existsSync(filePath)) {
    console.error(`[sendImage] file not found: ${filePath}`);
    return;
  }

  const ext = path.extname(filePath).toLowerCase();
  const mimeType = ext === '.png' ? 'image/png' : 'image/jpeg';
  const fileBuffer = fs.readFileSync(filePath);

  if (!isReady || !sock) {
    console.log(
      `[MOCK WHATSAPP] Sending Original Image (${mimeType}) to ${jid}: ${path.basename(filePath)} (Caption: ${caption})`
    );
    return;
  }

  console.log(`[sendImage] Sending image to ${jid}: ${path.basename(filePath)} (${fileBuffer.length} bytes)`);
  await sock.sendMessage(jid, {
    image: fileBuffer,
    caption: caption || '',
    mimetype: mimeType,
  });
}

/**
 * Convert any audio file to OGG/Opus format (required by WhatsApp mobile for PTT).
 * Returns path to the converted temp file.
 */
function convertToOpus(inputPath) {
  return new Promise((resolve, reject) => {
    const tmpFile = path.join(os.tmpdir(), `wa_audio_${Date.now()}.ogg`);
    ffmpeg(inputPath)
      .audioCodec('libopus')
      .audioFrequency(16000)
      .audioChannels(1)
      .audioBitrate('32k')
      .format('ogg')
      .on('error', (err) => {
        console.error('[convertToOpus] ffmpeg error:', err.message);
        reject(err);
      })
      .on('end', () => {
        console.log(`[convertToOpus] Converted to OGG/Opus: ${tmpFile}`);
        resolve(tmpFile);
      })
      .save(tmpFile);
  });
}

/**
 * Send an audio file as a native Voice Note (PTT).
 * Converts to OGG/Opus first so it plays on WhatsApp mobile AND desktop.
 */
async function sendAudio(to, filePath) {
  const jid = toJid(to);

  if (!fs.existsSync(filePath)) {
    console.error(`[sendAudio] file not found: ${filePath}`);
    return;
  }

  const fileStats = fs.statSync(filePath);
  if (fileStats.size < 100) {
    console.error(`[sendAudio] file too small (${fileStats.size} bytes), skipping: ${filePath}`);
    return;
  }

  if (!isReady || !sock) {
    console.log(
      `[MOCK WHATSAPP] Sending Voice Note (audio/ogg; codecs=opus) to ${jid}: ${path.basename(filePath)}`
    );
    return;
  }

  let opusPath = null;
  try {
    // Convert to OGG/Opus — required for WhatsApp mobile PTT playback
    opusPath = await convertToOpus(filePath);
    const fileBuffer = fs.readFileSync(opusPath);
    console.log(`[sendAudio] Sending OGG/Opus voice note to ${jid}: ${path.basename(filePath)} → ${fileBuffer.length} bytes`);

    await sock.sendMessage(jid, {
      audio: fileBuffer,
      mimetype: 'audio/ogg; codecs=opus',
      ptt: true,
    });
  } catch (err) {
    console.error(`[sendAudio] Conversion failed, sending raw m4a as fallback: ${err.message}`);
    // Fallback: send as regular audio document (not PTT) so it still plays
    const rawBuffer = fs.readFileSync(filePath);
    await sock.sendMessage(jid, {
      audio: rawBuffer,
      mimetype: 'audio/mp4',
      ptt: false,
    });
  } finally {
    // Clean up temp opus file
    if (opusPath && fs.existsSync(opusPath)) {
      try { fs.unlinkSync(opusPath); } catch (_) {}
    }
  }
}

/** Get latest QR code string for web rendering */
function getQr() {
  return latestQr;
}

/** Check if client is connected */
function getStatus() {
  return isReady;
}

module.exports = { sendText, sendImage, sendAudio, getStatus, getQr };
