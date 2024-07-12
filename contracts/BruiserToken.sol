// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract BruiserToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    uint256 private _maxSupply;
    
    event InitializationAttempted(address initializer, address initialOwner, uint256 initialSupply, uint256 maxSupply);
    event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);

    /// @custom:oz-upgrades-unsafe-allow constructor
    function initialize(address initialOwner, uint256 initialSupply, uint256 maxSupply) initializer public {
        emit InitializationAttempted(msg.sender, initialOwner, initialSupply, maxSupply);
        
        require(initialOwner != address(0), "BruiserToken: Initial owner cannot be the zero address");
        require(initialSupply > 0, "BruiserToken: Initial supply must be greater than zero");
        require(maxSupply >= initialSupply, "BruiserToken: Max supply must be greater than or equal to initial supply");
        require(maxSupply > 0, "BruiserToken: Max supply must be greater than zero");
        
        uint256 initialSupplyInWei = initialSupply * 10**decimals();
        uint256 maxSupplyInWei = maxSupply * 10**decimals();
        
        __ERC20_init("BruiserToken", "BBRU");
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("BruiserToken");
        __UUPSUpgradeable_init();

        _maxSupply = maxSupplyInWei;
        _mint(initialOwner, initialSupplyInWei);
        transferOwnership(initialOwner);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address to, uint256 amount) public onlyOwner whenNotPaused {
        require(totalSupply() + amount <= _maxSupply, "BruiserToken: Minting would exceed max supply");
        _mint(to, amount);
    }

    function burn(uint256 amount) public override whenNotPaused {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override whenNotPaused {
        super.burnFrom(account, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function transfer(address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    function updateMaxSupply(uint256 newMaxSupply) public onlyOwner {
        require(newMaxSupply > _maxSupply, "BruiserToken: New max supply must be greater than current max supply");
        emit MaxSupplyUpdated(_maxSupply, newMaxSupply);
        _maxSupply = newMaxSupply;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}