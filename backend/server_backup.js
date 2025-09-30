// backend/server.js
require('dotenv').config();
const express = require('express');
const multer = require('multer');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs-extra');
const path = require('path');

const w3up = require('@web3-storage/w3up-client');
// optional import — some versions expose helpers here
let accessPkg;
try { accessPkg = require('@web3-storage/access'); } catch (e) { accessPkg = null; }

const upload = multer();
const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: '50mb' }));

const DELEGATION_PATH = process.env.WEB3_DELEGATION; // e.g. ./medchain-delegation.json
if (!DELEGATION_PATH) {
  console.error("❌ ERROR: set WEB3_DELEGATION=./medchain-delegation.json in backend/.env");
  process.exit(1);
}

const DB_PATH = path.join(__dirname, 'audit_db.json');
if (!fs.existsSync(DB_PATH)) fs.writeJsonSync(DB_PATH, { audit: [], grants: [] }, { spaces: 2 });

function appendToDB(key, obj) {
  const db = fs.readJsonSync(DB_PATH);
  db[key].push(obj);
  fs.writeJsonSync(DB_PATH, db, { spaces: 2 });
}

// W3UP client + delegation import (robust)
let client;
let currentSpaceDid = null;

async function initClient() {
  if (client) return client;

  client = await w3up.create();
  console.log('w3up client created. available methods:', Object.keys(client).join(', '));

  // load delegation file
  const resolved = path.resolve(process.env.WEB3_DELEGATION);
  if (!fs.existsSync(resolved)) {
    throw new Error(`Delegation file not found at ${resolved}`);
  }

  const raw = fs.readFileSync(resolved);
  // Try to parse as JSON first (some CLIs produce JSON); otherwise keep as Buffer
  let delegationParsed = null;
  try {
    const s = raw.toString('utf8');
    delegationParsed = JSON.parse(s);
    console.log('Delegation loaded as JSON (parsed). keys:', Object.keys(delegationParsed).slice(0,10));
  } catch (e) {
    // Not JSON — keep binary buffer
    delegationParsed = null;
    console.log('Delegation file is binary or non-JSON; keeping raw bytes.');
  }

  // Try multiple import strategies (many sdk versions differ)
  // Strategy A: client.importSpace(delegationParsed) or client.importSpace(raw)
  // Strategy B: client.addSpace(delegationParsed) or client.addSpace(raw)
  // Strategy C: if accessPkg exists, try accessPkg.Delegation.extract(raw) then client.importSpace(...)
  let imported = false;
  const errors = [];

  // Helper attempt
  async function tryImport(arg, name) {
    if (imported) return;
    try {
      if (!arg) throw new Error('no-arg');
      if (typeof client.importSpace === 'function') {
        const res = await client.importSpace(arg);
        // importSpace may return a space object or space DID - try to derive DID
        if (res && typeof res === 'object') {
          if (typeof res.did === 'function') currentSpaceDid = res.did();
          else if (res.did) currentSpaceDid = res.did;
        } else if (typeof res === 'string') {
          currentSpaceDid = res;
        }
        imported = true;
        console.log(`importSpace succeeded using ${name}`);
        return;
      } else if (typeof client.addSpace === 'function') {
        const res = await client.addSpace(arg);
        if (res && typeof res === 'object' && typeof res.did === 'function') currentSpaceDid = res.did();
        else if (res && res.did) currentSpaceDid = res.did;
        else if (typeof res === 'string') currentSpaceDid = res;
        imported = true;
        console.log(`addSpace succeeded using ${name}`);
        return;
      } else {
        throw new Error('client has neither importSpace nor addSpace');
      }
    } catch (e) {
      errors.push({ name, message: e && e.message ? e.message : String(e) });
    }
  }

  // Try direct parsed JSON
  if (delegationParsed) {
    await tryImport(delegationParsed, 'parsed-JSON');
  }

  // Try using access package to extract delegation (if available)
  if (!imported && accessPkg && typeof accessPkg.Delegation === 'object') {
    try {
      // Some versions provide extract; others provide from...
      if (typeof accessPkg.Delegation.extract === 'function') {
        const extracted = accessPkg.Delegation.extract(raw);
        await tryImport(extracted, 'accessPkg.extract(raw)');
      } else if (typeof accessPkg.Delegation.fromJSON === 'function') {
        const extracted = accessPkg.Delegation.fromJSON(JSON.parse(raw.toString('utf8')));
        await tryImport(extracted, 'accessPkg.fromJSON');
      } else if (typeof accessPkg.Delegation.from === 'function') {
        // fallback
        const extracted = accessPkg.Delegation.from(raw);
        await tryImport(extracted, 'accessPkg.from');
      }
    } catch (e) {
      errors.push({ name: 'accessPkg.try', message: e.message || String(e) });
    }
  }

  // Try raw buffer
  if (!imported) {
    await tryImport(raw, 'raw-buffer');
  }

  // Try raw string
  if (!imported) {
    await tryImport(raw.toString('utf8'), 'raw-string');
  }

  if (!imported) {
    console.error('Failed to import delegation. Attempts:', errors);
    throw new Error('delegation import failed; see server logs for attempts array');
  }

  // if we still don't have a DID, try to query client.currentSpace
  try {
    if (!currentSpaceDid && typeof client.currentSpace === 'function') {
      const sp = await client.currentSpace();
      if (sp && typeof sp === 'object') {
        if (typeof sp.did === 'function') currentSpaceDid = sp.did();
        else if (sp.did) currentSpaceDid = sp.did;
      } else if (typeof sp === 'string') currentSpaceDid = sp;
    }
  } catch (e) {
    // ignore
  }

  console.log('W3UP space ready. space DID =', currentSpaceDid);
  return client;
}

// Upload route (unchanged behavior, but uses initClient)
app.post('/api/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "no file provided" });

    const client = await initClient();

    // Create File in Node: global File may not be defined; use Web-like File via Blob polyfill
    let FileClass = global.File;
    if (!FileClass) {
      // quick polyfill using node:buffer -> Blob/File
      const { Blob } = require('buffer');
      // create a minimal File-like object for client.uploadFile
      FileClass = function (parts, filename, opts) {
        const b = new Blob(parts, opts);
        b.name = filename;
        b.lastModified = Date.now();
        return b;
      };
    }

    const fileObj = new FileClass([req.file.buffer], req.file.originalname, {
      type: req.file.mimetype || 'application/octet-stream'
    });

    if (typeof client.uploadFile !== 'function') {
      // Some client versions use client.upload([...files]) etc.
      if (typeof client.upload === 'function') {
        // try client.upload([file])
        const cid = await client.upload([fileObj]);
        appendToDB('audit', { action: 'upload', cid: String(cid), space: currentSpaceDid, filename: req.file.originalname, ts: Date.now() });
        return res.json({ cid: String(cid), space: currentSpaceDid });
      } else {
        throw new Error('client does not provide uploadFile or upload');
      }
    }

    const cid = await client.uploadFile(fileObj);
    appendToDB('audit', { action: 'upload', cid: cid.toString(), space: currentSpaceDid, filename: req.file.originalname, ts: Date.now() });
    return res.json({ cid: cid.toString(), space: currentSpaceDid });
  } catch (err) {
    console.error('upload error', err);
    return res.status(500).json({ error: err && err.message ? err.message : String(err) });
  }
});

// upload-key route
app.post('/api/upload-key', async (req, res) => {
  try {
    const client = await initClient();
    const json = JSON.stringify(req.body);
    // create File-like object
    const { Blob } = require('buffer');
    const fileObj = new (function (parts, filename, opts) {
      const b = new Blob(parts, opts);
      b.name = filename;
      b.lastModified = Date.now();
      return b;
    })([json], 'encKey.json', { type: 'application/json' });

    if (typeof client.uploadFile === 'function') {
      const cid = await client.uploadFile(fileObj);
      appendToDB('audit', { action: 'upload-key', cid: cid.toString(), space: currentSpaceDid, ts: Date.now() });
      return res.json({ cid: cid.toString(), space: currentSpaceDid });
    } else if (typeof client.upload === 'function') {
      const cid = await client.upload([fileObj]);
      appendToDB('audit', { action: 'upload-key', cid: String(cid), space: currentSpaceDid, ts: Date.now() });
      return res.json({ cid: String(cid), space: currentSpaceDid });
    } else {
      throw new Error('client lacks uploadFile/upload method');
    }
  } catch (err) {
    console.error('upload-key error', err);
    return res.status(500).json({ error: err && err.message ? err.message : String(err) });
  }
});

app.get('/api/audit', (req, res) => {
  try {
    const db = fs.readJsonSync(DB_PATH);
    res.json(db);
  } catch (e) {
    res.status(500).json({ error: 'read audit db failed' });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`✅ Backend listening on ${PORT}`));
