const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execSync, execFile } = require('child_process');

// Load config
const configPath = path.join(__dirname, 'config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

const PORT = config.port || 9876;
const MAX_SIZE = (config.max_file_size_mb || 50) * 1024 * 1024;

// Resolve temp dir
const tempDir = config.temp_dir.startsWith('~')
  ? path.join(os.homedir(), config.temp_dir.slice(1))
  : path.resolve(config.temp_dir);

// Ensure temp dir exists, clean on start
if (fs.existsSync(tempDir)) {
  fs.rmSync(tempDir, { recursive: true });
}
fs.mkdirSync(tempDir, { recursive: true });

// Detect platform
const isMac = process.platform === 'darwin';
const isWin = process.platform === 'win32';

const libDir = path.join(__dirname, 'lib');

function injectClipboard(type, content) {
  if (isMac) {
    execFile('bash', [path.join(libDir, 'clipboard-mac.sh'), type, content], (err, stdout) => {
      if (err) console.error('Clipboard inject error:', err.message);
      else console.log(stdout.trim());
    });
  } else if (isWin) {
    execFile('powershell', [
      '-ExecutionPolicy', 'Bypass', '-NoProfile', '-File',
      path.join(libDir, 'clipboard-win.ps1'),
      '-Type', type, '-Content', content
    ], (err, stdout) => {
      if (err) console.error('Clipboard inject error:', err.message);
      else console.log(stdout.trim());
    });
  }
}

function notify(message) {
  if (isMac) {
    try {
      execSync(`osascript -e 'display notification "${message}" with title "Clipboard Share"'`);
    } catch {}
  } else if (isWin) {
    try {
      execSync(`powershell -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('${message}','Clipboard Share')" `, { timeout: 1000 });
    } catch {}
  }
}

// Express app
const app = express();
app.use(express.json({ limit: '1mb' }));

// Multer for file uploads
const storage = multer.diskStorage({
  destination: tempDir,
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  }
});
const upload = multer({ storage, limits: { fileSize: MAX_SIZE } });

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', hostname: os.hostname(), platform: process.platform });
});

// Receive clipboard
app.post('/clip', upload.single('file'), (req, res) => {
  // File upload
  if (req.file) {
    const filePath = path.resolve(req.file.path);
    console.log(`Received file: ${req.file.originalname} (${req.file.size} bytes)`);
    injectClipboard('file', filePath);
    notify(`Arquivo recebido: ${req.file.originalname}`);
    return res.json({ ok: true, type: 'file', filename: req.file.originalname });
  }

  // Text
  if (req.body && req.body.type === 'text' && req.body.data) {
    const text = req.body.data;
    console.log(`Received text: ${text.length} chars`);
    injectClipboard('text', text);
    notify('Texto recebido');
    return res.json({ ok: true, type: 'text', length: text.length });
  }

  res.status(400).json({ error: 'No text or file provided' });
});

// Error handler for multer
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: `File too large. Max: ${config.max_file_size_mb}MB` });
  }
  next(err);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Clipboard Share server running on port ${PORT}`);
  console.log(`Platform: ${process.platform} | Hostname: ${os.hostname()}`);
  console.log(`Temp dir: ${tempDir}`);
  console.log(`Max file size: ${config.max_file_size_mb}MB`);
});
