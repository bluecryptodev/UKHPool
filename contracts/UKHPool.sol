// Token Pool
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract UHKPool is Initializable, ContextUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    IERC20Upgradeable token;
    uint256 private _maxAmountOfToken = 0;
    address private _tokenAddress;

    uint256 private _timeLockDuration = 10 minutes; //to test

    bool _closeSale = false;

    address private _routerV2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping(address => uint256) private _contributesAmount;
    mapping(address => uint256) private _contributesTime;
    mapping(string => uint256) private _commissionRatePlan;

    event Contribute(address indexed investor, uint256 value);

    constructor(address tokenAddress, uint256 maxTokenAmount) {
        OwnableUpgradeable.__Ownable_init();
        _tokenAddress = tokenAddress;
        _maxAmountOfToken = maxTokenAmount;
        token = IERC20Upgradeable(tokenAddress);
        initCommissionRate();
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_routerV2);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
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
        return _tokenAddress;
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
            _tokenAddress != tokenAddress,
            "Can't change same token address"
        );
        require(
            tokenAddress != address(0),
            "The token address can not be 0 address"
        );
        _tokenAddress = tokenAddress;
    }

    function setTimeLockDuration(uint256 duration) external onlyOwner {
        require(duration == 0, "The time lock duration can not be 0");
        _timeLockDuration = block.timestamp + duration;
    }

    function closeSale() external onlyOwner {
        _closeSale = true;
    }

    //withdraw ETH
    function withdrawETH(address payable receiver, uint256 amount)
        public
        onlyOwner
    {
        bool sent = receiver.send(amount);
        require(sent, "Failed to send Ether");
    }

    //withdraw Token
    function withdrawToken(address receiver, uint256 anmount) public onlyOwner {
        require(anmount > 0, "You need to send some token");
        IERC20Upgradeable(_tokenAddress).transfer(receiver, anmount);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount)
        public
        onlyOwner
    {
        // approve token transfer to cover all possible scenarios
        token.approve(address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(token),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function removeLiquidity(uint256 tokenAmount) public onlyOwner {
        // approve token transfer to cover all possible scenarios
        token.approve(address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.removeLiquidityETH(
            address(token),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(token),
            block.timestamp
        );
    }

    //function for all users
    function subscribe(uint256 amount) external {
        require(
            amount < _maxAmountOfToken,
            "You can't contribute more than maximum token amount"
        );
        require(amount > 0, "You need to sell at least some tokens");
        require(_closeSale == false, "This sale is finished by admin!");
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= amount, "Check the token allowance");
        _contributesAmount[msg.sender] = amount;
        _contributesTime[_msgSender()] = block.timestamp + _timeLockDuration;
        IERC20Upgradeable(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    function redeem() external {
        require(
            block.timestamp > _contributesTime[_msgSender()],
            "Don't allow this feature"
        );

        (uint256 rate, uint256 profitTokenAmount) = _getCommissionRate(
            _contributesAmount[_msgSender()],
            100000000
        );
        _contributesAmount[_msgSender()] = 0;
        token.transfer(_msgSender(), profitTokenAmount);
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
}
