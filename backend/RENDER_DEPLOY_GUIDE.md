# 🚀 Deploying Safety App Backend to Render.com

This guide provides step-by-step instructions to deploy your WhatsApp Emergency Alert Backend to **Render.com** (100% Free tier supported).

---

## 📋 Step 1: Push the `backend` Folder to GitHub

1. Create a repository on GitHub (e.g. `safety-app-backend`).
2. Push your `backend` folder to your GitHub repo:
   ```bash
   cd backend
   git init
   git add .
   git commit -m "Deploy safety app backend to render"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/safety-app-backend.git
   git push -u origin main
   ```

---

## 🌐 Step 2: Create a New Web Service on Render.com

1. Go to [https://dashboard.render.com](https://dashboard.render.com) and sign in.
2. Click **New +** &rarr; select **Web Service**.
3. Connect your GitHub repository (`safety-app-backend`).
4. Configure the service:
   - **Name**: `safety-app-backend` (or any name you like)
   - **Region**: Select the closest region (e.g., *Singapore* or *Frankfurt*)
   - **Language / Runtime**: Select **Docker** *(Render will automatically detect your `Dockerfile`)*
   - **Instance Type**: **Free** ($0/month)
5. Click **Create Web Service** at the bottom.

---

## 📱 Step 3: Scan the WhatsApp QR Code

1. Wait 2-3 minutes for Render to finish building and deploying.
2. Render will assign you a live HTTPS URL (e.g., `https://safety-app-backend.onrender.com`).
3. Open the QR page in your browser:
   ```text
   https://safety-app-backend.onrender.com/qr
   ```
4. On your phone:
   - Open **WhatsApp** &rarr; tap **Menu (⋮)** / **Settings** &rarr; **Linked Devices**.
   - Tap **Link a Device** and scan the QR code displayed on the webpage.
5. The webpage will immediately show: **`✅ WhatsApp is Connected!`**

---

## 📲 Step 4: Update Your Android App with Your Render URL

1. Open the **Personal Safety** app on your phone.
2. Tap the **Settings** tab &rarr; find **Backend PC URL / Cloudflare Tunnel**.
3. Enter your Render live URL:
   ```text
   https://safety-app-backend.onrender.com
   ```
4. Tap **Save** &rarr; tap **Test Connection to Server**.
5. You will see: **`✅ Connected to PC Server & WhatsApp is Ready!`**
