// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "hardhat/console.sol";

contract UtilityFunctionsTest {
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

    function testSlice() public {
        bytes memory data = hex"11223344556677889900aabbccddeeff";
        console.logBytes(data);
        
        bytes memory result = slice(data, 4, 8);
        console.logBytes(result);
        
        bytes memory expected = hex"556677889900aabb";
        console.logBytes(expected);
        
        Assert.equal(keccak256(result), keccak256(expected), "Slice function did not return expected result");
    }
}