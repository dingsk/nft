// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./AnyCallApp.sol";

contract GoldRush is ERC721Enumerable, AnyCallApp {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    bytes32 public Method_Claim = keccak256("claim");
    bytes32 public Method_Transfer = keccak256("transfer");

    constructor(
        address callProxy,
        string memory name,
        string memory symbol
    ) AnyCallApp(callProxy, 0, 0.1e18) ERC721(name, symbol) {}

    uint public constant MINT_TYPE_PUBLIC = 0;
    uint public constant MINT_TYPE_FREE = 1;
    uint public constant MINT_TYPE_WHITE = 2;
    bool private mintPaused = false;
    // selling price
    uint public constant MINT_PRICE = 0.4 ether; 
    uint public constant WHITE_MINT_PRICE = 0.25 ether; 
    // white list merkle root
    bytes32 public whiteListRoot = 0x7198422677e34e571980486c661ebc08bb6ec2dc8d0449102da312e6e7cc1052;
    bytes32 public freeMintRoot = 0x74ddcb7bb86d304dc312bd381bbe898fd7aa5a9cb2fd2aa4e9d1b3ced1b6dd3c;
    uint private mintMax = 3000;
    uint private _mintMax = 0;
    uint private whiteMintMax = 400;
    uint private _whiteMintMax = 0;
    uint private freeMintMax = 200;
    uint private _freeMintMax = 0;

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
            _type = MINT_TYPE_WHITE;
        }
        
        return _mintProxy(to, _type);
    }

    function freeMint(address to, bytes32[] memory _proof)
        public
        returns (uint256)
    {
        bytes32 leaf = keccak256(abi.encodePacked(to));
        require(MerkleProof.verify(_proof,freeMintRoot,leaf), "Not free mint address");
        
        return _mintProxy(to, MINT_TYPE_FREE);
    }

    function _mintProxy(address to, uint _type) internal returns (uint256) {
        require(!mintPaused, "Already paused");
        require(_mintMax < mintMax, "GoldRush is sold out!");
        _mintMax += 1;
        if(_type == MINT_TYPE_FREE){
            require(!freeClaimed[to], "Address has already claimed!");
            require(_freeMintMax < freeMintMax, "Free mint is sold out!");
            freeClaimed[to] = true;
            _freeMintMax += 1;
        }else if(_type == MINT_TYPE_WHITE) {
            require(!whiteListClaimed[to], "Address has already claimed!");
            require(_whiteMintMax < whiteMintMax, "White mint is sold out!");
            whiteListClaimed[to] = true;
            _whiteMintMax += 1;
        }

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(to, newItemId);

        return newItemId;
    }

    function _burnProxy(address to, uint256 tokenId, uint _type) internal {
        _mintMax -= 1;
        if(_type == MINT_TYPE_FREE){
            freeClaimed[to] = false;
            _freeMintMax -= 1;
        }else if(_type == MINT_TYPE_WHITE) {
            whiteListClaimed[to] = false;
            _whiteMintMax -= 1;
        }

        _burn(tokenId);
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

    function Swapout_no_fallback(
        address to,
        uint256 tokenId,
        uint256 toChainID
    ) public payable {
        safeTransferFrom(msg.sender, address(this), tokenId);
        bytes memory data = abi.encode(Method_Transfer, to, tokenId, false);
        _anyCall(peer[toChainID], data, address(this), toChainID);
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
            bool sendBack 
        ) = abi.decode(
                data, (bytes32, address, uint256, bool)
            );
        if (method == Method_Claim) {
            if (sendBack) { /// cross by anyCall
                tokenId = _mintProxy(address(this), MINT_TYPE_PUBLIC);
                bytes memory _data = abi.encode(Method_Transfer, to, tokenId, false);
                _anyCall(peer[fromChainID], _data, address(this), fromChainID);
            }else{
                tokenId = _mintProxy(to, MINT_TYPE_PUBLIC);
            }
            return (true, "");
        }
        if (method == Method_Transfer) {
            safeTransferFrom(address(this), to, tokenId);
            return (true, "");
        }
        return (false, "");
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
            bool sendBack 
        ) = abi.decode(
                data, (bytes32, address, uint256, bool)
            );
        if (method == Method_Claim) {
            if(sendBack){
                _burnProxy(to, tokenId, MINT_TYPE_PUBLIC);
            }else{
                /// no operation
            }
        }
        if (method == Method_Transfer) {
            safeTransferFrom(address(this), to, tokenId);
            return (true, "");
        }
        return (true, "");
    }
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
