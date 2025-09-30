// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Audit Logger
/// @notice Minimal immutable audit entries for access / emergency events
contract AuditLogger {
    enum Action { Grant, Revoke, Emergency, Other }

    struct Entry {
        address actor;
        Action action;
        string fileCid;
        string meta; // optional small notes (e.g. encKeyCid, reason)
        uint256 timestamp;
    }

    Entry[] public entries;

    event AuditLogged(uint256 indexed entryId, address indexed actor, Action action, string fileCid, string meta, uint256 timestamp);

    function log(Action action, string calldata fileCid, string calldata meta) external returns (uint256) {
        uint256 id = entries.length;
        entries.push(Entry({
            actor: msg.sender,
            action: action,
            fileCid: fileCid,
            meta: meta,
            timestamp: block.timestamp
        }));
        emit AuditLogged(id, msg.sender, action, fileCid, meta, block.timestamp);
        return id;
    }

    // helper read
    function getEntry(uint256 id) external view returns (address actor, Action action, string memory fileCid, string memory meta, uint256 timestamp) {
        Entry storage e = entries[id];
        return (e.actor, e.action, e.fileCid, e.meta, e.timestamp);
    }

    function totalEntries() external view returns (uint256) {
        return entries.length;
    }
}
