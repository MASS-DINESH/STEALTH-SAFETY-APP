require('dotenv').config();
const express = require('express');
const multer  = require('multer');
const path    = require('path');
const fs      = require('fs');
const QRCode  = require('qrcode');
const wa      = require('./whatsapp');

const app = express();
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

const uploadDir = path.join(__dirname, 'uploads');
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const ext = path.extname(file.originalname) || (file.fieldname === 'audio' || file.mimetype.includes('audio') ? '.aac' : '.jpg');
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + ext);
  }
});
const upload = multer({ storage: storage });

// ------------------------------------------------------------------
// In-memory Session Store for Live Moving Location Tracker
// ------------------------------------------------------------------
const liveSessions = new Map();

// ------------------------------------------------------------------
// GET / — Server Dashboard & Health
// ------------------------------------------------------------------
app.get('/', (_req, res) => {
  const isReady = wa.getStatus();
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🛡️ Personal Safety Backend</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B0F19; color: #F8FAFC; margin: 0; padding: 40px 20px; display: flex; justify-content: center; }
    .card { background: #111827; border: 1px solid #1F2937; border-radius: 20px; max-width: 520px; width: 100%; padding: 32px; box-shadow: 0 20px 40px rgba(0,0,0,0.5); text-align: center; }
    .badge { display: inline-flex; align-items: center; gap: 8px; padding: 6px 14px; border-radius: 20px; font-weight: bold; font-size: 13px; margin-bottom: 20px; }
    .ready { background: rgba(16, 185, 129, 0.15); color: #10B981; border: 1px solid #10B981; }
    .not-ready { background: rgba(245, 158, 11, 0.15); color: #F59E0B; border: 1px solid #F59E0B; }
    h1 { margin: 0 0 10px 0; font-size: 24px; font-weight: 800; }
    p { color: #94A3B8; font-size: 14px; line-height: 1.6; margin: 0 0 24px 0; }
    .btn { display: inline-block; background: #6366F1; color: white; text-decoration: none; padding: 12px 24px; border-radius: 12px; font-weight: bold; font-size: 14px; transition: 0.2s; }
    .btn:hover { background: #4F46E5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge ${isReady ? 'ready' : 'not-ready'}">
      ${isReady ? '● WhatsApp Connected & Ready' : '▲ WhatsApp Needs QR Linking'}
    </div>
    <h1>Personal Safety Server</h1>
    <p>Backend API for SOS emergency alerts, moving GPS map streaming, audio voice notes, and evidence dispatch.</p>
    ${isReady ? '<a href="/health" class="btn" style="background:#10B981">Server Status: Healthy</a>' : '<a href="/qr" class="btn">Scan WhatsApp QR Code</a>'}
  </div>
</body>
</html>`);
});

// ------------------------------------------------------------------
// GET /qr — Web-based WhatsApp QR Code Scanner for Render
// ------------------------------------------------------------------
app.get('/qr', async (_req, res) => {
  const isReady = wa.getStatus();
  const rawQr = wa.getQr();

  if (isReady) {
    return res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>WhatsApp Connected</title>
  <style>
    body { font-family: -apple-system, sans-serif; background: #0B0F19; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .box { background: #111827; border: 1px solid #10B981; border-radius: 20px; padding: 32px; text-align: center; max-width: 400px; }
    .check { font-size: 54px; margin-bottom: 12px; }
    h2 { color: #10B981; margin: 0 0 8px 0; }
    p { color: #94A3B8; font-size: 14px; }
  </style>
</head>
<body>
  <div class="box">
    <div class="check">✅</div>
    <h2>WhatsApp is Connected!</h2>
    <p>Your server is authenticated and ready to deliver emergency voice notes, images, and live tracking alerts.</p>
  </div>
</body>
</html>`);
  }

  if (!rawQr) {
    return res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="refresh" content="3">
  <title>Generating QR Code...</title>
  <style>
    body { font-family: -apple-system, sans-serif; background: #0B0F19; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
    .box { background: #111827; border: 1px solid #1F2937; border-radius: 20px; padding: 32px; text-align: center; }
    .spinner { width: 40px; height: 40px; border: 4px solid rgba(99,102,241,0.2); border-top-color: #6366F1; border-radius: 50%; animation: spin 1s linear infinite; margin: 0 auto 16px auto; }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="box">
    <div class="spinner"></div>
    <h3>Initializing WhatsApp Engine...</h3>
    <p style="color:#94A3B8; font-size: 13px;">Please wait, generating QR code...</p>
  </div>
</body>
</html>`);
  }

  try {
    const qrDataUrl = await QRCode.toDataURL(rawQr, { margin: 2, scale: 7 });
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="refresh" content="12">
  <title>Scan WhatsApp QR Code</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B0F19; color: #F8FAFC; margin: 0; padding: 24px; display: flex; align-items: center; justify-content: center; min-height: 90vh; }
    .card { background: #111827; border: 1px solid #1F2937; border-radius: 24px; padding: 28px; text-align: center; max-width: 420px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
    .qr-img { border-radius: 16px; background: white; padding: 12px; margin: 16px 0; max-width: 240px; width: 100%; height: auto; }
    h2 { font-size: 20px; margin: 0 0 6px 0; }
    ol { text-align: left; font-size: 13px; color: #94A3B8; line-height: 1.8; margin: 16px 0 0 0; padding-left: 20px; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Scan with WhatsApp</h2>
    <p style="color:#94A3B8; font-size: 13px; margin:0;">Link your server to send automatic voice notes & photos</p>
    <img src="${qrDataUrl}" alt="WhatsApp QR Code" class="qr-img" />
    <ol>
      <li>Open <b>WhatsApp</b> on your phone</li>
      <li>Tap <b>Menu (⋮)</b> or <b>Settings</b> &gt; <b>Linked Devices</b></li>
      <li>Tap <b>Link a Device</b> and point camera at this QR</li>
    </ol>
  </div>
</body>
</html>`);
  } catch (err) {
    res.status(500).send('Error rendering QR code: ' + err.message);
  }
});

// ------------------------------------------------------------------
// GET /api/status  — health + WhatsApp connection status
// ------------------------------------------------------------------
app.get('/api/status', (_req, res) => {
  res.json({ ok: true, whatsapp: wa.getStatus(), hasQr: !!wa.getQr() });
});

// ------------------------------------------------------------------
// GET /health
// ------------------------------------------------------------------
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// ------------------------------------------------------------------
// GET /api/session/:sessionId/location - Poll live coordinates
// ------------------------------------------------------------------
app.get('/api/session/:sessionId/location', (req, res) => {
  const session = liveSessions.get(req.params.sessionId);
  if (!session) {
    return res.status(404).json({ error: 'session not found' });
  }
  res.json({
    ok: true,
    lat: session.lat,
    lng: session.lng,
    history: session.history,
    lastUpdated: session.lastUpdated,
  });
});

// ------------------------------------------------------------------
// GET /track/:sessionId — Live Interactive Moving Map Tracker
// ------------------------------------------------------------------
app.get('/track/:sessionId', (req, res) => {
  const sessionId = req.params.sessionId;
  const session = liveSessions.get(sessionId);
  const initialLat = session && session.lat ? session.lat : 13.0827;
  const initialLng = session && session.lng ? session.lng : 80.2707;

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🚨 Live Emergency Tracking</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    body, html { margin: 0; padding: 0; height: 100%; width: 100%; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #111; color: #fff; }
    #header { position: absolute; top: 0; left: 0; right: 0; height: 60px; background: rgba(20, 20, 20, 0.95); z-index: 1000; display: flex; align-items: center; justify-content: space-between; padding: 0 16px; border-bottom: 2px solid #e53935; }
    #header .title { font-weight: bold; font-size: 16px; color: #ff5252; display: flex; align-items: center; gap: 8px; }
    #header .pulse { width: 12px; height: 12px; border-radius: 50%; background: #4caf50; animation: pulse 1.5s infinite; }
    #map { position: absolute; top: 60px; bottom: 0; left: 0; right: 0; }
    #status-card { position: absolute; bottom: 20px; left: 20px; right: 20px; max-width: 400px; background: rgba(25, 25, 25, 0.95); border-radius: 12px; padding: 14px 18px; z-index: 1000; border: 1px solid #333; box-shadow: 0 8px 24px rgba(0,0,0,0.5); }
    #status-card h4 { margin: 0 0 6px 0; font-size: 14px; color: #fff; }
    #status-card p { margin: 0; font-size: 12px; color: #aaa; }
    .google-btn { display: inline-block; margin-top: 10px; padding: 8px 14px; background: #e53935; color: white; border-radius: 8px; text-decoration: none; font-size: 12px; font-weight: bold; }
    @keyframes pulse { 0% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(76, 175, 80, 0.7); } 70% { transform: scale(1); box-shadow: 0 0 0 10px rgba(76, 175, 80, 0); } 100% { transform: scale(0.95); box-shadow: 0 0 0 0 rgba(76, 175, 80, 0); } }
  </style>
</head>
<body>
  <div id="header">
    <div class="title">
      <div class="pulse"></div>
      LIVE EMERGENCY TRACKER
    </div>
    <div id="clock" style="font-size: 12px; color: #bbb;">Updating...</div>
  </div>
  <div id="map"></div>
  <div id="status-card">
    <h4>📍 Current Device Location</h4>
    <p id="coords-text">Lat: ${initialLat}, Lng: ${initialLng}</p>
    <p id="time-text">Last Updated: Just now</p>
    <a id="gmaps-link" class="google-btn" href="https://maps.google.com/?q=${initialLat},${initialLng}" target="_blank">Open in Google Maps</a>
  </div>

  <script>
    var map = L.map('map').setView([${initialLat}, ${initialLng}], 16);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '© OpenStreetMap'
    }).addTo(map);

    var markerIcon = L.divIcon({
      className: 'custom-pin',
      html: '<div style="background-color:#e53935;width:20px;height:20px;border-radius:50%;border:3px solid white;box-shadow:0 0 12px rgba(229,57,53,0.9);"></div>',
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    });

    var marker = L.marker([${initialLat}, ${initialLng}], { icon: markerIcon }).addTo(map);
    var polyline = L.polyline([[${initialLat}, ${initialLng}]], { color: '#e53935', weight: 4, opacity: 0.8 }).addTo(map);

    function pollLocation() {
      fetch('/api/session/${sessionId}/location')
        .then(res => res.json())
        .then(data => {
          if (data.ok && data.lat && data.lng) {
            var latLng = [data.lat, data.lng];
            marker.setLatLng(latLng);
            map.panTo(latLng);

            if (data.history && data.history.length > 0) {
              polyline.setLatLngs(data.history.map(h => [h[0], h[1]]));
            }

            document.getElementById('coords-text').innerText = 'Lat: ' + data.lat.toFixed(6) + ', Lng: ' + data.lng.toFixed(6);
            document.getElementById('time-text').innerText = 'Last GPS ping: ' + new Date(data.lastUpdated).toLocaleTimeString();
            document.getElementById('clock').innerText = 'LIVE TRACKING';
            document.getElementById('gmaps-link').href = 'https://maps.google.com/?q=' + data.lat + ',' + data.lng;
          }
        })
        .catch(err => console.error(err));
    }

    setInterval(pollLocation, 2500);
  </script>
</body>
</html>`;
  res.send(html);
});

// ------------------------------------------------------------------
// POST /api/alert-start
// Fires immediately on emergency trigger.
// Body: { parent_number, lat, lng, session_id }
// ------------------------------------------------------------------
app.post('/api/alert-start', async (req, res) => {
  try {
    const { parent_number, lat, lng, session_id } = req.body;
    if (!parent_number) return res.status(400).json({ error: 'missing parent_number' });

    const sId = session_id || Date.now().toString();
    const numLat = lat ? parseFloat(lat) : null;
    const numLng = lng ? parseFloat(lng) : null;

    liveSessions.set(sId, {
      lat: numLat,
      lng: numLng,
      lastUpdated: Date.now(),
      history: numLat && numLng ? [[numLat, numLng, Date.now()]] : []
    });

    const host = req.get('host') || 'localhost:3000';
    const proto = req.headers['x-forwarded-proto'] || (host.includes('trycloudflare.com') || host.includes('loca.lt') ? 'https' : 'http');
    const liveTrackerUrl = `${proto}://${host}/track/${sId}`;
    const gmapsUrl = numLat && numLng ? `https://maps.google.com/?q=${numLat},${numLng}` : '';

    const msg =
      `🚨 *EMERGENCY ALERT TRIGGERED* 🚨\n` +
      `Your contact has activated emergency SOS!\n\n` +
      `📍 *Live Moving Location Tracker*:\n${liveTrackerUrl}\n\n` +
      (gmapsUrl ? `🗺️ *Google Maps Pin*:\n${gmapsUrl}\n\n` : '') +
      `📸 Photos and 🎤 audio evidence are being captured and sent below:`;

    const numbers = parent_number.split(',').map(n => n.trim()).filter(Boolean);
    for (const n of numbers) {
      await wa.sendText(n, msg).catch(err =>
        console.error(`[alert-start] failed for ${n}:`, err.message));
    }
    res.json({ ok: true, trackingUrl: liveTrackerUrl });
  } catch (err) {
    console.error('[alert-start]', err);
    res.status(500).json({ error: err.message });
  }
});

// ------------------------------------------------------------------
// POST /api/location
// Body: { parent_number, session_id, lat, lng }
// Updates the live session GPS so contacts tracking the link see movement!
// ------------------------------------------------------------------
app.post('/api/location', async (req, res) => {
  try {
    const { session_id, lat, lng } = req.body;
    if (!lat || !lng) return res.status(400).json({ error: 'missing lat/lng' });

    const sId = session_id || 'default';
    const numLat = parseFloat(lat);
    const numLng = parseFloat(lng);

    let session = liveSessions.get(sId);
    if (!session) {
      session = { lat: numLat, lng: numLng, lastUpdated: Date.now(), history: [] };
      liveSessions.set(sId, session);
    }
    session.lat = numLat;
    session.lng = numLng;
    session.lastUpdated = Date.now();
    session.history.push([numLat, numLng, Date.now()]);
    if (session.history.length > 500) session.history.shift();

    res.json({ ok: true });
  } catch (err) {
    console.error('[location]', err);
    res.status(500).json({ error: err.message });
  }
});

// ------------------------------------------------------------------
// POST /api/photo   (multipart, field: file)
// ------------------------------------------------------------------
app.post('/api/photo', upload.single('file'), async (req, res) => {
  const filePath = req.file ? req.file.path : null;
  try {
    const { parent_number, index, total } = req.body;
    if (!parent_number || !filePath) return res.status(400).json({ error: 'missing fields' });

    const numbers = parent_number.split(',').map(n => n.trim()).filter(Boolean);
    const caption = `📸 *Emergency Photo* (${index || 1}/${total || index || 1})`;
    
    for (const n of numbers) {
      await wa.sendImage(n, filePath, caption).catch(err =>
        console.error(`[photo] failed for ${n}:`, err.message));
    }
    res.json({ ok: true, index });
  } catch (err) {
    console.error('[photo]', err);
    res.status(500).json({ error: err.message });
  } finally {
    if (filePath) {
      setTimeout(() => fs.unlink(filePath, () => {}), 15000);
    }
  }
});

// ------------------------------------------------------------------
// POST /api/audio   (multipart, field: file)
// ------------------------------------------------------------------
app.post('/api/audio', upload.single('file'), async (req, res) => {
  const filePath = req.file ? req.file.path : null;
  try {
    const { parent_number, loop, total_loops, duration } = req.body;
    if (!parent_number || !filePath) return res.status(400).json({ error: 'missing fields' });

    const numbers = parent_number.split(',').map(n => n.trim()).filter(Boolean);
    const partText = total_loops && Number(total_loops) > 1 ? ` (Part ${loop || 1}/${total_loops})` : '';
    const headerMsg = `🎤 *Emergency Voice Note*${partText}${duration ? ` [${duration}s]` : ''}:`;
    
    for (const n of numbers) {
      await wa.sendText(n, headerMsg).catch(() => {});
      await wa.sendAudio(n, filePath).catch(err =>
        console.error(`[audio] failed for ${n}:`, err.message));
    }
    res.json({ ok: true });
  } catch (err) {
    console.error('[audio]', err);
    res.status(500).json({ error: err.message });
  } finally {
    if (filePath) {
      setTimeout(() => fs.unlink(filePath, () => {}), 15000);
    }
  }
});

// ------------------------------------------------------------------
// POST /api/low-battery-audio
// ------------------------------------------------------------------
app.post('/api/low-battery-audio', upload.single('file'), async (req, res) => {
  const filePath = req.file ? req.file.path : null;
  try {
    const { parent_number } = req.body;
    if (!parent_number || !filePath) return res.status(400).json({ error: 'missing fields' });

    const numbers = parent_number.split(',').map(n => n.trim()).filter(Boolean);
    for (const n of numbers) {
      await wa.sendText(n, '🔋 Battery below 20% — sending last saved voice note.').catch(() => {});
      await wa.sendAudio(n, filePath).catch(err =>
        console.error(`[low-battery] failed for ${n}:`, err.message));
    }
    res.json({ ok: true });
  } catch (err) {
    console.error('[low-battery-audio]', err);
    res.status(500).json({ error: err.message });
  } finally {
    if (filePath) {
      setTimeout(() => fs.unlink(filePath, () => {}), 15000);
    }
  }
});

// ------------------------------------------------------------------
// POST /api/test
// ------------------------------------------------------------------
app.post('/api/test', async (req, res) => {
  try {
    const { parent_number } = req.body;
    if (!parent_number) return res.status(400).json({ error: 'missing parent_number' });
    const numbers = parent_number.split(',').map(n => n.trim()).filter(Boolean);
    for (const n of numbers) {
      await wa.sendText(n,
        '🛡️ [Test] This is a test alert from Personal Safety App. All systems operational.'
      ).catch(err => console.error(`[test] failed for ${n}:`, err.message));
    }
    res.json({ ok: true });
  } catch (err) {
    console.error('[test]', err);
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () =>
  console.log(`\n🛡️  Safety App Backend listening on http://0.0.0.0:${PORT}\n`)
);
