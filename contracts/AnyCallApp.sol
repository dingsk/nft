// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Administrable.sol";
import "./IAnycallProxy.sol";
import "./IExecutor.sol";

abstract contract AnyCallApp is Administrable {
    uint256 public flag; // 0: pay on src chain, 2: pay on dest chain
    address public anyCallProxy;
    uint256 public _anycall_fee;

    mapping(uint256 => address) internal peer;

    modifier onlyExecutor() {
        require(msg.sender == IAnycallProxy(anyCallProxy).executor());
        _;
    }

    

    constructor (address anyCallProxy_, uint256 flag_, uint256 _anycall_fee_) {
        anyCallProxy = anyCallProxy_;
        flag = flag_;
        setAdmin(msg.sender);
        _anycall_fee = _anycall_fee_;
    }

    function setPeers(uint256[] memory chainIDs, address[] memory  peers) public onlyAdmin {
        for (uint i = 0; i < chainIDs.length; i++) {
            peer[chainIDs[i]] = peers[i];
        }
    }

    function getPeer(uint256 foreignChainID) external view returns (address) {
        return peer[foreignChainID];
    }

    function setAnyCallProxy(address proxy) public onlyAdmin {
        anyCallProxy = proxy;
    }

    function _anyExecute(uint256 fromChainID, bytes calldata data) internal virtual returns (bool success, bytes memory result);
    function _anyFallback(bytes memory data) internal virtual returns (bool success, bytes memory result);

    function _anyCall(address _to, bytes memory _data, uint256 _toChainID) internal {
        if (flag == 2) {
            IAnycallProxy(anyCallProxy).anyCall(_to, _data, _toChainID, flag, "");
        } else {
            IAnycallProxy(anyCallProxy).anyCall{value: _anycall_fee}(_to, _data, _toChainID, flag, "");
        }
    }

    function anyExecute(bytes calldata data) external onlyExecutor returns (bool success, bytes memory result) {
        (address callFrom, uint256 fromChainID,) = IExecutor(IAnycallProxy(anyCallProxy).executor()).context();
        require(peer[fromChainID] == callFrom, "call not allowed");
        return _anyExecute(fromChainID, data);
    }

    function anyFallback(bytes memory data) external onlyExecutor returns (bool success, bytes memory result) {
        return _anyFallback(data);
    }
}