// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAuditLogger {
    enum Action { Grant, Revoke, Emergency, Other }
    function log(Action action, string calldata fileCid, string calldata meta) external returns (uint256);
}

contract ConsentManager {
    struct Consent {
        address patient;
        address grantee;
        string fileCid;
        uint256 expiresAt;
        string encKeyCid;
        bool active;
    }

    mapping(bytes32 => Consent) private consents;
    address public auditLogger;

    event AccessGranted(address indexed patient, address indexed grantee, string fileCid, uint256 expiresAt, string encKeyCid);
    event AccessRevoked(address indexed patient, address indexed grantee, string fileCid);
    event EmergencyAccess(address indexed requester, string fileCid, uint256 timestamp);

    constructor(address _auditLogger) {
        auditLogger = _auditLogger;
    }

    function setAuditLogger(address _auditLogger) external {
        // For MVP, allow re-setting by anyone (or restrict to owner if you add Ownable later)
        auditLogger = _auditLogger;
    }

    function grantAccess(string calldata fileCid, address grantee, uint256 expiresAt, string calldata encKeyCid) external {
        bytes32 key = keccak256(abi.encodePacked(fileCid, grantee));
        consents[key] = Consent(msg.sender, grantee, fileCid, expiresAt, encKeyCid, true);
        emit AccessGranted(msg.sender, grantee, fileCid, expiresAt, encKeyCid);

        // call audit logger (best-effort; if auditLogger is zero address skip)
        if (auditLogger != address(0)) {
            // meta: include encKeyCid so offchain knows where to fetch encrypted key
            IAuditLogger(auditLogger).log(IAuditLogger.Action.Grant, fileCid, encKeyCid);
        }
    }

    function revokeAccess(string calldata fileCid, address grantee) external {
        bytes32 key = keccak256(abi.encodePacked(fileCid, grantee));
        Consent storage c = consents[key];
        require(c.patient == msg.sender, "only patient can revoke");
        c.active = false;
        emit AccessRevoked(msg.sender, grantee, fileCid);

        if (auditLogger != address(0)) {
            IAuditLogger(auditLogger).log(IAuditLogger.Action.Revoke, fileCid, "");
        }
    }

    function isAccessAllowed(string calldata fileCid, address grantee) external view returns (bool) {
        bytes32 key = keccak256(abi.encodePacked(fileCid, grantee));
        Consent storage c = consents[key];
        return (c.active && c.expiresAt >= block.timestamp);
    }

    function emergencyAccess(string calldata fileCid) external {
        emit EmergencyAccess(msg.sender, fileCid, block.timestamp);
        if (auditLogger != address(0)) {
            IAuditLogger(auditLogger).log(IAuditLogger.Action.Emergency, fileCid, "");
        }
    }

    function getConsent(string calldata fileCid, address grantee) external view returns (address patient, address _grantee, uint256 expiresAt, string memory encKeyCid, bool active) {
        bytes32 key = keccak256(abi.encodePacked(fileCid, grantee));
        Consent storage c = consents[key];
        return (c.patient, c.grantee, c.expiresAt, c.encKeyCid, c.active);
    }
}
