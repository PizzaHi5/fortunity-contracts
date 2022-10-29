// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { Strings } from "./FortStrings.sol";
import { ChainlinkClient } from "@chainlink/contracts/src/v0.7/ChainlinkClient.sol";
import { ConfirmedOwner } from "@chainlink/contracts/src/v0.7/ConfirmedOwner.sol";
import { Chainlink } from "@chainlink/contracts/src/v0.7/Chainlink.sol";
import { LinkTokenInterface } from "@chainlink/contracts/src/v0.7/interfaces/LinkTokenInterface.sol";

contract FortTfi is ChainlinkClient, ConfirmedOwner(msg.sender) {
    using Chainlink for Chainlink.Request;

    bytes public result;
    mapping(bytes32 => bytes) public results;
    address public oracleId;
    string public jobId;
    uint256 public fee;

    //
    // EXTERNAL NON-VIEW
    //

    function initialize(
        address oracleId_,
        string memory jobId_,
        uint256 fee_,
        address token_
        //changed from initilizer ConfirmedOwner
    ) external onlyOwner {
        setChainlinkToken(token_);
        oracleId = oracleId_;
        jobId = jobId_;
        fee = fee_;
    }

    //
    // PUBLIC NON-VIEW
    //
    
    function doRequest(
        string memory service_,
        string memory data_,
        string memory keypath_,
        string memory abi_,
        string memory multiplier_
        ) public returns (bytes32 requestId) {
          Chainlink.Request memory req = buildChainlinkRequest(
            _bytesToBytes32(bytes(jobId)),
            address(this), this.fulfillBytes.selector);
        req.add("service", service_);
        req.add("data", data_);
        req.add("keypath", keypath_);
        req.add("abi", abi_);
        req.add("multiplier", multiplier_);
        return sendChainlinkRequestTo(oracleId, req, fee);
    }

    function doTransferAndRequest(
        string memory service_,
        string memory data_,
        string memory keypath_,
        string memory abi_,
        string memory multiplier_,
        uint256 fee_
        ) public returns (bytes32 requestId) {
        require(LinkTokenInterface(getToken()).transferFrom(
               msg.sender, address(this), fee_), "transfer failed");
        Chainlink.Request memory req = buildChainlinkRequest(
            _bytesToBytes32(bytes(jobId)),
            address(this), this.fulfillBytes.selector);
        req.add("service", service_);
        req.add("data", data_);
        req.add("keypath", keypath_);
        req.add("abi", abi_);
        req.add("multiplier", multiplier_);
        req.add("refundTo",
                Strings.toHexString(uint256(uint160(msg.sender)), 20));
        return sendChainlinkRequestTo(oracleId, req, fee_);
    }

    function fulfillBytes(bytes32 _requestId, bytes memory bytesData)
        public recordChainlinkFulfillment(_requestId) {
        result = bytesData;
        results[_requestId] = bytesData;
    }

    //
    // PUBLIC ONLY-OWNER
    //

    function changeOracle(address _oracle) public onlyOwner {
        oracleId = _oracle;
    }

    function changeJobId(string memory _jobId) public onlyOwner {
        jobId = _jobId;
    }

    function changeFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function changeToken(address _address) public onlyOwner {
        setChainlinkToken(_address);
    }

    //
    // PUBLIC VIEW
    //

    function getToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    function getInt256(bytes32 _requestId) public view returns (int256) {
       return toInt256(results[_requestId]);
    }

    //
    // INTERNAL PURE
    //

    function toInt256(bytes memory _bytes) 
    internal 
    pure
      returns (int256 value) {
          assembly {
            value := mload(add(_bytes, 0x20))
      }
   }

    //
    // PRIVATE PURE
    //

    //Converts first 32 bytes of input bytes
    function _bytesToBytes32(bytes memory source) private pure 
    returns (bytes32 result_) {
        if (source.length == 0) {
            return 0x0;
        }
        assembly {
            result_ := mload(add(source, 32))
        }
    }
}
