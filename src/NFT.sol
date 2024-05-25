// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract NFTWhiteList is ERC721 {
    bytes32 private root;
    address immutable public signer;
    uint256 public totalSupply = 10000;
    uint256 [10000] public ids;
    uint256 public mintCount;
    
    constructor(bytes32 _root, address _signer) ERC721("WhiteList", "NWL") {
      root = _root;
      signer = _signer;
    }

    function mintMerkleProofFakeRandom(address account, bytes32[] memory proof) external {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account))));
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
        uint256 randomNumber = getRandomOnchain();
        uint256 tokenId = pickRandomUniqueId (randomNumber);
        _mint(account, tokenId);
    }

    function mintSignatureFakeRandom(address account, bytes memory signature) external {
        bytes32 _msgHash = getMessageHash(account);
        bytes32 _ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(_msgHash);
        require (SignatureChecker.isValidSignatureNow (signer, _ethSignedMessageHash, signature), "Invalid signature"); // ECDSA 检验通过
        uint256 randomNumber = getRandomOnchain();
        uint256 tokenId = pickRandomUniqueId (randomNumber);
        _mint(account, tokenId);
    }
    
    function getMessageHash(address account) public pure returns(bytes32){
        return keccak256(abi.encodePacked(account));
    }

    function getRandomOnchain() public view returns(uint256){
        bytes32 randomBytes = keccak256(abi.encodePacked(block.timestamp, msg.sender, blockhash(block.number-1)));
        return uint256(randomBytes);
    }

    function pickRandomUniqueId(uint256 random) private returns (uint256 tokenId) {
        uint256 len = totalSupply - mintCount++;
        require (len> 0, "mint close");
        uint256 randomIndex = random % len;
        tokenId = ids [randomIndex] != 0 ? ids [randomIndex] : randomIndex;
        ids [randomIndex] = ids [len - 1] == 0 ? len - 1 : ids [len - 1];
        ids [len - 1] = 0;
    }
}