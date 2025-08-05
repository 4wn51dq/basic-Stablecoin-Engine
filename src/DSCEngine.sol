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
    error DSCEngine__redeemingFailed();
    error DSCEngine__transferFailed();
    error DSCEngine__burningFailed();
    error DSCEngine__HealthFactorNonLiquidatable();
    error DSCEngine__HealthFactorNotImproved();
}

abstract contract EngineEvents {
    event NewCollateralDeposited(address user, address tokenDeposited, uint256 amount);
    event CollateralRedeemed(address indexed, address, uint256);
    event _CollateralRedeemed(address from, address to, address collateralTokenAddress, uint256 amount);
}

contract DSCEngine is IDSCEngine, EngineErrors, EngineEvents, ReentrancyGuard {

    mapping (address => bool) public s_tokenIsAllowed;
    mapping (address => address) public s_tokenPriceFeed;
    mapping (address => mapping(address => uint256)) public s_amountOfCollateralDepositedByUser;
    mapping (address => uint256) public s_DSCMintedByUser;

    /**
     * @notice LIQUIDATION_THRESHOLD: determines what portion (%) of the collateral is a 'safe' backing for the loan
     * for every $1000 dollar as collateral, you can borrow up to $500 worth of asset. (LT=50)
     * If you buy more than $50 worth of asset, you are at a risk of getting your collateral liquidated.
     * @notice LIQUIDATED collateral represents your debt position: collateral is sold or auctioned off 
     * to repay your debt.
     * Now suppose your collateral value initially was 10 ETH = $1000, (LT=50), and you borrow ASSET = $420.
     * this means your health factor = ($1000*50/100)/420 = 1.18
     * Now suppose 10 ETH = $800, (LT=50), now your health factor becomes: 0.95
     * What happens now? A liquidator (a bot or an arbitrageur) repays a part/all of your collateral debt.
     * How would this Help them???
     * suppose the liquidator pays $210 to the protocol, he shall now receive the same worth of eth 
     * with 10% incentive ($231). 
     * @notice MINIMUM_OVERCOLLATERALIZATION_RATIO = 1/LIQUIDATION_THRESHOLD(%)
     * You must have at least 2x the value of your debt in collateral to avoid liquidation.
     *
     * suppose: $1000 worth ETH backs $500 dollar worth stablecoin
     * now ETH price drops to $200, price of stablecoin is no more worth $1 !!
     * so we need to make sure we remove the people's position in this system if the price of the collateral tanks.
     * 
     * @notice if someone is undercolateralized, liquidate them, pay their debt, and get their collateral asset. 
     * thats free money for liquidators. 
     * 
     * liquidator pays off entire debt: $500, but will they? nope. they will be in a $300 loss in this case, 
     * in case of debt owed> collateral value, and cases of crashing prices, the system has to use emergency measures!
     * roughly 200% overcollateralized protocol helps avoid this too.
     *
     * but if the price only dropped to $800, and the user is undercollateralized, liquidator pays off $500 debt, 
     * they get $300 profit via the collateral asset. 
     */

    address[] private s_collateralTokens;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION =100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    DecentralizedStablecoin private i_dsc;

    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address DSCAddress
    ) {
        require (tokenAddresses.length == priceFeedAddresses.length, DSCEngine__tokensAndPriceFeedsAreNotMatched());

        for (uint256 i=0; i< tokenAddresses.length; i++) {
            s_tokenPriceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStablecoin(DSCAddress);
    }

    /////////////////////////
    // Modifiers           //
    /////////////////////////

    modifier nonZeroAmount(uint256 amount) {
        require (amount>0, DSCEngine__NonZeroAmountRequired());
        _;
    }

    modifier isAllowedToken (address tokenAddress) {
        require(s_tokenPriceFeed[tokenAddress] != address(0), DSCEngine__noPriceFeedForTheToken());
        _;
    }

    /////////////////////////
    // Public       /////////
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

    function getHealthFactor(address user) public view override returns (uint256) {
        return _healthFactor(user);
    }

    function getTokenAmountFromUsd(address tokenAddress, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenPriceFeed[tokenAddress]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei*PRECISION)/(uint256(price)*ADDITIONAL_FEED_PRECISION);
    }

    function _redeemCollateral(
        address collateralTokenAddress, 
        uint256 amountToRedeem,
        address from,
        address to) 
        public override nonZeroAmount(amountToRedeem) nonReentrant {
            s_amountOfCollateralDepositedByUser[from][collateralTokenAddress]-=amountToRedeem;
            emit _CollateralRedeemed(from, to, collateralTokenAddress,amountToRedeem);

            (bool success)= IERC20(collateralTokenAddress).transferFrom(
                from, to, amountToRedeem
                );
            require(success, DSCEngine__redeemingFailed());
        }

    /////////////////////////
    // External     /////////
    /////////////////////////

    /**
     * a user can redeem their collateral only if:
     * they have a health factor>1 after the collateral is pulled
     * 
     * @notice we need a method by which another user can liquidate those 
     * unhealthy positions to secure the value of the stablecoin.
     * @notice Users who assist the protocol by liquidating unhealthy positions will be rewarded with the
     * collateral for the position they've closed, which will exceed the value of the DSC burnt by virtue 
     * of our liquidation threshold.
     *
     * param: collateralTokenAddress is the erc20 collateral address to liquidate
     * param: user is the address with broken health factor
     * param: debtToCover is the amount of money (of the debt portion of user) the liquidator wants to pay.
     * debtToCover will also be the amount of dsc that will be burned to improve the user's health factor
     * 
     * @notice 10% liquidation bonus 
     * @notice the function assumes the protocol is roughly 200% overcollateralized.
     * 
     * @dev we should also revert lastly if the liquidator's health factor is broken! 
     */

    function liquidate(
        address collateralTokenAddress,
        address user,
        uint256 debtToCover) 
        nonZeroAmount(debtToCover)
        nonReentrant
        external override 
    {
        uint256 startingUserHF = _healthFactor(user);
        require (startingUserHF <= MIN_HEALTH_FACTOR, DSCEngine__HealthFactorNonLiquidatable());

        uint256 tokenAmountFromDebtToCover = getTokenAmountFromUsd(collateralTokenAddress, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtToCover*LIQUIDATION_BONUS)/LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtToCover + bonusCollateral;

        // redeem to whoever is calling liquidate

        _redeemCollateral(collateralTokenAddress, totalCollateralToRedeem, user, msg.sender);
        _burnDSC(debtToCover, user, msg.sender);

        uint256 endingUserHF = _healthFactor(user);
        require (endingUserHF>= startingUserHF, DSCEngine__HealthFactorNotImproved());

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateral(
        address collateralTokenAddress, 
        uint256 amountToRedeem) 
        external override 
        nonZeroAmount(amountToRedeem)
        nonReentrant
        {
            _redeemCollateral(collateralTokenAddress, amountToRedeem, address(this), msg.sender);

            _revertIfHealthFactorIsBroken(msg.sender);
    }

    function redeemCollateralBurnDSC(
        address collateralTokenAddress,
        uint256 amountToRedeem
        ) 
        external override 
        nonZeroAmount(amountToRedeem)
    {
        this.redeemCollateral(
            collateralTokenAddress,
            amountToRedeem
        );

        this.burnDSC(
            amountToRedeem
        );
    }


    function mintDSCByCollateral(
        address collateralTokenAddress,
        uint256 amountOfCollateral,
        uint256 amountDscToMint
    ) 
        external override 
        nonReentrant {
        this.depositCollateral(
            collateralTokenAddress,
            amountOfCollateral
        );

        this.mintDSC(
            amountDscToMint
        );
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

    function burnDSC(
        uint256 amountToBeBurned
        )
        external override 
        nonZeroAmount(amountToBeBurned)
        nonReentrant
    {
        _burnDSC(amountToBeBurned, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    
    ////////////////////////
    // Private & Internal //
    ////////////////////////

        /**
         * @dev low-level internal function: _burnDSC, do not call unless function calling it checks for brokenHealthFactor.
         * @param onBehalfOf: Decrease the internal debt record of the user at address onBehalfOf.
         * @param dscFrom: take the tokens from addres dscFrom
         * @notice why transfer to on behalf of? 
         * so that the dsc engine can burn the tokens from the debtor's address.
         * i_dsc.burn(amountDscToBurn) removes the existence of the tokens from the blockchain.
         */

    function _burnDSC(uint256 amountDSCToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMintedByUser[onBehalfOf]-= amountDSCToBurn;
        // _revertIfHealthFactorIsBroken(msg.sender);
        // omitted here since burning debt improves health factor anyway

        bool success = i_dsc.transferFrom(dscFrom, onBehalfOf, amountDSCToBurn);
        require (success, DSCEngine__transferFailed());

        i_dsc.burn(amountDSCToBurn);
    }


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
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEnginer__breaksHealthFactor();
        }
    }
}