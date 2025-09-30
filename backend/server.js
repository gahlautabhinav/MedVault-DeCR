// backend/server.js
require('dotenv').config();
const express = require('express');
const multer = require('multer');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs-extra');
const path = require('path');
const { exec } = require('child_process');
const { ethers } = require('ethers');
const CONSENT_JSON = require('../medchain-blockchain/deployments/ConsentManager.json');
const CONSENT_ADDR = CONSENT_JSON.address;
const CONSENT_ABI = CONSENT_JSON.abi;

const upload = multer({ storage: multer.memoryStorage() });
const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));

// === Config (set these in backend/.env) ===
// SPACE_DID: did:key:... (the Space DID where files should be uploaded)
// Example backend/.env:
//   SPACE_DID=did:key:z6MkkaP9...
const SPACE_DID = process.env.SPACE_DID;
if (!SPACE_DID) {
  console.error('ERROR: set SPACE_DID=did:key:... in backend/.env');
  process.exit(1);
}

const TMP_DIR = path.join(__dirname, 'tmp');
fs.ensureDirSync(TMP_DIR);

// local audit DB
const DB_PATH = path.join(__dirname, 'audit_db.json');
if (!fs.existsSync(DB_PATH)) fs.writeJsonSync(DB_PATH, { audit: [], grants: [] }, { spaces: 2 });

function appendToDB(key, obj) {
  const db = fs.readJsonSync(DB_PATH);
  db[key].push(obj);
  fs.writeJsonSync(DB_PATH, db, { spaces: 2 });
}

// ================== Helper: run w3 CLI and extract CID ==================
function extractCidFromOutput(output) {
  if (!output) return null;
  // Try common CID patterns (bafy... or Qm...)
  const cidMatch = output.match(/(bafy[^\s'"]+|Qm[^\s'"]+)/i);
  if (cidMatch) return cidMatch[1];

  // Try to extract from an ipfs link (last path segment)
  const urlMatch = output.match(/https?:\/\/[^\s]+\/(bafy[^\s'"]+|Qm[^\s'"]+)/i);
  if (urlMatch) return urlMatch[1];

  return null;
}

function w3UploadFileSync(filePath) {
  // Try several w3 subcommands; return CID string or throw
  const candidates = [
    ['put', filePath, '--space', SPACE_DID],
    ['upload', filePath, '--space', SPACE_DID],
    ['files', 'put', filePath, '--space', SPACE_DID],
    ['put', filePath] // fallback without --space (if CLI has current space set)
  ];

  for (const args of candidates) {
    const cmd = `w3 ${args.map(a => (a.includes(' ') ? `"${a}"` : a)).join(' ')}`;
    try {
      // execSync would throw if non-zero; using exec with callback wrapped in Promise instead
      const output = require('child_process').execSync(cmd, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
      const out = String(output || '').trim();
      const cid = extractCidFromOutput(out);
      if (cid) return cid;
    } catch (e) {
      // command failed - continue to next candidate
      // keep going, but record nothing here
    }
  }
  // If nothing worked, attempt a final call capturing stdout/stderr to show to user
  throw new Error('w3 CLI upload failed (no CID extracted). Ensure `w3` is installed, logged in and the space is accessible. Run `w3 put <file> --space <SPACE_DID>` manually to verify.');
}

// Promise wrapper version (used by async route)
function w3UploadFile(filePath) {
  return new Promise((resolve, reject) => {
    // Choose the same candidate list but attempt one-by-one asynchronously
    const candidates = [
      `w3 put "${filePath}" --space ${SPACE_DID}`,
      `w3 upload "${filePath}" --space ${SPACE_DID}`,
      `w3 files put "${filePath}" --space ${SPACE_DID}`,
      `w3 put "${filePath}"`
    ];

    (function tryNext(i) {
      if (i >= candidates.length) return reject(new Error('w3 CLI upload failed (no CID extracted). Ensure `w3` is installed and logged in.'));
      const cmd = candidates[i];
      exec(cmd, { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }, (err, stdout, stderr) => {
        const out = (stdout || '') + (stderr || '');
        if (!err) {
          const cid = extractCidFromOutput(out);
          if (cid) return resolve(cid);
          // if no CID found, try next
          return tryNext(i + 1);
        } else {
          // try next candidate
          return tryNext(i + 1);
        }
      });
    })(0);
  });
}

// ================== Routes ==================

// Upload encrypted file blob
app.post('/api/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'no file provided' });

    // create a unique temp filename
    const tmpName = `${Date.now()}-${Math.random().toString(36).substring(2, 9)}-${req.file.originalname}`;
    const tmpPath = path.join(TMP_DIR, tmpName);

    // write file to tmp
    await fs.writeFile(tmpPath, req.file.buffer);

    // upload via w3 CLI
    let cid;
    try {
      cid = await w3UploadFile(tmpPath);
    } finally {
      // cleanup temp file
      try { await fs.unlink(tmpPath); } catch (e) { /* ignore */ }
    }

    // append to local audit DB
    appendToDB('audit', {
      action: 'upload',
      cid,
      space: SPACE_DID,
      filename: req.file.originalname,
      ts: Date.now()
    });

    return res.json({ cid: String(cid), space: SPACE_DID });
  } catch (err) {
    console.error('upload error', err);
    return res.status(500).json({ error: err && err.message ? err.message : String(err) });
  }
});

// Upload encrypted symmetric key JSON
app.post('/api/upload-key', async (req, res) => {
  try {
    const json = JSON.stringify(req.body || {});
    const tmpName = `${Date.now()}-${Math.random().toString(36).substring(2, 9)}-encKey.json`;
    const tmpPath = path.join(TMP_DIR, tmpName);
    await fs.writeFile(tmpPath, json);

    let cid;
    try {
      cid = await w3UploadFile(tmpPath);
    } finally {
      try { await fs.unlink(tmpPath); } catch (e) {}
    }

    appendToDB('audit', { action: 'upload-key', cid, space: SPACE_DID, ts: Date.now() });
    return res.json({ cid: String(cid), space: SPACE_DID });
  } catch (err) {
    console.error('upload-key error', err);
    return res.status(500).json({ error: err && err.message ? err.message : String(err) });
  }
});

const provider = new ethers.JsonRpcProvider(process.env.AMOY_RPC_URL);
const wallet = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);
const consentManager = new ethers.Contract(CONSENT_ADDR, CONSENT_ABI, wallet);

async function checkConsent(grantee, fileCid) {
  const provider = new ethers.JsonRpcProvider(process.env.AMOY_RPC_URL);
  const wallet = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);

  const cm = new ethers.Contract(
    require('../medchain-blockchain/deployments/ConsentManager.json').address,
    require('../medchain-blockchain/deployments/ConsentManager.json').abi,
    wallet
  );

  const consent = await cm.getConsent(fileCid, grantee);
  const now = Math.floor(Date.now() / 1000);

  return {
    patient: consent[0],
    grantee: consent[1],
    expiresAt: Number(consent[2]),
    encKeyCid: consent[3],
    active: consent[4] && Number(consent[2]) > now
  };
}

function sanitizeAddress(addr) {
  if (ethers.isAddress(addr)) {
    return ethers.getAddress(addr); // checksum version
  }
  // Don't attempt ENS
  throw new Error("Invalid Ethereum address: " + addr);
}


// ------------------- GRANT ACCESS ROUTE (ENS-FREE, correct param order) -------------------
app.post('/api/grant-access', async (req, res) => {
  try {
    const { grantee, fileCid, encKeyCid, expirySecs } = req.body;

    // basic validation
    if (!grantee || !fileCid || !encKeyCid) {
      return res.status(400).json({ error: "Missing required fields: grantee, fileCid, encKeyCid" });
    }

    // validate grantee is a hex address (no ENS)
    const addr = String(grantee).trim();
    if (!/^0x[a-fA-F0-9]{40}$/.test(addr)) {
      return res.status(400).json({ error: "Invalid Ethereum address format. Must be 0x..." });
    }
    const safeGrantee = ethers.getAddress(addr); // checksum only, no resolve

    // prepare CIDs and expiry
    const safeFileCid = String(fileCid);
    const safeEncKeyCid = String(encKeyCid);
    const seconds = parseInt(expirySecs || "600", 10);
    const now = Math.floor(Date.now() / 1000);
    const expiresAt = now + seconds;

    console.log(`Granting consent (ENS-free): fileCid=${safeFileCid}, grantee=${safeGrantee}, encKeyCid=${safeEncKeyCid}, expiresAt=${expiresAt} (${seconds}s from now)`);

    // sanity: ensure DEPLOYER_PRIVATE_KEY is set
    if (!process.env.DEPLOYER_PRIVATE_KEY) {
      throw new Error("DEPLOYER_PRIVATE_KEY is not set in backend/.env");
    }
    if (!process.env.AMOY_RPC_URL) {
      throw new Error("AMOY_RPC_URL is not set in backend/.env");
    }

    // build provider/signer (explicit network info helps avoid ENS lookups)
    const providerLocal = new ethers.JsonRpcProvider(process.env.AMOY_RPC_URL, { chainId: 80002, name: "amoy" });
    const walletLocal = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY);
    const signer = walletLocal.connect(providerLocal);

    // encode calldata locally — IMPORTANT: use correct arg order from ABI
    // grantAccess(string fileCid, address grantee, uint256 expiresAt, string encKeyCid)
    const iface = new ethers.Interface(CONSENT_ABI);
    const data = iface.encodeFunctionData("grantAccess", [
      safeFileCid,
      safeGrantee,
      expiresAt,
      safeEncKeyCid
    ]);

    // transaction request: explicitly set 'to' to contract address (hex string)
    const txRequest = {
      to: CONSENT_ADDR,
      data,
      // optionally set gasLimit: 800_000 (adjust if necessary)
      // gasLimit: 800000
    };

    // sign & send
    const txResp = await signer.sendTransaction(txRequest);
    const receipt = await txResp.wait();

    // append audit
    const db = fs.readJsonSync(DB_PATH);
    db.grants.push({
      patient: signer.address,
      fileCid: safeFileCid,
      grantee: safeGrantee,
      encKeyCid: safeEncKeyCid,
      expiresAt,
      txHash: txResp.hash,
      blockNumber: receipt.blockNumber || null,
      ts: Date.now(),
      space: process.env.SPACE_DID || "unknown"
    });
    fs.writeJsonSync(DB_PATH, db, { spaces: 2 });

    return res.json({ success: true, txHash: txResp.hash, blockNumber: receipt.blockNumber || null, expiresAt });
  } catch (err) {
    console.error("grant-access error (ens-free):", err);
    return res.status(500).json({ error: err?.message || String(err) });
  }
});

// ------------------- REVOKE ACCESS ROUTE -------------------
app.post('/api/revoke-access', async (req, res) => {
  try {
    const { grantee, fileCid } = req.body;
    if (!grantee || !fileCid) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const safeGrantee = sanitizeAddress(grantee);
    console.log(`Revoking consent: grantee=${safeGrantee}, fileCid=${fileCid}`);

    const tx = await consentManager.revokeAccess(fileCid, safeGrantee);
    await tx.wait();

    appendToDB('audit', {
      action: 'revoke-access',
      patient: wallet.address,
      grantee: safeGrantee,
      fileCid,
      txHash: tx.hash,
      ts: Date.now()
    });

    return res.json({ success: true, txHash: tx.hash });
  } catch (err) {
    console.error("revoke-access error", err);
    return res.status(500).json({ error: err.message || "revoke-access failed" });
  }
});


// ------------------- EMERGENCY ACCESS ROUTE -------------------
app.post('/api/emergency-access', async (req, res) => {
  try {
    const { fileCid } = req.body;
    if (!fileCid) return res.status(400).json({ error: "Missing fileCid" });

    const provider = new ethers.JsonRpcProvider(process.env.AMOY_RPC_URL);
    const wallet = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);

    const cm = new ethers.Contract(
      require('../medchain-blockchain/deployments/ConsentManager.json').address,
      require('../medchain-blockchain/deployments/ConsentManager.json').abi,
      wallet
    );

    console.log(`🚨 Emergency Access: fileCid=${fileCid}`);

    const tx = await cm.emergencyAccess(fileCid);
    await tx.wait();

    appendToDB('audit', {
      action: 'emergency-access',
      patient: wallet.address,
      fileCid,
      txHash: tx.hash,
      ts: Date.now(),
      space: process.env.SPACE_DID || "unknown"
    });

    return res.json({ success: true, txHash: tx.hash });
  } catch (err) {
    console.error("emergency-access error", err);
    return res.status(500).json({ error: err.message || "emergency-access failed" });
  }
});


// audit viewer
app.get('/api/audit', (req, res) => {
  try {
    const db = fs.readJsonSync(DB_PATH);
    res.json(db);
  } catch (e) {
    res.status(500).json({ error: 'read audit db failed' });
  }
});

// optional: list grants endpoint (if you want)
app.get('/api/grants', (req, res) => {
  try {
    const db = fs.readJsonSync(DB_PATH);
    res.json(db.grants || []);
  } catch (e) {
    res.status(500).json({ error: 'read grants db failed' });
  }
});

// ========== On-chain audit viewer ==========
app.get('/api/onchain-audit', (req, res) => {
  try {
    const db = fs.readJsonSync(DB_PATH);
    const { type } = req.query;

    let result = db.audit || [];

    if (type) {
      const t = type.toLowerCase();
      result = result.filter(evt => {
        if (t === "emergency") return evt.event === "EmergencyAccess";
        if (t === "grants") return evt.event === "AccessGranted";
        if (t === "revokes") return evt.event === "AccessRevoked";
        if (t === "audit") return evt.event === "AuditLogged";
        return true; // fallback: return all
      });
    }

    return res.json(result);
  } catch (err) {
    return res.status(500).json({ error: "read onchain audit db failed" });
  }
});


// ------------------- CHECK CONSENT STATUS -------------------
app.get('/api/consent-status', async (req, res) => {
  try {
    const { grantee, fileCid } = req.query;
    if (!grantee || !fileCid) {
      return res.status(400).json({ error: "Missing grantee or fileCid" });
    }

    const result = await checkConsent(grantee, fileCid);
    return res.json(result);
  } catch (err) {
    console.error("consent-status error", err);
    return res.status(500).json({ error: err.message || "consent-status failed" });
  }
});


const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`✅ Backend listening on ${PORT} (CLI upload fallback)`));
