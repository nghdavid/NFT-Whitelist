// SPDX-License-Identifier: UNLICENSED
pragma solidity = 0.8.25;
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract NFTWhiteList is ERC721, VRFConsumerBaseV2Plus {
    using ECDSA for bytes32;
    bytes32 private root; // Merkle root
    address public immutable signer; // Account that signs the signature
    uint256 public totalSupply = 10000;
    uint256[10000] public ids;
    uint256 public mintCount;

    // Chainlink VRF2.5
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    IVRFCoordinatorV2Plus COORDINATOR;

    mapping(uint256 => address) public requestToSender; // requestId --> sender
    uint256 s_subscriptionId; // VRF subscription id

    uint256[] public requestIds;
    uint256 public lastRequestId; // past requests id

    bytes32 keyHash =
        0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be; // 50 gwei Key Hash
    address public VRFAddress = 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61;
    uint32 callbackGasLimit = 1000000; // callback is fulfillRandomWords
    uint16 requestConfirmations = 3; // number of confirmations request to be made on fulfillRandomWords
    uint32 numWords = 1; // number of random words to be generated

    constructor(
        bytes32 _root,
        address _signer,
        uint256 subscriptionId
    ) VRFConsumerBaseV2Plus(VRFAddress) ERC721("WhiteList", "NWL") {
        root = _root; // Merkle root
        signer = _signer; // Account that signs the signature
        COORDINATOR = IVRFCoordinatorV2Plus(VRFAddress); // Chainlink VRF contract
        s_subscriptionId = subscriptionId; // VRF subscription id
    }

    function mintMerkleProofRealRandom(
        address account,
        bytes32[] memory proof
    ) external returns (uint256 requestId) {
        require(totalSupply - mintCount > 0, "Mint finish");
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account))));
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
        // Request VRF contract to generate random words
        requestId = makeRandomRequest(account);
        return requestId;
    }
    
    function mintSignatureRealRandom(
        address account,
        bytes memory signature
    ) external returns (uint256 requestId){
        require(totalSupply - mintCount > 0, "Mint finish");
        bytes32 _msgHash = keccak256 (abi.encodePacked (account)); // Message
        bytes32 _ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            _msgHash
        ); // Eth signed message
        // Validate the signature
        require(
            SignatureChecker.isValidSignatureNow(
                signer,
                _ethSignedMessageHash,
                signature
            ),
            "Invalid signature"
        );
        // Request VRF contract to generate random words
        requestId = makeRandomRequest(account);
        return requestId;
    }
    
    // It asks Chainlink VRF to generate random words
    function makeRandomRequest(address account) internal returns (uint256 requestId){
        // Call COORDINATOR's function(requestRandomWords)
        requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        // Add new status to s_requests
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        requestToSender[requestId] = account;
        emit RequestSent(requestId, numWords);
    }

    // It receives the random words from Chainlink VRF and mint NFT
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "Request not found");
        // Update the request status
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
        address account = requestToSender[_requestId];
        uint256 tokenId = pickRandomUniqueId(_randomWords[0]);
        _mint(account, tokenId);
    }

    // Pick a random unique id based on the random number
    function pickRandomUniqueId(
        uint256 random
    ) private returns (uint256 tokenId) {
        uint256 len = totalSupply - mintCount++;
        require(len > 0, "Mint Finish");
        uint256 randomIndex = random % len;
        tokenId = ids[randomIndex] != 0 ? ids[randomIndex] : randomIndex;
        ids[randomIndex] = ids[len - 1] == 0 ? len - 1 : ids[len - 1];
        ids[len - 1] = 0;
  }
}
