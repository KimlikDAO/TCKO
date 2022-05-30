//SPDX-License-Identifier: MIT
//🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿🧿

pragma solidity ^0.8.14;

import "./DistroStage.sol";
import "./IERC20.sol";
import "./KimlikDAO.sol";

/**
 * A KilitliTCKO represents a locked TCKO, which cannot be redeemed or
 * transferred, but turns into a TCKO automatically at the prescribed
 * `DistroStage`.
 *
 * The unlocking is triggered by the `DEV_KASASI` using the `unlockAllEven()`
 * or `unlockAllOdd()` methods and the gas is paid by KimlikDAO; the user does
 * not need to take any action to unlock their tokens.
 *
 * Invariants:
 *   (I1) sum_a(balances[a][0]) + sum_a(balances[a][1]) == supply
 *   (I2) supply == TCKO.balances[kilitliTCKO]
 *   (I3) balance[a][0] > 0 => accounts0.includes(a)
 *   (I4) balance[a][1] > 0 => accounts1.includes(a)
 */
contract KilitliTCKO is IERC20 {
    string public override name = "KimlikDAO Kilitli Tokeni";
    string public override symbol = "TCKO-k";
    uint8 public override decimals = 6;

    IERC20 private tcko = IERC20(msg.sender);
    mapping(address => uint128[2]) private balances;
    address[] private accounts0;
    // Split Presale2 accounts out, so that even if we can't unlock them in
    // one shot due to gas limit, we can still unlock others in one shot.
    address[] private accounts1;
    uint256 private supply;

    function totalSupply() external view override returns (uint256) {
        return supply;
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return balances[account][0] + balances[account][1];
    }

    function transfer(address to, uint256) external override returns (bool) {
        if (to == address(this)) return unlock(msg.sender);
        return false;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) external pure override returns (bool) {
        return false;
    }

    function allowance(address, address)
        external
        pure
        override
        returns (uint256)
    {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return false;
    }

    function mint(
        address account,
        uint256 amount,
        DistroStage stage
    ) external {
        require(msg.sender == address(tcko));
        unchecked {
            if (uint256(stage) & 1 == 0) {
                accounts0.push(account);
                balances[account][0] += uint128(amount);
            } else {
                accounts1.push(account);
                balances[account][1] += uint128(amount);
            }
            supply += amount;
            emit Transfer(address(this), account, amount);
        }
    }

    function unlock(address account) public returns (bool) {
        DistroStage stage = HasDistroStage(address(tcko)).distroStage();
        uint256 locked = 0;
        if (stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint) {
            locked += balances[account][0];
            delete balances[account][0];
        }
        if (stage >= DistroStage.Presale2Unlock) {
            locked += balances[account][1];
            delete balances[account][1];
        }
        if (locked > 0) {
            emit Transfer(account, address(this), locked);
            supply -= locked;
            tcko.transfer(account, locked);
            return true;
        }
        return false;
    }

    function unlockAllEven() external {
        DistroStage stage = HasDistroStage(address(tcko)).distroStage();
        require(
            stage >= DistroStage.DAOSaleEnd && stage != DistroStage.FinalMint,
            "TCKO-k: Not matured"
        );

        uint256 length = accounts0.length;
        for (uint256 i = 0; i < length; ++i) {
            address account = accounts0[i];
            uint256 locked = balances[account][0];
            if (locked > 0) {
                delete balances[account][0];
                emit Transfer(account, address(this), locked);
                supply -= locked;
                tcko.transfer(account, locked);
            }
        }
    }

    function unlockAllOdd() external {
        require(
            HasDistroStage(address(tcko)).distroStage() >=
                DistroStage.Presale2Unlock,
            "TCKO-k: Not matured"
        );

        uint256 length = accounts1.length;
        for (uint256 i = 0; i < length; ++i) {
            address account = accounts1[i];
            uint256 locked = balances[account][1];
            if (locked > 0) {
                delete balances[account][1];
                emit Transfer(account, address(this), locked);
                supply -= locked;
                tcko.transfer(account, locked);
            }
        }
    }

    /**
     * Set the TCKO contract address.
     *
     * This method can be called only once, during the setup by `DEV_KASASI`.
     */
    function setTCKOAddress(IERC20 tckoAddr) external {
        require(tx.origin == DEV_KASASI);
        require(address(tcko) == address(0));
        tcko = tckoAddr;
    }

    /**
     * Deletes the contract if all TCKO-k's have been unlocked.
     */
    function selfDestruct() external {
        // We restrict this method to `DEV_KASASI` as there may be ERC20 tokens
        // sent to this contract by accident waiting to be rescued.
        require(tx.origin == DEV_KASASI);
        require(supply == 0);
        selfdestruct(DAO_KASASI);
    }

    /**
     * Moves ERC20 tokens sent to this address by accident to `DAO_KASASI`.
     */
    function rescueToken(IERC20 token) external {
        // We restrict this method to `DEV_KASASI` only, as we call a method
        // of an unkown contract, which could potentially be a security risk.
        require(tx.origin == DEV_KASASI);
        // Disable sending out TCKO to ensure the invariant TCKO.(I4).
        require(token != tcko);
        token.transfer(DAO_KASASI, token.balanceOf(address(this)));
    }
}