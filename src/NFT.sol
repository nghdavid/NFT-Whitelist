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
    bytes32 private root;
    address public immutable signer;
    uint256 public totalSupply = 10000;
    uint256[10000] public ids;
    uint256 public mintCount;

    // Chainlink VRF
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

    mapping(uint256 => address) public requestToSender;
    // Your subscription ID.
    uint256 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    bytes32 keyHash =
        0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be;
    address public VRFAddress = 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61;
    uint32 callbackGasLimit = 1000000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    constructor(
        bytes32 _root,
        address _signer,
        uint256 subscriptionId
    ) VRFConsumerBaseV2Plus(VRFAddress) ERC721("WhiteList", "NWL") {
        root = _root;
        signer = _signer;
        COORDINATOR = IVRFCoordinatorV2Plus(VRFAddress);
        s_subscriptionId = subscriptionId;
    }

    function mintMerkleProofRealRandom(
        address account,
        bytes32[] memory proof
    ) external returns (uint256 requestId) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account))));
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
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

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        requestToSender[requestId] = account;
        emit RequestSent(requestId, numWords);
        return requestId;
    }
    
    function mintSignatureRealRandom(
        address account,
        bytes memory signature
    ) external returns (uint256 requestId){
        bytes32 _msgHash = keccak256(abi.encodePacked(account));
        bytes32 _ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            _msgHash
        );
        require(
            SignatureChecker.isValidSignatureNow(
                signer,
                _ethSignedMessageHash,
                signature
            ),
            "Invalid signature"
        );
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

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        requestToSender[requestId] = account;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
        address account = requestToSender[_requestId];
        uint256 tokenId = pickRandomUniqueId(_randomWords[0]);
        _mint(account, tokenId);
    }

    function pickRandomUniqueId(
        uint256 random
    ) private returns (uint256 tokenId) {
        uint256 len = totalSupply - mintCount++;
        require(len > 0, "mint close");
        uint256 randomIndex = random % len;
        tokenId = ids[randomIndex] != 0 ? ids[randomIndex] : randomIndex;
        ids[randomIndex] = ids[len - 1] == 0 ? len - 1 : ids[len - 1];
        ids[len - 1] = 0;
  }
}
