// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AssetToken} from "./AssetToken.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title AssetTokenV2
 * @dev Adds pause functionality to AssetToken V1
 */
contract AssetTokenV2 is AssetToken, PausableUpgradeable {
    /// @dev Event emitted when contract is paused
    event ContractPaused(address indexed account);

    /// @dev Event emitted when contract is unpaused
    event ContractUnpaused(address indexed account);

    /**
     * @dev Initializes V2 functionality
     */
    function initializeV2() public reinitializer(2) {
        __Pausable_init();
    }

    /**
     * @dev Pauses token transfers (admin only)
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        emit ContractPaused(msg.sender);
    }

    /**
     * @dev Unpauses token transfers (admin only)
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit ContractUnpaused(msg.sender);
    }

    /// @dev Override to add pause check
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }
}
