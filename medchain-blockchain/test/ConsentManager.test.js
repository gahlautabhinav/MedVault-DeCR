const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ConsentManager", function () {
  let ConsentManager, cm, owner, patient, doctor;

  beforeEach(async function () {
    [owner, patient, doctor] = await ethers.getSigners();

    // Deploy AuditLogger first
    const AuditLogger = await ethers.getContractFactory("AuditLogger");
    const al = await AuditLogger.connect(owner).deploy();
    await al.waitForDeployment();

    // Deploy ConsentManager with audit logger address
    ConsentManager = await ethers.getContractFactory("ConsentManager");
    cm = await ConsentManager.connect(owner).deploy(await al.getAddress());
    await cm.waitForDeployment();
  });

  it("grantAccess emits AccessGranted and stores consent", async function () {
    const fileCid = "QmTestFileCid";
    const expiresAt = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    const encKeyCid = "QmEncKeyCid";

    await expect(cm.connect(patient).grantAccess(fileCid, doctor.address, expiresAt, encKeyCid))
      .to.emit(cm, "AccessGranted")
      .withArgs(patient.address, doctor.address, fileCid, expiresAt, encKeyCid);

    const c = await cm.getConsent(fileCid, doctor.address);
    const patientAddr = c.patient;
    const granteeAddr = c._grantee || c.grantee;
    const expiresAtReturned = Number(c.expiresAt);
    const encKeyCidReturned = c.encKeyCid;
    const activeReturned = c.active;

    expect(patientAddr).to.equal(patient.address);
    expect(granteeAddr).to.equal(doctor.address);
    expect(expiresAtReturned).to.equal(expiresAt);
    expect(encKeyCidReturned).to.equal(encKeyCid);
    expect(activeReturned).to.equal(true);
  });

  it("revokeAccess disables future access", async function () {
    const fileCid = "QmX";
    const expiresAt = Math.floor(Date.now() / 1000) + 3600;
    const encKeyCid = "QmK";
    await cm.connect(patient).grantAccess(fileCid, doctor.address, expiresAt, encKeyCid);
    await expect(cm.connect(patient).revokeAccess(fileCid, doctor.address))
       .to.emit(cm, "AccessRevoked")
       .withArgs(patient.address, doctor.address, fileCid);

    const allowed = await cm.isAccessAllowed(fileCid, doctor.address);
    expect(allowed).to.equal(false);
  });

  it("isAccessAllowed respects expiry (explicit check with block timestamp)", async function () {
    const fileCid = "QmY";
    const expiresAt = Math.floor(Date.now() / 1000) - 10; // intentionally already expired
    const encKeyCid = "QmK2";

    // Call grantAccess with an already-expired timestamp
    await cm.connect(patient).grantAccess(fileCid, doctor.address, expiresAt, encKeyCid);

    // Read stored consent and convert types
    const c = await cm.getConsent(fileCid, doctor.address);
    const storedExpires = Number(c.expiresAt);

    // Read the latest block timestamp from the provider (explicit)
    const latestBlock = await ethers.provider.getBlock("latest");
    const blockTs = latestBlock.timestamp;

    // Debug printing (will show in mocha output) - remove if you want cleaner logs
    console.log("storedExpires:", storedExpires, "blockTs:", blockTs, "expiresAt (input):", expiresAt);

    // Assert stored expiry is indeed in the past compared to block timestamp
    expect(storedExpires).to.be.lessThan(blockTs);

    // Now assert isAccessAllowed returns false
    const allowed = await cm.isAccessAllowed(fileCid, doctor.address);
    expect(allowed).to.equal(false);
  });

  it("emergencyAccess emits EmergencyAccess", async function () {
    const fileCid = "QmZ";
    await expect(cm.connect(doctor).emergencyAccess(fileCid))
      .to.emit(cm, "EmergencyAccess");
  });

  it("writes audit entries on grant", async function () {
    const fileCid = "QmTestFileCid2";
    const expiresAt = Math.floor(Date.now() / 1000) + 3600;
    const encKeyCid = "QmEncKeyCid2";

    // patient calls grant
    await cm.connect(patient).grantAccess(fileCid, doctor.address, expiresAt, encKeyCid);

    const auditAddr = await cm.auditLogger();
    const AuditLogger = await ethers.getContractFactory("AuditLogger");
    const al = await AuditLogger.attach(auditAddr);

    const total = await al.totalEntries();
    expect(Number(total)).to.equal(1);

    const entry = await al.getEntry(0);
    const cmAddress = await cm.getAddress();
    expect(entry.actor).to.equal(cmAddress);
    expect(Number(entry.timestamp)).to.be.greaterThan(0);
    expect(entry.meta).to.equal(encKeyCid);
  });

});
