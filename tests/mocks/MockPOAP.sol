// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockPOAP {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event EventToken(uint256 indexed eventId, uint256 indexed tokenId);

    uint256 public mockEventId;
    uint256 public mockTokenId;
    address public mockRecipient;

    function setMockEventData(uint256 _eventId, uint256 _tokenId, address _recipient) external {
        mockEventId = _eventId;
        mockTokenId = _tokenId;
        mockRecipient = _recipient;
    }

    function emitMockEvents() external {
        emit Transfer(address(0), mockRecipient, mockTokenId);
        emit EventToken(mockEventId, mockTokenId);
    }

    function getPastEvents(string memory, uint256, uint256) external view returns (bytes[] memory) {
        bytes[] memory events = new bytes[](2);
        events[0] = abi.encode(
            keccak256("Transfer(address,address,uint256)"),
            address(0),
            mockRecipient,
            mockTokenId
        );
        events[1] = abi.encode(
            keccak256("EventToken(uint256,uint256)"),
            mockEventId,
            mockTokenId
        );
        return events;
    }

    // Reset function for testing purposes
    function reset() external {
        mockEventId = 0;
        mockTokenId = 0;
        mockRecipient = address(0);
    }
}