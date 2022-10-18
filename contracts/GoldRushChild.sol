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
    address public tokenETH;

    constructor(
        address callProxy,
        uint256 _mainChain,
        address _xETH,
        string memory name,
        string memory symbol
    ) AnyCallApp(callProxy, 4, 0.1e18) ERC721(name, symbol) {
        mainChain = _mainChain;
        tokenETH = _xETH;
    }

    bool private mintPaused = false;
    // selling price
    uint public constant MINT_PRICE = 0.4 ether; 

    function mint(address to)
        public
        payable
        returns (uint256)
    {
        require(EIP20Interface(tokenETH).transferFrom(msg.sender, address(this), MINT_PRICE));
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
        EIP20Interface token = EIP20Interface(tokenETH);
        uint256 wad = token.balanceOf(address(this));
        token.transfer(msg.sender, wad);
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
            require(EIP20Interface(tokenETH).transfer(msg.sender, MINT_PRICE));
        }
        if (method == Method_Transfer) {
            _mint(to, tokenId);
        }
        return (true, "");
    }
}

/**
 * @title ERC 20 Token Standard Interface
 *  https://eips.ethereum.org/EIPS/eip-20
 */
interface EIP20Interface {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256 balance);
    function transfer(address dst, uint256 amount) external returns (bool success);
    function transferFrom(address src, address dst, uint256 amount) external returns (bool success);
    function approve(address spender, uint256 amount) external returns (bool success);
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}
