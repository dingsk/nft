// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAnycallProxy {
    function anyCall(
        address _to,
        bytes calldata _data,
        uint256 _toChainID,
        uint256 _flags,
        bytes calldata x
    ) external payable;

    function executor() external view returns (address);
}