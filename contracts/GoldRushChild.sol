// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./AnyCallApp.sol";

contract GoldRushChild is ERC721Enumerable, AnyCallApp {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    bytes32 public Method_Claim = keccak256("claim");
    bytes32 public Method_Transfer = keccak256("transfer");

    uint256 immutable mainChain;
    // address public immutable xETH;

    constructor(
        address callProxy,
        uint256 _mainChain,
        // address _xETH,
        string memory name,
        string memory symbol
    ) AnyCallApp(callProxy, 0, 0.1e18) ERC721(name, symbol) {
        mainChain = _mainChain;
        // xETH = _xETH;
    }

    bool private mintPaused = false;
    // selling price
    uint public constant MINT_PRICE = 0.4 ether; 

    function mint(address to)
        public
        payable
        returns (uint256)
    {
        require(msg.value >= MINT_PRICE, "Price err");
        claimAndFetch(to, 0);
        return 0;
    }
    function paused() public view returns (bool) {
        return mintPaused;
    }
    function setPaused() public onlyAdmin {
        require(!mintPaused, "Already paused");
        mintPaused = true;
    }
    function unpaused() public onlyAdmin {
        require(mintPaused, "Already unpaused");
        mintPaused = false;
    }

    function withdraw() public onlyAdmin {
        uint256 wad = address(this).balance;
        payable(msg.sender).transfer(wad);
    }

    function claimAndFetch(address to, uint256 tokenId) internal {
        bytes memory data = abi.encode(Method_Claim, to, tokenId, true); // mint and fetch
        _anyCall(peer[mainChain], data, mainChain);
    }

    function Swapout_no_fallback(
        uint256 toChainID,
        address to,
        uint256 tokenId
    ) public payable {
        _burn(tokenId);
        bytes memory data = abi.encode(Method_Transfer, to, tokenId, false);
        _anyCall(peer[toChainID], data, toChainID);
    }

    function _anyExecute(uint256 fromChainID, bytes calldata data)
        internal
        override
        returns (bool success, bytes memory result)
    {
        (
            bytes32 method, 
            address to, 
            uint256 tokenId,
        ) = abi.decode(
                data, (bytes32, address, uint256, bool)
            );
        if (method == Method_Transfer) {
            _mint(to, tokenId);
        }
        return (true, "");
    }

    function _anyFallback(bytes memory data)
        internal
        override
        returns (bool success, bytes memory result)
    {
        (
            bytes32 method, 
            address to,
            uint256 tokenId , 
        ) = abi.decode(
                data, (bytes32, address, uint256, bool)
            );
        if (method == Method_Claim) {
            payable(to).transfer(MINT_PRICE);
        }
        if (method == Method_Transfer) {
            _mint(to, tokenId);
        }
        return (true, "");
    }
}
