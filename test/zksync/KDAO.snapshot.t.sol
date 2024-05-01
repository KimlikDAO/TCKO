// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {IProtocolFund} from "interfaces/kimlikdao/IProtocolFund.sol";
import {
    KDAO_LOCKED,
    KDAO_LOCKED_DEPLOYER,
    KDAO_ZKSYNC,
    KDAO_ZKSYNC_DEPLOYER,
    VOTING
} from "interfaces/kimlikdao/addresses.sol";
import {amountAddrFrom} from "interfaces/types/amountAddr.sol";
import {computeCreateAddress as computeZkSyncCreateAddress} from "interfaces/zksync/IZkSync.sol";
import {KDAO} from "zksync/KDAO.sol";
import {KDAOLocked} from "zksync/KDAOLocked.sol";

contract KDAOSnapshotTest is Test {
    KDAO private kdao;
    KDAOLocked private kdaol;

    function mintAll(uint256 amount) public {
        vm.startPrank(VOTING);
        for (uint256 i = 1; i <= 20; ++i) {
            kdao.mint(amountAddrFrom(amount, vm.addr(i)));
        }
        vm.stopPrank();
    }

    function setUp() external {
        vm.etch(KDAO_LOCKED, type(KDAOLocked).runtimeCode);
        kdaol = KDAOLocked(KDAO_LOCKED);

        vm.etch(KDAO_ZKSYNC, type(KDAO).runtimeCode);
        kdao = KDAO(KDAO_ZKSYNC);

        mintAll(1e12);
    }

    function testAddressConsistency() external pure {
        assertEq(computeZkSyncCreateAddress(KDAO_LOCKED_DEPLOYER, 0), KDAO_LOCKED);
        assertEq(computeZkSyncCreateAddress(KDAO_ZKSYNC_DEPLOYER, 0), KDAO_ZKSYNC);
    }

    function testSnapshot0() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);
        vm.prank(VOTING);
        kdao.snapshot0();

        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(3));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertFalse(kdao.snapshot0BalanceOf(vm.addr(3)) == 0);
        assertFalse(kdao.snapshot0BalanceOf(vm.addr(2)) == 750_000e6);
    }

    function testSnapshot1() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);
        vm.prank(VOTING);
        kdao.snapshot1();

        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(3));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.snapshot1BalanceOf(vm.addr(3)), 250_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 500_000e6);
    }

    function testSnapshot2() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);
        vm.prank(VOTING);
        kdao.snapshot2();

        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(3));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.snapshot2BalanceOf(vm.addr(3)), 250_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 500_000e6);
    }

    function testAllSnapshotsRepeatedly() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);

        vm.prank(VOTING);
        kdao.snapshot0();
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(3));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.snapshot0BalanceOf(vm.addr(3)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(VOTING);
        kdao.snapshot1();
        assertEq(kdao.snapshot0BalanceOf(vm.addr(3)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(3)), 0);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 750_000e6);

        vm.prank(vm.addr(4));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.snapshot0BalanceOf(vm.addr(4)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(4)), 250_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 750_000e6);

        vm.prank(VOTING);
        kdao.snapshot2();
        assertEq(kdao.snapshot2BalanceOf(vm.addr(4)), 0);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 1e12);

        assertEq(kdao.snapshot0BalanceOf(vm.addr(4)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(4)), 250_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 750_000e6);
    }

    function testUsingSnapshotMultipleTimes() external {
        uint256 balance = kdao.balanceOf(vm.addr(1));
        for (uint256 i = 1; i <= 10; ++i) {
            vm.prank(VOTING);
            kdao.snapshot0();

            uint256 amount = i * 10e6;
            for (uint256 x = 1; x <= 20; ++x) {
                vm.prank(vm.addr(x));
                kdao.transfer(vm.addr(50), amount);
            }

            for (uint256 y = 1; y <= 20; ++y) {
                assertEq(kdao.snapshot0BalanceOf(vm.addr(y)), balance);
            }

            balance = balance - amount;
        }
    }

    function testSnapshotValuesArePreserved() external {
        uint256 balance = kdao.balanceOf(vm.addr(1));
        for (uint256 i = 1; i <= 20; ++i) {
            vm.prank(VOTING);
            kdao.snapshot1();

            uint256 amount = i * 10e6;
            for (uint256 j = 1; j <= 20; ++j) {
                vm.prank(vm.addr(j));
                kdao.transfer(vm.addr((j % 20) + 1), amount);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                assertEq(kdao.balanceOf(vm.addr(i)), balance);
                assertEq(kdao.snapshot1BalanceOf(vm.addr(j)), balance);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                vm.prank(vm.addr(j));
                kdao.transfer(vm.addr(50), amount);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                assertEq(kdao.balanceOf(vm.addr(i)), balance - amount);
                assertEq(kdao.snapshot1BalanceOf(vm.addr(j)), balance);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                vm.prank(vm.addr(50));
                kdao.transfer(vm.addr(j), amount);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                assertEq(kdao.balanceOf(vm.addr(i)), balance);
                assertEq(kdao.snapshot1BalanceOf(vm.addr(j)), balance);
            }

            for (uint256 j = 1; j <= 20; ++j) {
                vm.prank(vm.addr(j));
                kdao.transfer(vm.addr(50), amount);
            }

            balance = balance - amount;
        }
    }

    function testSnapshot0WrapsAround() external {
        vm.prank(VOTING);
        kdao.snapshot0();
        vm.store(address(kdao), bytes32(uint256(5)), bytes32(((uint256(1) << 24) - 1) << 232));

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(VOTING);
        kdao.snapshot0();
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(2));
        kdao.transfer(vm.addr(1), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(VOTING);
        kdao.snapshot0();
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 250_000e6);
    }

    function testSnapshot1WrapsAround() external {
        vm.prank(VOTING);
        kdao.snapshot0();
        assertEq(uint256(vm.load(address(kdao), bytes32(uint256(5)))) >> 232, 1);
        vm.store(address(kdao), bytes32(uint256(5)), bytes32(((uint256(1) << 21) - 1) << 212));
        assertEq(uint256(vm.load(address(kdao), bytes32(uint256(5)))) >> 232, 1);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(VOTING);
        kdao.snapshot1();

        assertEq(uint256(vm.load(address(kdao), bytes32(uint256(5)))) >> 232, 1);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(2));
        kdao.transfer(vm.addr(1), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(VOTING);
        kdao.snapshot1();
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 250_000e6);
    }

    function testSnapshot2WrapsAround() external {
        vm.prank(VOTING);
        kdao.snapshot1();
        assertEq(uint256(vm.load(address(kdao), bytes32(uint256(5)))) >> 212, 1);
        vm.store(address(kdao), bytes32(uint256(5)), bytes32(((uint256(1) << 21) - 1) << 192));
        assertEq(uint256(vm.load(address(kdao), bytes32(uint256(5)))) >> 212, 1);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(VOTING);
        kdao.snapshot2();

        assertEq(uint256(vm.load(address(kdao), bytes32(uint256(5)))) >> 212, 1);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(vm.addr(2));
        kdao.transfer(vm.addr(1), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 500_000e6);

        vm.prank(VOTING);
        kdao.snapshot2();
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 250_000e6);
    }

    function testConsumeSnapshotNBalance3Snapshots() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(1 + 1), 50_000e6);

        vm.startPrank(VOTING);
        kdao.snapshot0();
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 200_000e6);
        uint256 snapshot0Balance = kdao.snapshot0BalanceOf(vm.addr(1));
        uint256 snapshot0ConsumedBalance = kdao.consumeSnapshot0Balance(vm.addr(1));
        vm.stopPrank();
        assertEq(snapshot0Balance, 200_000e6);
        assertEq(snapshot0Balance, snapshot0ConsumedBalance);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1 + 1)), 300_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 0);

        vm.prank(vm.addr(1 + 1));
        kdao.transfer(vm.addr(1), 50_000e6);

        vm.startPrank(VOTING);
        kdao.snapshot1();
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 250_000e6);
        uint256 snapshot1Balance = kdao.snapshot1BalanceOf(vm.addr(1));
        uint256 snapshot1ConsumedBalance = kdao.consumeSnapshot1Balance(vm.addr(1));
        vm.stopPrank();
        assertEq(snapshot1Balance, 250_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(snapshot1Balance, snapshot1ConsumedBalance);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1 + 1)), 250_000e6);

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(1 + 1), 25_000e6);

        vm.startPrank(VOTING);
        kdao.snapshot2();
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 225_000e6);
        uint256 snapshot2Balance = kdao.snapshot2BalanceOf(vm.addr(1));
        uint256 snapshot2ConsumedBalance = kdao.consumeSnapshot2Balance(vm.addr(1));
        vm.stopPrank();
        assertEq(snapshot2Balance, 225_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(snapshot2Balance, snapshot2ConsumedBalance);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1 + 1)), 275_000e6);
    }

    function testConsumeSnapshot0Balance() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 100_000e6);

        vm.startPrank(VOTING);
        kdao.snapshot0();
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 150_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), kdao.consumeSnapshot0Balance(vm.addr(1)));
        vm.stopPrank();
        assertEq(kdao.balanceOf(vm.addr(1)), 150_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 350_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 350_000e6);

        vm.prank(VOTING);
        assertEq(kdao.consumeSnapshot0Balance(vm.addr(2)), 350_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 350_000e6);
    }

    function testConsumeSnapshot1Balance() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 100_000e6);

        vm.startPrank(VOTING);
        kdao.snapshot1();
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 150_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), kdao.consumeSnapshot1Balance(vm.addr(1)));
        vm.stopPrank();
        assertEq(kdao.balanceOf(vm.addr(1)), 150_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 350_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 350_000e6);

        vm.prank(VOTING);
        assertEq(kdao.consumeSnapshot1Balance(vm.addr(2)), 350_000e6);
        assertEq(kdao.snapshot1BalanceOf(vm.addr(2)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 350_000e6);
    }

    function testConsumeSnapshot2Balance() external {
        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 100_000e6);

        vm.startPrank(VOTING);
        kdao.snapshot2();
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 150_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), kdao.consumeSnapshot2Balance(vm.addr(1)));
        vm.stopPrank();
        assertEq(kdao.balanceOf(vm.addr(1)), 150_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 350_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 350_000e6);

        vm.prank(VOTING);
        assertEq(kdao.consumeSnapshot2Balance(vm.addr(2)), 350_000e6);
        assertEq(kdao.snapshot2BalanceOf(vm.addr(2)), 0);
        assertEq(kdao.balanceOf(vm.addr(2)), 350_000e6);
    }

    function testConsumeSnapshotBalanceWithTransactions() external {
        vm.prank(VOTING);
        kdao.snapshot0();

        for (uint256 i = 1; i <= 4; ++i) {
            assertEq(kdao.balanceOf(vm.addr(i)), 250_000e6);
            assertEq(kdao.snapshot0BalanceOf(vm.addr(i)), 250_000e6);
        }

        vm.prank(vm.addr(1));
        kdao.transfer(vm.addr(2), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 0);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(2)), 500_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(vm.addr(3));
        kdao.transfer(vm.addr(1337), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(3)), 0);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(3)), 250_000e6);

        vm.prank(vm.addr(2));
        kdao.transfer(vm.addr(1), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(1)), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(2)), 250_000e6);

        vm.prank(vm.addr(4));
        kdao.transfer(vm.addr(3), 100_000e6);

        assertEq(kdao.balanceOf(vm.addr(3)), 100_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(3)), 250_000e6);

        assertEq(kdao.balanceOf(vm.addr(4)), 150_000e6);
        assertEq(kdao.snapshot0BalanceOf(vm.addr(4)), 250_000e6);

        vm.startPrank(VOTING);
        for (uint256 i = 1; i <= 4; ++i) {
            assertEq(kdao.snapshot0BalanceOf(vm.addr(i)), kdao.consumeSnapshot0Balance(vm.addr(i)));

            assertEq(kdao.snapshot0BalanceOf(vm.addr(i)), 0);
        }
        vm.stopPrank();

        assertEq(kdao.balanceOf(vm.addr(1)), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(2)), 250_000e6);
        assertEq(kdao.balanceOf(vm.addr(3)), 100_000e6);
        assertEq(kdao.balanceOf(vm.addr(4)), 150_000e6);
    }

    function testBalanceIsPreservedAfterConsume() external {
        assertEq(kdao.balanceOf(vm.addr(1)), 250_000e6);
        vm.prank(VOTING);
        kdao.snapshot2();
        vm.prank(VOTING);
        kdao.consumeSnapshot2Balance(vm.addr(1));
        assertEq(kdao.balanceOf(vm.addr(1)), 250_000e6);
    }
}
