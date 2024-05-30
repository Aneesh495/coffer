// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/test;

@test:Config {}
function testWalAppendAndReplay() returns error? {
    WalManager wal = new ();

    WalRecord r1 = wal.append(WAL_TX_INIT, "tx_101:Alice->Bob:100USD", 1730550000000000);
    test:assertEquals(r1.lsn, 1);

    WalRecord r2 = wal.append(WAL_TX_SETTLED, "tx_101:SETTLED:FEDNOW", 1730550001000000);
    test:assertEquals(r2.lsn, 2);

    WalRecord r3 = wal.append(WAL_LEDGER_POSTING, "bat_01:Alice-100:Bob+100", 1730550002000000);
    test:assertEquals(r3.lsn, 3);

    test:assertEquals(wal.getRecordCount(), 3);
    test:assertEquals(wal.getCurrentLsn(), 3);

    // Replay and verify checksums
    WalRecord[] verified = check wal.replayAndVerify();
    test:assertEquals(verified.length(), 3);
    test:assertEquals(verified[0].payload, "tx_101:Alice->Bob:100USD");
    test:assertEquals(verified[2].lsn, 3);
}

@test:Config {}
function testMerkleTreeRootAndOddNodes() {
    string h1 = "a1b2c3d4e5f60102030405060708090a1b2c3d4e5f60102030405060708090a1";
    string h2 = "b2c3d4e5f60102030405060708090a1b2c3d4e5f60102030405060708090a1b2";
    string h3 = "c3d4e5f60102030405060708090a1b2c3d4e5f60102030405060708090a1b2c3";

    // 2 leaves
    string root2 = computeMerkleRoot([h1, h2]);
    test:assertTrue(root2.length() == 64);

    // 3 leaves (odd count: tests duplicate/self-hashing)
    string root3 = computeMerkleRoot([h1, h2, h3]);
    test:assertTrue(root3.length() == 64);
    test:assertNotEquals(root2, root3);

    // 1 leaf returns itself
    string root1 = computeMerkleRoot([h1]);
    test:assertEquals(root1, h1);

    // 0 leaves returns empty string
    string root0 = computeMerkleRoot([]);
    test:assertEquals(root0, "");
}

@test:Config {}
function testMerkleProofVerification() {
    string leafA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    string leafB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

    string root = computeMerkleRoot([leafA, leafB]);

    MerkleProofStep step = {
        siblingHash: leafB,
        isRightSibling: true
    };

    MerkleProof proof = {
        leafHash: leafA,
        leafIndex: 0,
        steps: [step],
        rootHash: root
    };

    test:assertTrue(verifyMerkleProof(proof));

    // Tampered root should fail
    MerkleProof badProof = {
        leafHash: leafA,
        leafIndex: 0,
        steps: [step],
        rootHash: "0000000000000000000000000000000000000000000000000000000000000000"
    };
    test:assertFalse(verifyMerkleProof(badProof));
}

@test:Config {}
function testSnapshotManagement() {
    SnapshotManager sm = new ();
    test:assertEquals(sm.getLatestSnapshot(), ());

    StateSnapshot snap = {
        snapshotId: "SNAP_001",
        lastCommittedLsn: 1500,
        timestampEpochNs: 1730550000000000,
        accountCount: 45,
        transactionCount: 750,
        stateDigest: "abcdef123456"
    };

    sm.saveSnapshot(snap);
    StateSnapshot? fetched = sm.getLatestSnapshot();
    test:assertTrue(fetched is StateSnapshot);
    if fetched is StateSnapshot {
        test:assertEquals(fetched.snapshotId, "SNAP_001");
        test:assertEquals(fetched.lastCommittedLsn, 1500);
    }
}
