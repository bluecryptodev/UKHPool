// Token Pool
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract UHKPool is OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    IERC20Upgradeable token;
    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Pair public uniswapV2Pair;

    uint256 private _maxAmountOfToken;
    uint256 private _totalTokenAmount;
    uint256 private _initialExchangeRate;

    uint256 private _timeLockDuration = 180 days;

    bool _closeSale = false;

    mapping(address => uint256) private _contributesAmount;
    mapping(address => uint256) private _contributesTime;
    mapping(string => uint256) private _commissionRatePlan;

    event Contribute(address indexed investor, uint256 value);

    function initialize(
        address tokenAddress,
        address routerAddress,
        uint256 maxTokenAmount
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        _maxAmountOfToken = maxTokenAmount;
        token = IERC20Upgradeable(tokenAddress);
        initCommissionRate();
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddress);
        // Create a uniswap pair for this new token
        address pairAddress = IUniswapV2Factory(_uniswapV2Router.factory())
            .getPair(address(tokenAddress), _uniswapV2Router.WETH());
        if (pairAddress == address(0)) {
            uniswapV2Pair = IUniswapV2Pair(
                IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
                    address(tokenAddress),
                    _uniswapV2Router.WETH()
                )
            );
        } else {
            uniswapV2Pair = IUniswapV2Pair(pairAddress);
        }
        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        _initialExchangeRate = 10000;
    }

    receive() external payable {}

    function initCommissionRate() private {
        _commissionRatePlan["level0"] = 0;
        _commissionRatePlan["level1"] = 10;
        _commissionRatePlan["level2"] = 15;
        _commissionRatePlan["level3"] = 30;
        _commissionRatePlan["level4"] = 50;
        _commissionRatePlan["level5"] = 100;
    }

    function getMaxAmountOfToken() public view returns (uint256) {
        return _maxAmountOfToken;
    }

    function getTokenAddress() public view returns (address) {
        return address(token);
    }

    function getTimeLockDuration() public view returns (uint256) {
        return _timeLockDuration;
    }

    function setMaxAmountOfToKen(uint256 amount) external onlyOwner {
        require(_maxAmountOfToken != amount, "Can't change same amount");
        _maxAmountOfToken = amount;
    }

    function setTokenAddress(address tokenAddress) external onlyOwner {
        require(
            address(token) != tokenAddress,
            "Can't change same token address"
        );
        require(
            tokenAddress != address(0),
            "The token address can not be 0 address"
        );
        token = IERC20Upgradeable(tokenAddress);
    }

    function setTimeLockDuration(uint256 duration) external onlyOwner {
        require(duration > 0, "The time lock duration can not be 0");
        _timeLockDuration = duration * 1 days;
    }

    function setInitialExchangeRate(uint256 exchageRate) external onlyOwner {
        require(exchageRate > 0, "The exchange rate must be over 0");
        _initialExchangeRate = exchageRate;
    }

    function setCommissionRatePlan(string memory level, uint256 rate)
        external
        onlyOwner
    {
        // level condition, when level does not exit.
        _commissionRatePlan[level] = rate;
    }

    function closeSale() external onlyOwner {
        _closeSale = true;
    }

    function openSale() external onlyOwner {
        _closeSale = false;
    }

    //withdraw ETH
    function withdrawETH(address payable receiver, uint256 amount)
        public
        onlyOwner
    {
        _withdrawETH(receiver, amount);
    }

    //withdraw Token
    function withdrawToken(address receiver, uint256 amount) public onlyOwner {
        _withdrawToken(receiver, amount);
    }

    function tokenApprove(uint256 tokenAmount) public onlyOwner {
        token.approve(address(uniswapV2Router), tokenAmount);
    }

    function addLiquidity() public onlyOwner {
        require(_closeSale == true, "This sale did not close yet");
        uint256 lpEtherAmount = _totalTokenAmount.div(_initialExchangeRate);
        require(
            address(this).balance >= lpEtherAmount,
            "Ether amount is not engough"
        );
        token.approve(address(uniswapV2Router), _totalTokenAmount);
        _addLiquidity(_totalTokenAmount, lpEtherAmount);
    }

    function lpTokenAprrove(uint256 liquidity) public onlyOwner {
        uniswapV2Pair.approve(address(this), liquidity);
        uniswapV2Pair.approve(address(uniswapV2Router), liquidity);
    }

    function removeLiquidity() public onlyOwner {}

    //function for all users
    function subscribe(uint256 amount) external {
        require(_closeSale == false, "This sale is finished by admin!");
        require(
            _totalTokenAmount.add(amount) < _maxAmountOfToken,
            "You can't contribute more than maximum token amount"
        );
        require(amount > 0, "You need to sell at least some tokens");
        require(
            _contributesAmount[_msgSender()] <= 0,
            "You have already contributed"
        );
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "Check the token allowance");
        _contributesAmount[msg.sender] = amount;
        _contributesTime[_msgSender()] = block.timestamp + _timeLockDuration;
        _totalTokenAmount = _totalTokenAmount.add(amount);
        token.transferFrom(msg.sender, address(this), amount);
    }

    function redeem() external {
        require(
            _contributesAmount[_msgSender()] > 0,
            "You didn't contribut yet"
        );
        require(
            block.timestamp > _contributesTime[_msgSender()],
            "Don't allow this feature"
        );
        uint256 removeLPTokenAmount = _getRemoveLPTokenAmount(_msgSender());
        (uint256 amountToken, uint256 amountETH) = _removeLiquidity(
            removeLPTokenAmount
        );
        (uint256 rate, uint256 profitTokenAmount) = _getCommissionRate(
            _contributesAmount[_msgSender()],
            amountToken
        );
        _totalTokenAmount.sub(_contributesAmount[_msgSender()]);
        _contributesAmount[_msgSender()] = 0;
        token.transfer(_msgSender(), profitTokenAmount);
        _withdrawETH(payable(_msgSender()), amountETH.mul(rate));
    }

    function _withdrawETH(address payable receiver, uint256 amount) private {
        bool sent = receiver.send(amount);
        require(sent, "Failed to send Ether");
    }

    function _withdrawToken(address receiver, uint256 amount) private {
        require(amount > 0, "You need to send some token");
        token.transfer(receiver, amount);
    }

    function _addLiquidity(uint256 tokenAmount, uint256 etherAmount) private {
        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: etherAmount}(
            address(token),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function _removeLiquidity(uint256 liquidity)
        private
        returns (uint256 amountToken, uint256 amountETH)
    {
        IUniswapV2Pair(uniswapV2Pair).approve(address(this), liquidity);
        IUniswapV2Pair(uniswapV2Pair).approve(
            address(uniswapV2Router),
            liquidity
        );

        // add the liquidity
        return
            uniswapV2Router.removeLiquidityETH(
                address(token),
                liquidity,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                address(this),
                block.timestamp
            );
    }

    function _getCommissionRate(uint256 contributeAmount, uint256 totalAmount)
        private
        view
        returns (uint256, uint256)
    {
        uint256 rate = 0;
        uint256 profitTokenAmount = 0;
        if (contributeAmount > totalAmount) {
            rate = _commissionRatePlan["level0"];
        } else if (
            contributeAmount < totalAmount &&
            contributeAmount.mul(15).div(10) >= totalAmount
        ) {
            rate = _commissionRatePlan["level1"];
            profitTokenAmount = contributeAmount;
        } else if (
            contributeAmount.mul(15).div(10) < totalAmount &&
            contributeAmount.mul(2) >= totalAmount
        ) {
            rate = _commissionRatePlan["level2"];
            profitTokenAmount = contributeAmount;
        } else if (
            contributeAmount.mul(2) < totalAmount &&
            contributeAmount.mul(3) >= totalAmount
        ) {
            rate = _commissionRatePlan["level3"];
            profitTokenAmount = contributeAmount;
        } else if (
            contributeAmount.mul(3) < totalAmount &&
            contributeAmount.mul(5) >= totalAmount
        ) {
            _commissionRatePlan["level4"];
            profitTokenAmount = contributeAmount;
        } else if (contributeAmount.mul(5) < totalAmount) {
            rate = _commissionRatePlan["level5"];
            profitTokenAmount = contributeAmount;
        }

        return (rate, profitTokenAmount);
    }

    function _getRemoveLPTokenAmount(address requester)
        private
        view
        returns (uint256)
    {
        uint256 lpTokenAmount = uniswapV2Pair.balanceOf(address(this));
        uint256 percentOfReuester = _contributesAmount[requester]
            .mul(10000)
            .div(_totalTokenAmount);
        return lpTokenAmount.mul(percentOfReuester).div(10000);
    }
}
