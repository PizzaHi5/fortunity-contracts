import "forge-std/Test.sol";
import "../../../contracts/MarketRegistry.sol";
import "../../../contracts/ClearingHouse.sol";
import "../../../contracts/QuoteToken.sol";
import "../../../contracts/BaseToken.sol";
import "../../../contracts/VirtualToken.sol";
import "@perp/perp-oracle-contract/contracts/interface/IPriceFeed.sol";
import "@uniswap/v3-core/contracts/UniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3PoolDeployer.sol";
import "@uniswap/v3-core/contracts/UniswapV3Pool.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract BaseSetup is Test {
    string constant BASE_TOKEN_NAME = "vETH";
    string constant QUOTE_TOKEN_NAME = "vUSD";
    uint24 constant DEFAULT_POOL_FEE = 3000;
    address internal PRICE_FEED = makeAddr("PRICE_FEED");
    MarketRegistry internal marketRegistry;
    ClearingHouse internal clearingHouse;
    UniswapV3Factory internal uniswapV3Factory;
    UniswapV3Pool internal pool;
    BaseToken internal baseToken;
    QuoteToken internal quoteToken;

    function setUp() public virtual {
        uniswapV3Factory = createUniswapV3Factory();
        quoteToken = createQuoteToken();
        clearingHouse = createClearingHouse();
        marketRegistry = createMarketRegistry(address(uniswapV3Factory), address(quoteToken), address(clearingHouse));
        baseToken = createBaseToken(BASE_TOKEN_NAME, address(quoteToken), address(clearingHouse), false);
        pool = createUniswapV3Pool(uniswapV3Factory, baseToken, quoteToken, DEFAULT_POOL_FEE);
    }

    function createQuoteToken() internal returns (QuoteToken) {
        QuoteToken quoteToken = new QuoteToken();
        quoteToken.initialize(QUOTE_TOKEN_NAME, QUOTE_TOKEN_NAME);
        vm.mockCall(address(quoteToken), abi.encodeWithSelector(ERC20Upgradeable.decimals.selector), abi.encode(18));
        vm.mockCall(
            address(quoteToken),
            abi.encodeWithSelector(ERC20Upgradeable.totalSupply.selector),
            abi.encode(type(uint256).max)
        );
        vm.mockCall(address(quoteToken), abi.encodeWithSelector(VirtualToken.isInWhitelist.selector), abi.encode(true));
        return quoteToken;
    }

    function createBaseToken(
        string memory tokenName,
        address quoteToken,
        address clearingHouse,
        bool largerThan
    ) internal returns (BaseToken) {
        BaseToken baseToken;
        while (address(baseToken) == address(0) || (largerThan != (quoteToken < address(baseToken)))) {
            baseToken = new BaseToken();
        }
        // NOTE: put faked code on price feed address, must have contract code to make mockCall
        vm.etch(PRICE_FEED, "PRICE_FEED");
        vm.mockCall(PRICE_FEED, abi.encodeWithSelector(IPriceFeed.decimals.selector), abi.encode(18));
        baseToken.initialize(tokenName, tokenName, PRICE_FEED);
        baseToken.mintMaximumTo(clearingHouse);
        baseToken.addWhitelist(clearingHouse);
        return baseToken;
    }

    function createUniswapV3Factory() internal returns (UniswapV3Factory) {
        return new UniswapV3Factory();
    }

    function createUniswapV3Pool(
        UniswapV3Factory uniswapV3Factory,
        BaseToken baseToken,
        QuoteToken quoteToken,
        uint24 fee
    ) internal returns (UniswapV3Pool) {
        address poolAddress = uniswapV3Factory.createPool(address(baseToken), address(quoteToken), fee);
        baseToken.addWhitelist(poolAddress);
        quoteToken.addWhitelist(poolAddress);
        return UniswapV3Pool(poolAddress);
    }

    function createMarketRegistry(
        address uniswapV3Factory,
        address quoteToken,
        address clearingHouse
    ) internal returns (MarketRegistry) {
        MarketRegistry marketRegistry = new MarketRegistry();
        marketRegistry.initialize(uniswapV3Factory, quoteToken);
        marketRegistry.setClearingHouse(clearingHouse);
        return marketRegistry;
    }

    function createClearingHouse() internal returns (ClearingHouse) {
        return new ClearingHouse();
    }
}
