// Copyright (c) 2026 Aneesh Krishna
// Licensed under the MIT License. See LICENSE for details.

import ballerina/crypto;

# Inclusion proof node along the path from leaf to Merkle root.
#
# + siblingHash - Sibling hash at this tree height
# + isRightSibling - True if sibling is on the right
public type MerkleProofStep record {|
    string siblingHash;
    boolean isRightSibling;
|};

# Complete cryptographic proof certifying that a leaf is included in a Merkle root.
#
# + leafHash - Original target leaf hash
# + leafIndex - Leaf position in the original ordered batch
# + steps - Array of MerkleProofSteps ascending to the root
# + rootHash - Computed Merkle root
public type MerkleProof record {|
    string leafHash;
    int leafIndex;
    MerkleProofStep[] steps;
    string rootHash;
|};

# Computes a binary SHA-256 Merkle root across an array of leaf string hashes.
#
# + leafHashes - Array of leaf hashes
# + return - 64-character hexadecimal SHA-256 root hash or empty string if empty
public isolated function computeMerkleRoot(string[] leafHashes) returns string {
    if leafHashes.length() == 0 {
        return "";
    }
    if leafHashes.length() == 1 {
        return leafHashes[0];
    }

    string[] currentLayer = [];
    foreach string h in leafHashes {
        currentLayer.push(h);
    }

    while currentLayer.length() > 1 {
        string[] nextLayer = [];
        int i = 0;
        while i < currentLayer.length() {
            string left = currentLayer[i];
            string right = (i + 1 < currentLayer.length()) ? currentLayer[i + 1] : left; // Duplicate last if odd

            string combined = left + right;
            byte[] parentHashBytes = crypto:hashSha256(combined.toBytes());
            nextLayer.push(parentHashBytes.toBase16());

            i = i + 2;
        }
        currentLayer = nextLayer;
    }

    return currentLayer[0];
}

# Verifies an audit Merkle inclusion proof against a known root hash.
#
# + proof - MerkleProof containing leaf and sibling steps
# + return - True if hash path mathematically reconstructs the rootHash
public isolated function verifyMerkleProof(MerkleProof proof) returns boolean {
    string currentHash = proof.leafHash;

    foreach MerkleProofStep step in proof.steps {
        string combined = "";
        if step.isRightSibling {
            combined = currentHash + step.siblingHash;
        } else {
            combined = step.siblingHash + currentHash;
        }
        byte[] parentHashBytes = crypto:hashSha256(combined.toBytes());
        currentHash = parentHashBytes.toBase16();
    }

    return currentHash == proof.rootHash;
}
