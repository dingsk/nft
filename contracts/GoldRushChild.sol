// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./AnyCallApp.sol";

contract GoldRushChild is ERC721Enumerable, AnyCallApp {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string private _baseTokenURI;
    bytes32 public Method_Claim = keccak256("claim");
    bytes32 public Method_Transfer = keccak256("transfer");

    uint256 immutable mainChain;
    address public tokenETH;

    constructor(
        address callProxy,
        uint256 _mainChain,
        string memory name,
        string memory symbol
    ) AnyCallApp(callProxy, 4, 0.1e18) ERC721(name, symbol) {
        mainChain = _mainChain;
    }

    uint public constant MINT_TYPE_PUBLIC = 0;
    uint public constant MINT_TYPE_FREE = 1;
    uint public constant MINT_TYPE_WHITE = 2;
    bool private mintPaused = false;
    // selling price
    uint public constant MINT_PRICE = 0.1 ether; 
    uint public constant WHITE_MINT_PRICE = 0.05 ether; 
    // white list merkle root
    bytes32 public whiteListRoot;
    bytes32 public freeMintRoot;

    mapping(address => bool) public whiteListClaimed;
    mapping(address => bool) public freeClaimed;

    function mint(address to, bytes32[] memory _proof)
        public
        payable
        returns (uint256)
    {
        bool isWhite = false;
        bytes32 leaf = keccak256(abi.encodePacked(to));
        if(msg.value < MINT_PRICE && MerkleProof.verify(_proof,whiteListRoot,leaf)) {
            require(msg.value >= WHITE_MINT_PRICE, "Price err");
            isWhite = true;
        } else {
            require(msg.value >= MINT_PRICE, "Price err");
        }
        
        uint _type = MINT_TYPE_PUBLIC;
        if(isWhite){
            require(!whiteListClaimed[to], "Address has already claimed!");
            whiteListClaimed[to] = true;
            _type = MINT_TYPE_WHITE;
        }

        claimAndFetch(to, 0);
        return 0;
    }

    function freeMint(address to, bytes32[] memory _proof)
        public
        returns (uint256)
    {
        bytes32 leaf = keccak256(abi.encodePacked(to));
        require(MerkleProof.verify(_proof,freeMintRoot,leaf), "Not free mint address");
        require(!freeClaimed[to], "Address has already claimed!");
        freeClaimed[to] = true;
        claimAndFetch(to, 0);
        return 0;
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    function setBaseURI(string memory _uri) public onlyAdmin {
        _baseTokenURI = _uri;
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

    function setWhiteListRoot(bytes32 _root) public onlyAdmin {
        whiteListRoot = _root;
    }
    function setFreeMintRoot(bytes32 _root) public onlyAdmin {
        freeMintRoot = _root;
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
            uint256 tokenId,
        ) = abi.decode(
                data, (bytes32, address, uint256, bool)
            );
        if (method == Method_Claim) {
            // 
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


/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}
