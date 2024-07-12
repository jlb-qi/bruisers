// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

interface IToken {
    function mint(address to, uint256 amount) external;
}

interface IPOAP {
    function getPastEvents(string calldata eventName, uint fromBlock, uint toBlock) external view returns (bytes[] memory);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event EventToken(uint256 indexed eventId, uint256 indexed tokenId);
}

contract EventListener is Initializable, UUPSUpgradeable, OwnableUpgradeable, AutomationCompatibleInterface {
    IToken public tokenContract;
    IPOAP public poapContract;
    mapping(uint256 => bool) public whitelistedEventIds;
    mapping(uint256 => bool) public processedTokenIds;
    uint256 public constant TOKENS_PER_POAP = 3 * 10**18; // 3 tokens with 18 decimals
    uint256 public lastProcessedBlock;
    uint256 public maxEventsPerUpkeep;

    event TargetEventReceived(address indexed user, uint256 eventId, uint256 tokenId);
    event EventIdWhitelisted(uint256 eventId);
    event EventIdRemoved(uint256 eventId);
    event UpkeepStarted(uint256 fromBlock, uint256 toBlock);
    event UpkeepCompleted(uint256 fromBlock, uint256 toBlock, uint256 eventsProcessed);
    event UpkeepFailed(string reason);
    event CheckUpkeepCall(CheckUpkeepInfo info);


    struct EventData {
        uint256 eventId;
        uint256 tokenId;
        address user;
    }

/// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address _tokenContract, address _poapContract, uint256 _maxEventsPerUpkeep) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        tokenContract = IToken(_tokenContract);
        poapContract = IPOAP(_poapContract);
        lastProcessedBlock = block.number;
        maxEventsPerUpkeep = _maxEventsPerUpkeep;
    }

    function whitelistEventId(uint256 eventId) external onlyOwner {
        whitelistedEventIds[eventId] = true;
        emit EventIdWhitelisted(eventId);
        console.log("Event ID %d whitelisted", eventId);
    }

    function removeEventId(uint256 eventId) external onlyOwner {
        whitelistedEventIds[eventId] = false;
        emit EventIdRemoved(eventId);
        console.log("Event ID %d removed from whitelist", eventId);
    }

    struct CheckUpkeepInfo {
        address caller;
        address target;
        bytes checkData;
        uint256 latestBlock;
        uint256 fromBlock;
        uint256 toBlock;
        uint256 blocksSinceLastUpkeep;
        bool upkeepNeeded;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 latestBlock = block.number;
        uint256 fromBlock = lastProcessedBlock + 1;
        
        // Failsafe: If fromBlock is too old, move it forward
        if (fromBlock < latestBlock - 50000) {
            fromBlock = latestBlock - 50000;
        }
        
        uint256 toBlock = Math.min(fromBlock + maxEventsPerUpkeep - 1, latestBlock);
        uint256 blocksSinceLastUpkeep = latestBlock - lastProcessedBlock;

        upkeepNeeded = fromBlock <= latestBlock;

        CheckUpkeepInfo memory info = CheckUpkeepInfo({
            caller: msg.sender,
            target: address(this),
            checkData: checkData,
            latestBlock: latestBlock,
            fromBlock: fromBlock,
            toBlock: toBlock,
            blocksSinceLastUpkeep: blocksSinceLastUpkeep,
            upkeepNeeded: upkeepNeeded
        });

        performData = abi.encode(info);

    }

    function logCheckUpkeepInfo(CheckUpkeepInfo memory info) internal {
        emit CheckUpkeepCall(info);
    }

    function decodeEventLogs(bytes[] memory logs) internal pure returns (EventData[] memory eventDataArray) {
        eventDataArray = new EventData[](logs.length / 2); 
        uint256 eventDataIndex = 0;
        
        for (uint256 i = 0; i < logs.length; i++) {
            bytes32 eventSignature = bytesToBytes32(slice(logs[i], 0, 32));
            
            if (eventSignature == keccak256("Transfer(address,address,uint256)")) {
                // Decode Transfer event
                address to = bytesToAddress(slice(logs[i], 32, 20));
                uint256 tokenId = bytesToUint256(slice(logs[i], 64, 32));
                
                eventDataArray[eventDataIndex].user = to;
                eventDataArray[eventDataIndex].tokenId = tokenId;
                console.log("Decoded Transfer event: to=%s, tokenId=%d", to, tokenId);
            } else if (eventSignature == keccak256("EventToken(uint256,uint256)")) {
                // Decode EventToken event
                uint256 eventId = bytesToUint256(slice(logs[i], 32, 32));
                uint256 tokenId = bytesToUint256(slice(logs[i], 64, 32));
                
                eventDataArray[eventDataIndex].eventId = eventId;
                // Cross-check tokenId
                require(eventDataArray[eventDataIndex].tokenId == tokenId, "TokenId mismatch");
                eventDataIndex++;
                console.log("Decoded EventToken event: eventId=%d, tokenId=%d", eventId, tokenId);
            }
        }
        
        assembly {
            mstore(eventDataArray, eventDataIndex)
        }
    }

    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory tempBytes;
        assembly {
            switch iszero(length)
            case 0 {
                tempBytes := mload(0x40)
                let lengthmod := and(length, 31)
                let mc := add(add(tempBytes, lengthmod), mul(iszero(lengthmod), 32))
                let end := add(mc, length)

                for {
                    let cc := add(add(add(data, lengthmod), mul(iszero(lengthmod), 32)), start)
                } lt(mc, end) {
                    mc := add(mc, 32)
                    cc := add(cc, 32)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, length)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            default {
                tempBytes := mload(0x40)
                mstore(tempBytes, 0)
                mstore(0x40, add(tempBytes, 32))
            }
        }
        return tempBytes;
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

    function bytesToBytes32(bytes memory b) internal pure returns (bytes32) {
        bytes32 out;
        assembly {
            out := mload(add(b, 32))
        }
        return out;
    }

     function performUpkeep(bytes calldata performData) external override {
        CheckUpkeepInfo memory info = abi.decode(performData, (CheckUpkeepInfo));
        (uint256 fromBlock, uint256 toBlock) = abi.decode(performData, (uint256, uint256));
        require(fromBlock < toBlock, "Invalid block range");

        // Log the CheckUpkeepInfo
        logCheckUpkeepInfo(info);

        emit UpkeepStarted(fromBlock, toBlock);

        uint256 processedUntil = fromBlock;
        uint256 eventCount = 0;

        for (uint256 i = fromBlock; i <= toBlock && eventCount < maxEventsPerUpkeep; i++) {
            (bool success, bytes memory result) = address(poapContract).staticcall(
                abi.encodeWithSignature("getPastEvents(string,uint256,uint256)", "EventToken", i, i)
            );
            require(success, "POAP contract call failed");

            if (result.length > 0) {
                bytes[] memory logs = abi.decode(result, (bytes[]));
                EventData[] memory eventDataArray = decodeEventLogs(logs);
                
                for (uint256 j = 0; j < eventDataArray.length; j++) {
                    if (whitelistedEventIds[eventDataArray[j].eventId] && !processedTokenIds[eventDataArray[j].tokenId]) {
                        processedTokenIds[eventDataArray[j].tokenId] = true;
                        bool handleSuccess = handleTargetEvent(eventDataArray[j].user, eventDataArray[j].eventId, eventDataArray[j].tokenId);
                        require(handleSuccess, "Failed to handle target event");
                        eventCount++;
                    }
                }
            }
            processedUntil = i;
        }

        lastProcessedBlock = processedUntil;
        emit UpkeepCompleted(fromBlock, processedUntil, eventCount);
    }

    function handleTargetEvent(address user, uint256 eventId, uint256 tokenId) internal returns (bool) {
        try tokenContract.mint(user, TOKENS_PER_POAP) {
            emit TargetEventReceived(user, eventId, tokenId);
            return true;
        } catch Error(string memory reason) {
            emit UpkeepFailed(string(abi.encodePacked("Token mint failed: ", reason)));
            return false;
        } catch (bytes memory /*lowLevelData*/) {
            emit UpkeepFailed("Token mint failed with unknown error");
            return false;
        }
    }

    // Function to update maxEventsPerUpkeep
    function setMaxEventsPerUpkeep(uint256 _maxEventsPerUpkeep) external onlyOwner {
        maxEventsPerUpkeep = _maxEventsPerUpkeep;
    }

    function setLastProcessedBlockForTesting(uint256 _block) public {
        lastProcessedBlock = _block;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed");
    }

    // Function to allow the contract to receive ETH
    receive() external payable {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}