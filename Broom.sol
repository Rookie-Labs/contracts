// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

/**
                                                         __
     _____      __      ___    ___     ___     __       /\_\    ___
    /\ '__`\  /'__`\   /'___\ / __`\  /'___\ /'__`\     \/\ \  / __`\
    \ \ \_\ \/\ \_\.\_/\ \__//\ \_\ \/\ \__//\ \_\.\_  __\ \ \/\ \_\ \
     \ \ ,__/\ \__/.\_\ \____\ \____/\ \____\ \__/.\_\/\_\\ \_\ \____/
      \ \ \/  \/__/\/_/\/____/\/___/  \/____/\/__/\/_/\/_/ \/_/\/___/
       \ \_\
        \/_/

    The sweetest DeFi portfolio manager.

**/

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouter02.sol";

contract Broom is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public constant PACOCA = 0x55671114d774ee99D653D6C12460c780a67f1D18;
    address public constant buyBackAddress = 0x000000000000000000000000000000000000dEaD;

    uint public buyBackRate = 300; // Initial fee 3%;
    uint public constant buyBackRateMax = 10000; // 100 = 1%
    uint public constant buyBackRateUL = 1000; // Fee upper limit 10%

    event SetBuyBackRate(uint _buyBackRate);

    constructor (address _owner) public {
        transferOwnership(_owner);
    }

    function sweep(
        address _router,
        address _connector,
        address[] calldata _tokens,
        uint[] calldata _amounts,
        uint[] calldata _amountsOutMin
    ) external {
        for (uint index = 0; index < _tokens.length; ++index) {
            _approveTokenIfNeeded(_tokens[index], _router);

            IERC20(_tokens[index]).safeTransferFrom(msg.sender, address(this), _amounts[index]);

            _swap(
                _router,
                _connector,
                _tokens[index],
                IERC20(_tokens[index]).balanceOf(address(this)),
                _amountsOutMin[index]
            );
        }

        uint balance = IERC20(PACOCA).balanceOf(address(this));
        uint buyBackAmount = balance.mul(buyBackRate).div(buyBackRateMax);

        _safePACOCATransfer(buyBackAddress, buyBackAmount);
        _safePACOCATransfer(msg.sender, balance.sub(buyBackAmount));
    }

    function _approveTokenIfNeeded(address token, address router) private {
        if (IERC20(token).allowance(address(this), router) == 0) {
            IERC20(token).safeApprove(router, uint(- 1));
        }
    }

    function _swap(
        address _router,
        address _connector,
        address _fromToken,
        uint _amount,
        uint _amountOutMin
    ) private {
        if (_fromToken == PACOCA) {
            return;
        }

        address[] memory path;

        if (_fromToken == _connector) {
            path = new address[](2);

            path[0] = _fromToken;
            path[1] = PACOCA;
        } else {
            path = new address[](3);

            path[0] = _fromToken;
            path[1] = _connector;
            path[2] = PACOCA;
        }

        IPancakeRouter02(_router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount, // input amount
            _amountOutMin, // min output amount
            path, // path
            address(this), // to
            block.timestamp // deadline
        );
    }

    function setBuyBackRate(uint _buyBackRate) external onlyOwner {
        require(_buyBackRate <= buyBackRateUL, "_buyBackRate too high");
        buyBackRate = _buyBackRate;

        emit SetBuyBackRate(_buyBackRate);
    }

    // Safe PACOCA transfer function, just in case if rounding error causes pool to not have enough
    function _safePACOCATransfer(address _to, uint256 _amount) private {
        uint256 balance = IERC20(PACOCA).balanceOf(address(this));

        if (_amount > balance) {
            IERC20(PACOCA).transfer(_to, balance);
        } else {
            IERC20(PACOCA).transfer(_to, _amount);
        }
    }
}
