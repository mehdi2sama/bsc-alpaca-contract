// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { DeltaNeutralVault04Base_Test } from "./DeltaNeutralVault04Base.t.sol";

import { BaseTest, DeltaNeutralVault04Like, MockErc20Like, MockLpErc20Like, console } from "../../base/BaseTest.sol";
import { mocking } from "../../utils/mocking.sol";

import { DeltaNeutralVault04HealthChecker } from "../../../contracts/8.13/DeltaNeutralVault04HealthChecker.sol";
import { FakeDeltaWorker } from "../../fake/FakeDeltaWorker.sol";
import { FakeAutomateVaultController } from "../../fake/FakeAutomateVaultController.sol";
import { FakeDeltaNeutralOracle } from "../../fake/FakeDeltaNeutralOracle.sol";
import { FakeVault } from "../../fake/FakeVault.sol";
import { FakeDeltaNeutralVaultConfig02 } from "../../fake/FakeDeltaNeutralVaultConfig02.sol";
import { FakeDeltaNeutralDepositExecutor } from "../../fake/FakeDeltaNeutralDepositExecutor.sol";
import { FakeDeltaNeutralWithdrawExecutor } from "../../fake/FakeDeltaNeutralWithdrawExecutor.sol";
import { FakeDeltaNeutralRebalanceExecutor } from "../../fake/FakeDeltaNeutralRebalanceExecutor.sol";
import { FakeDeltaNeutralReinvestExecutor } from "../../fake/FakeDeltaNeutralReinvestExecutor.sol";
import { FakeRouter } from "../../fake/FakeRouter.sol";
import { FakeFairLaunch } from "../../fake/FakeFairLaunch.sol";

// solhint-disable func-name-mixedcase
// solhint-disable contract-name-camelcase
contract DeltaNeutralVault04_RepurchaseTest is DeltaNeutralVault04Base_Test {
  using mocking for *;

  function setUp() public override {
    super.setUp();
  }

  function testCorrectness_GetPositiveExposureShouldWork() external {
    _assetVault.setDebt(20 ether, 20 ether);
    _lpToken.totalSupply.mockv(200 ether);
    _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
    _lpToken.token0.mockv(address(_stableToken));
    int256 _exposure = _deltaNeutralVault.getExposure();
    assertEq(_exposure, 55 ether);
  }

  function testCorrectness_GetNegativeExposureShouldWork() external {
    _assetVault.setDebt(100 ether, 100 ether);
    _lpToken.totalSupply.mockv(200 ether);
    _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
    _lpToken.token0.mockv(address(_stableToken));
    int256 _exposure = _deltaNeutralVault.getExposure();
    assertEq(_exposure, -25 ether);
  }

  function testCorrectness_GetZeroExposureShouldWork() external {
    _assetVault.setDebt(75 ether, 75 ether);
    _lpToken.totalSupply.mockv(200 ether);
    _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
    _lpToken.token0.mockv(address(_stableToken));
    int256 _exposure = _deltaNeutralVault.getExposure();
    assertEq(_exposure, 0 ether);
  }

  function testRevert_RepurchaseWithStableTokenWhileExposureIsNegativeShouldRevert() external {
    _assetVault.setDebt(100 ether, 100 ether);
    _lpToken.totalSupply.mockv(200 ether);
    _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
    _lpToken.token0.mockv(address(_stableToken));

    uint256 _amountToPurchase = 100 ether;
    uint256 _minReceiveAmount = 100 ether;
    vm.expectRevert(abi.encodeWithSignature("DeltaNeutralVault04_InvalidRepurchaseTokenIn()"));
    _deltaNeutralVault.repurchase(address(_stableToken), _amountToPurchase, _minReceiveAmount);
  }

  function testRevert_RepurchaseWithAssetTokenWhileExposureIsPositiveShouldRevert() external {
    _assetVault.setDebt(25 ether, 25 ether);
    _lpToken.totalSupply.mockv(200 ether);
    _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
    _lpToken.token0.mockv(address(_stableToken));

    uint256 _amountToPurchase = 100 ether;
    uint256 _minReceiveAmount = 100 ether;
    vm.expectRevert(abi.encodeWithSignature("DeltaNeutralVault04_InvalidRepurchaseTokenIn()"));
    _deltaNeutralVault.repurchase(address(_assetToken), _amountToPurchase, _minReceiveAmount);
  }

  // function testCorrectness_RepurchaseWithStableTokenWhileExposureIsPositiveShouldWork() external {
  //   _assetVault.setDebt(25 ether, 25 ether);
  //   _lpToken.totalSupply.mockv(200 ether);
  //   _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
  //   _lpToken.token0.mockv(address(_stableToken));

  //   uint256 _amountToPurchase = 50 ether;
  //   uint256 _minReceiveAmount = 50 ether;

  //   uint256 _stableBalance = _stableToken.balanceOf(address(this));
  //   uint256 _assetBalance = _assetToken.balanceOf(address(this));

  //   // current debt stable : 50, asset : 25
  //   // target debt stable: 0, asset : 75
  //   _repurchaseExecutor.setExecutionValue(0, 75 ether);

  //   _deltaNeutralVault.repurchase(address(_stableToken), _amountToPurchase, _minReceiveAmount);

  //   uint256 _actualAmountInAfterDiscount = _stableBalance - _stableToken.balanceOf(address(this));
  //   uint256 _actualAmountOut = _assetToken.balanceOf(address(this)) - _assetBalance;

  //   // 15 bps discount hardcoded in the contract
  //   assertEq(_actualAmountInAfterDiscount, (_amountToPurchase * 9985) / 10000);
  //   // check amount out
  //   assertEq(_actualAmountOut, 50 ether);
  // }

  function testCorrectness_RepurchaseWithAssetTokenWhileExposureIsNegativeShouldWork() external {
    _assetVault.setDebt(100 ether, 100 ether);
    _lpToken.totalSupply.mockv(200 ether);
    _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
    _lpToken.token0.mockv(address(_stableToken));

    uint256 _amountToPurchase = 25 ether;
    uint256 _minReceiveAmount = 25 ether;

    uint256 _stableBalance = _stableToken.balanceOf(address(this));
    uint256 _assetBalance = _assetToken.balanceOf(address(this));

    // current debt stable : 50, asset : 100
    // target debt stable: 75, asset : 75
    _repurchaseExecutor.setExecutionValue(75 ether, 75 ether);

    _deltaNeutralVault.repurchase(address(_assetToken), _amountToPurchase, _minReceiveAmount);

    uint256 _actualAmountInAfterDiscount = _assetBalance - _assetToken.balanceOf(address(this));
    uint256 _actualAmountOut = _stableToken.balanceOf(address(this)) - _stableBalance;

    // 15 bps discount hardcoded in the contract
    assertEq(_actualAmountInAfterDiscount, (_amountToPurchase * 9985) / 10000);
    // check amount out
    assertEq(_actualAmountOut, 25 ether);
  }

  function testRevert_RepurchaseMoreThanExposureWhileExposureIsPositiveShouldRevert() external {
    _assetVault.setDebt(100 ether, 100 ether);
    _lpToken.totalSupply.mockv(200 ether);
    _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
    _lpToken.token0.mockv(address(_stableToken));

    uint256 _amountToPurchase = 30 ether;
    uint256 _minReceiveAmount = 30 ether;

    vm.expectRevert(abi.encodeWithSignature("DeltaNeutralVault04_NotEnoughExposure()"));
    _deltaNeutralVault.repurchase(address(_assetToken), _amountToPurchase, _minReceiveAmount);
  }

  function testRevert_RepurchaseMoreThanExposureWhileExposureIsNegativeShouldRevert() external {
    _assetVault.setDebt(50 ether, 50 ether);
    _lpToken.totalSupply.mockv(200 ether);
    _lpToken.getReserves.mockv(100 ether, 100 ether, uint32(block.timestamp));
    _lpToken.token0.mockv(address(_stableToken));

    uint256 _amountToPurchase = 30 ether;
    uint256 _minReceiveAmount = 30 ether;

    vm.expectRevert(abi.encodeWithSignature("DeltaNeutralVault04_NotEnoughExposure()"));
    _deltaNeutralVault.repurchase(address(_stableToken), _amountToPurchase, _minReceiveAmount);
  }
}
