// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../contracts/EventListenerBase.sol";
import "hardhat/console.sol";

contract LogParseTest is EventListenerBase {
    uint256 public mintedAmount;
    mapping(address => uint256) public userMintedAmount;

    function handleTargetEvent(address user, uint256 eventId, uint256 tokenId) internal override {
        super.handleTargetEvent(user, eventId, tokenId);
        mintedAmount += TOKENS_PER_POAP;
        userMintedAmount[user] += TOKENS_PER_POAP;
    }

    function testDecodeEventLogs() public {
        bytes[] memory logs = new bytes[](4);  // We'll create 2 pairs of logs (Transfer + EventToken)

        // First pair of logs
        logs[0] = abi.encode(
            bytes32(0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef),  // Transfer event signature
            bytes32(0),  // from address (0 for minting)
            bytes32(uint256(uint160(0x1234567890123456789012345678901234567890))),  // to address
            bytes32(uint256(1000))  // tokenId
        );
        logs[1] = abi.encode(
            bytes32(0x4b3711cd7ece062b0828c1b6e08d814a72d4c003383a016c833cbb1b45956e34),  // EventToken event signature
            bytes32(uint256(123)),  // eventId
            bytes32(0),  // Unused topic
            bytes32(0),  // Unused topic
            bytes32(uint256(1000))  // tokenId in data field
        );

        // Second pair of logs
        logs[2] = abi.encode(
            bytes32(0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef),
            bytes32(0),
            bytes32(uint256(uint160(0x9876543210987654321098765432109876543210))),
            bytes32(uint256(1001))
        );
        logs[3] = abi.encode(
            bytes32(0x4b3711cd7ece062b0828c1b6e08d814a72d4c003383a016c833cbb1b45956e34),
            bytes32(uint256(456)),
            bytes32(0),
            bytes32(0),
            bytes32(uint256(1001))
        );
    
        EventData[] memory result = decodeEventLogs(logs);
        
        for (uint i = 0; i < result.length; i++) {
            console.log("Decoded Event:");
            console.log("User:", uint256(uint160(result[i].user)));
            console.log("EventId:", result[i].eventId);
            console.log("TokenId:", result[i].tokenId);
        }
    }
   }