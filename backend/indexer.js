// backend/indexer.js
require('dotenv').config();
const fs = require('fs-extra');
const path = require('path');
const { ethers } = require('ethers');

const DB_PATH = path.join(__dirname, 'audit_db.json');
if (!fs.existsSync(DB_PATH)) fs.writeJsonSync(DB_PATH, { audit: [], grants: [] }, { spaces: 2 });

// Helpers -----------------------------------------------------------
// Convert BigInt => Number when safe else => string; run recursively.
function normalizeValue(v) {
  if (typeof v === 'bigint') {
    // if safe to convert to Number, do so; else use string
    if (v <= BigInt(Number.MAX_SAFE_INTEGER) && v >= BigInt(Number.MIN_SAFE_INTEGER)) {
      return Number(v);
    }
    return v.toString();
  }
  if (Array.isArray(v)) return v.map(normalizeValue);
  if (v && typeof v === 'object') {
    const out = {};
    for (const k of Object.keys(v)) out[k] = normalizeValue(v[k]);
    return out;
  }
  return v;
}

// JSON stringify replacer to handle BigInt anywhere
function jsonReplacer(_, value) {
  if (typeof value === 'bigint') {
    return value.toString();
  }
  return value;
}

function writeDb(db) {
  // Use stringify with replacer then write raw to file (avoids jsonfile BigInt issue)
  fs.writeFileSync(DB_PATH, JSON.stringify(db, jsonReplacer, 2), 'utf8');
}

function readDb() {
  try {
    return fs.readJsonSync(DB_PATH);
  } catch (e) {
    return { audit: [], grants: [] };
  }
}

// Config & contracts ------------------------------------------------
const provider = new ethers.JsonRpcProvider(process.env.AMOY_RPC_URL);
const consentJson = require('../medchain-blockchain/deployments/ConsentManager.json');
const auditJson = require('../medchain-blockchain/deployments/AuditLogger.json');

const CONSENT_ADDR = consentJson.address;
const AUDIT_ADDR = auditJson.address;

console.log('🔎 Indexer (polling mode, getLogs) running…');
console.log('  ConsentManager:', CONSENT_ADDR);
console.log('  AuditLogger:   ', AUDIT_ADDR);

// Build topics via Interface (ethers v6)
const consentIface = new ethers.Interface(consentJson.abi);
const auditIface = new ethers.Interface(auditJson.abi);

// Topics for events we care about
// Use .getEvent() + .topicHash in ethers v6
const topics = {
  AccessGranted: consentIface.getEvent("AccessGranted").topicHash,
  AccessRevoked: consentIface.getEvent("AccessRevoked").topicHash,
  EmergencyAccess: consentIface.getEvent("EmergencyAccess").topicHash,
  AuditLogged: auditIface.getEvent("AuditLogged").topicHash
};

// Polling state
let lastBlock = 0;
const POLL_INTERVAL_MS = 4_000;

async function processLogs(logs) {
  const db = readDb();

  for (const log of logs) {
    try {
      // Which contract?
      if (log.address.toLowerCase() === CONSENT_ADDR.toLowerCase()) {
        // Try parse with consent ABI
        const parsed = consentIface.parseLog(log);
        const args = parsed.args;

        if (parsed.name === 'AccessGranted') {
          const obj = {
            contract: 'ConsentManager',
            event: 'AccessGranted',
            args: normalizeValue([
              args.patient,
              args.grantee,
              args.fileCid,
              args.expiresAt, // bigint normally
              args.encKeyCid
            ]),
            txHash: log.transactionHash,
            blockNumber: Number(log.blockNumber),
            ts: Date.now()
          };
          db.audit.push(obj);
          // Also add to grants list for quick lookup
          db.grants.push({
            patient: String(args.patient),
            grantee: String(args.grantee),
            fileCid: String(args.fileCid),
            encKeyCid: String(args.encKeyCid),
            expiresAt: normalizeValue(args.expiresAt),
            txHash: log.transactionHash,
            blockNumber: Number(log.blockNumber),
            ts: Date.now(),
            space: process.env.SPACE_DID || 'unknown'
          });
          console.log('📌 ConsentManager Event: AccessGranted', Array.from(obj.args || []));
        } else if (parsed.name === 'AccessRevoked') {
          const obj = {
            contract: 'ConsentManager',
            event: 'AccessRevoked',
            args: normalizeValue([args.patient, args.grantee, args.fileCid]),
            txHash: log.transactionHash,
            blockNumber: Number(log.blockNumber),
            ts: Date.now()
          };
          db.audit.push(obj);
          // push revoke audit entry as well (MVP)
          db.audit.push({
            action: 'revoke-access',
            patient: String(args.patient),
            grantee: String(args.grantee),
            fileCid: String(args.fileCid),
            txHash: log.transactionHash,
            ts: Date.now()
          });
          console.log('📌 ConsentManager Event: AccessRevoked', Array.from(obj.args || []));
        } else if (parsed.name === 'EmergencyAccess') {
          const obj = {
            contract: 'ConsentManager',
            event: 'EmergencyAccess',
            requester: String(args.requester),
            fileCid: String(args.fileCid),
            timestamp: normalizeValue(args.timestamp),
            txHash: log.transactionHash,
            blockNumber: Number(log.blockNumber),
            ts: Date.now()
          };
          db.audit.push(obj);
          db.audit.push({
            action: 'emergency-access',
            patient: String(args.requester),
            fileCid: String(args.fileCid),
            txHash: log.transactionHash,
            ts: Date.now(),
            space: process.env.SPACE_DID || 'unknown'
          });
          console.log('📌 ConsentManager Event: EmergencyAccess', obj.requester, obj.fileCid);
        } else {
          // Unexpected event (skip)
        }
      } else if (log.address.toLowerCase() === AUDIT_ADDR.toLowerCase()) {
        const parsed = auditIface.parseLog(log);
        const args = parsed.args;
        // AuditLogged(entryId, actor, action, fileCid, meta, timestamp)
        const obj = {
          contract: 'AuditLogger',
          event: 'AuditLogged',
          entryId: normalizeValue(args.entryId),
          actor: String(args.actor),
          action: normalizeValue(args.action),
          fileCid: String(args.fileCid || ''),
          meta: String(args.meta || ''),
          timestamp: normalizeValue(args.timestamp),
          txHash: log.transactionHash,
          blockNumber: Number(log.blockNumber),
          ts: Date.now()
        };
        db.audit.push(obj);
        console.log('📝 AuditLogger Event: AuditLogged', [
          obj.entryId,
          obj.actor,
          obj.action,
          obj.fileCid,
          obj.meta,
          obj.timestamp
        ]);
      } else {
        // another contract - ignore
      }
    } catch (err) {
      console.error('parse log error', err);
    }
  }

  // write DB safely (normalize bigints)
  try {
    writeDb(db);
  } catch (err) {
    console.error('writeDb error', err);
  }
}

// Polling loop using getLogs (works around filter issues on some RPCs)
async function poll() {
  try {
    const latest = await provider.getBlockNumber();
    if (!lastBlock) lastBlock = Math.max(latest - 50, 0); // catch last 50 blocks on first run

    let from = lastBlock + 1;
    let to = latest;

    // No new blocks → skip
    if (from > to) return;

    // Clamp range size (some RPCs reject huge ranges)
    if (to - from > 2000) {
      to = from + 2000; // chunk in 2000 block windows
    }

    const filter = {
      address: [CONSENT_ADDR, AUDIT_ADDR],
      fromBlock: from,
      toBlock: to
    };

    const logs = await provider.getLogs(filter);
    if (logs && logs.length > 0) {
      await processLogs(logs);
    }

    // Advance the last processed block
    lastBlock = to;
  } catch (err) {
    // Graceful error handling for flaky RPCs
    if (
      err &&
      err.code === -32000 &&
      err.message &&
      (err.message.toLowerCase().includes("filter not found") ||
        err.message.toLowerCase().includes("invalid block range"))
    ) {
      console.warn("@TODO RPC warning (ignored):", err.message);
    } else {
      console.error("poll error", err);
    }
  }
}

// Main entry
(async function main() {
  try {
    console.log('🔎 Indexer (polling mode, getLogs) running…');
    console.log('   ConsentManager:', CONSENT_ADDR);
    console.log('   AuditLogger:   ', AUDIT_ADDR);

    // initial seed: read current latest and set lastBlock to latest (so we only get future logs)
    const latest = await provider.getBlockNumber();
    lastBlock = latest;

    // but also run one immediate poll for recent blocks (catch events that happened right after deployment)
    await poll();

    // interval poll
    setInterval(() => {
      poll().catch(err => console.error('poll top error', err));
    }, POLL_INTERVAL_MS);
  } catch (err) {
    console.error('Indexer startup error:', err);
    process.exit(1);
  }
})();
