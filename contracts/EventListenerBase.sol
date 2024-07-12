// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "hardhat/console.sol";

contract EventListenerBase {
    mapping(uint256 => bool) public whitelistedEventIds;
    mapping(uint256 => bool) public processedTokenIds;
    uint256 public constant TOKENS_PER_POAP = 3 * 10**18; // 3 tokens with 18 decimals

    event TargetEventReceived(address indexed user, uint256 eventId, uint256 tokenId);
    event DebugLog(string message);
    event DebugLogBytes(bytes data);
    event DebugLogAddress(address data);
    event DebugLogUint256(uint256 data);
    event DebugLogString(string data);
    event EventDataLog(address user, uint256 eventId, uint256 tokenId);
    event RawLogData(bytes logData);


    struct EventData {
        uint256 eventId;
        uint256 tokenId;
        address user;
    }

    function whitelistEventId(uint256 eventId) public {
        whitelistedEventIds[eventId] = true;
    }

    function processEvents(bytes[] memory logs) public returns (uint256) {
        EventData[] memory eventDataArray = decodeEventLogs(logs);
        uint256 processedCount = 0;
        
        for (uint256 j = 0; j < eventDataArray.length; j++) {
            if (whitelistedEventIds[eventDataArray[j].eventId] && !processedTokenIds[eventDataArray[j].tokenId]) {
                processedTokenIds[eventDataArray[j].tokenId] = true;
                handleTargetEvent(eventDataArray[j].user, eventDataArray[j].eventId, eventDataArray[j].tokenId);
                processedCount++;
            }
        }

        return processedCount;
    }

    function decodeEventLogs(bytes[] memory logs) internal returns (EventData[] memory eventDataArray) {
        eventDataArray = new EventData[](logs.length / 2); 
        uint256 eventDataIndex = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            emit DebugLog("Begin decode...");
            emit RawLogData(logs[i]);  // Emit the raw log data
            //emit DebugLogString("Log data slice: ");
            //emit DebugLogBytes(slice(logs[i], 0, 32));

            bytes32 eventSignature = bytesToBytes32(slice(logs[i], 0, 32));
            string memory eventSignatureStr = bytes32ToString(eventSignature);
            emit DebugLogString(eventSignatureStr);
            
            if (eventSignature == keccak256("Transfer(address,address,uint256)")) {
                // Decode Transfer event
                emit DebugLog("transfer event");
                address to = bytesToAddress(slice(logs[i], 32, 20));
                uint256 tokenId = bytesToUint256(slice(logs[i], 64, 32));
                
                emit DebugLogAddress(to);
                emit DebugLogUint256(tokenId);

                eventDataArray[eventDataIndex].user = to;
                eventDataArray[eventDataIndex].tokenId = tokenId;
            } else if (eventSignature == keccak256("EventToken(uint256,uint256)")) {
                // Decode EventToken event
                emit DebugLog("eventtoken event");
                uint256 eventId = bytesToUint256(slice(logs[i], 32, 32));
                uint256 tokenId = bytesToUint256(slice(logs[i], 64, 32));
                
                emit DebugLogUint256(eventId);
                emit DebugLogUint256(tokenId);

                eventDataArray[eventDataIndex].eventId = eventId;
                // Cross-check tokenId
                require(eventDataArray[eventDataIndex].tokenId == tokenId, "TokenId mismatch");
                eventDataIndex++;
            } else {
                // No matching eventSignature
                emit DebugLog("no matching eventSignature");
                emit DebugLogBytes(slice(logs[i], 0, 32));
            }
        }
        
        assembly {
            mstore(eventDataArray, eventDataIndex)
        }
    }

    function bytes32ToString(bytes32 _bytes32) private pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (uint8 j = 0; j < i; j++) {
            bytesArray[j] = _bytes32[j];
        }
        return string(bytesArray);
    }
        

    function handleTargetEvent(address user, uint256 eventId, uint256 tokenId) internal virtual {
        emit TargetEventReceived(user, eventId, tokenId);
        // Token minting logic would go here in the actual implementation
    }

    // Utility functions
    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        require(data.length >= (start + length), "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(length)
            case 0 {
                tempBytes := mload(0x40)
                let mc := add(tempBytes, 0x20)
                let end := add(mc, length)
                for {
                    let cc := add(add(data, 0x20), start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }
                mstore(tempBytes, length)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            default {
                tempBytes := mload(0x40)
                mstore(tempBytes, 0)
                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function bytesToBytes32(bytes memory b) internal pure returns (bytes32) {
        bytes32 out;
        assembly {
            out := mload(add(b, 32))
        }
        return out;
    }

    function bytesToAddress(bytes memory b) internal pure returns (address) {
        address addr;
        assembly {
            addr := mload(add(b, 20))
        }
        return addr;
    }

    function bytesToUint256(bytes memory b) internal pure returns (uint256) {
        uint256 numValue;
        assembly {
            numValue := mload(add(b, 32))
        }
        return numValue;
    }
}