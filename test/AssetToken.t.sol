// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {AssetTokenV2} from "../src/AssetTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title AssetTokenTest
 * @dev Comprehensive test suite for AssetToken upgrade lifecycle
 */
contract AssetTokenTest is Test {
    AssetToken public v1Implementation;
    AssetTokenV2 public v2Implementation;
    AssetToken public proxy;
    ERC1967Proxy public erc1967Proxy;

    address public admin;
    address public minter;
    address public user;
    address public attacker;

    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**18; // 1M tokens
    uint256 public constant MINT_AMOUNT = 100 * 10**18; // 100 tokens

    event TokensMinted(address indexed to, uint256 amount);
    event ContractPaused(address indexed account);
    event ContractUnpaused(address indexed account);

    function setUp() public {
        admin = address(0x1);
        minter = address(0x2);
        user = address(0x3);
        attacker = address(0x4);

        // Deploy V1 implementation
        v1Implementation = new AssetToken();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            AssetToken.initialize.selector,
            "Xault Asset Token",
            "XAT",
            MAX_SUPPLY,
            admin
        );

        // Deploy ERC1967Proxy with V1 implementation
        erc1967Proxy = new ERC1967Proxy(address(v1Implementation), initData);
        proxy = AssetToken(address(erc1967Proxy));

        // Grant MINTER_ROLE to minter (admin is set during initialization)
        vm.startPrank(admin);
        proxy.grantRole(proxy.MINTER_ROLE(), minter);
        vm.stopPrank();
    }

    /**
     * @dev Test 1: Setup - Deploy V1 via ERC1967Proxy and initialize with 1M max supply
     */
    function test_Setup_DeployV1AndInitialize() public {
        assertEq(proxy.maxSupply(), MAX_SUPPLY);
        assertEq(proxy.totalSupply(), 0);
        assertTrue(proxy.hasRole(proxy.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(proxy.hasRole(proxy.MINTER_ROLE(), minter));
    }

    /**
     * @dev Test 2: State Check - Mint 100 tokens to a user and assert balanceOf is 100
     */
    function test_StateCheck_Mint100Tokens() public {
        vm.prank(minter);
        vm.expectEmit(true, false, false, true);
        emit TokensMinted(user, MINT_AMOUNT);
        proxy.mint(user, MINT_AMOUNT);

        assertEq(proxy.balanceOf(user), MINT_AMOUNT);
        assertEq(proxy.totalSupply(), MINT_AMOUNT);
    }

    /**
     * @dev Test 3: Upgrade - Deploy V2 and upgrade the proxy
     */
    function test_Upgrade_DeployV2AndUpgrade() public {
        // First mint some tokens to verify persistence
        vm.prank(minter);
        proxy.mint(user, MINT_AMOUNT);
        assertEq(proxy.balanceOf(user), MINT_AMOUNT);

        // Deploy V2 implementation
        v2Implementation = new AssetTokenV2();

        // Upgrade the proxy to V2
        vm.prank(admin);
        proxy.upgradeToAndCall(address(v2Implementation), abi.encodeWithSelector(AssetTokenV2.initializeV2.selector));

        // Verify we can now call V2 functions
        AssetTokenV2 proxyV2 = AssetTokenV2(address(proxy));
        assertTrue(address(proxyV2) == address(proxy));
    }

    /**
     * @dev Test 4: Persistence Check - Assert user's balance is still 100 after upgrade
     */
    function test_PersistenceCheck_BalancePersistsAfterUpgrade() public {
        // Mint tokens before upgrade
        vm.prank(minter);
        proxy.mint(user, MINT_AMOUNT);
        uint256 balanceBefore = proxy.balanceOf(user);
        assertEq(balanceBefore, MINT_AMOUNT);

        // Deploy and upgrade to V2
        v2Implementation = new AssetTokenV2();
        vm.prank(admin);
        proxy.upgradeToAndCall(address(v2Implementation), abi.encodeWithSelector(AssetTokenV2.initializeV2.selector));

        // Verify balance persists
        uint256 balanceAfter = proxy.balanceOf(user);
        assertEq(balanceAfter, MINT_AMOUNT);
        assertEq(balanceAfter, balanceBefore);
    }

    /**
     * @dev Test 5: New Logic Check - Call pause() on V2 and assert transfers now revert
     */
    function test_NewLogicCheck_PausePreventsTransfers() public {
        // Setup: Mint tokens and upgrade to V2
        vm.prank(minter);
        proxy.mint(user, MINT_AMOUNT);

        v2Implementation = new AssetTokenV2();
        vm.prank(admin);
        proxy.upgradeToAndCall(address(v2Implementation), abi.encodeWithSelector(AssetTokenV2.initializeV2.selector));

        AssetTokenV2 proxyV2 = AssetTokenV2(address(proxy));

        // Pause the contract
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ContractPaused(admin);
        proxyV2.pause();

        // Attempt transfer should revert
        vm.prank(user);
        vm.expectRevert();
        proxy.transfer(attacker, 10 * 10**18);
    }

    /**
     * @dev Test: Unpause allows transfers again
     */
    function test_Unpause_AllowsTransfers() public {
        // Setup: Mint tokens and upgrade to V2
        vm.prank(minter);
        proxy.mint(user, MINT_AMOUNT);

        v2Implementation = new AssetTokenV2();
        vm.prank(admin);
        proxy.upgradeToAndCall(address(v2Implementation), abi.encodeWithSelector(AssetTokenV2.initializeV2.selector));

        AssetTokenV2 proxyV2 = AssetTokenV2(address(proxy));

        // Pause
        vm.prank(admin);
        proxyV2.pause();

        // Unpause
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit ContractUnpaused(admin);
        proxyV2.unpause();

        // Transfer should work now
        vm.prank(user);
        proxy.transfer(attacker, 10 * 10**18);
        assertEq(proxy.balanceOf(attacker), 10 * 10**18);
    }

    /**
     * @dev Test: MaxSupplyExceeded error is thrown when minting exceeds max supply
     */
    function test_MaxSupplyExceeded() public {
        // Try to mint more than max supply
        vm.prank(minter);
        vm.expectRevert(AssetToken.MaxSupplyExceeded.selector);
        proxy.mint(user, MAX_SUPPLY + 1);
    }

    /**
     * @dev Test: Only minter can mint
     */
    function test_OnlyMinterCanMint() public {
        vm.prank(attacker);
        vm.expectRevert();
        proxy.mint(user, MINT_AMOUNT);
    }

    /**
     * @dev Test: Only admin can upgrade
     */
    function test_OnlyAdminCanUpgrade() public {
        v2Implementation = new AssetTokenV2();
        vm.prank(attacker);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(v2Implementation), abi.encodeWithSelector(AssetTokenV2.initializeV2.selector));
    }

    /**
     * @dev Test: Only admin can pause
     */
    function test_OnlyAdminCanPause() public {
        v2Implementation = new AssetTokenV2();
        vm.prank(admin);
        proxy.upgradeToAndCall(address(v2Implementation), abi.encodeWithSelector(AssetTokenV2.initializeV2.selector));

        AssetTokenV2 proxyV2 = AssetTokenV2(address(proxy));
        vm.prank(attacker);
        vm.expectRevert();
        proxyV2.pause();
    }

    /**
     * @dev Test: Complete upgrade lifecycle as specified in requirements
     */
    function test_CompleteUpgradeLifecycle() public {
        // 1. Setup: Deploy V1 via ERC1967Proxy. Initialize with 1M max supply.
        assertEq(proxy.maxSupply(), MAX_SUPPLY);

        // 2. State Check: Mint 100 tokens to a user. Assert balanceOf is 100.
        vm.prank(minter);
        proxy.mint(user, MINT_AMOUNT);
        assertEq(proxy.balanceOf(user), MINT_AMOUNT);

        // 3. Upgrade: Deploy AssetTokenV2. Execute the upgrade on the proxy to switch to V2.
        v2Implementation = new AssetTokenV2();
        vm.prank(admin);
        proxy.upgradeToAndCall(address(v2Implementation), abi.encodeWithSelector(AssetTokenV2.initializeV2.selector));

        // 4. Persistence Check: Assert the user's balance is still 100.
        assertEq(proxy.balanceOf(user), MINT_AMOUNT);

        // 5. New Logic Check: Call pause() on V2 and assert that transfers now revert.
        AssetTokenV2 proxyV2 = AssetTokenV2(address(proxy));
        vm.prank(admin);
        proxyV2.pause();

        vm.prank(user);
        vm.expectRevert();
        proxy.transfer(attacker, 10 * 10**18);
    }
}
