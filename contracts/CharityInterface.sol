// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
import './KYC.sol';
contract CharityInterface{
    IKycDapp kycDappContract;

    mapping(address => bool) public KYC; /// @dev Checks whether a particular user has a KYC or not
    mapping(address => bool) public Donors; /// @dev Checks whether a particular user is donor or not -->> testing
    mapping(address => bool) public Faithminers; /// @dev Checks whether a particular user is faithminer or not
    mapping(address => bool) public Daogoverners; /// @dev Checks whether a particular user is daogoverner
    
      
    modifier onlyKYC() {
        require(KYC[msg.sender], "KYC needs to be completed");
        _;
    }
    
    modifier onlyDonor() {
        require(Donors[msg.sender], "Should be Donor");
        require(kycDappContract.isKycLevel1(msg.sender), 'KYC Level 1 is not approved');
        _;
    }
    modifier onlyFaithminersAndDaogoverners() {
        require(Faithminers[msg.sender], "Should be FaithMiner");
        require(Daogoverners[msg.sender], "Should be FaithMiner");
        require(kycDappContract.isKycLevel2(msg.sender), 'KYC Level 2 is not approved');
        _;
    }
    
    modifier onlyKycApproved() {
        require(kycDappContract.isKycLevel1(msg.sender), 'KYC Level 1 is not approved');
        _;
    }

    modifier onlyKycLevel2Approved() {
        require(kycDappContract.isKycLevel2(msg.sender), 'KYC Level 2 is not approved');
        _;
    }
    
    function setKYC(address user) public{
        KYC[user] = true;
    }
    
    function setDonor(address user) public{
        Donors[user] = true;
    }
    
    function setFaithMiners(address user) public{
        Faithminers[user] = true;
    }
    
    function setDaoGoverners(address user) public{
        Daogoverners[user] = true;
    }
}