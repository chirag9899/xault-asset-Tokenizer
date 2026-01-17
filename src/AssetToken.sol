// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title AssetToken
 * @dev UUPS-upgradeable ERC20 with role-based access control and max supply cap
 */
contract AssetToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    /// @dev Custom error for when max supply is exceeded
    error MaxSupplyExceeded();

    /// @dev Role identifier for minters
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Maximum supply of tokens
    uint256 public maxSupply;

    /// @dev Event emitted when tokens are minted
    event TokensMinted(address indexed to, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param maxSupply_ Maximum supply of tokens
     * @param admin_ Address that will receive DEFAULT_ADMIN_ROLE
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address admin_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __AccessControl_init();

        maxSupply = maxSupply_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    /**
     * @dev Mints tokens to specified address
     * @param to Recipient address
     * @param amount Token amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (totalSupply() + amount > maxSupply) {
            revert MaxSupplyExceeded();
        }
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Authorizes upgrade to new implementation (admin only)
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
