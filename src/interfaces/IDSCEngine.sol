//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * This stablecoin has the following properties:
 * 1. Exogenous Collateralized
 * 2. Dollar pegged
 * 3. Algorithmically stable
 * 
 * This is similiar to DAI coin except there is no governance, no fees, and its rather backed by WETH and WBTC.
 * @notice the engine handles all logic for mining and redeeming dsc, as well as depositing and wihtdrawing collateral.
 * @notice very much based on the MakerDAO DSS (DAI) system.
 *
 * The DSC system shall be overcollateralized. NetCollateralBalance>= $ backing it value;
 */

interface IDSCEngine {

    function mintDSCByCollateral(
        address collateralTokenAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external ;

    /*
     * @param collateralTokenAddress is the address of the token that can be taken as collateral;
     * @param collateralAmount is the amount of collateral to be deposited.
     */

    function redeemCollateralBurnDSC(address collateralTokenAddress, uint256 collateralAmount) external ;

    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount) external ;

    function redeemCollateral(address collateralTokenAddress, uint256 amountToRedeem) external ;

    function _redeemCollateral(address collateralTokenAddress, uint256 amountToRedeem, address from, address to) external ;

    function mintDSC(uint256 amountToBeMinted) external ;

    function burnDSC(uint256 amountToBeBurned) external ;

    function liquidate(address collateralTokenAddress, address user, uint256 debtToRepay) external ;

    function getHealthFactor(address user) external returns (uint256);

    /**
    function revertIfHealthFactorIsBroken(address user) external ;

    function healthFactor(address user) external view returns (uint256);

    function getAccountInformation(address user) external view returns (
        uint256 dscMintedByUser, 
        uint256 netCollateralValueInUSD) 
    ;
    */

    function getCollateralValue(address user) external view returns (
        uint256 collateralOwnedByTheUserInUSD)
    ;

    function getUSDValue(address token, uint256 amount) external view returns (
        uint256 valueOfAmountOfTokenInUSD)
    ;


}