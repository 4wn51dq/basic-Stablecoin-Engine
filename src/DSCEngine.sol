//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IDSCEngine} from "./interfaces/IDSCEngine.sol";
import {DecentralizedStablecoin} from "./DecentralizedStablecoin.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

abstract contract EngineErrors {
    error DSCEngine__NonZeroAmountRequired();
    error DSCEngine__tokensAndPriceFeedsAreNotMatched();
    error DSCEngine__noPriceFeedForTheToken();
    error DSCEngine__DepositFailed();
    error DSCEnginer__breaksHealthFactor();
    error DSCEngine__mintingFailed();
}

abstract contract EngineEvents {
    event NewCollateralDeposited(address user, address tokenDeposited, uint256 amount);
}

contract DSCEngine is IDSCEngine, EngineErrors, EngineEvents, ReentrancyGuard {

    mapping (address => bool) public s_tokenIsAllowed;
    mapping (address => address) public s_tokenPriceFeed;
    mapping (address => mapping(address => uint256)) public s_amountOfCollateralDepositedByUser;
    mapping (address => uint256) public s_DSCMintedByUser;

    address[] private s_collateralTokens;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION =100;

    DecentralizedStablecoin private i_dsc;

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address DSCAddress
    ) {
        require (tokenAddresses.length == priceFeedAddresses.length, DSCEngine__tokensAndPriceFeedsAreNotMatched());

        for (uint256 i=0; i<= tokenAddresses.length; i++) {
            s_tokenPriceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStablecoin(DSCAddress);
    }

    /////////////////////////
    // Modifiers           //
    /////////////////////////

    modifier nonZeroAmount(uint256 amount) {
        require (amount>=0, DSCEngine__NonZeroAmountRequired());
        _;
    }

    modifier isAllowedToken (address tokenAddress) {
        require(s_tokenPriceFeed[tokenAddress] != address(0), DSCEngine__noPriceFeedForTheToken());
        _;
    }

    /////////////////////////
    // Public and External //
    /////////////////////////

    function getCollateralValue(address user) public view override returns (uint256 valueInUSD) {
        for (uint256 i=0; i< s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_amountOfCollateralDepositedByUser[user][token];
            valueInUSD = getUSDValue(token, amount);
        }

        return valueInUSD;
    }

    function getUSDValue(address token, uint256 amount) public view override returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenPriceFeed[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price)*ADDITIONAL_FEED_PRECISION)*amount)/PRECISION;
    }

    function mintDSCByCollateral() external override {

    }

    function depositCollateral(
        address collateralTokenAddress, 
        uint256 collateralAmount) 
        external override
        nonZeroAmount(collateralAmount)
        isAllowedToken(collateralTokenAddress)
        nonReentrant
    {
        s_amountOfCollateralDepositedByUser[msg.sender][collateralTokenAddress]+= collateralAmount;
        emit NewCollateralDeposited(msg.sender, collateralTokenAddress, collateralAmount);

        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), collateralAmount);
        require(success, DSCEngine__DepositFailed());
    }

    function mintDSC(
        uint256 amountToBeMinted) /** minter must have more collateral than the min amount */
        external override 
        nonZeroAmount(amountToBeMinted)
        nonReentrant

    {
        s_DSCMintedByUser[msg.sender] += amountToBeMinted;
        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountToBeMinted);
        require (minted, DSCEngine__mintingFailed());
    }

    ////////////////////////
    // Private & Internal //
    ////////////////////////

    function _getAccountInformation(address user) private view returns (uint256, uint256) {
        return (
            s_DSCMintedByUser[user],
            getCollateralValue(user)
        );
    }

    /**
     * @return uint256 returns how close to liquidation a user is.
     * a value less than 1 indicates they can get liquidated.
     */

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 DSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUSD*LIQUIDATION_THRESHOLD)/LIQUIDATION_PRECISION;
        return collateralAdjustedForThreshold/DSCMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < 1) {
            revert DSCEnginer__breaksHealthFactor();
        }
    }

}