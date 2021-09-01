// Token Pool
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UHKPool is Context, Ownable, Initializable {
    using SafeMath for uint256;
    using Address for address;

    uint256 private _maxAmountOfToken = 0;
    address private _tokenAddress;

    uint256 private _timeLockDuration = block.timestamp + 180 days;

    mapping(address => uint256) private _cotributes;

    event Contribute(address indexed investor, uint256 value);

    constructor(address tokenAddress, uint256 maxTokenAmount) {
        _tokenAddress = tokenAddress;
        _maxAmountOfToken = maxTokenAmount;
    }

    receive() external payable {}

    function getMaxAmountOfToken() public view returns (uint256) {
        return _maxAmountOfToken;
    }

    function getTokenAddress() public view returns (address) {
        return _tokenAddress;
    }

    function getTimeLockDuration() public view returns (uint256) {
        return _timeLockDuration;
    }

    function setMaxAmountOfTolen(uint256 amount) external onlyOwner {
        require(_maxAmountOfToken != amount, "Can't change same amount");
        _maxAmountOfToken = amount;
    }

    function setTokenAddress(address tokenAddress) external onlyOwner {
        require(
            _tokenAddress != tokenAddress,
            "Can't change same token address"
        );
        require(
            tokenAddress == address(0),
            "The token address can not be 0 address"
        );
        _tokenAddress = tokenAddress;
    }

    function setTimeLockDuration(uint256 duration) external onlyOwner {
        require(duration == 0, "The time lock duration can not be 0");
        _timeLockDuration = block.timestamp + duration;
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
        uint256 dexBalance = IERC20(_tokenAddress).balanceOf(address(this));
        require(anmount > 0, "You need to send some token");
        require(anmount <= dexBalance, "Not enough tokens in the reserve");
        IERC20(_tokenAddress).transfer(receiver, anmount);
    }
}
